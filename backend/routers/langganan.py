"""Endpoint langganan, promosi karya, dan tagihan. Aturan: services/langganan_service.py."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models.user import User
from schemas.langganan import (
    BayarTagihanIn, BeliLangganan, BeliPromosi, LanggananSaya, PaketList, PromosiList, TagihanOut,
)
from services import langganan_service as svc
from services import pembayaran
from services.auth_deps import butuh_role, get_current_user

router = APIRouter(prefix="/api", tags=["langganan"])


@router.get("/langganan/paket", response_model=PaketList)
async def paket():
    """Katalog paket & harga promosi (publik; harga ditentukan server)."""
    return PaketList(paket=svc.daftar_paket(), promosi=svc.daftar_harga_promosi())


@router.get("/langganan/saya", response_model=LanggananSaya)
async def langganan_saya(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    aktif = await svc.saya(db, user)
    plans = {a.plan for a in aktif}
    return LanggananSaya(aktif=aktif, pro="komunitas_pro" in plans, ar="ar_akses" in plans)


@router.post("/langganan/beli", response_model=TagihanOut, status_code=201)
async def beli(body: BeliLangganan, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Buat tagihan langganan 30 hari (atau pakai tagihan terbuka yang sudah ada)."""
    return svc.tagihan_out(await svc.beli_langganan(db, user, body.plan))


@router.post("/promosi", response_model=TagihanOut, status_code=201)
async def beli_promosi(body: BeliPromosi, user: User = Depends(butuh_role("seniman")), db: AsyncSession = Depends(get_db)):
    """Beli promosi untuk karya terverifikasi milikmu (wajib Seniman PRO)."""
    return svc.tagihan_out(await svc.beli_promosi(db, user, body.karya_id, body.durasi_hari, body.di_beranda, body.di_lelang))


@router.get("/promosi/saya", response_model=PromosiList)
async def promosi_saya(user: User = Depends(butuh_role("seniman")), db: AsyncSession = Depends(get_db)):
    return PromosiList(items=await svc.promosi_saya(db, user))


@router.get("/tagihan/{tagihan_id}", response_model=TagihanOut)
async def detail_tagihan(tagihan_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    return svc.tagihan_out(await svc.kunci(db, tagihan_id, user))


@router.post("/tagihan/{tagihan_id}/bayar", response_model=TagihanOut)
async def pilih_metode(tagihan_id: str, body: BayarTagihanIn, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    t = await svc.kunci(db, tagihan_id, user)
    await svc.pilih_metode(db, t, body.metode)
    return svc.tagihan_out(t)


@router.post("/tagihan/{tagihan_id}/bayar/simulasi", response_model=TagihanOut)
async def simulasi(tagihan_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """SANDBOX: anggap pembayaran masuk, lalu langganan/promosi diaktifkan."""
    if not pembayaran.simulasi_diizinkan():
        raise HTTPException(404, "Tidak tersedia.")
    t = await svc.kunci(db, tagihan_id, user)
    await svc.tandai_dibayar(db, t)
    return svc.tagihan_out(t)


@router.post("/tagihan/{tagihan_id}/batal", response_model=TagihanOut)
async def batal(tagihan_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    t = await svc.kunci(db, tagihan_id, user)
    await svc.batalkan(db, t)
    return svc.tagihan_out(t)
