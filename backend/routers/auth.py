"""Auth pengguna: daftar, masuk, perpanjang sesi, keluar, profil, dan masuk dengan Google.

Akun admin dashboard TIDAK lewat sini (lihat ``routers/admin_dashboard.py``); peran ``admin`` tidak bisa didaftarkan publik.
"""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Request, Response
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models.user import User, UserRole
from schemas.auth import GoogleReq, LoginReq, RefreshReq, RegisterReq, TokenPair, UserOut
from services import auth_service as svc
from services.auth_deps import get_current_user

router = APIRouter(prefix="/api/auth", tags=["auth"])


def _ip(request: Request) -> str:
    return request.client.host if request.client else "?"


def _device(request: Request, device: str | None) -> str | None:
    return device or request.headers.get("user-agent")


def _user_out(u: User) -> UserOut:
    return UserOut(
        id=str(u.id), email=u.email, display_name=u.display_name, role=u.role.value,
        avatar_url=u.avatar_url, nomor_hp=u.nomor_hp, email_verified=u.email_verified,
    )


def _butuh_konfigurasi() -> None:
    if not svc.terkonfigurasi():
        raise HTTPException(503, "Auth belum dikonfigurasi di server (JWT_SECRET kosong).")


async def _terbitkan(db: AsyncSession, user: User, request: Request, device: str | None) -> TokenPair:
    sesi, refresh = await svc.buat_sesi(db, user, device=_device(request, device), ip=_ip(request))
    await db.commit()
    access, ttl = svc.buat_access_token(user, sesi.id)
    return TokenPair(access_token=access, refresh_token=refresh, expires_in=ttl, user=_user_out(user))


@router.post("/register", response_model=TokenPair, status_code=201)
async def register(body: RegisterReq, request: Request, db: AsyncSession = Depends(get_db)):
    _butuh_konfigurasi()
    user = User(
        id=uuid.uuid4(), email=body.email, password_hash=await svc.hash_password(body.password),
        display_name=body.display_name, role=UserRole(body.role), nomor_hp=body.nomor_hp, email_verified=False,
    )
    db.add(user)
    try:
        await db.flush()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(409, "Email ini sudah terdaftar. Coba masuk, atau pakai email lain.")
    return await _terbitkan(db, user, request, None)


@router.post("/login", response_model=TokenPair)
async def login(body: LoginReq, request: Request, db: AsyncSession = Depends(get_db)):
    _butuh_konfigurasi()
    ip = _ip(request)
    sisa = svc.sisa_kunci(body.email, ip)
    if sisa:
        raise HTTPException(429, f"Terlalu banyak percobaan. Coba lagi dalam {sisa} detik.", headers={"Retry-After": str(sisa)})
    user = (await db.execute(select(User).where(User.email == body.email))).scalar_one_or_none()
    # bcrypt selalu dihitung (hash tiruan bila akun tak ada / akun Google-only): waktu respons seragam
    cocok = await svc.cek_password(body.password, user.password_hash if user else None)
    if user is None or not cocok:
        svc.catat_gagal(body.email, ip)
        raise HTTPException(401, "Email atau password salah.")
    if not user.is_active:
        raise HTTPException(403, "Akun ini dinonaktifkan. Hubungi admin GALERIA.")
    svc.reset_gagal(body.email, ip)
    return await _terbitkan(db, user, request, body.device)


@router.post("/refresh", response_model=TokenPair)
async def refresh(body: RefreshReq, db: AsyncSession = Depends(get_db)):
    _butuh_konfigurasi()
    try:
        user, sesi, token_baru = await svc.putar_refresh(db, body.refresh_token)
    except svc.AuthError as e:
        raise HTTPException(e.status, e.pesan)
    await db.commit()
    access, ttl = svc.buat_access_token(user, sesi.id)
    return TokenPair(access_token=access, refresh_token=token_baru, expires_in=ttl, user=_user_out(user))


@router.post("/logout", status_code=204)
async def logout(body: RefreshReq, db: AsyncSession = Depends(get_db)):
    """Keluar dari perangkat ini. Selalu 204 (idempoten), termasuk bila token sudah tidak berlaku."""
    await svc.cabut_sesi(db, body.refresh_token)
    return Response(status_code=204)


@router.post("/logout-semua")
async def logout_semua(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Keluar dari SEMUA perangkat (mis. ganti perangkat / curiga akun dipakai orang lain)."""
    return {"sesi_dicabut": await svc.cabut_semua_sesi(db, user.id)}


@router.get("/me", response_model=UserOut)
async def saya(user: User = Depends(get_current_user)):
    return _user_out(user)


@router.post("/google", response_model=TokenPair)
async def masuk_google(body: GoogleReq, request: Request, db: AsyncSession = Depends(get_db)):
    """Masuk/daftar dengan Google. Klien mengirim ID token; server memverifikasinya lalu menerbitkan token GALERIA sendiri
    (ID token Google dibuang setelah dipakai)."""
    _butuh_konfigurasi()
    try:
        info = await svc.verifikasi_google(body.id_token)
    except svc.AuthError as e:
        raise HTTPException(e.status, e.pesan)
    sub, email = info["sub"], info["email"].strip().lower()
    user = (await db.execute(select(User).where(User.google_sub == sub))).scalar_one_or_none()
    if user is None:
        user = (await db.execute(select(User).where(User.email == email))).scalar_one_or_none()
        if user is not None:
            # Tautkan Google ke akun email yang sudah ada. Bila email akun itu BELUM terverifikasi, kata sandinya mungkin
            # dibuat orang lain yang mendaftar dengan email korban lebih dulu -> kata sandi dihapus + semua sesi dicabut.
            # Urutan penting: google_sub diisi DULU, karena DB mewajibkan minimal satu kredensial (password ATAU google_sub).
            tak_terverifikasi = not user.email_verified
            user.google_sub = sub
            user.email_verified = True
            if tak_terverifikasi:
                user.password_hash = None
                await svc.cabut_semua_sesi(db, user.id)  # commit: perubahan akun di atas ikut tersimpan
            user.avatar_url = user.avatar_url or info.get("picture")
        else:
            if body.role is None:
                raise HTTPException(422, "Akun baru: pilih peran (seniman/kolektor/komunitas) dulu.")
            user = User(
                id=uuid.uuid4(), email=email, password_hash=None, google_sub=sub,
                display_name=(info.get("name") or email.split("@")[0])[:60], avatar_url=info.get("picture"),
                role=UserRole(body.role), email_verified=True,
            )
            db.add(user)
        try:
            await db.flush()
        except IntegrityError:
            await db.rollback()
            raise HTTPException(409, "Akun dengan data ini sudah ada. Coba masuk lagi.")
    if not user.is_active:
        raise HTTPException(403, "Akun ini dinonaktifkan. Hubungi admin GALERIA.")
    return await _terbitkan(db, user, request, body.device)
