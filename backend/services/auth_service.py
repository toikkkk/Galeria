"""Logic Auth pengguna: hash password (bcrypt), access token JWT, refresh token ter-hash di ``auth_sessions``.

Desain (lihat root CLAUDE.md "Autentikasi"):
* Access token = JWT pendek (15 menit), stateless. Refresh token = acak, 30 hari, DISIMPAN TER-HASH di ``auth_sessions``
  sehingga bisa dicabut (logout paksa / ban) walau JWT-nya stateless.
* Refresh token berformat ``<session_id>.<rahasia>``: lookup lewat PK (bukan scan tabel) dan dibandingkan waktu-konstan.
* Refresh = ROTASI: tiap pemakaian menerbitkan token baru; token lama otomatis tidak berlaku. Memakai token lama
  (tanda dicuri / klien tersinkron salah) mencabut sesi itu.
* Secret = ``JWT_SECRET`` (BUKAN ``ADMIN_JWT_SECRET``) dan audience ``galeria-app`` -- token pengguna tidak bisa lolos
  sebagai token admin dashboard, dan sebaliknya.

Keterbatasan yang disengaja (MVP): pembatas percobaan login disimpan di memori proses (hilang saat restart, tidak
dibagi antar-worker); access token yang sudah terbit tetap valid sampai kedaluwarsa (maks 15 menit) walau sesinya dicabut.
"""

from __future__ import annotations

import asyncio
import hashlib
import hmac
import ipaddress
import os
import secrets
import time
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from models.user import AuthSession, User

ALGO = "HS256"
AUDIENCE = "galeria-app"
ACCESS_MENIT = 15
REFRESH_HARI = 30
BCRYPT_COST = 12

BATAS_GAGAL = 5
JEDA_DETIK = 300
_gagal: dict[str, list[float]] = {}
_hash_dummy_cache: bytes | None = None


class AuthError(Exception):
    """Error auth yang aman ditampilkan ke klien (``status`` = kode HTTP)."""

    def __init__(self, status: int, pesan: str):
        super().__init__(pesan)
        self.status = status
        self.pesan = pesan


# ------------------------------------------------------------------ konfigurasi
def _secret() -> str:
    # sengaja tanpa fallback ke ADMIN_JWT_SECRET
    return os.environ.get("JWT_SECRET", "")


def terkonfigurasi() -> bool:
    return bool(_secret())


def google_client_id() -> str:
    return os.environ.get("GOOGLE_OAUTH_CLIENT_ID", "")


# ------------------------------------------------------------------ password
def _hash_dummy() -> bytes:
    """Hash tiruan supaya waktu respons tidak membocorkan apakah email terdaftar."""
    global _hash_dummy_cache
    if _hash_dummy_cache is None:
        import bcrypt

        _hash_dummy_cache = bcrypt.hashpw(b"dummy", bcrypt.gensalt(BCRYPT_COST))
    return _hash_dummy_cache


async def hash_password(pw: str) -> str:
    import bcrypt

    # bcrypt ~250 ms (CPU-bound): jalankan di thread agar event loop tidak macet
    return (await asyncio.to_thread(bcrypt.hashpw, pw.encode(), bcrypt.gensalt(BCRYPT_COST))).decode()


async def cek_password(pw: str, hash_tersimpan: str | None) -> bool:
    """Selalu menghitung bcrypt (pakai hash tiruan bila akun/hash tidak ada) agar waktu respons seragam."""
    import bcrypt

    target = hash_tersimpan.encode() if hash_tersimpan else _hash_dummy()
    try:
        ok = await asyncio.to_thread(bcrypt.checkpw, pw.encode()[:72], target)
    except ValueError:  # hash rusak
        return False
    return ok and hash_tersimpan is not None


# ------------------------------------------------------------------ pembatas percobaan
def _kunci(email: str, ip: str) -> str:
    return f"{ip}|{email}"


def sisa_kunci(email: str, ip: str) -> int:
    """Sisa detik terkunci untuk kombinasi (IP, email); 0 = boleh mencoba."""
    k, sekarang = _kunci(email, ip), time.time()
    percobaan = [t for t in _gagal.get(k, []) if sekarang - t < JEDA_DETIK]
    _gagal[k] = percobaan
    if len(percobaan) >= BATAS_GAGAL:
        return int(JEDA_DETIK - (sekarang - percobaan[0])) + 1
    return 0


def catat_gagal(email: str, ip: str) -> None:
    _gagal.setdefault(_kunci(email, ip), []).append(time.time())


def reset_gagal(email: str, ip: str) -> None:
    _gagal.pop(_kunci(email, ip), None)


# ------------------------------------------------------------------ token
def _sekarang() -> datetime:
    return datetime.now(timezone.utc)


def buat_access_token(user: User, sesi_id: uuid.UUID) -> tuple[str, int]:
    import jwt

    sekarang = _sekarang()
    exp = sekarang + timedelta(minutes=ACCESS_MENIT)
    token = jwt.encode(
        {"sub": str(user.id), "role": user.role.value, "sid": str(sesi_id), "aud": AUDIENCE, "iat": sekarang, "exp": exp},
        _secret(),
        algorithm=ALGO,
    )
    return token, ACCESS_MENIT * 60


def baca_access_token(token: str) -> dict | None:
    """Payload token bila valid (tanda tangan, audience, kedaluwarsa), selain itu None."""
    import jwt

    try:
        return jwt.decode(token, _secret(), algorithms=[ALGO], audience=AUDIENCE, options={"require": ["exp", "sub", "aud"]})
    except jwt.PyJWTError:
        return None


def _hash_refresh(rahasia: str) -> str:
    # rahasia berentropi tinggi (384 bit), jadi SHA-256 cukup (bcrypt tidak perlu)
    return hashlib.sha256(rahasia.encode()).hexdigest()


def _ip_valid(ip: str | None) -> str | None:
    try:
        return str(ipaddress.ip_address(ip)) if ip else None
    except ValueError:
        return None


async def buat_sesi(db: AsyncSession, user: User, *, device: str | None, ip: str | None) -> tuple[AuthSession, str]:
    """Buat sesi baru; mengembalikan (sesi, refresh_token mentah). Token mentah hanya ada di sini -- tidak disimpan."""
    rahasia = secrets.token_urlsafe(48)
    sesi = AuthSession(
        id=uuid.uuid4(),
        user_id=user.id,
        refresh_token_hash=_hash_refresh(rahasia),
        device_info=(device or "")[:200] or None,
        ip_address=_ip_valid(ip),
        expires_at=_sekarang() + timedelta(days=REFRESH_HARI),
    )
    db.add(sesi)
    await db.flush()
    return sesi, f"{sesi.id}.{rahasia}"


def _pecah_refresh(token: str) -> tuple[uuid.UUID, str] | None:
    sid, titik, rahasia = token.partition(".")
    if not titik or not rahasia:
        return None
    try:
        return uuid.UUID(sid), rahasia
    except ValueError:
        return None


async def putar_refresh(db: AsyncSession, token: str) -> tuple[User, AuthSession, str]:
    """Tukar refresh token dengan pasangan baru (rotasi). Memakai token lama/salah mencabut sesinya."""
    gagal = AuthError(401, "Sesi tidak valid atau sudah berakhir. Silakan masuk lagi.")
    bagian = _pecah_refresh(token)
    if bagian is None:
        raise gagal
    sid, rahasia = bagian
    # FOR UPDATE: dua permintaan refresh bersamaan pada sesi yang sama diproses bergantian
    sesi = (await db.execute(select(AuthSession).where(AuthSession.id == sid).with_for_update())).scalar_one_or_none()
    if sesi is None or sesi.revoked_at is not None or sesi.expires_at <= _sekarang():
        raise gagal
    if not hmac.compare_digest(sesi.refresh_token_hash, _hash_refresh(rahasia)):
        # token lama dipakai ulang: anggap bocor/tersinkron salah -> cabut sesi ini
        sesi.revoked_at = _sekarang()
        await db.commit()
        raise gagal
    user = await db.get(User, sesi.user_id)
    if user is None or not user.is_active:
        raise gagal
    baru = secrets.token_urlsafe(48)
    sesi.refresh_token_hash = _hash_refresh(baru)
    sesi.expires_at = _sekarang() + timedelta(days=REFRESH_HARI)
    await db.flush()
    return user, sesi, f"{sesi.id}.{baru}"


async def cabut_sesi(db: AsyncSession, token: str) -> None:
    """Logout satu perangkat. Idempoten: token tak dikenal dibiarkan (tidak membocorkan apa pun)."""
    bagian = _pecah_refresh(token)
    if bagian is None:
        return
    sid, rahasia = bagian
    sesi = (await db.execute(select(AuthSession).where(AuthSession.id == sid))).scalar_one_or_none()
    if sesi and sesi.revoked_at is None and hmac.compare_digest(sesi.refresh_token_hash, _hash_refresh(rahasia)):
        sesi.revoked_at = _sekarang()
        await db.commit()


async def cabut_semua_sesi(db: AsyncSession, user_id: uuid.UUID) -> int:
    hasil = await db.execute(
        update(AuthSession)
        .where(AuthSession.user_id == user_id, AuthSession.revoked_at.is_(None))
        .values(revoked_at=_sekarang())
    )
    await db.commit()
    return hasil.rowcount or 0


# ------------------------------------------------------------------ Google
async def verifikasi_google(id_token_str: str) -> dict:
    """Verifikasi ID token Google (tanda tangan, audience = Client ID Web kita, kedaluwarsa). Token TIDAK disimpan."""
    cid = google_client_id()
    if not cid:
        raise AuthError(503, "Login Google belum dikonfigurasi di server.")
    try:
        from google.auth.transport import requests as g_requests
        from google.oauth2 import id_token
    except ImportError:
        raise AuthError(503, "Paket google-auth belum terpasang di server.")
    try:
        info = await asyncio.to_thread(id_token.verify_oauth2_token, id_token_str, g_requests.Request(), cid)
    except ValueError:
        raise AuthError(401, "Token Google tidak valid.")
    if not info.get("email") or not info.get("email_verified") or not info.get("sub"):
        raise AuthError(401, "Akun Google belum terverifikasi emailnya.")
    return info
