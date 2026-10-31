"""Endpoint lelang. Penjelasan aturan: services/lelang_service.py."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models.karya import Karya
from models.langganan import KaryaPromosi
from models.lelang import Lelang, LelangBid, StatusLelang as SL
from models.user import User
from schemas.lelang import BidIn, LelangBuat, LelangDetail, LelangList, LelangOut
from services import lelang_service as svc
from services.auth_deps import butuh_role, get_user_opsional

router = APIRouter(prefix="/api/lelang", tags=["lelang"])


@router.post("", response_model=LelangOut, status_code=201)
async def buat(body: LelangBuat, user: User = Depends(butuh_role("seniman")), db: AsyncSession = Depends(get_db)):
    """Seniman melelang karya terverifikasinya sendiri."""
    await svc.finalisasi(db)
    l = await svc.buat(db, user, body.karya_id, body.harga_awal_idr, body.kelipatan_bid_idr, body.mulai_at, body.selesai_at)
    return (await svc.ke_out_banyak(db, [l], user))[0]


@router.get("", response_model=LelangList)
async def daftar(
    status: str = Query("semua", pattern="^(semua|akan_datang|berlangsung|selesai)$"),
    ikut: bool = Query(False, description="hanya lelang yang pernah kamu tawar (butuh login)"),
    page: int = Query(1, ge=1),
    page_size: int = Query(30, ge=1, le=100),
    user: User | None = Depends(get_user_opsional),
    db: AsyncSession = Depends(get_db),
):
    """Daftar lelang publik. ``ikut=true`` menyaring lelang yang pernah kamu tawar."""
    await svc.finalisasi(db)
    filt = Lelang.status != SL.DIBATALKAN
    if ikut:
        if user is None:
            raise HTTPException(401, "Masuk dulu untuk melihat lelang yang kamu ikuti.")
        filt = filt & Lelang.id.in_(select(LelangBid.lelang_id).where(LelangBid.bidder_id == user.id))
    if status == "akan_datang":
        filt = filt & (Lelang.status == SL.AKAN_DATANG) & (Lelang.mulai_at > func.now())
    elif status == "berlangsung":
        filt = filt & Lelang.status.in_([SL.AKAN_DATANG, SL.BERLANGSUNG]) & (Lelang.mulai_at <= func.now()) & (Lelang.selesai_at > func.now())
    elif status == "selesai":
        filt = filt & (Lelang.status == SL.SELESAI)
    total = (await db.execute(select(func.count()).select_from(Lelang).where(filt))).scalar_one()
    # yang sedang berlangsung dan paling cepat berakhir tampil lebih dulu; sisanya yang terbaru
    rows = (
        await db.execute(
            select(Lelang).where(filt)
            .order_by(
                (Lelang.status == SL.SELESAI).asc(),
                # karya yang sedang dipromosikan (ruang lelang) tampil lebih dulu
                Lelang.karya_id.in_(select(KaryaPromosi.karya_id).where(KaryaPromosi.di_lelang.is_(True), KaryaPromosi.berakhir_at > func.now())).desc(),
                Lelang.selesai_at.asc() if status in ("berlangsung", "akan_datang") else Lelang.selesai_at.desc())
            .offset((page - 1) * page_size).limit(page_size)
        )
    ).scalars().all()
    return LelangList(items=await svc.ke_out_banyak(db, list(rows), user), total=total)


@router.get("/saya", response_model=LelangList)
async def lelang_saya(user: User = Depends(butuh_role("seniman")), db: AsyncSession = Depends(get_db)):
    """Semua lelang milik seniman yang login (termasuk yang dibatalkan)."""
    await svc.finalisasi(db)
    rows = (
        await db.execute(
            select(Lelang).join(Karya, Karya.id == Lelang.karya_id).where(Karya.seniman_id == user.id)
            .order_by(Lelang.created_at.desc()).limit(100)
        )
    ).scalars().all()
    return LelangList(items=await svc.ke_out_banyak(db, list(rows), user), total=len(rows))


@router.get("/{lelang_id}", response_model=LelangDetail)
async def detail(lelang_id: str, user: User | None = Depends(get_user_opsional), db: AsyncSession = Depends(get_db)):
    await svc.finalisasi(db)
    l = await svc.muat(db, lelang_id)
    return await svc.detail(db, l, user)


@router.post("/{lelang_id}/bid", response_model=LelangDetail)
async def bid(
    lelang_id: str, body: BidIn, user: User = Depends(butuh_role("kolektor", "komunitas")), db: AsyncSession = Depends(get_db)
):
    """Pasang tawaran. Minimal = harga awal (bid pertama) atau bid tertinggi + kelipatan."""
    l = await svc.pasang_bid(db, user, lelang_id, body.jumlah_idr)
    return await svc.detail(db, l, user)


@router.post("/{lelang_id}/batal", response_model=LelangOut)
async def batal(lelang_id: str, user: User = Depends(butuh_role("seniman")), db: AsyncSession = Depends(get_db)):
    l = await svc.batalkan(db, user, lelang_id)
    return (await svc.ke_out_banyak(db, [l], user))[0]
