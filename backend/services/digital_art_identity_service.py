"""Business logic "verification engine": Art-to-Art (deteksi duplikat) +
Art-to-AI (deteksi AI-generated). Lihat CLAUDE.md "Skema Data Utama" domain 2
& "Riwayat Keputusan" #10 untuk konteks arsitektur.

Tanggung jawab file ini:
- Muat DUA sesi ONNX (``art_to_art.onnx``, ``art_to_ai.onnx``) SEKALI saat
  startup (lihat ``main.py`` lifespan) -- pola sama persis dgn
  ``VisualSearchService``, TAPI dua model INI TERPISAH dari model Visual
  Search (backbone beda, preprocessing beda, ruang vektor beda).
- Preprocessing gambar upload -> tensor, PERSIS mengikuti transform notebook
  masing-masing model (lihat komentar tiap fungsi -- kalau beda sedikit saja
  dari training, hasil model bisa meleset).
- Hitung fingerprint 1 karya: phash + embedding Art-to-Art + probabilitas
  Art-to-AI.
- Cari kandidat duplikat di katalog via pgvector L2 distance (BUKAN cosine --
  lihat catatan di ``models/verification.py``) + pemindaian pHash Hamming
  distance sebagai sinyal kedua yang independen.
- Orkestrasi ``verify()``: gabungkan semua sinyal di atas -> tulis baris
  ``karya_fingerprints`` (upsert) + ``karya_verifikasi_log`` (append-only,
  2 baris per pemanggilan) -- TAPI TIDAK melakukan ``db.commit()`` sendiri,
  itu tanggung jawab caller (router) supaya batas transaksi jelas di satu
  tempat.

CATATAN JUJUR (skala): inferensi ONNX di sini dipanggil SINKRON di dalam
method ``async`` (pola sama seperti ``VisualSearchService``) -- untuk lalu
lintas rendah/menengah ini aman, tapi di traffic tinggi akan memblokir event
loop FastAPI selama durasi inferensi. Kalau nanti jadi bottleneck nyata,
pindahkan panggilan ONNX ke ``run_in_executor``/thread pool -- BUKAN
prioritas sekarang, konsisten dgn keputusan yang sama di ``visual_search_service.py``.
"""

from __future__ import annotations

import uuid
from pathlib import Path

import imagehash
import numpy as np
from PIL import Image
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models.karya import Karya
from models.verification import HasilCek, KaryaFingerprint, KaryaVerifikasiLog, TipeCek

# Samakan persis dengan ml-digital-art-identity/configs/config.yaml
IMAGENET_MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
IMAGENET_STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)

ART_TO_ART_RESIZE = 256
ART_TO_ART_CROP = 224
ART_TO_AI_SIZE = 320

# Lihat ml-digital-art-identity/configs/config.yaml utk sumber & alasan tiap angka.
DEFAULT_DISTANCE_THRESHOLD = 0.10       # Euclidean, embedding ter-L2-normalize
DEFAULT_AI_PROBABILITY_THRESHOLD = 0.5
DEFAULT_PHASH_HAMMING_THRESHOLD = 5     # dari 64 bit -- BELUM dikalibrasi ROC, lihat config.yaml


class DigitalArtIdentityService:
    """Singleton-ish service: 1 instance dibuat saat startup, dipakai semua request."""

    def __init__(
        self,
        art_to_art_model_path: str | Path,
        art_to_ai_model_path: str | Path,
        distance_threshold: float = DEFAULT_DISTANCE_THRESHOLD,
        ai_probability_threshold: float = DEFAULT_AI_PROBABILITY_THRESHOLD,
        phash_hamming_threshold: int = DEFAULT_PHASH_HAMMING_THRESHOLD,
        art_to_art_model_version: str = "siamese_convnext_v1",
        art_to_ai_model_version: str = "convnext_ai_detector_v1",
    ) -> None:
        self.art_to_art_model_path = Path(art_to_art_model_path)
        self.art_to_ai_model_path = Path(art_to_ai_model_path)
        self.distance_threshold = distance_threshold
        self.ai_probability_threshold = ai_probability_threshold
        self.phash_hamming_threshold = phash_hamming_threshold
        self.art_to_art_model_version = art_to_art_model_version
        self.art_to_ai_model_version = art_to_ai_model_version
        self._art_to_art_session = None
        self._art_to_ai_session = None

    def load(self) -> None:
        """Panggil sekali di FastAPI startup event (lihat main.py lifespan)."""
        import onnxruntime as ort

        self._art_to_art_session = ort.InferenceSession(
            str(self.art_to_art_model_path), providers=["CPUExecutionProvider"]
        )
        self._art_to_ai_session = ort.InferenceSession(
            str(self.art_to_ai_model_path), providers=["CPUExecutionProvider"]
        )

    # ------------------------------------------------------------ preprocessing --

    def _preprocess_art_to_art(self, image: Image.Image) -> np.ndarray:
        """Resize(256,256, BICUBIC) -> CenterCrop(224) -> Normalize ImageNet.

        PERSIS ``eval_transforms`` di ``model_devArt.ipynb``. ``resize((256,256))``
        (tuple, bukan int tunggal) = squash ke persegi, BUKAN resize
        proporsional -- disengaja, mengikuti ``torchvision.transforms.Resize((256,256))``.
        """
        img = image.convert("RGB").resize((ART_TO_ART_RESIZE, ART_TO_ART_RESIZE), Image.BICUBIC)
        left = top = (ART_TO_ART_RESIZE - ART_TO_ART_CROP) // 2
        img = img.crop((left, top, left + ART_TO_ART_CROP, top + ART_TO_ART_CROP))
        x = np.asarray(img, dtype=np.float32) / 255.0
        x = (x - IMAGENET_MEAN) / IMAGENET_STD
        x = x.transpose(2, 0, 1)  # HWC -> CHW
        return x[None, ...].astype(np.float32)

    def _preprocess_art_to_ai(self, image: Image.Image) -> np.ndarray:
        """Resize(320,320) langsung (TANPA crop) -> Normalize ImageNet.

        PERSIS pipeline Albumentations ``model_devAI.ipynb``
        (``A.Resize`` + ``A.Normalize`` + ``ToTensorV2``). Interpolasi PIL
        BILINEAR dipakai sbg padanan ``cv2.INTER_LINEAR`` default Albumentations
        -- selisih numerik sangat kecil, sama seperti pendekatan yang sudah
        dipakai ``VisualSearchService`` (numpy/PIL murni, tanpa dependency
        training-stack di server).
        """
        img = image.convert("RGB").resize((ART_TO_AI_SIZE, ART_TO_AI_SIZE), Image.BILINEAR)
        x = np.asarray(img, dtype=np.float32) / 255.0
        x = (x - IMAGENET_MEAN) / IMAGENET_STD
        x = x.transpose(2, 0, 1)
        return x[None, ...].astype(np.float32)

    # --------------------------------------------------------------- inferensi --

    def embed_art_to_art(self, image: Image.Image) -> list[float]:
        """Embedding 512-d L2-normalized (sudah dinormalisasi di dalam graf ONNX,
        lihat ``ForwardOnceWrapper`` di ``ml-digital-art-identity/src/export.py``)."""
        if self._art_to_art_session is None:
            raise RuntimeError("Art-to-Art model belum di-load -- panggil load() saat startup.")
        x = self._preprocess_art_to_art(image)
        (out,) = self._art_to_art_session.run(["output"], {"image": x})
        return out[0].tolist()

    def predict_ai_generated(self, image: Image.Image) -> float:
        """Probabilitas 0..1 "kemungkinan AI-generated" (sigmoid sudah diterapkan
        di dalam graf ONNX, lihat ``SigmoidWrapper`` di ``src/export.py``)."""
        if self._art_to_ai_session is None:
            raise RuntimeError("Art-to-AI model belum di-load -- panggil load() saat startup.")
        x = self._preprocess_art_to_ai(image)
        (out,) = self._art_to_ai_session.run(["output"], {"image": x})
        return float(out[0][0])

    @staticmethod
    def compute_phash(image: Image.Image) -> str:
        """PERSIS ``str(imagehash.phash(img))`` di ``model_devArt.ipynb``."""
        return str(imagehash.phash(image.convert("RGB")))

    # ----------------------------------------------------------- pencarian duplikat --

    async def _query_embedding_neighbors(
        self, embedding: list[float], db: AsyncSession, exclude_karya_id: uuid.UUID | None, top_k: int
    ) -> list[dict]:
        """Nearest-neighbor via pgvector L2 distance (Euclidean) -- lihat
        ``models/verification.py`` kenapa L2, bukan cosine.
        """
        distance_expr = KaryaFingerprint.embedding_arttoart.l2_distance(embedding)
        stmt = (
            select(Karya, distance_expr.label("distance"))
            .join(KaryaFingerprint, KaryaFingerprint.karya_id == Karya.id)
            .order_by(distance_expr)
            .limit(top_k)
        )
        if exclude_karya_id is not None:
            stmt = stmt.where(Karya.id != exclude_karya_id)
        rows = (await db.execute(stmt)).all()
        return [
            {
                "karya_id": karya.id,
                "distance": float(distance),
                "title": karya.title,
                "artist_name": karya.artist_name,
                "image_filename": karya.image_filename,
            }
            for karya, distance in rows
        ]

    async def _query_phash_neighbors(
        self, phash: str, db: AsyncSession, exclude_karya_id: uuid.UUID | None
    ) -> list[dict]:
        """Pemindaian Hamming distance FULL-TABLE terhadap kolom ``phash``
        (TEXT, murah -- bukan kolom vector 512-d) -- Postgres tidak punya
        index native untuk Hamming distance string sembarang, jadi
        dihitung di Python. AMAN untuk skala ratusan-ribuan karya (cuma 2
        kolom di-fetch); kalau katalog membesar jauh (>100k), perlu index
        khusus (LSH/BK-tree) -- BELUM diimplementasikan, di luar scope saat ini
        (sama filosofinya dgn keputusan pgvector-vs-FAISS di CLAUDE.md).
        """
        stmt = select(KaryaFingerprint.karya_id, KaryaFingerprint.phash)
        if exclude_karya_id is not None:
            stmt = stmt.where(KaryaFingerprint.karya_id != exclude_karya_id)
        rows = (await db.execute(stmt)).all()

        query_hash = imagehash.hex_to_hash(phash)
        matches: list[dict] = []
        for karya_id, other_phash in rows:
            try:
                distance = query_hash - imagehash.hex_to_hash(other_phash)
            except ValueError:
                continue  # phash lama format beda (mis. hash_size lain) -- lewati, bukan crash
            if distance <= self.phash_hamming_threshold:
                matches.append({"karya_id": karya_id, "hamming_distance": int(distance)})
        matches.sort(key=lambda m: m["hamming_distance"])
        return matches

    # -------------------------------------------------------------------- verify --

    async def verify(
        self,
        image: Image.Image,
        db: AsyncSession,
        karya_id: uuid.UUID | None = None,
        persist: bool = True,
        top_k: int = 5,
    ) -> dict:
        """Jalankan Art-to-Art + Art-to-AI atas 1 gambar, opsional simpan hasilnya.

        ``karya_id``:
            - Diisi (karya sudah ada di tabel ``karya``) -> hasil BISA di-``persist``
              (upsert ``karya_fingerprints`` + insert 2 baris ``karya_verifikasi_log``),
              dan pencarian duplikat mengecualikan karya itu sendiri.
            - ``None`` -> mode pratinjau (mis. cek sebelum submit form upload),
              ``persist`` dipaksa ``False`` (tidak ada baris karya untuk digantungi FK).

        TIDAK memanggil ``db.commit()`` -- caller (router) yang menentukan
        kapan transaksi selesai.

        Return dict siap dipetakan ke ``schemas.verification.VerificationResult``.
        """
        if karya_id is None:
            persist = False

        phash = self.compute_phash(image)
        embedding = self.embed_art_to_art(image)
        ai_probability = self.predict_ai_generated(image)
        ai_flag = ai_probability >= self.ai_probability_threshold

        embedding_matches = await self._query_embedding_neighbors(embedding, db, karya_id, top_k)
        phash_matches = await self._query_phash_neighbors(phash, db, karya_id)

        embedding_triggered = bool(embedding_matches) and embedding_matches[0]["distance"] <= self.distance_threshold
        phash_triggered = bool(phash_matches)
        is_duplicate = embedding_triggered or phash_triggered

        # pHash near-exact match = sinyal lebih literal ("kemungkinan file yang
        # sama persis") drpd jarak embedding -- diprioritaskan untuk pelaporan
        # kalau dua-duanya menyala. Kalau cuma satu yang menyala, pakai itu.
        if phash_triggered:
            referensi_karya_id = phash_matches[0]["karya_id"]
            art_to_art_skor = float(phash_matches[0]["hamming_distance"])
            art_to_art_catatan = f"pHash Hamming distance={phash_matches[0]['hamming_distance']}"
        elif embedding_triggered:
            referensi_karya_id = embedding_matches[0]["karya_id"]
            art_to_art_skor = embedding_matches[0]["distance"]
            art_to_art_catatan = None
        else:
            referensi_karya_id = None
            art_to_art_skor = embedding_matches[0]["distance"] if embedding_matches else None
            art_to_art_catatan = None

        art_to_art_hasil = HasilCek.DUPLIKAT_TERDETEKSI if is_duplicate else HasilCek.LOLOS
        art_to_ai_hasil = HasilCek.AI_GENERATED_TERDETEKSI if ai_flag else HasilCek.LOLOS

        rekomendasi_status = _decide_status(
            is_duplicate=is_duplicate,
            phash_triggered=phash_triggered,
            embedding_distance=embedding_matches[0]["distance"] if embedding_matches else None,
            distance_threshold=self.distance_threshold,
            ai_flag=ai_flag,
        )

        if persist:
            await self._persist(
                karya_id=karya_id,
                phash=phash,
                embedding=embedding,
                ai_probability=ai_probability,
                ai_flag=ai_flag,
                art_to_art_hasil=art_to_art_hasil,
                art_to_art_skor=art_to_art_skor,
                art_to_art_catatan=art_to_art_catatan,
                referensi_karya_id=referensi_karya_id,
                art_to_ai_hasil=art_to_ai_hasil,
                db=db,
            )

        return {
            "art_to_art_result": art_to_art_hasil.value,
            "ai_detection_result": art_to_ai_hasil.value,
            "rekomendasi_status": rekomendasi_status,
            "ai_generated_probability": ai_probability,
            "phash": phash,
            "duplicate_matches": [
                {
                    "karya_id": str(m["karya_id"]),
                    "distance": m["distance"],
                    "title": m["title"],
                    "artist_name": m["artist_name"],
                    "image_filename": m["image_filename"],
                }
                for m in embedding_matches
            ],
            "model_version_arttoart": self.art_to_art_model_version,
            "model_version_arttoai": self.art_to_ai_model_version,
        }

    async def _persist(
        self,
        *,
        karya_id: uuid.UUID,
        phash: str,
        embedding: list[float],
        ai_probability: float,
        ai_flag: bool,
        art_to_art_hasil: HasilCek,
        art_to_art_skor: float | None,
        art_to_art_catatan: str | None,
        referensi_karya_id: uuid.UUID | None,
        art_to_ai_hasil: HasilCek,
        db: AsyncSession,
    ) -> None:
        existing = await db.get(KaryaFingerprint, karya_id)
        if existing is None:
            db.add(
                KaryaFingerprint(
                    karya_id=karya_id,
                    phash=phash,
                    embedding_arttoart=embedding,
                    ai_generated_probability=ai_probability,
                    ai_generated_flag=ai_flag,
                    model_version_arttoart=self.art_to_art_model_version,
                    model_version_arttoai=self.art_to_ai_model_version,
                )
            )
        else:
            # Re-verifikasi (mis. karya di-upload ulang) -- TIMPA snapshot
            # terbaru di sini (bukan append-only, beda dari karya_verifikasi_log
            # di bawah -- lihat docstring KaryaFingerprint).
            existing.phash = phash
            existing.embedding_arttoart = embedding
            existing.ai_generated_probability = ai_probability
            existing.ai_generated_flag = ai_flag
            existing.model_version_arttoart = self.art_to_art_model_version
            existing.model_version_arttoai = self.art_to_ai_model_version

        db.add(
            KaryaVerifikasiLog(
                id=uuid.uuid4(),
                karya_id=karya_id,
                tipe_cek=TipeCek.ART_TO_ART,
                hasil=art_to_art_hasil,
                skor=art_to_art_skor,
                referensi_karya_id=referensi_karya_id,
                catatan=art_to_art_catatan,
            )
        )
        db.add(
            KaryaVerifikasiLog(
                id=uuid.uuid4(),
                karya_id=karya_id,
                tipe_cek=TipeCek.ART_TO_AI,
                hasil=art_to_ai_hasil,
                skor=ai_probability,
                referensi_karya_id=None,
                catatan=None,
            )
        )
        await db.flush()


def _decide_status(
    *,
    is_duplicate: bool,
    phash_triggered: bool,
    embedding_distance: float | None,
    distance_threshold: float,
    ai_flag: bool,
) -> str:
    """Heuristik rekomendasi status verifikasi -- BUKAN keputusan final
    otomatis, cuma rekomendasi yang perlu direview manusia untuk kasus abu-abu.

    Aturan (sengaja konservatif, lihat CLAUDE.md "jangan overclaim"):
    - Duplikat yang SANGAT jelas (pHash near-exact ATAU jarak embedding jauh
      di bawah threshold) -> "ditolak" otomatis, sinyalnya kuat sekali.
    - Duplikat borderline (jarak embedding dekat dgn threshold) -> "perlu_ditinjau",
      jangan auto-tolak kasus yang masih bisa salah.
    - AI-generated terdeteksi -> SELALU "perlu_ditinjau", TIDAK PERNAH
      auto-tolak -- tuduhan "karya ini AI-generated" ke seniman yang salah
      (false positive) merusak reputasi & kepercayaan jauh lebih parah drpd
      biaya 1 review manual tambahan.
    - Bersih semua -> "terverifikasi".

    NOTE implementasi: hasil ini belum ditulis ke ``karya.status_verifikasi``
    (kolom itu belum ada -- lihat CLAUDE.md Fase 1 Auth). Caller yang punya
    akses ke kolom itu nanti yang menerapkan rekomendasi ini.
    """
    if is_duplicate:
        very_confident = phash_triggered or (
            embedding_distance is not None and embedding_distance <= distance_threshold / 2
        )
        if very_confident:
            return "ditolak"
        return "perlu_ditinjau"
    if ai_flag:
        return "perlu_ditinjau"
    return "terverifikasi"
