"""Login admin dashboard: satu akun admin dari env (bukan tabel ``users``), token JWT bertanda tangan.

Sementara modul Auth tim (users/auth_sessions) belum ada. Password disimpan sebagai hash bcrypt di
``ADMIN_PASSWORD_HASH`` (buat dgn ``python scripts/buat_hash_admin.py``) -- tidak pernah plaintext.
"""

from __future__ import annotations

import hmac
import os
import time
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt

ALGO = "HS256"
TTL_MENIT = 60
TTL_INGAT_MENIT = 7 * 24 * 60   # 'Ingat saya' = 7 hari
BATAS_GAGAL = 5       # percobaan gagal per IP ...
JEDA_DETIK = 300      # ... lalu dikunci selama ini

_gagal: dict[str, list[float]] = {}

# hash dummy: bcrypt tetap dihitung saat email salah, supaya waktu respons tidak membocorkan email mana yang valid
_HASH_DUMMY = bcrypt.hashpw(b"dummy", bcrypt.gensalt(12))


def terkonfigurasi() -> bool:
    return bool(os.environ.get("ADMIN_EMAIL") and os.environ.get("ADMIN_PASSWORD_HASH") and _secret())


def _secret() -> str:
    return os.environ.get("ADMIN_JWT_SECRET") or os.environ.get("JWT_SECRET") or ""


def terkunci(ip: str) -> int:
    """Sisa detik kunci untuk IP ini (0 = boleh mencoba)."""
    sekarang = time.time()
    percobaan = [t for t in _gagal.get(ip, []) if sekarang - t < JEDA_DETIK]
    _gagal[ip] = percobaan
    if len(percobaan) >= BATAS_GAGAL:
        return int(JEDA_DETIK - (sekarang - percobaan[0])) + 1
    return 0


def catat_gagal(ip: str) -> None:
    _gagal.setdefault(ip, []).append(time.time())


def reset_gagal(ip: str) -> None:
    _gagal.pop(ip, None)


def cek_kredensial(email: str, password: str) -> bool:
    email_ok = hmac.compare_digest(email.strip().lower().encode(), os.environ["ADMIN_EMAIL"].strip().lower().encode())
    try:
        hash_asli = os.environ["ADMIN_PASSWORD_HASH"].encode()
        pw_ok = bcrypt.checkpw(password.encode()[:72], hash_asli if email_ok else _HASH_DUMMY)
    except ValueError:  # hash di .env rusak
        return False
    return email_ok and pw_ok


def buat_token(ingat: bool = False) -> tuple[str, int]:
    ttl = TTL_INGAT_MENIT if ingat else TTL_MENIT
    exp = datetime.now(timezone.utc) + timedelta(minutes=ttl)
    token = jwt.encode(
        {"sub": "admin", "role": "admin", "exp": exp}, _secret(), algorithm=ALGO
    )
    return token, ttl * 60


def token_valid(token: str) -> bool:
    try:
        d = jwt.decode(token, _secret(), algorithms=[ALGO], options={"require": ["exp", "sub"]})
    except jwt.PyJWTError:
        return False
    return d.get("role") == "admin"
