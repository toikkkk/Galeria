"""Tambahan akun DEMO kolektor Budi Santoso (kolektor01@demo.galeria.test): koleksi yang padat.

Butuh ``scripts.siapkan_akun_demo`` sudah dijalankan. Menambah 2 seniman demo baru (``@demo.galeria.test``)
dengan 8 karya terverifikasi yang SEMUANYA sudah dimiliki Budi: 6 lewat pembelian, 2 lewat lelang yang
dimenanginya (lelang selesai + riwayat bid + pesanan bertanda tangan). Ditambah 3 ulasan dan 6 karya favorit.
Ini DATA CONTOH di database yang sama dengan data asli: jangan dipakai untuk klaim performa.

    python -m scripts.tambah_koleksi_demo   # tambah
    (hapus: ``python -m scripts.siapkan_akun_demo --hapus`` -- ikut membersihkan akun & karya baru ini)
"""

from __future__ import annotations

import asyncio
import hashlib
import random
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import select

from database import _session_factory, engine
from models.engagement import KoleksiFavorit
from models.karya import Karya, StatusVerifikasiKarya
from models.lelang import Lelang, LelangBid, StatusLelang
from models.sertifikat import SigningKey
from models.transaksi import KepemilikanKarya, SumberKepemilikan
from models.ulasan import Ulasan
from models.user import AlamatPengiriman, User, UserRole
from scripts.siapkan_akun_demo import (
    DASAR, DOMAIN, PASSWORD, ULASAN, _isi_siklus, _tanda_tangan_transaksi, _varian,
)
from services import auth_service, sentimen_ringan, storage
from services.kripto import muat_private_key
from services.sertifikat_service import terbitkan_sertifikat

NOW = datetime.now(timezone.utc)
BUDI_EMAIL = f"kolektor01{DOMAIN}"

SENIMAN = [
    ("rina.maharani", "Rina Maharani", "Studio Rina"),
    ("bagus.prakoso", "Bagus Prakoso", "Bengkel Seni Bagus"),
]
# (judul, harga, hari lalu diterima, cara)   cara: beli | lelang
KARYA = [
    ("Perahu di Teluk Pagi", 3_200_000, 150, "beli"),
    ("Taman Bunga Merah", 2_400_000, 128, "beli"),
    ("Potret Penenun", 5_600_000, 101, "lelang"),
    ("Kabut Lembah Arjuna", 4_100_000, 84, "beli"),
    ("Senja di Pelabuhan Tua", 6_300_000, 63, "beli"),
    ("Dua Gadis di Beranda", 3_900_000, 45, "lelang"),
    ("Pasar Ikan Pagi", 2_750_000, 28, "beli"),
    ("Lanskap Sawah Terasering", 4_800_000, 12, "beli"),
]


async def tambah() -> None:
    rnd = random.Random(404)
    hash_pw = await auth_service.hash_password(PASSWORD)
    async with _session_factory() as db:
        budi = (await db.execute(select(User).where(User.email == BUDI_EMAIL))).scalar_one_or_none()
        if budi is None:
            raise SystemExit("Akun demo belum ada. Jalankan `python -m scripts.siapkan_akun_demo` dulu.")
        if (await db.execute(select(User.id).where(User.email == f"{SENIMAN[0][0]}{DOMAIN}"))).first():
            raise SystemExit("Koleksi demo sudah ada. Jalankan `python -m scripts.siapkan_akun_demo --hapus` dulu bila ingin membuat ulang.")
        if not storage.terkonfigurasi():
            raise SystemExit("R2 belum dikonfigurasi di .env (gambar karya wajib di R2).")
        key = await db.scalar(select(SigningKey).where(SigningKey.is_active.is_(True)))
        if key is None:
            raise SystemExit("Tidak ada signing key aktif.")
        muat_private_key(key.kms_key_ref)
        alamat = (await db.execute(select(AlamatPengiriman).where(AlamatPengiriman.user_id == budi.id))).scalars().first()
        if alamat is None:
            raise SystemExit("Budi belum punya alamat; jalankan siapkan_akun_demo.")
        lawan = list((await db.execute(select(User).where(User.email.like(f"kolektor0%{DOMAIN}"), User.id != budi.id).order_by(User.email))).scalars())[:4]

        seniman: list[User] = []
        for slug, nama, _ in SENIMAN:
            u = User(id=uuid.uuid4(), email=f"{slug}{DOMAIN}", password_hash=hash_pw, display_name=nama, role=UserRole.SENIMAN,
                     email_verified=True, is_active=True, nomor_hp=f"+62813{rnd.randint(10**7, 10**8 - 1)}")
            db.add(u)
            seniman.append(u)
        await db.flush()

        karya_baru: list[Karya] = []
        for i, (judul, harga, hari, cara) in enumerate(KARYA):
            sen = seniman[i % 2]
            gallery = SENIMAN[i % 2][2]
            berkas, gaya = DASAR[(i + 3) % len(DASAR)]
            isi = _varian(berkas, 8 + i, rnd)
            kid = uuid.uuid4()
            k_key = f"karya/{kid}.jpg"
            await storage.unggah(k_key, isi, "image/jpeg")
            diterima = NOW - timedelta(days=hari)
            k = Karya(id=kid, seniman_id=sen.id, title=judul, artist_name=sen.display_name, gallery_name=gallery, style_name=gaya,
                      price_idr=harga, image_filename=f"{kid}.jpg", image_key=k_key, lebar_cm=rnd.choice([40, 50, 60, 70, 80]),
                      tinggi_cm=rnd.choice([50, 60, 70, 80, 90]), file_hash=hashlib.sha256(isi).hexdigest(),
                      status_verifikasi=StatusVerifikasiKarya.TERVERIFIKASI,
                      created_at=(diterima - timedelta(days=rnd.randint(14, 35))).replace(tzinfo=None),
                      deskripsi=f"{judul}: karya bergaya {gaya}, cat minyak di atas kanvas. Dikerjakan langsung oleh seniman.")
            db.add(k)
            karya_baru.append(k)
        await db.flush()
        for k in karya_baru:
            await terbitkan_sertifikat(db, k, "lolos", "lolos")

        transaksi_ulasan = []
        for i, (judul, harga, hari, cara) in enumerate(KARYA):
            k = karya_baru[i]
            selesai = NOW - timedelta(days=hari)
            dibuat = selesai - timedelta(days=rnd.randint(5, 8))
            lelang = None
            if cara == "lelang":
                awal = int(harga * 0.6 // 50_000 * 50_000)
                lelang = Lelang(id=uuid.uuid4(), karya_id=k.id, harga_awal_idr=awal, kelipatan_bid_idr=100_000,
                                mulai_at=dibuat - timedelta(days=5), selesai_at=dibuat - timedelta(hours=1),
                                status=StatusLelang.SELESAI, pemenang_id=budi.id)
                db.add(lelang)
                await db.flush()
                naik = [awal + j * 400_000 for j in range(1, 5)]
                naik = [min(b, harga - 100_000) for b in naik] + [harga]
                for j, jumlah in enumerate(naik):
                    bidder = budi if j == len(naik) - 1 or j % 3 == 0 else lawan[j % len(lawan)]
                    if j == len(naik) - 2:
                        bidder = lawan[0]
                    db.add(LelangBid(id=uuid.uuid4(), lelang_id=lelang.id, bidder_id=bidder.id, jumlah_idr=jumlah,
                                     created_at=lelang.mulai_at + timedelta(hours=18 * (j + 1))))
            t = await _tanda_tangan_transaksi(db, key, k, budi, harga, dibuat)
            _isi_siklus(t, alamat, "selesai", dibuat, rnd, "")
            t.selesai_at = selesai
            t.dikirim_at = selesai - timedelta(days=rnd.randint(2, 3))
            t.dikonfirmasi_at = t.dikirim_at - timedelta(days=1)
            t.dibayar_at = min(t.dikonfirmasi_at - timedelta(hours=3), dibuat + timedelta(hours=5))
            t.created_at = dibuat
            if lelang is not None:
                t.lelang_id = lelang.id
            db.add(KepemilikanKarya(id=uuid.uuid4(), karya_id=k.id, pemilik_id=budi.id,
                                    sumber=SumberKepemilikan.LELANG if lelang else SumberKepemilikan.PEMBELIAN,
                                    transaksi_id=t.id, diperoleh_at=selesai, created_at=selesai))
            transaksi_ulasan.append((t, k, selesai))

        # 3 ulasan dari Budi (rating tinggi)
        for (t, k, selesai), (rating, teks) in zip(transaksi_ulasan[:3], [ULASAN[0], ULASAN[3], ULASAN[8]]):
            u = Ulasan(id=uuid.uuid4(), transaksi_id=t.id, karya_id=k.id, pembeli_id=budi.id, seniman_id=k.seniman_id,
                       rating=rating, teks=teks, created_at=selesai + timedelta(days=2))
            hasil = sentimen_ringan.prediksi(teks)
            if hasil:
                u.sentimen_prediksi, u.model_version, u.dihitung_pada = hasil["label"], hasil["model_version"], u.created_at
                u.prob_negatif, u.prob_netral, u.prob_positif = (hasil["prob"][c] for c in ("negatif", "netral", "positif"))
            db.add(u)

        # favorit: karya Aria yang masih tersedia
        aria = (await db.execute(select(User.id).where(User.email == f"aria.wijaya{DOMAIN}"))).scalar_one_or_none()
        if aria is not None:
            tersedia = list((await db.execute(select(Karya.id).where(Karya.seniman_id == aria, Karya.deleted_at.is_(None))
                                              .order_by(Karya.created_at.desc()).limit(6))).scalars())
            for n, kid in enumerate(tersedia):
                db.add(KoleksiFavorit(user_id=budi.id, karya_id=kid, created_at=NOW - timedelta(days=n + 1)))
        await db.commit()

    await engine.dispose()
    print(f"Koleksi Budi: +{len(KARYA)} karya (6 dibeli, 2 menang lelang), 3 ulasan, favorit ditambahkan.")
    print(f"Seniman baru: {', '.join(f'{s[0]}{DOMAIN}' for s in SENIMAN)} / {PASSWORD}")


if __name__ == "__main__":
    asyncio.run(tambah())
