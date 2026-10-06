"""Endpoint dashboard seniman (statistik deskriptif data dummy rekomendasi).

Hanya membaca; bukan prediksi/saran harga (fitur Estimasi Harga di-drop).
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from schemas.dashboard import (
    AliranSeniman,
    PenjualanBulan,
    RingkasanSeniman,
    SegmenPembeliResponse,
    SenimanDemoItem,
    TrenPasar,
)
from services import dashboard_repo as repo

router = APIRouter(prefix="/api/dashboard", tags=["dashboard-seniman"])


async def _seniman_atau_404(db: AsyncSession, seniman_id: str):
    sid = repo.parse_uuid(seniman_id)
    seniman = await repo.get_seniman(db, sid) if sid else None
    if seniman is None:
        raise HTTPException(404, "Seniman tidak ditemukan")
    return sid, seniman


@router.get("/demo-seniman", response_model=list[SenimanDemoItem])
async def demo_seniman(db: AsyncSession = Depends(get_db)):
    """Seniman contoh (pengganti login sampai Auth selesai), terbanyak terjual dulu."""
    return await repo.daftar_seniman_demo(db)


@router.get("/seniman/{seniman_id}/ringkasan", response_model=RingkasanSeniman)
async def ringkasan(
    seniman_id: str,
    periode: int = Query(30, description="30, 90, atau 365 hari"),
    db: AsyncSession = Depends(get_db),
):
    if periode not in (30, 90, 365):
        raise HTTPException(422, "periode harus 30, 90, atau 365")
    sid, seniman = await _seniman_atau_404(db, seniman_id)
    return await repo.ringkasan(db, seniman, sid, periode)


@router.get("/seniman/{seniman_id}/penjualan-bulanan", response_model=list[PenjualanBulan])
async def penjualan_bulanan(
    seniman_id: str,
    bulan: int = Query(12, ge=1, le=36),
    db: AsyncSession = Depends(get_db),
):
    sid, _ = await _seniman_atau_404(db, seniman_id)
    return await repo.penjualan_bulanan(db, sid, bulan)


@router.get("/seniman/{seniman_id}/aliran", response_model=list[AliranSeniman])
async def aliran(seniman_id: str, db: AsyncSession = Depends(get_db)):
    sid, _ = await _seniman_atau_404(db, seniman_id)
    return await repo.aliran(db, sid)


@router.get("/seniman/{seniman_id}/segmen-pembeli", response_model=SegmenPembeliResponse)
async def segmen_pembeli(seniman_id: str, db: AsyncSession = Depends(get_db)):
    sid, _ = await _seniman_atau_404(db, seniman_id)
    return await repo.segmen_pembeli(db, sid)


@router.get("/pasar/tren", response_model=TrenPasar)
async def tren_pasar(db: AsyncSession = Depends(get_db)):
    return await repo.tren_pasar(db)
