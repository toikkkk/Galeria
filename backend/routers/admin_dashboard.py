"""Endpoint dashboard admin: pendapatan platform (komisi 2,5% penjualan karya + langganan Pro
kolektor + langganan Pro seniman), forecasting, Pro vs non-Pro.

Hanya membaca (data contoh schema ``dummy_admin``). Forecast = hasil batch yang sudah
tersimpan, bukan dihitung saat request. Akses: ``POST /api/admin/login`` (email+password dari env,
lihat ``services/admin_auth.py``) -> JWT, lalu header ``Authorization: Bearer``. Kunci lama
``X-Admin-Key`` (env ``ADMIN_API_KEY``) tetap diterima untuk skrip.
"""

from __future__ import annotations

import hmac
import os

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from schemas.admin import ForecastPendapatan, PendapatanBulan, ProVsNonPro, RingkasanAdmin
from services import admin_auth, admin_repo as repo


async def _cek_akses(authorization: str | None = Header(default=None), x_admin_key: str | None = Header(default=None)):
    if authorization and authorization.lower().startswith("bearer ") and admin_auth.token_valid(authorization[7:].strip()):
        return
    kunci = os.environ.get("ADMIN_API_KEY")
    if kunci and x_admin_key and hmac.compare_digest(x_admin_key, kunci):
        return
    raise HTTPException(401, "Belum login atau sesi berakhir", headers={"WWW-Authenticate": "Bearer"})


class LoginReq(BaseModel):
    email: str
    password: str
    ingat: bool = False


class LoginResp(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int


router = APIRouter(prefix="/api/admin", tags=["dashboard-admin"])


@router.post("/login", response_model=LoginResp)
async def login(body: LoginReq, request: Request):
    if not admin_auth.terkonfigurasi():
        raise HTTPException(503, "Login admin belum dikonfigurasi (ADMIN_EMAIL / ADMIN_PASSWORD_HASH / ADMIN_JWT_SECRET)")
    ip = request.client.host if request.client else "?"
    sisa = admin_auth.terkunci(ip)
    if sisa:
        raise HTTPException(429, f"Terlalu banyak percobaan. Coba lagi dalam {sisa} detik.", headers={"Retry-After": str(sisa)})
    if not admin_auth.cek_kredensial(body.email, body.password):
        admin_auth.catat_gagal(ip)
        raise HTTPException(401, "Email atau password salah")
    admin_auth.reset_gagal(ip)
    token, ttl = admin_auth.buat_token(body.ingat)
    return LoginResp(access_token=token, expires_in=ttl)


protected = APIRouter(dependencies=[Depends(_cek_akses)])


@protected.get("/ringkasan", response_model=RingkasanAdmin)
async def ringkasan(periode: int = Query(30), db: AsyncSession = Depends(get_db)):
    if periode not in (30, 90, 365):
        raise HTTPException(422, "periode harus 30, 90, atau 365")
    return await repo.ringkasan(db, periode)


@protected.get("/pendapatan-bulanan", response_model=list[PendapatanBulan])
async def pendapatan_bulanan(bulan: int = Query(36, ge=1, le=60), db: AsyncSession = Depends(get_db)):
    return await repo.pendapatan_bulanan(db, bulan)


@protected.get("/forecast", response_model=ForecastPendapatan)
async def forecast(
    target: str = Query("total"),
    bulan_aktual: int = Query(18, ge=3, le=60),
    db: AsyncSession = Depends(get_db),
):
    if target not in repo.TARGET_VALID:
        raise HTTPException(422, f"target harus salah satu dari {', '.join(repo.TARGET_VALID)}")
    return await repo.forecast(db, target, bulan_aktual)


@protected.get("/pro-vs-nonpro", response_model=list[ProVsNonPro])
async def pro_vs_nonpro(
    role: str = Query("kolektor"),
    bulan: int = Query(12, ge=1, le=36),
    db: AsyncSession = Depends(get_db),
):
    if role not in repo.PLAN:
        raise HTTPException(422, "role harus kolektor atau seniman")
    return await repo.pro_vs_nonpro(db, role, bulan)


router.include_router(protected)
