"""Business logic Visual Search: muat model sekali saat startup, layani inferensi.

Tanggung jawab file ini:
- Muat ``model.onnx`` (ONNXRuntime, bukan PyTorch -- server tidak perlu
  training stack penuh) SEKALI saat aplikasi start (lihat ``main.py`` --
  jangan reload per-request).
- Preprocessing gambar upload -> tensor (SquarePad + resize 224 + normalize
  ImageNet) IDENTIK dengan ``ml-visual-search/src/transforms.py``
  (``build_eval_transforms`` dgn ``pad_to_square=true``: SquarePad mode
  "edge" -> Resize langsung ke 224x224, TANPA center-crop). Kalau
  preprocessing di sini beda sedikit saja dari training, hasil model bisa
  meleset -- pastikan konstanta (mean/std/ukuran) disalin dari
  ``ml-visual-search/configs/config.yaml``, jangan ditebak ulang.
- Cari nearest-neighbor ke katalog via pgvector (tabel ``karya_embeddings``,
  bukan lagi file ``.npz`` statis -- katalog sekarang di database) + hitung
  ``confidence_verdict`` (logic copy persis dari
  ``ml-visual-search/src/embedding.py``, supaya jawaban ke user konsisten
  dengan yang sudah divalidasi di notebook demo).

Catatan penting: ``model.onnx`` HANYA expose embedding (L2-normalized),
TIDAK expose logit klasifikasi style -- jadi ``style_predictions`` di
response selalu kosong untuk sekarang (butuh re-export model dgn output
tambahan kalau nanti mau diisi).

Artefak yang dikonsumsi (hasil dari ``ml-visual-search/``):
    ../ml-visual-search/export/model.onnx
"""

from __future__ import annotations

import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models.karya import Karya, KaryaEmbedding

# Samakan persis dengan ml-visual-search/configs/config.yaml [image]
IMAGE_SIZE = 224
IMAGENET_MEAN = (0.485, 0.456, 0.406)
IMAGENET_STD = (0.229, 0.224, 0.225)

# Sama persis dgn ml-visual-search/src/embedding.py::confidence_verdict.
_SURE_THRESHOLD = 0.85
_MAYBE_THRESHOLD = 0.6
_MIN_GAP = 0.05

_VERDICT_MESSAGES = {
    "confirmed": "Karya ini kemungkinan besar ada di katalog GALERIA.",
    "ambiguous": (
        "Ditemukan karya yang mirip, tapi belum tentu sama persis -- "
        "cek detail kandidat di bawah sebelum yakin."
    ),
    "not_found": "Karya ini sepertinya belum ada di katalog GALERIA.",
}


def confidence_verdict(
    scores: list[float],
    sure_threshold: float = _SURE_THRESHOLD,
    maybe_threshold: float = _MAYBE_THRESHOLD,
    min_gap: float = _MIN_GAP,
) -> str:
    """Copy persis dari ``ml-visual-search/src/embedding.py`` (jangan diubah
    tanpa mengubah juga versi aslinya di ml-visual-search/, supaya perilaku
    tetap konsisten dgn yang sudah divalidasi di notebook demo).
    """
    if not scores:
        return "not_found"
    top1 = float(scores[0])
    gap = top1 - float(scores[1]) if len(scores) > 1 else top1
    if top1 >= sure_threshold and gap >= min_gap:
        return "confirmed"
    if top1 >= maybe_threshold:
        return "ambiguous"
    return "not_found"


def _auto_detect_bbox(
    image: Image.Image, min_area_frac: float = 0.04, max_area_frac: float = 0.92
) -> tuple[int, int, int, int] | None:
    """Heuristik cari kotak pembungkus area paling TERANG vs latar (BUKAN
    model AI -- threshold Otsu + contour klasik). Port persis dari
    ``ml-visual-search/notebooks/03_demo_inference.ipynb::_auto_detect_bbox``.

    TERBUKTI TIDAK STABIL di kondisi lapangan (lihat catatan di
    ``_candidate_crops``) -- goyah tergantung pencahayaan/pantulan/sudut
    kecil. JANGAN dipakai sebagai satu-satunya sumber crop lagi -- cuma
    salah satu dari beberapa kandidat yang dicoba, similarity tertinggi yang
    menang.

    Return ``(x, y, w, h)`` atau ``None`` kalau tidak ketemu kandidat yang
    masuk akal.
    """
    arr = np.asarray(image.convert("RGB"))
    gray = cv2.cvtColor(arr, cv2.COLOR_RGB2GRAY)
    gray = cv2.GaussianBlur(gray, (7, 7), 0)
    _, thresh = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    thresh = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, np.ones((15, 15), np.uint8))
    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not contours:
        return None

    h_frame, w_frame = arr.shape[:2]
    frame_area = h_frame * w_frame
    best: tuple[int, int, int, int] | None = None
    best_area = 0.0
    for cnt in contours:
        area = cv2.contourArea(cnt)
        if area < min_area_frac * frame_area or area > max_area_frac * frame_area:
            continue
        if area > best_area:
            best_area = area
            best = cv2.boundingRect(cnt)
    return best


def _center_crop_bracket(image: Image.Image) -> Image.Image:
    """Crop tengah DETERMINISTIK sesuai proporsi bracket panduan yang
    ditampilkan di layar (82% dimensi pendek, aspect ~4:5 -- lihat
    ``visual_search_camera_screen.dart``). Beda dari
    :func:`_auto_detect_bbox`: hasil ini SELALU sama untuk framing yang sama
    -- tidak bergantung pencahayaan/kontras -- karena user yang mengontrol
    lewat framing kamera (mereka LIHAT bracket-nya di layar), bukan algoritma
    yang menebak.
    """
    w_img, h_img = image.size
    short_side = min(w_img, h_img)
    crop_w = min(int(short_side * 0.82), w_img)
    crop_h = min(int(crop_w * 5 / 4), h_img)
    crop_w = min(crop_w, int(crop_h * 4 / 5))
    cx, cy = w_img // 2, h_img // 2
    x0 = max(0, cx - crop_w // 2)
    y0 = max(0, cy - crop_h // 2)
    return image.crop((x0, y0, x0 + crop_w, y0 + crop_h))


def _hint_crop(
    image: Image.Image, hint_rect: tuple[float, float, float, float]
) -> Image.Image | None:
    """Crop sesuai kotak hijau live-detect yang USER SENDIRI lihat di layar
    saat membidik sebelum menekan shutter (fraksi 0..1 relatif ukuran foto,
    dikirim dari mobile -- lihat
    ``camera_preview_layer.dart::_detectBrightRegion`` +
    ``visual_search_camera_screen.dart::_scan``).

    Ini kandidat PALING RELEVAN dari semuanya: bukan tebakan algoritma
    server, tapi framing yang sudah dikonfirmasi visual oleh user. Dikasih
    padding 12% tiap sisi supaya toleran kalau kotak live sedikit lebih
    ketat dari objek sebenarnya (deteksi live jalan di frame preview
    resolusi rendah, sedikit meleset dari batas asli objek itu wajar).
    """
    left, top, width, height = hint_rect
    pad_x, pad_y = width * 0.12, height * 0.12
    left = max(0.0, left - pad_x)
    top = max(0.0, top - pad_y)
    right = min(1.0, left + width + 2 * pad_x)
    bottom = min(1.0, top + height + 2 * pad_y)
    if right - left < 0.05 or bottom - top < 0.05:
        return None

    w_img, h_img = image.size
    box = (
        int(left * w_img),
        int(top * h_img),
        int(right * w_img),
        int(bottom * h_img),
    )
    return image.crop(box)


def _candidate_crops(
    image: Image.Image,
    hint_rect: tuple[float, float, float, float] | None = None,
) -> list[tuple[str, Image.Image]]:
    """Beberapa strategi crop dicoba SEKALIGUS tiap scan, bukan cuma
    andalkan 1 metode -- similarity tertinggi dari semua kandidat yang
    dipakai jadi hasil akhir (lihat ``VisualSearchService.search``).

    Kenapa: log lapangan menunjukkan :func:`_auto_detect_bbox` TIDAK STABIL
    -- similarity untuk scan yang niatnya sama bisa 0.09 di satu percobaan,
    0.74 di percobaan lain, cuma beda pencahayaan/sudut kecil. Daripada
    andalkan satu heuristik yang goyah, coba beberapa & ambil yang terbaik:
    0. Kotak hijau live-detect yang user lihat & konfirmasi sendiri sebelum
       menekan shutter (kalau dikirim) -- prioritas tertinggi, lihat
       :func:`_hint_crop`.
    1. Foto penuh (baseline paling aman, tanpa crop apa pun)
    2. Auto-detect Otsu+contour (kalau ketemu) -- bisa sangat bagus (pernah
       kasih 0.832) tapi tidak selalu
    3. Center-crop deterministik sesuai bracket panduan (82% dimensi pendek,
       aspect 4:5) -- prediktif, dikontrol user lewat framing yang mereka
       lihat sendiri di layar

    Return list ``(label, image)`` -- label dipasangkan langsung ke gambar
    yang bersangkutan (bukan zip terpisah dgn daftar label tetap) supaya
    tidak salah label kalau salah satu kandidat tidak ketemu (mis. label
    "auto-detect" pernah salah tertempel ke center-crop saat auto-detect
    gagal, karena zip lama pakai indeks posisi, bukan nama).
    """
    candidates: list[tuple[str, Image.Image]] = []

    if hint_rect is not None:
        hint = _hint_crop(image, hint_rect)
        if hint is not None:
            candidates.append(("live-hint", hint))

    candidates.append(("full-frame", image))

    bbox = _auto_detect_bbox(image)
    if bbox is not None:
        x, y, w, h = bbox
        candidates.append(("auto-detect", image.crop((x, y, x + w, y + h))))

    candidates.append(("center-crop", _center_crop_bracket(image)))
    return candidates


class VisualSearchService:
    """Singleton-ish service: 1 instance dibuat saat startup, dipakai semua request."""

    def __init__(self, model_path: str | Path, label_map_path: str | Path) -> None:
        self.model_path = Path(model_path)
        self.label_map_path = Path(label_map_path)
        self._session = None  # onnxruntime.InferenceSession, di-set di load()
        self._idx_to_label: dict[int, str] | None = None

    def load(self) -> None:
        """Panggil sekali di FastAPI startup event (lihat main.py lifespan)."""
        import onnxruntime as ort

        self._session = ort.InferenceSession(
            str(self.model_path), providers=["CPUExecutionProvider"]
        )
        # Label map disimpan tapi TIDAK dipakai untuk prediksi -- model.onnx
        # tidak expose logit klasifikasi (lihat catatan di atas). Disiapkan
        # untuk kemungkinan pemakaian lain / re-export model di masa depan.
        if self.label_map_path.exists():
            label_to_idx = json.loads(self.label_map_path.read_text())
            self._idx_to_label = {v: k for k, v in label_to_idx.items()}

    def _preprocess(self, image: Image.Image) -> np.ndarray:
        """SquarePad (mode edge, replikasi piksel tepi) -> resize langsung ke
        224x224 -> normalize ImageNet. Padding pakai numpy (bukan torchvision)
        supaya server tidak perlu dependency PyTorch/torchvision.

        TIDAK lagi melakukan crop/auto-detect di sini -- caller
        (``search()``) yang menentukan kandidat crop mana yang dikirim (lihat
        :func:`_candidate_crops`), supaya method ini murni "1 gambar -> 1
        tensor" dan bisa dipanggil berkali-kali dgn kandidat crop berbeda.

        Selalu pad-to-square (beda dari pipeline katalog training yang
        ``pad_to_square=false`` krn sudah pre-padded) -- penting utk foto HP
        asli yang rasio aspeknya sembarang, dan no-op aman utk gambar yang
        kebetulan sudah persegi.
        """
        arr = np.asarray(image.convert("RGB"), dtype=np.uint8)  # (H, W, 3)
        h, w = arr.shape[:2]
        side = max(h, w)
        pad_top = (side - h) // 2
        pad_bottom = side - h - pad_top
        pad_left = (side - w) // 2
        pad_right = side - w - pad_left
        arr = np.pad(
            arr,
            ((pad_top, pad_bottom), (pad_left, pad_right), (0, 0)),
            mode="edge",
        )

        img = Image.fromarray(arr).resize((IMAGE_SIZE, IMAGE_SIZE), Image.BILINEAR)
        x = np.asarray(img, dtype=np.float32) / 255.0  # (224, 224, 3), 0..1

        mean = np.array(IMAGENET_MEAN, dtype=np.float32)
        std = np.array(IMAGENET_STD, dtype=np.float32)
        x = (x - mean) / std

        x = x.transpose(2, 0, 1)  # HWC -> CHW
        return x[None, ...].astype(np.float32)  # (1, 3, 224, 224)

    def embed(self, image: Image.Image) -> list[float]:
        """Preprocess + inferensi ONNX -> embedding L2-normalized (768,).

        Dipakai dua tempat: ``search()`` (query dari upload user) dan
        ``scripts/seed_karya.py`` (hitung embedding katalog awal) -- supaya
        keduanya lewat pipeline preprocessing yang PERSIS SAMA.
        """
        if self._session is None:
            raise RuntimeError(
                "Model belum di-load -- pastikan load() dipanggil saat startup "
                "(lihat main.py lifespan)."
            )
        x = self._preprocess(image)
        result = self._session.run(None, {"image": x})[0]
        return result[0].tolist()

    async def search(
        self,
        image: Image.Image,
        db: AsyncSession,
        top_k: int = 5,
        hint_rect: tuple[float, float, float, float] | None = None,
    ) -> dict:
        """Coba beberapa kandidat crop (lihat :func:`_candidate_crops`), cari
        kecocokan katalog via pgvector cosine distance utk MASING-MASING
        kandidat, lalu pakai kandidat dgn similarity top-1 TERTINGGI sebagai
        hasil akhir -- bukan cuma andalkan 1 crop (lihat catatan
        ``_candidate_crops`` soal auto-detect yang terbukti tidak stabil).

        ``hint_rect`` (opsional): kotak hijau live-detect yang user lihat &
        konfirmasi sendiri sebelum menekan shutter (fraksi 0..1: left, top,
        width, height) -- lihat :func:`_hint_crop`.

        Return dict siap dipetakan ke ``schemas.visual_search.VisualSearchResponse``.
        """
        best_matches: list[dict] = []
        best_similarities: list[float] = []
        best_crop_label = "full-frame"

        for label, candidate in _candidate_crops(image, hint_rect):
            embedding = self.embed(candidate)
            matches, similarities = await self._query_catalog(embedding, db, top_k)
            if not best_similarities or (
                similarities and similarities[0] > best_similarities[0]
            ):
                best_matches, best_similarities = matches, similarities
                best_crop_label = label

        verdict = confidence_verdict(best_similarities)
        return {
            "style_predictions": [],  # TODO: butuh re-export ONNX dgn output logit
            "catalog_matches": best_matches,
            "verdict": verdict,
            "verdict_message": _VERDICT_MESSAGES[verdict],
        }

    async def _query_catalog(
        self, query_embedding: list[float], db: AsyncSession, top_k: int
    ) -> tuple[list[dict], list[float]]:
        """Query `karya_embeddings` via pgvector cosine distance utk 1 embedding
        query. Dipisah dari `search()` supaya bisa dipanggil berkali-kali
        (1x per kandidat crop) tanpa duplikasi logic.
        """
        distance_expr = KaryaEmbedding.embedding.cosine_distance(query_embedding)
        stmt = (
            select(Karya, distance_expr.label("distance"))
            .join(KaryaEmbedding, KaryaEmbedding.karya_id == Karya.id)
            .order_by(distance_expr)
            .limit(top_k)
        )
        rows = (await db.execute(stmt)).all()

        matches: list[dict] = []
        similarities: list[float] = []
        for karya, distance in rows:
            # pgvector cosine_distance = 1 - cosine_similarity (embedding
            # sudah L2-normalized di training, lihat ml-visual-search).
            similarity = 1.0 - float(distance)
            similarities.append(similarity)
            matches.append(
                {
                    "karya_id": str(karya.id),
                    "similarity": similarity,
                    "title": karya.title,
                    "artist_name": karya.artist_name,
                    "style_name": karya.style_name,
                    "gallery_name": karya.gallery_name,
                    "price_idr": karya.price_idr,
                    "image_filename": karya.image_filename,
                }
            )
        return matches, similarities
