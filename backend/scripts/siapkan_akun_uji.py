"""Buat (atau perbarui) 2 akun uji untuk mencoba semua fitur di HP: satu seniman, satu kolektor.

Seniman: langganan PRO aktif 30 hari + 3 karya terverifikasi (gambar diunggah ke R2).
Kolektor: langganan Akses AR aktif 30 hari + 1 alamat pengiriman.
Idempotent: dijalankan ulang hanya mereset password/langganan dan tidak menggandakan karya.

    python -m scripts.siapkan_akun_uji
"""

from __future__ import annotations

import asyncio
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

from sqlalchemy import select

from database import _session_factory, engine
from models.engagement import PlanSubscription, StatusSubscription, Subscription
from models.karya import Karya, StatusVerifikasiKarya
from models.user import AlamatPengiriman, User, UserRole
from services import auth_service, storage

PASSWORD = "Galeria2026"
SENIMAN = ("seniman.uji@galeria.test", "Rani Seniman Uji", UserRole.SENIMAN)
KOLEKTOR = ("kolektor.uji@galeria.test", "Budi Kolektor Uji", UserRole.KOLEKTOR)
ASET = Path(__file__).resolve().parents[2] / "mobile" / "assets" / "images" / "catalog"
KARYA = [
    ("Senja di Teluk", "impressionism_01.jpg", "Impressionism", 2_500_000),
    ("Lanskap Badai", "romanticism_01.jpg", "Romanticism", 4_200_000),
    ("Komposisi Abstrak", "cubism_01.jpg", "Cubism", 1_800_000),
]


async def siapkan_user(db, email, nama, role) -> User:
    u = (await db.execute(select(User).where(User.email == email))).scalar_one_or_none()
    h = await auth_service.hash_password(PASSWORD)
    if u is None:
        u = User(id=uuid.uuid4(), email=email, password_hash=h, display_name=nama, role=role, email_verified=True, is_active=True,
                 nomor_hp="+6281200000000")
        db.add(u)
    else:
        u.password_hash, u.is_active, u.email_verified = h, True, True
    await db.flush()
    return u


async def beri_langganan(db, user, plan) -> None:
    now = datetime.now(timezone.utc)
    s = (await db.execute(select(Subscription).where(Subscription.user_id == user.id, Subscription.plan_type == plan))).scalars().first()
    if s is None:
        db.add(Subscription(id=uuid.uuid4(), user_id=user.id, plan_type=plan, status=StatusSubscription.AKTIF, mulai_at=now, berakhir_at=now + timedelta(days=30)))
    else:
        s.status, s.mulai_at, s.berakhir_at = StatusSubscription.AKTIF, now, now + timedelta(days=30)


async def main() -> None:
    async with _session_factory() as db:
        sen = await siapkan_user(db, *SENIMAN)
        kol = await siapkan_user(db, *KOLEKTOR)
        await beri_langganan(db, sen, PlanSubscription.KOMUNITAS_PRO)
        await beri_langganan(db, kol, PlanSubscription.AR_AKSES)

        if (await db.execute(select(AlamatPengiriman).where(AlamatPengiriman.user_id == kol.id))).first() is None:
            db.add(AlamatPengiriman(id=uuid.uuid4(), user_id=kol.id, label="Rumah", nama_penerima=kol.display_name, telepon="+6281200000000",
                                    alamat_lengkap="Jl. Tunjungan No. 10, Genteng", kota="Surabaya", kode_pos="60275", is_utama=True))

        ada = {k.title for k in (await db.execute(select(Karya).where(Karya.seniman_id == sen.id, Karya.deleted_at.is_(None)))).scalars()}
        for judul, berkas, gaya, harga in KARYA:
            if judul in ada:
                continue
            kid = uuid.uuid4()
            isi = (ASET / berkas).read_bytes()
            key = f"karya/{kid}.jpg"
            if storage.terkonfigurasi():
                await storage.unggah(key, isi, "image/jpeg")
            else:
                raise SystemExit("R2 belum dikonfigurasi di .env")
            db.add(Karya(id=kid, seniman_id=sen.id, title=judul, artist_name=sen.display_name, gallery_name=sen.display_name, style_name=gaya,
                         price_idr=harga, image_filename=f"{kid}.jpg", image_key=key, lebar_cm=60, tinggi_cm=80,
                         status_verifikasi=StatusVerifikasiKarya.TERVERIFIKASI))
        await db.commit()
    await engine.dispose()
    print(f"Seniman : {SENIMAN[0]}  / {PASSWORD}  (PRO aktif, 3 karya terverifikasi)")
    print(f"Kolektor: {KOLEKTOR[0]}  / {PASSWORD}  (Akses AR aktif, 1 alamat)")


asyncio.run(main())
