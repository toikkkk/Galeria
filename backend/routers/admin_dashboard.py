"""Endpoint dashboard admin: pendapatan platform (komisi 2,5% penjualan karya + langganan Pro
kolektor + langganan Pro seniman), forecasting, Pro vs non-Pro.

Hanya membaca (data contoh schema ``dummy_admin``). Forecast = hasil batch yang sudah
tersimpan, bukan dihitung saat request. Auth admin sungguhan menunggu modul Auth; sementara
itu, bila env ``ADMIN_API_KEY`` di-set, semua endpoint mewajibkan header ``X-Admin-Key``.
"""

from __future__ import annotations

import hmac
import os

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from schemas.admin import ForecastPendapatan, PendapatanBulan, ProVsNonPro, RingkasanAdmin
from services import admin_repo as repo


async def _cek_kunci(x_admin_key: str | None = Header(default=None)):
    kunci = os.environ.get("ADMIN_API_KEY")
    if kunci and not (x_admin_key and hmac.compare_digest(x_admin_key, kunci)):
        raise HTTPException(401, "Kunci admin tidak valid")


router = APIRouter(prefix="/api/admin", tags=["dashboard-admin"], dependencies=[Depends(_cek_kunci)])


@router.get("/ringkasan", response_model=RingkasanAdmin)
async def ringkasan(periode: int = Query(30), db: AsyncSession = Depends(get_db)):
    if periode not in (30, 90, 365):
        raise HTTPException(422, "periode harus 30, 90, atau 365")
    return await repo.ringkasan(db, periode)


@router.get("/pendapatan-bulanan", response_model=list[PendapatanBulan])
async def pendapatan_bulanan(bulan: int = Query(36, ge=1, le=60), db: AsyncSession = Depends(get_db)):
    return await repo.pendapatan_bulanan(db, bulan)


@router.get("/forecast", response_model=ForecastPendapatan)
async def forecast(
    target: str = Query("total"),
    bulan_aktual: int = Query(18, ge=3, le=60),
    db: AsyncSession = Depends(get_db),
):
    if target not in repo.TARGET_VALID:
        raise HTTPException(422, f"target harus salah satu dari {', '.join(repo.TARGET_VALID)}")
    return await repo.forecast(db, target, bulan_aktual)


@router.get("/pro-vs-nonpro", response_model=list[ProVsNonPro])
async def pro_vs_nonpro(
    role: str = Query("kolektor"),
    bulan: int = Query(12, ge=1, le=36),
    db: AsyncSession = Depends(get_db),
):
    if role not in repo.PLAN:
        raise HTTPException(422, "role harus kolektor atau seniman")
    return await repo.pro_vs_nonpro(db, role, bulan)
