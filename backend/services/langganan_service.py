"""Langganan (Seniman PRO, akses AR) dan promosi karya berbayar.

Semua produk ini dibayar lewat ``tagihan`` + pembayaran sandbox (lihat ``services/pembayaran.py``): tagihan dibuat dulu,
baru setelah dibayar server menerbitkan ``subscriptions`` (atau memperpanjangnya 30 hari) / ``karya_promosi``.
Harga dan manfaat ditentukan SERVER, bukan aplikasi.

Penegakan: Seniman PRO diwajibkan SERVER saat membuat event dan membeli promosi. Akses AR dijalankan di perangkat
(ARCore), jadi gerbang ``ar_akses`` hanya berlaku di aplikasi -- bukan jaminan server.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from models.engagement import PlanSubscription, StatusSubscription, Subscription, TipeNotifikasi
from models.karya import Karya, StatusVerifikasiKarya
from models.langganan import KaryaPromosi, Tagihan
from models.transaksi import StatusTransaksi, Transaksi
from models.user import User
from schemas.langganan import LanggananAktif, PaketOut, PromosiHarga, PromosiOut, TagihanOut
from schemas.pesanan import InstruksiBayar
from services import notifikasi_service as notif
from services import pembayaran

BATAS_BAYAR_MENIT = 30
DURASI_LANGGANAN_HARI = 30
MAKS_PROMOSI_AKTIF = 5

PAKET: dict[str, dict] = {
    "komunitas_pro": {
        "nama": "Seniman PRO", "harga_idr": 149_000, "untuk": ["seniman", "komunitas"],
        "manfaat": [
            "Membuat event pameran lengkap dengan tiket",
            "Mempromosikan karya di beranda dan tab lelang",
            "Lencana PRO pada profil toko",
        ],
    },
    "ar_akses": {
        "nama": "Akses AR", "harga_idr": 49_000, "untuk": ["kolektor"],
        "manfaat": ["Mencoba karya di ruanganmu lewat kamera (AR) dengan ukuran asli", "Berlaku untuk semua karya di katalog"],
    },
}
HARGA_PROMOSI = {7: 50_000, 14: 90_000, 30: 170_000}

LABEL = {"menunggu_pembayaran": "Menunggu pembayaran", "dibayar": "Lunas", "dibatalkan": "Dibatalkan"}


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _parse(v: str, pesan: str) -> uuid.UUID:
    try:
        return uuid.UUID(v)
    except ValueError:
        raise HTTPException(404, pesan)


def daftar_paket() -> list[PaketOut]:
    return [PaketOut(plan=k, nama=v["nama"], harga_idr=v["harga_idr"], durasi_hari=DURASI_LANGGANAN_HARI, untuk=v["untuk"], manfaat=v["manfaat"]) for k, v in PAKET.items()]


def daftar_harga_promosi() -> list[PromosiHarga]:
    return [PromosiHarga(durasi_hari=d, harga_idr=h) for d, h in HARGA_PROMOSI.items()]


async def langganan_aktif(db: AsyncSession, user_id: uuid.UUID, plan: str) -> Subscription | None:
    return (await db.execute(
        select(Subscription).where(
            Subscription.user_id == user_id, Subscription.plan_type == PlanSubscription(plan),
            Subscription.status == StatusSubscription.AKTIF, Subscription.berakhir_at > _now(),
        ).order_by(Subscription.berakhir_at.desc()).limit(1)
    )).scalar_one_or_none()


async def pastikan_pro(db: AsyncSession, user: User) -> None:
    if await langganan_aktif(db, user.id, "komunitas_pro") is None:
        raise HTTPException(402, "Fitur ini khusus Seniman PRO. Berlangganan dulu untuk membukanya.")


async def saya(db: AsyncSession, user: User) -> list[LanggananAktif]:
    out = []
    for plan, p in PAKET.items():
        s = await langganan_aktif(db, user.id, plan)
        if s is not None:
            out.append(LanggananAktif(plan=plan, nama=p["nama"], mulai_at=s.mulai_at, berakhir_at=s.berakhir_at, sisa_hari=max(0, (s.berakhir_at - _now()).days + 1)))
    return out


# ------------------------------------------------------------------ tagihan
async def kedaluwarsakan(db: AsyncSession) -> None:
    await db.execute(update(Tagihan).where(Tagihan.status == "menunggu_pembayaran", Tagihan.batas_bayar_at < _now()).values(status="dibatalkan"))
    await db.commit()


def tagihan_out(t: Tagihan) -> TagihanOut:
    ins = None
    if t.status == "menunggu_pembayaran" and t.metode_pembayaran and t.referensi_pembayaran:
        ins = InstruksiBayar(metode=t.metode_pembayaran, nama_metode=pembayaran.METODE[t.metode_pembayaran][0], nomor=t.referensi_pembayaran,
                             jumlah_idr=t.jumlah_idr, batas_bayar_at=t.batas_bayar_at, mode=pembayaran.mode())
    return TagihanOut(id=str(t.id), jenis=t.jenis, judul=t.judul, jumlah_idr=t.jumlah_idr, status=t.status, status_label=LABEL[t.status],
                      instruksi_bayar=ins, batas_bayar_at=t.batas_bayar_at, dibayar_at=t.dibayar_at,
                      aksi=["bayar", "batal"] if t.status == "menunggu_pembayaran" else [])


async def kunci(db: AsyncSession, tagihan_id: str, user: User) -> Tagihan:
    await kedaluwarsakan(db)
    t = (await db.execute(select(Tagihan).where(Tagihan.id == _parse(tagihan_id, "Tagihan tidak ditemukan")).with_for_update())).scalar_one_or_none()
    if t is None or t.user_id != user.id:
        raise HTTPException(404, "Tagihan tidak ditemukan")
    return t


def _menunggu(t: Tagihan) -> None:
    if t.status != "menunggu_pembayaran":
        raise HTTPException(409, "Tagihan ini tidak lagi menunggu pembayaran.")


async def pilih_metode(db: AsyncSession, t: Tagihan, metode: str) -> None:
    _menunggu(t)
    try:
        _, nomor = pembayaran.buat_instruksi(metode, t.id)
    except pembayaran.PembayaranTidakTersedia as exc:
        raise HTTPException(501, str(exc))
    t.metode_pembayaran = metode
    t.referensi_pembayaran = nomor
    await db.commit()


async def batalkan(db: AsyncSession, t: Tagihan) -> None:
    _menunggu(t)
    t.status = "dibatalkan"
    await db.commit()


async def tandai_dibayar(db: AsyncSession, t: Tagihan) -> None:
    _menunggu(t)
    if not t.metode_pembayaran:
        raise HTTPException(409, "Pilih metode pembayaran dulu.")
    now = _now()
    t.status = "dibayar"
    t.dibayar_at = now
    if t.jenis == "langganan":
        plan = t.payload["plan"]
        aktif = await langganan_aktif(db, t.user_id, plan)
        if aktif is not None:  # perpanjang dari akhir masa aktif sekarang, bukan dari hari ini
            aktif.berakhir_at = aktif.berakhir_at + timedelta(days=DURASI_LANGGANAN_HARI)
        else:
            db.add(Subscription(id=uuid.uuid4(), user_id=t.user_id, plan_type=PlanSubscription(plan), status=StatusSubscription.AKTIF,
                                mulai_at=now, berakhir_at=now + timedelta(days=DURASI_LANGGANAN_HARI)))
        notif.kirim(db, t.user_id, TipeNotifikasi.SISTEM, f"{PAKET[plan]['nama']} aktif", f"Berlaku {DURASI_LANGGANAN_HARI} hari. Terima kasih sudah berlangganan!", None)
    else:  # promosi
        p = t.payload
        db.add(KaryaPromosi(
            id=uuid.uuid4(), karya_id=uuid.UUID(p["karya_id"]), seniman_id=t.user_id, tagihan_id=t.id, durasi_hari=int(p["durasi_hari"]),
            harga_idr=t.jumlah_idr, di_beranda=bool(p["di_beranda"]), di_lelang=bool(p["di_lelang"]), mulai_at=now,
            berakhir_at=now + timedelta(days=int(p["durasi_hari"])),
        ))
        notif.kirim(db, t.user_id, TipeNotifikasi.SISTEM, "Promosi karya aktif", f"{t.judul} sedang dipromosikan {p['durasi_hari']} hari.", f"karya:{p['karya_id']}")
    await db.commit()


# ------------------------------------------------------------------ membuat tagihan
async def beli_langganan(db: AsyncSession, user: User, plan: str) -> Tagihan:
    p = PAKET[plan]
    if user.role.value not in p["untuk"]:
        raise HTTPException(403, f"Paket {p['nama']} tidak tersedia untuk akun {user.role.value}.")
    await kedaluwarsakan(db)
    ada = await db.scalar(select(Tagihan.id).where(Tagihan.user_id == user.id, Tagihan.jenis == "langganan", Tagihan.status == "menunggu_pembayaran", Tagihan.payload["plan"].astext == plan))
    if ada is not None:  # satu tagihan terbuka per paket: pakai yang sudah ada
        return await db.get(Tagihan, ada)
    t = Tagihan(id=uuid.uuid4(), user_id=user.id, jenis="langganan", judul=f"{p['nama']} · {DURASI_LANGGANAN_HARI} hari", jumlah_idr=p["harga_idr"],
                payload={"plan": plan}, batas_bayar_at=_now() + timedelta(minutes=BATAS_BAYAR_MENIT))
    db.add(t)
    await db.commit()
    return t


async def beli_promosi(db: AsyncSession, user: User, karya_id: str, durasi: int, di_beranda: bool, di_lelang: bool) -> Tagihan:
    if not (di_beranda or di_lelang):
        raise HTTPException(422, "Pilih minimal satu ruang promosi (beranda atau lelang).")
    await pastikan_pro(db, user)
    await kedaluwarsakan(db)
    kid = _parse(karya_id, "Karya tidak ditemukan")
    karya = await db.get(Karya, kid)
    if karya is None or karya.deleted_at is not None or karya.seniman_id != user.id:
        raise HTTPException(404, "Karya tidak ditemukan")
    if karya.status_verifikasi != StatusVerifikasiKarya.TERVERIFIKASI:
        raise HTTPException(409, "Hanya karya yang sudah terverifikasi yang bisa dipromosikan.")
    if await db.scalar(select(Transaksi.id).where(Transaksi.karya_id == kid, Transaksi.status != StatusTransaksi.DIBATALKAN)) is not None:
        raise HTTPException(409, "Karya yang sudah terjual atau sedang dipesan tidak perlu dipromosikan.")
    sekarang = _now()
    if await db.scalar(select(KaryaPromosi.id).where(KaryaPromosi.karya_id == kid, KaryaPromosi.berakhir_at > sekarang)) is not None:
        raise HTTPException(409, "Karya ini masih dalam masa promosi.")
    aktif = (await db.execute(select(func.count()).select_from(KaryaPromosi).where(KaryaPromosi.seniman_id == user.id, KaryaPromosi.berakhir_at > sekarang))).scalar_one()
    if aktif >= MAKS_PROMOSI_AKTIF:
        raise HTTPException(409, f"Maksimal {MAKS_PROMOSI_AKTIF} promosi aktif sekaligus.")
    t = Tagihan(id=uuid.uuid4(), user_id=user.id, jenis="promosi", judul=f"Promosi \"{karya.title}\" · {durasi} hari", jumlah_idr=HARGA_PROMOSI[durasi],
                payload={"karya_id": str(kid), "durasi_hari": durasi, "di_beranda": di_beranda, "di_lelang": di_lelang},
                batas_bayar_at=sekarang + timedelta(minutes=BATAS_BAYAR_MENIT))
    db.add(t)
    await db.commit()
    return t


async def promosi_saya(db: AsyncSession, user: User) -> list[PromosiOut]:
    rows = (await db.execute(select(KaryaPromosi, Karya.title).join(Karya, Karya.id == KaryaPromosi.karya_id).where(KaryaPromosi.seniman_id == user.id).order_by(KaryaPromosi.created_at.desc()).limit(50))).all()
    now = _now()
    return [PromosiOut(id=str(p.id), karya_id=str(p.karya_id), judul_karya=j, durasi_hari=p.durasi_hari, harga_idr=p.harga_idr, di_beranda=p.di_beranda,
                       di_lelang=p.di_lelang, mulai_at=p.mulai_at, berakhir_at=p.berakhir_at, aktif=p.berakhir_at > now) for p, j in rows]


async def karya_dipromosikan(db: AsyncSession, karya_ids: list[uuid.UUID], *, ruang: str | None = None) -> set[uuid.UUID]:
    """Id karya (dari [karya_ids]) yang punya promosi aktif; ``ruang`` = 'beranda' | 'lelang' | None (keduanya)."""
    if not karya_ids:
        return set()
    q = select(KaryaPromosi.karya_id).where(KaryaPromosi.karya_id.in_(karya_ids), KaryaPromosi.berakhir_at > _now())
    if ruang == "beranda":
        q = q.where(KaryaPromosi.di_beranda.is_(True))
    elif ruang == "lelang":
        q = q.where(KaryaPromosi.di_lelang.is_(True))
    return set((await db.execute(q)).scalars())
