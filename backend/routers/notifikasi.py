"""Notifikasi in-app milik pengguna yang login. Penerbitan: services/notifikasi_service.py."""

from __future__ import annotations

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models.engagement import Notifikasi
from models.user import User
from services.auth_deps import get_current_user

router = APIRouter(prefix="/api/notifikasi", tags=["notifikasi"])


class NotifikasiOut(BaseModel):
    id: str
    tipe: str
    judul: str
    isi: str | None
    tautan: str | None
    dibaca: bool
    waktu: datetime


class NotifikasiList(BaseModel):
    items: list[NotifikasiOut]
    belum_dibaca: int
    ada_lagi: bool


class Jumlah(BaseModel):
    belum_dibaca: int


def _out(n: Notifikasi) -> NotifikasiOut:
    return NotifikasiOut(id=str(n.id), tipe=n.tipe.value, judul=n.judul, isi=n.isi, tautan=n.tautan, dibaca=n.is_read, waktu=n.created_at)


async def _belum(db: AsyncSession, user: User) -> int:
    return int((await db.execute(select(func.count()).select_from(Notifikasi).where(Notifikasi.user_id == user.id, Notifikasi.is_read.is_(False)))).scalar_one())


@router.get("", response_model=NotifikasiList)
async def daftar(
    belum: bool = Query(False, description="hanya yang belum dibaca"),
    sebelum: datetime | None = Query(None, description="halaman berikutnya: ambil yang lebih lama dari waktu ini"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    q = select(Notifikasi).where(Notifikasi.user_id == user.id)
    if belum:
        q = q.where(Notifikasi.is_read.is_(False))
    if sebelum is not None:
        q = q.where(Notifikasi.created_at < sebelum)
    rows = list((await db.execute(q.order_by(Notifikasi.created_at.desc()).limit(31))).scalars())
    return NotifikasiList(items=[_out(n) for n in rows[:30]], belum_dibaca=await _belum(db, user), ada_lagi=len(rows) > 30)


@router.get("/jumlah", response_model=Jumlah)
async def jumlah(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Jumlah belum dibaca (untuk titik merah di ikon lonceng)."""
    return Jumlah(belum_dibaca=await _belum(db, user))


@router.post("/baca-semua", response_model=Jumlah)
async def baca_semua(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    await db.execute(update(Notifikasi).where(Notifikasi.user_id == user.id, Notifikasi.is_read.is_(False)).values(is_read=True))
    await db.commit()
    return Jumlah(belum_dibaca=0)


@router.post("/{notifikasi_id}/baca", response_model=Jumlah)
async def baca(notifikasi_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    try:
        nid = uuid.UUID(notifikasi_id)
    except ValueError:
        raise HTTPException(404, "Notifikasi tidak ditemukan")
    n = await db.get(Notifikasi, nid)
    if n is None or n.user_id != user.id:
        raise HTTPException(404, "Notifikasi tidak ditemukan")  # bukan 403: jangan bocorkan notifikasi orang lain
    n.is_read = True
    await db.commit()
    return Jumlah(belum_dibaca=await _belum(db, user))
