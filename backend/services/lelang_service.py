"""Logika lelang: membuat lelang, memasang bid, dan menutup lelang (menentukan pemenang).

Aturan:
- Hanya karya terverifikasi milik seniman sendiri yang belum terjual / sedang dipesan / sedang dilelang.
- Bid pertama minimal ``harga_awal``; bid berikutnya minimal bid tertinggi + ``kelipatan``. Pemegang bid tertinggi
  tidak boleh menimpa bid-nya sendiri. Penjual tidak boleh ikut menawar.
- Bid di 2 menit terakhir memperpanjang lelang 2 menit (anti-sniping), jadi penawar lain sempat membalas.
- Penutupan dilakukan LAZY (saat ada yang mengakses, tanpa job terjadwal): lelang yang waktunya habis ditutup,
  bid tertinggi menang, dan satu pesanan (``transaksi``, bertanda tangan) dibuat atas nama pemenang tanpa alamat;
  pemenang memilih alamat lalu membayar dalam 24 jam. Tidak ada bid = lelang selesai tanpa pemenang.
- Status ditentukan dari JAM SERVER, bukan jam HP.
"""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException
from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from models.karya import Karya, StatusVerifikasiKarya
from models.lelang import Lelang, LelangBid, StatusLelang as SL
from models.transaksi import StatusTransaksi as ST
from models.transaksi import Transaksi
from models.user import User
from schemas.lelang import BidOut, KaryaLelang, LelangDetail, LelangOut
from services import storage
from services import notifikasi_service as notif
from models.engagement import TipeNotifikasi
from services.pesanan_service import BATAS_BAYAR_JAM, hitung_komisi
from services.transaksi_service import buat_transaksi

logger = logging.getLogger("galeria.lelang")

DURASI_MIN = timedelta(minutes=5)
DURASI_MAKS = timedelta(days=14)
PERPANJANGAN = timedelta(minutes=2)


def _now() -> datetime:
    return datetime.now(timezone.utc)


def nama_singkat(nama: str) -> str:
    kata = nama.split()
    return nama if len(kata) <= 1 else f"{kata[0]} {kata[-1][0].upper()}."


def status_efektif(l: Lelang, now: datetime | None = None) -> str:
    now = now or _now()
    if l.status in (SL.DIBATALKAN, SL.SELESAI):
        return l.status.value
    if now < l.mulai_at:
        return "akan_datang"
    return "berlangsung" if now < l.selesai_at else "selesai"


async def finalisasi(db: AsyncSession) -> None:
    """Tutup lelang yang waktunya habis dan sinkronkan status 'berlangsung'."""
    now = _now()
    await db.execute(
        update(Lelang).where(Lelang.status == SL.AKAN_DATANG, Lelang.mulai_at <= now, Lelang.selesai_at > now)
        .values(status=SL.BERLANGSUNG)
    )
    rows = (
        await db.execute(
            select(Lelang).where(Lelang.status.in_([SL.AKAN_DATANG, SL.BERLANGSUNG]), Lelang.selesai_at <= now)
            .with_for_update(skip_locked=True)
        )
    ).scalars().all()
    for l in rows:
        top = (
            await db.execute(
                select(LelangBid).where(LelangBid.lelang_id == l.id)
                .order_by(LelangBid.jumlah_idr.desc(), LelangBid.created_at.asc()).limit(1)
            )
        ).scalar_one_or_none()
        karya = await db.get(Karya, l.karya_id)
        if top is None:
            l.status = SL.SELESAI
            notif.kirim(db, karya.seniman_id, TipeNotifikasi.LELANG, "Lelang berakhir tanpa tawaran", f'"{karya.title}" tidak mendapat tawaran.', f"lelang:{l.id}")
            continue
        try:
            async with db.begin_nested():
                t = await buat_transaksi(db, l.karya_id, top.bidder_id, karya.seniman_id, top.jumlah_idr, hitung_komisi(top.jumlah_idr))
                t.lelang_id = l.id
                t.batas_bayar_at = _now() + timedelta(hours=BATAS_BAYAR_JAM)
                l.status = SL.SELESAI
                l.pemenang_id = top.bidder_id
                notif.kirim(db, top.bidder_id, TipeNotifikasi.LELANG, "Kamu memenangkan lelang!", f'"{karya.title}" Rp{top.jumlah_idr:,}. Pilih alamat dan bayar dalam 24 jam.'.replace(",", "."), f"pesanan:{t.id}")
                notif.kirim(db, karya.seniman_id, TipeNotifikasi.LELANG, "Lelang berakhir dengan pemenang", f'"{karya.title}" terjual Rp{top.jumlah_idr:,}. Menunggu pembayaran pemenang.'.replace(",", "."), f"pesanan:{t.id}")
        except (RuntimeError, IntegrityError) as exc:
            # tanpa signing key / karya sempat dipesan lewat jalur lain: coba lagi di akses berikutnya
            logger.warning("Lelang %s belum bisa ditutup: %s", l.id, exc)
    await db.commit()


async def _agregat(db: AsyncSession, ids: list[uuid.UUID]) -> dict[uuid.UUID, tuple[int, int]]:
    """lelang_id -> (bid tertinggi, jumlah bid)."""
    if not ids:
        return {}
    rows = await db.execute(
        select(LelangBid.lelang_id, func.max(LelangBid.jumlah_idr), func.count())
        .where(LelangBid.lelang_id.in_(ids)).group_by(LelangBid.lelang_id)
    )
    return {r[0]: (int(r[1]), int(r[2])) for r in rows}


async def ke_out_banyak(db: AsyncSession, daftar: list[Lelang], user: User | None) -> list[LelangOut]:
    if not daftar:
        return []
    now = _now()
    agg = await _agregat(db, [l.id for l in daftar])
    karya = {k.id: k for k in (await db.execute(select(Karya).where(Karya.id.in_([l.karya_id for l in daftar])))).scalars()}
    uids = {k.seniman_id for k in karya.values() if k.seniman_id} | {l.pemenang_id for l in daftar if l.pemenang_id}
    nama = {u.id: u.display_name for u in (await db.execute(select(User).where(User.id.in_(uids)))).scalars()} if uids else {}
    # penawar tertinggi tiap lelang (untuk 'saya_tertinggi')
    top_bidder: dict[uuid.UUID, uuid.UUID] = {}
    for l in daftar:
        if agg.get(l.id):
            b = (
                await db.execute(
                    select(LelangBid.bidder_id).where(LelangBid.lelang_id == l.id)
                    .order_by(LelangBid.jumlah_idr.desc(), LelangBid.created_at.asc()).limit(1)
                )
            ).scalar_one()
            top_bidder[l.id] = b
    from services import langganan_service

    promo = await langganan_service.karya_dipromosikan(db, [l.karya_id for l in daftar], ruang="lelang")
    pesanan = {
        t.lelang_id: t.id for t in (
            await db.execute(select(Transaksi).where(Transaksi.lelang_id.in_([l.id for l in daftar])))
        ).scalars()
    }
    out = []
    for l in daftar:
        k = karya[l.karya_id]
        tertinggi, n = agg.get(l.id, (0, 0))
        st = status_efektif(l, now)
        saya_pemenang = bool(user and l.pemenang_id == user.id)
        penjual = bool(user and k.seniman_id == user.id)
        out.append(
            LelangOut(
                id=str(l.id), status=st,
                karya=KaryaLelang(
                    id=str(k.id), title=k.title, artist_name=k.artist_name, style_name=k.style_name,
                    image_url=storage.url_gambar(k.image_key), image_filename=k.image_filename,
                    lebar_cm=k.lebar_cm, tinggi_cm=k.tinggi_cm,
                ),
                seniman_nama=nama.get(k.seniman_id, k.artist_name),
                harga_awal_idr=l.harga_awal_idr, kelipatan_bid_idr=l.kelipatan_bid_idr,
                harga_saat_ini_idr=tertinggi or l.harga_awal_idr, jumlah_bid=n,
                bid_minimum_berikutnya_idr=(tertinggi + l.kelipatan_bid_idr) if n else l.harga_awal_idr,
                mulai_at=l.mulai_at, selesai_at=l.selesai_at, server_now=now,
                saya_tertinggi=bool(user and top_bidder.get(l.id) == user.id),
                saya_pemenang=saya_pemenang,
                pemenang_nama=nama_singkat(nama[l.pemenang_id]) if l.pemenang_id in nama else None,
                pesanan_id=str(pesanan[l.id]) if (l.id in pesanan and (saya_pemenang or penjual)) else None,
                bisa_dibatalkan=penjual and n == 0 and st in ("akan_datang", "berlangsung"),
                dipromosikan=l.karya_id in promo,
            )
        )
    return out


async def detail(db: AsyncSession, l: Lelang, user: User | None) -> LelangDetail:
    base = (await ke_out_banyak(db, [l], user))[0]
    rows = (
        await db.execute(
            select(LelangBid, User.display_name).join(User, User.id == LelangBid.bidder_id)
            .where(LelangBid.lelang_id == l.id).order_by(LelangBid.jumlah_idr.desc(), LelangBid.created_at.asc()).limit(30)
        )
    ).all()
    bids = [BidOut(nama=nama_singkat(n), jumlah_idr=b.jumlah_idr, waktu=b.created_at, saya=bool(user and b.bidder_id == user.id)) for b, n in rows]
    return LelangDetail(**base.model_dump(), bids=bids)


def _parse(v: str, pesan: str) -> uuid.UUID:
    try:
        return uuid.UUID(v)
    except ValueError:
        raise HTTPException(404, pesan)


async def buat(db: AsyncSession, user: User, karya_id: str, harga_awal: int, kelipatan: int, mulai: datetime, selesai: datetime) -> Lelang:
    now = _now()
    if mulai.tzinfo is None or selesai.tzinfo is None:
        raise HTTPException(422, "Waktu harus menyertakan zona waktu.")
    if mulai < now - timedelta(minutes=1):
        raise HTTPException(422, "Waktu mulai tidak boleh di masa lalu.")
    if selesai - mulai < DURASI_MIN:
        raise HTTPException(422, "Durasi lelang minimal 5 menit.")
    if selesai - mulai > DURASI_MAKS:
        raise HTTPException(422, "Durasi lelang maksimal 14 hari.")
    if mulai - now > timedelta(days=60):
        raise HTTPException(422, "Lelang maksimal dijadwalkan 60 hari ke depan.")
    if kelipatan > harga_awal:
        raise HTTPException(422, "Kelipatan bid tidak boleh lebih besar dari harga awal.")
    kid = _parse(karya_id, "Karya tidak ditemukan")
    karya = (await db.execute(select(Karya).where(Karya.id == kid).with_for_update())).scalar_one_or_none()
    if karya is None or karya.deleted_at is not None or karya.seniman_id != user.id:
        raise HTTPException(404, "Karya tidak ditemukan")
    if karya.status_verifikasi != StatusVerifikasiKarya.TERVERIFIKASI:
        raise HTTPException(409, "Hanya karya yang sudah terverifikasi yang bisa dilelang.")
    if await db.scalar(select(Transaksi.id).where(Transaksi.karya_id == kid, Transaksi.status != ST.DIBATALKAN)) is not None:
        raise HTTPException(409, "Karya ini sudah terjual atau sedang dipesan.")
    if await db.scalar(select(Lelang.id).where(Lelang.karya_id == kid, Lelang.status.in_([SL.AKAN_DATANG, SL.BERLANGSUNG]))) is not None:
        raise HTTPException(409, "Karya ini sudah punya lelang yang aktif.")
    l = Lelang(
        id=uuid.uuid4(), karya_id=kid, harga_awal_idr=harga_awal, kelipatan_bid_idr=kelipatan,
        mulai_at=mulai, selesai_at=selesai, status=SL.BERLANGSUNG if mulai <= now else SL.AKAN_DATANG,
    )
    db.add(l)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(409, "Karya ini sudah punya lelang yang aktif.")
    return l


async def muat(db: AsyncSession, lelang_id: str, *, kunci: bool = False) -> Lelang:
    lid = _parse(lelang_id, "Lelang tidak ditemukan")
    q = select(Lelang).where(Lelang.id == lid)
    if kunci:
        q = q.with_for_update()
    l = (await db.execute(q)).scalar_one_or_none()
    if l is None:
        raise HTTPException(404, "Lelang tidak ditemukan")
    return l


async def pasang_bid(db: AsyncSession, user: User, lelang_id: str, jumlah: int) -> Lelang:
    await finalisasi(db)
    l = await muat(db, lelang_id, kunci=True)
    now = _now()
    st = status_efektif(l, now)
    if st == "akan_datang":
        raise HTTPException(409, "Lelang ini belum dimulai.")
    if st != "berlangsung":
        raise HTTPException(409, "Lelang ini sudah berakhir." if st == "selesai" else "Lelang ini dibatalkan.")
    karya = await db.get(Karya, l.karya_id)
    if karya.seniman_id == user.id:
        raise HTTPException(403, "Kamu tidak bisa menawar karyamu sendiri.")
    top = (
        await db.execute(
            select(LelangBid).where(LelangBid.lelang_id == l.id)
            .order_by(LelangBid.jumlah_idr.desc(), LelangBid.created_at.asc()).limit(1)
        )
    ).scalar_one_or_none()
    minimum = l.harga_awal_idr if top is None else top.jumlah_idr + l.kelipatan_bid_idr
    if top is not None and top.bidder_id == user.id:
        raise HTTPException(409, "Tawaranmu sudah yang tertinggi.")
    if jumlah < minimum:
        raise HTTPException(409, f"Tawaran minimal Rp{minimum:,}".replace(",", "."))
    db.add(LelangBid(id=uuid.uuid4(), lelang_id=l.id, bidder_id=user.id, jumlah_idr=jumlah))
    tautan = f"lelang:{l.id}"
    if top is not None:
        notif.kirim(db, top.bidder_id, TipeNotifikasi.LELANG, "Tawaranmu dikalahkan", f'Ada tawaran lebih tinggi untuk "{karya.title}". Tawar lagi sebelum lelang berakhir.', tautan)
    notif.kirim(db, karya.seniman_id, TipeNotifikasi.LELANG, "Tawaran baru masuk", f'"{karya.title}" ditawar Rp{jumlah:,}.'.replace(",", "."), tautan)
    if l.selesai_at - now < PERPANJANGAN:  # anti-sniping
        l.selesai_at = now + PERPANJANGAN
    await db.commit()
    return l


async def batalkan(db: AsyncSession, user: User, lelang_id: str) -> Lelang:
    await finalisasi(db)
    l = await muat(db, lelang_id, kunci=True)
    karya = await db.get(Karya, l.karya_id)
    if karya.seniman_id != user.id:
        raise HTTPException(404, "Lelang tidak ditemukan")
    if status_efektif(l) not in ("akan_datang", "berlangsung"):
        raise HTTPException(409, "Lelang ini sudah berakhir atau dibatalkan.")
    n = (await db.execute(select(func.count()).select_from(LelangBid).where(LelangBid.lelang_id == l.id))).scalar_one()
    if n:
        raise HTTPException(409, "Lelang yang sudah punya penawaran tidak bisa dibatalkan.")
    l.status = SL.DIBATALKAN
    await db.commit()
    return l
