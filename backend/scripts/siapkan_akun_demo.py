"""Akun DEMO seniman yang sudah ramai (karya, penjualan 6 bulan, ulasan) untuk screenshot mockup.

Semua baris ditandai domain email ``@demo.galeria.test`` (1 seniman + 12 pembeli) sehingga bisa dihapus
bersih. Ini DATA CONTOH di database yang sama dengan data asli: jangan dipakai untuk klaim performa.

    python -m scripts.siapkan_akun_demo           # buat
    python -m scripts.siapkan_akun_demo --hapus   # hapus semua data demo (juga gambar di R2)

Yang dibuat: 26 karya terverifikasi (15 terjual/selesai tersebar ~6 bulan, 5 pesanan berjalan, 6 tersedia),
12 ulasan (sentimen dihitung model ringan yang sama dengan aplikasi), kepemilikan, langganan PRO.
Transaksi & sertifikat ditandatangani dengan signing key aktif (butuh SIGNING_PRIVATE_KEY_V1 di .env).
CATATAN: sertifikat keaslian demo diterbitkan langsung, TANPA menjalankan model Art-to-Art/Art-to-AI.
"""

from __future__ import annotations

import asyncio
import hashlib
import io
import random
import sys
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

from PIL import Image
from sqlalchemy import delete, select, text

from database import _session_factory, engine
from models.engagement import PlanSubscription, StatusSubscription, Subscription
from models.karya import Karya, StatusVerifikasiKarya
from models.sertifikat import SigningKey
from models.transaksi import KepemilikanKarya, StatusTransaksi as S, SumberKepemilikan, Transaksi
from models.ulasan import Ulasan
from models.user import AlamatPengiriman, User, UserRole
from services import auth_service, sentimen_ringan, storage
from services.kripto import format_waktu_kanonik, hitung_payload_hash, muat_private_key, tanda_tangani
from services.sertifikat_service import terbitkan_sertifikat

DOMAIN = "@demo.galeria.test"
PASSWORD = "Galeria2026"
SENIMAN_EMAIL = f"aria.wijaya{DOMAIN}"
ASET = Path(__file__).resolve().parents[2] / "mobile" / "assets" / "images" / "catalog"
KOMISI = 0.10
NOW = datetime.now(timezone.utc)

PEMBELI = [
    "Budi Santoso", "Citra Lestari", "Dimas Prakoso", "Eka Putri", "Farhan Hidayat", "Gita Anggraini",
    "Hendra Wijaya", "Indah Permata", "Joko Susilo", "Kartika Sari", "Lukman Hakim", "Maya Kusuma",
]
KOTA = [("Surabaya", "60275"), ("Malang", "65111"), ("Sidoarjo", "61219"), ("Jakarta Selatan", "12730"), ("Bandung", "40115")]

# (berkas, gaya)
DASAR = [
    ("impressionism_01.jpg", "Impressionism"), ("romanticism_01.jpg", "Romanticism"), ("cubism_01.jpg", "Cubism"),
    ("expressionism_01.jpg", "Expressionism"), ("post_impressionism_01.jpg", "Post Impressionism"),
    ("baroque_01.jpg", "Baroque"), ("art_nouveau_01.jpg", "Art Nouveau"), ("symbolism_01.jpg", "Symbolism"),
]
JUDUL = [
    "Senja di Teluk", "Lanskap Badai", "Komposisi Abstrak", "Jeritan Sunyi", "Taman Pagi", "Potret Sang Penari",
    "Gelombang Merah", "Kabut Gunung Bromo", "Pasar Pagi", "Bayangan Senja", "Nyala Lilin", "Sawah Berembun",
    "Perahu Nelayan", "Tarian Cahaya", "Kota Tua", "Hujan di Jendela", "Bunga Teratai", "Musim Panen",
    "Lorong Sunyi", "Fajar di Pesisir", "Kereta Malam", "Wajah Perempuan Jawa", "Ladang Jingga", "Dermaga Kecil",
    "Pantulan Bulan", "Rumah Joglo",
]
HARGA = [2_500_000, 4_200_000, 1_800_000, 3_600_000, 5_500_000, 2_900_000, 7_800_000, 3_100_000, 1_500_000, 6_400_000,
         2_200_000, 4_800_000, 9_500_000, 3_300_000, 2_700_000, 5_100_000, 1_950_000, 8_200_000, 3_900_000, 2_450_000,
         4_600_000, 6_900_000, 2_050_000, 3_450_000, 5_800_000, 4_100_000]
# hari yang lalu pesanan SELESAI (15 penjualan, tren naik)
HARI_SELESAI = [172, 155, 141, 126, 112, 99, 84, 70, 58, 47, 36, 26, 17, 9, 1]
ULASAN = [  # (rating, teks)
    (5, "Lukisannya luar biasa indah, warnanya persis seperti di foto. Pengiriman rapi dan aman. Sangat puas!"),
    (5, "Karya yang bagus sekali dan elegan, cocok untuk ruang tamu. Seniman ramah dan cepat merespons. Rekomendasi!"),
    (4, "Kualitas lukisan sangat bagus dan detailnya halus. Pengemasan aman, hanya pengiriman sedikit lebih lama dari perkiraan."),
    (5, "Mantap, sesuai deskripsi dan sertifikat keaslian jelas. Terima kasih, pasti beli lagi."),
    (4, "Bagus dan sesuai ekspektasi, warnanya hidup. Puas dengan pembelian ini."),
    (5, "Sangat memuaskan, karya ini jadi pusat perhatian di rumah kami. Pelayanan seniman sangat baik."),
    (3, "Karyanya lumayan, sesuai gambar. Tapi ukurannya terasa sedikit lebih kecil dari bayangan saya."),
    (4, "Lukisan cantik dan berkualitas, kemasan kayu aman. Proses pembelian mudah."),
    (5, "Indah banget, goresannya terasa hidup. Worth it dengan harganya, sangat direkomendasikan."),
    (3, "Biasa saja, cukup sesuai deskripsi. Pengiriman agak lama tapi barang sampai dengan selamat."),
    (2, "Kurang sesuai harapan, warna aslinya lebih pudar dari foto dan pengiriman terlambat. Agak kecewa."),
    (5, "Hasilnya bagus dan rapi, seniman sangat profesional. Terima kasih banyak!"),
]
KURIR = ["JNE", "J&T Express", "SiCepat", "Tiki"]


def _varian(berkas: str, i: int, rnd: random.Random) -> bytes:
    """Gambar untuk karya demo ke-``i``: SATU LUKISAN BERBEDA dari subset WikiArt, dengan aliran yang sama
    seperti ``berkas`` di ``DASAR``. (Dulu: potongan acak dari 8 gambar dasar -> banyak karya tampak kembar.)
    Bila dataset WikiArt lokal tidak ada, jatuh ke cara lama (potongan gambar dasar)."""
    try:
        from scripts import gambar_wikiart

        return gambar_wikiart.ambil(rnd, dict(DASAR)[berkas])
    except SystemExit:
        raise
    except Exception:  # noqa: BLE001 - cadangan: cara lama
        pass
    im = Image.open(ASET / berkas).convert("RGB")
    w, h = im.size
    if i >= len(DASAR):  # putaran ke-2+: potong sebagian
        fx, fy = rnd.uniform(0.55, 0.85), rnd.uniform(0.55, 0.85)
        cw, ch = int(w * fx), int(h * fy)
        x, y = rnd.randint(0, w - cw), rnd.randint(0, h - ch)
        im = im.crop((x, y, x + cw, y + ch))
        if rnd.random() < 0.5:
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
    im.thumbnail((1400, 1400))
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=88)
    return buf.getvalue()


async def _tanda_tangan_transaksi(db, key: SigningKey, karya: Karya, pembeli: User, harga: int, dibuat: datetime) -> Transaksi:
    """Sama dengan services.transaksi_service.buat_transaksi, tapi ``dibuat_pada`` bertanggal mundur."""
    tid = uuid.uuid4()
    komisi = round(harga * KOMISI)
    payload = {
        "schema": "transaksi.v1", "transaksi_id": str(tid), "karya_id": str(karya.id), "pembeli_id": str(pembeli.id),
        "penjual_id": str(karya.seniman_id), "harga_final_idr": harga, "komisi_platform_idr": komisi,
        "dibuat_pada": format_waktu_kanonik(dibuat),
    }
    ph = hitung_payload_hash(payload)
    t = Transaksi(
        id=tid, karya_id=karya.id, pembeli_id=pembeli.id, penjual_id=karya.seniman_id, harga_final_idr=harga,
        komisi_platform_idr=komisi, status=S.MENUNGGU_PEMBAYARAN, payload_hash=ph,
        digital_signature=tanda_tangani(ph, muat_private_key(key.kms_key_ref)), signing_key_id=key.id, created_at=dibuat,
    )
    db.add(t)
    await db.flush()
    return t


def _isi_siklus(t: Transaksi, alamat: AlamatPengiriman, tahap: str, dibuat: datetime, rnd: random.Random, pesan: str) -> None:
    """tahap: menunggu | dibayar | dikonfirmasi | dikirim | selesai. ``dibuat`` = waktu pesanan dibuat."""
    t.alamat_snapshot = {"label": alamat.label, "nama_penerima": alamat.nama_penerima, "telepon": alamat.telepon,
                         "alamat_lengkap": alamat.alamat_lengkap, "kota": alamat.kota, "kode_pos": alamat.kode_pos}
    t.batas_bayar_at = dibuat + timedelta(hours=24)
    t.metode_pembayaran = rnd.choice(["va_bca", "va_mandiri", "qris", "va_bni"])
    t.referensi_pembayaran = f"DEMO{rnd.randint(10**9, 10**10 - 1)}"
    if tahap == "menunggu":
        t.status = S.MENUNGGU_PEMBAYARAN
        return
    t.dibayar_at = dibuat + timedelta(hours=rnd.randint(1, 8))
    t.status = S.DIBAYAR
    if tahap == "dibayar":
        return
    t.dikonfirmasi_at = t.dibayar_at + timedelta(hours=rnd.randint(2, 20))
    t.status = S.DIKONFIRMASI
    if tahap == "dikonfirmasi":
        return
    t.kurir = rnd.choice(KURIR)
    t.no_resi = f"{rnd.randint(10**11, 10**12 - 1)}"
    t.dikirim_at = t.dikonfirmasi_at + timedelta(days=1)
    if tahap == "dikirim":
        return
    t.selesai_at = t.dikirim_at + timedelta(days=rnd.randint(2, 4))
    t.status = S.SELESAI


async def buat() -> None:
    rnd = random.Random(2026)
    hash_pw = await auth_service.hash_password(PASSWORD)
    async with _session_factory() as db:
        if (await db.execute(select(User).where(User.email == SENIMAN_EMAIL))).scalar_one_or_none():
            raise SystemExit("Akun demo sudah ada. Jalankan dengan --hapus dulu bila ingin membuat ulang.")
        if not storage.terkonfigurasi():
            raise SystemExit("R2 belum dikonfigurasi di .env (gambar karya wajib di R2).")
        key = await db.scalar(select(SigningKey).where(SigningKey.is_active.is_(True)))
        if key is None:
            raise SystemExit("Tidak ada signing key aktif.")
        muat_private_key(key.kms_key_ref)  # gagal cepat bila private key tidak ada di .env

        sen = User(id=uuid.uuid4(), email=SENIMAN_EMAIL, password_hash=hash_pw, display_name="Aria Wijaya", role=UserRole.SENIMAN,
                   email_verified=True, is_active=True, nomor_hp="+6281234567890")
        db.add(sen)
        pembeli: list[User] = []
        alamat: dict[uuid.UUID, AlamatPengiriman] = {}
        for i, nama in enumerate(PEMBELI, 1):
            u = User(id=uuid.uuid4(), email=f"kolektor{i:02d}{DOMAIN}", password_hash=hash_pw, display_name=nama, role=UserRole.KOLEKTOR,
                     email_verified=True, is_active=True, nomor_hp=f"+62812000{i:04d}")
            db.add(u)
            pembeli.append(u)
        await db.flush()
        for i, u in enumerate(pembeli):
            kota, pos = KOTA[i % len(KOTA)]
            a = AlamatPengiriman(id=uuid.uuid4(), user_id=u.id, label="Rumah", nama_penerima=u.display_name, telepon=u.nomor_hp,
                                 alamat_lengkap=f"Jl. Contoh Demo No. {10 + i}", kota=kota, kode_pos=pos, is_utama=True)
            db.add(a)
            alamat[u.id] = a
        db.add(Subscription(id=uuid.uuid4(), user_id=sen.id, plan_type=PlanSubscription.KOMUNITAS_PRO, status=StatusSubscription.AKTIF,
                            mulai_at=NOW, berakhir_at=NOW + timedelta(days=30)))

        # --- karya ---
        karya: list[Karya] = []
        n_sold, n_pend = len(HARI_SELESAI), 5
        for i, judul in enumerate(JUDUL):
            berkas, gaya = DASAR[i % len(DASAR)]
            isi = _varian(berkas, i, rnd)
            kid = uuid.uuid4()
            k_key = f"karya/{kid}.jpg"
            await storage.unggah(k_key, isi, "image/jpeg")
            umur = (HARI_SELESAI[i] + rnd.randint(12, 30)) if i < n_sold else rnd.randint(2, 40)
            k = Karya(id=kid, seniman_id=sen.id, title=judul, artist_name=sen.display_name, gallery_name="Sanggar Aria", style_name=gaya,
                      price_idr=HARGA[i], image_filename=f"{kid}.jpg", image_key=k_key, lebar_cm=rnd.choice([40, 50, 60, 70, 80]),
                      tinggi_cm=rnd.choice([50, 60, 70, 80, 90]), file_hash=hashlib.sha256(isi).hexdigest(),
                      status_verifikasi=StatusVerifikasiKarya.TERVERIFIKASI, created_at=(NOW - timedelta(days=umur)).replace(tzinfo=None),
                      deskripsi=f"{judul}: karya bergaya {gaya}, cat minyak di atas kanvas. Dikerjakan langsung oleh seniman.")
            db.add(k)
            karya.append(k)
        await db.flush()
        for k in karya:
            await terbitkan_sertifikat(db, k, "lolos", "lolos")

        # --- penjualan selesai + ulasan ---
        urutan_ulasan = list(range(len(ULASAN)))
        for i in range(n_sold):
            k, p = karya[i], pembeli[i % len(pembeli)]
            selesai = NOW - timedelta(days=HARI_SELESAI[i])
            dibuat = selesai - timedelta(days=rnd.randint(5, 8))
            t = await _tanda_tangan_transaksi(db, key, k, p, k.price_idr, dibuat)
            _isi_siklus(t, alamat[p.id], "selesai", dibuat, rnd, "")
            t.selesai_at = selesai  # tepat pada hari yang direncanakan (tren bulanan terkendali)
            t.dikirim_at = selesai - timedelta(days=rnd.randint(2, 3))
            t.dikonfirmasi_at = t.dikirim_at - timedelta(days=1)
            t.dibayar_at = min(t.dikonfirmasi_at - timedelta(hours=3), dibuat + timedelta(hours=5))
            t.created_at = dibuat
            db.add(KepemilikanKarya(id=uuid.uuid4(), karya_id=k.id, pemilik_id=p.id, sumber=SumberKepemilikan.PEMBELIAN,
                                    transaksi_id=t.id, diperoleh_at=selesai, created_at=selesai))
            if i < len(ULASAN):
                rating, teks = ULASAN[urutan_ulasan[i]]
                u = Ulasan(id=uuid.uuid4(), transaksi_id=t.id, karya_id=k.id, pembeli_id=p.id, seniman_id=sen.id, rating=rating, teks=teks,
                           created_at=min(selesai + timedelta(days=rnd.randint(1, 3)), NOW - timedelta(hours=2)))
                hasil = sentimen_ringan.prediksi(teks)
                if hasil:
                    u.sentimen_prediksi, u.model_version, u.dihitung_pada = hasil["label"], hasil["model_version"], u.created_at
                    u.prob_negatif, u.prob_netral, u.prob_positif = (hasil["prob"][c] for c in ("negatif", "netral", "positif"))
                db.add(u)

        # --- pesanan berjalan (memicu banner "perlu diproses" di dashboard) ---
        for j, tahap in enumerate(["dibayar", "dibayar", "dikonfirmasi", "dikirim", "menunggu"]):
            k, p = karya[n_sold + j], pembeli[(n_sold + j) % len(pembeli)]
            dibuat = NOW - timedelta(hours={"menunggu": 3, "dibayar": 7 + j * 9, "dikonfirmasi": 40, "dikirim": 90}[tahap])
            t = await _tanda_tangan_transaksi(db, key, k, p, k.price_idr, dibuat)
            _isi_siklus(t, alamat[p.id], tahap, dibuat, rnd, "")
            t.created_at = dibuat
        await db.commit()

    await engine.dispose()
    print(f"Seniman demo: {SENIMAN_EMAIL}  /  {PASSWORD}")
    print(f"Pembeli demo: kolektor01{DOMAIN} .. kolektor12{DOMAIN}  /  {PASSWORD}")
    print(f"{len(JUDUL)} karya | {n_sold} terjual | {n_pend} pesanan berjalan | {len(ULASAN)} ulasan")


async def hapus() -> None:
    async with _session_factory() as db:
        ids = [r[0] for r in (await db.execute(text("SELECT id FROM users WHERE email LIKE :p"), {"p": f"%{DOMAIN}"})).all()]
        if not ids:
            print("Tidak ada data demo.")
            return
        # gambar R2 semua karya milik akun demo (Aria + seniman tambahan dari tambah_koleksi_demo)
        keys = [r[0] for r in (await db.execute(select(Karya.image_key).where(Karya.seniman_id.in_(ids)))).all() if r[0]]
        p = {"ids": ids}
        from scripts.tambah_aktivitas_demo import hapus_aktivitas  # event/komunitas/lelang demo (FK RESTRICT ke users/karya)

        await hapus_aktivitas(db, ids, termasuk_transaksi=True)
        for sql in (
            "DELETE FROM ulasan WHERE seniman_id = ANY(:ids) OR pembeli_id = ANY(:ids)",
            "DELETE FROM kepemilikan_karya WHERE pemilik_id = ANY(:ids) OR karya_id IN (SELECT id FROM karya WHERE seniman_id = ANY(:ids))",
            "DELETE FROM notifikasi WHERE user_id = ANY(:ids)",
            "DELETE FROM transaksi WHERE penjual_id = ANY(:ids) OR pembeli_id = ANY(:ids)",
            "DELETE FROM karya WHERE seniman_id = ANY(:ids)",
            "DELETE FROM users WHERE id = ANY(:ids)",
        ):
            await db.execute(text(sql), p)
        await db.commit()
    for k in keys:
        try:
            await storage.hapus(k)
        except Exception as exc:  # noqa: BLE001 - gambar yatim di R2 tidak fatal
            print(f"  gagal hapus {k}: {exc}")
    await engine.dispose()
    print(f"Dihapus: {len(ids)} akun demo beserta karya/transaksi/ulasannya ({len(keys)} gambar R2).")


if __name__ == "__main__":
    asyncio.run(hapus() if "--hapus" in sys.argv else buat())
