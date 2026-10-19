"""Kolektor menulis ulasan untuk sebuah karya (rating + alasan). Data dummy, tanpa Auth: ``kolektor_id``
berasal dari kolektor contoh sampai modul Auth selesai. Sentimen dihitung batch, bukan di request ini."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.exc import ProgrammingError
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from schemas.ulasan import KolektorUlasan, UlasanBaru, UlasanTersimpan
from services import dashboard_repo, ulasan_repo as repo
from services.db_errors import tabel_belum_ada

router = APIRouter(prefix="/api/ulasan", tags=["ulasan"])


@router.get("/kolektor-demo", response_model=KolektorUlasan)
async def kolektor_demo(db: AsyncSession = Depends(get_db)):
    """Kolektor contoh sebagai penulis ulasan (pengganti login)."""
    k = await repo.kolektor_demo(db)
    if k is None:
        raise HTTPException(404, "Belum ada kolektor contoh")
    return k


@router.post("", response_model=UlasanTersimpan, status_code=201)
async def tulis_ulasan(body: UlasanBaru, db: AsyncSession = Depends(get_db)):
    kar = dashboard_repo.parse_uuid(body.karya_id)
    kol = dashboard_repo.parse_uuid(body.kolektor_id)
    if kar is None or kol is None:
        raise HTTPException(422, "karya_id / kolektor_id harus UUID")
    sen = await repo.seniman_dari_karya(db, kar)
    if sen is None:
        raise HTTPException(404, "Karya tidak ditemukan")
    if not await repo.kolektor_ada(db, kol):
        raise HTTPException(404, "Kolektor tidak ditemukan")
    try:
        uid = await repo.simpan(db, karya_id=kar, kolektor_id=kol, seniman_id=sen, rating=body.rating, teks=body.teks)
    except repo.SudahMengulas:
        raise HTTPException(409, "Kamu sudah pernah mengulas karya ini")
    except ProgrammingError as exc:
        await db.rollback()
        if not tabel_belum_ada(exc):
            raise  # bug SQL sungguhan: jangan disamarkan sebagai 'tabel belum ada'
        raise HTTPException(503, "Fitur ulasan belum siap (tabel belum dimigrasi)")
    return UlasanTersimpan(ulasan_id=uid, karya_id=str(kar), rating=body.rating)
