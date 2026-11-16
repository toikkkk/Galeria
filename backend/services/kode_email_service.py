"""Kode 6 digit sekali pakai untuk reset password dan verifikasi email.

Keamanan:
* Kode disimpan sebagai HMAC-SHA256 (kunci ``JWT_SECRET``), dibandingkan waktu-konstan.
* Kedaluwarsa 15 menit, maks 5 tebakan per kode (lewat itu kode mati, harus minta baru), sekali pakai.
* Meminta kode baru membatalkan kode lama yang belum dipakai. Jeda 60 detik antar permintaan, maks 5 per jam per akun.
* Pembatas per (IP, email) di memori proses melindungi endpoint publik dari penyalahgunaan (hilang saat restart).
"""

from __future__ import annotations

import hmac
import os
import secrets
import time
import uuid
from datetime import datetime, timedelta, timezone
from hashlib import sha256

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from models.kode_email import KodeEmail
from models.user import User

TTL_MENIT = 15
MAKS_PERCOBAAN = 5
JEDA_DETIK = 60
MAKS_PER_JAM = 5

_batas: dict[str, list[float]] = {}


class KodeError(Exception):
    def __init__(self, status: int, pesan: str):
        super().__init__(pesan)
        self.status = status
        self.pesan = pesan


def _now() -> datetime:
    return datetime.now(timezone.utc)


def batasi(kunci: str, maks: int, jendela_detik: int) -> int:
    """Catat satu percobaan; kembalikan sisa detik terkunci bila melewati ``maks`` dalam ``jendela_detik`` (0 = boleh)."""
    sekarang = time.time()
    riwayat = [t for t in _batas.get(kunci, []) if sekarang - t < jendela_detik]
    if len(riwayat) >= maks:
        _batas[kunci] = riwayat
        return int(jendela_detik - (sekarang - riwayat[0])) + 1
    riwayat.append(sekarang)
    _batas[kunci] = riwayat
    return 0


def _hash(user_id: uuid.UUID, tujuan: str, kode: str) -> str:
    kunci = os.environ.get("JWT_SECRET", "").encode()
    return hmac.new(kunci, f"{user_id}:{tujuan}:{kode}".encode(), sha256).hexdigest()


async def buat_kode(db: AsyncSession, user: User, tujuan: str) -> str:
    """Buat kode baru (membatalkan yang lama). Melempar ``KodeError`` (429) bila terlalu sering. Caller yang commit."""
    sekarang = _now()
    terakhir = await db.scalar(select(func.max(KodeEmail.created_at)).where(KodeEmail.user_id == user.id, KodeEmail.tujuan == tujuan))
    if terakhir is not None:
        sisa = JEDA_DETIK - int((sekarang - terakhir).total_seconds())
        if sisa > 0:
            raise KodeError(429, f"Tunggu {sisa} detik sebelum meminta kode lagi.")
    sejam = await db.scalar(select(func.count()).select_from(KodeEmail).where(
        KodeEmail.user_id == user.id, KodeEmail.tujuan == tujuan, KodeEmail.created_at > sekarang - timedelta(hours=1)))
    if (sejam or 0) >= MAKS_PER_JAM:
        raise KodeError(429, "Terlalu banyak permintaan kode. Coba lagi dalam satu jam.")
    await db.execute(update(KodeEmail).where(
        KodeEmail.user_id == user.id, KodeEmail.tujuan == tujuan, KodeEmail.dipakai_at.is_(None)).values(dipakai_at=sekarang))
    kode = f"{secrets.randbelow(10**6):06d}"
    db.add(KodeEmail(id=uuid.uuid4(), user_id=user.id, tujuan=tujuan, kode_hash=_hash(user.id, tujuan, kode),
                     kedaluwarsa_at=sekarang + timedelta(minutes=TTL_MENIT)))
    return kode


async def periksa_kode(db: AsyncSession, user: User, tujuan: str, kode: str) -> bool:
    """Cek kode terbaru yang masih berlaku. Jumlah percobaan dicatat; caller HARUS commit (juga saat gagal)."""
    baris = (await db.execute(
        select(KodeEmail).where(KodeEmail.user_id == user.id, KodeEmail.tujuan == tujuan, KodeEmail.dipakai_at.is_(None),
                                KodeEmail.kedaluwarsa_at > _now())
        .order_by(KodeEmail.created_at.desc()).limit(1).with_for_update())).scalar_one_or_none()
    if baris is None or baris.percobaan >= MAKS_PERCOBAAN:
        return False
    baris.percobaan += 1
    cocok = hmac.compare_digest(baris.kode_hash, _hash(user.id, tujuan, kode))
    if cocok:
        baris.dipakai_at = _now()
    return cocok
