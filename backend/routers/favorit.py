"""Favorit / wishlist karya milik pengguna yang login (tabel ``koleksi_favorit``)."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models.engagement import KoleksiFavorit
from models.karya import Karya, StatusVerifikasiKarya
from models.user import User
from routers.katalog import tandai_terjual, to_list_item
from schemas.katalog import KaryaListItem
from services.auth_deps import get_current_user

router = APIRouter(prefix="/api/favorit", tags=["favorit"])

MAKS_FAVORIT = 500


class IdList(BaseModel):
    ids: list[str]


def _kid(v: str) -> uuid.UUID:
    try:
        return uuid.UUID(v)
    except ValueError:
        raise HTTPException(404, "Karya tidak ditemukan")


@router.get("", response_model=list[KaryaListItem])
async def daftar(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Karya favoritmu, yang terbaru difavoritkan dulu (karya yang sudah dihapus/ditolak tidak ditampilkan)."""
    rows = (await db.execute(
        select(Karya).join(KoleksiFavorit, KoleksiFavorit.karya_id == Karya.id)
        .where(KoleksiFavorit.user_id == user.id, Karya.deleted_at.is_(None), Karya.status_verifikasi == StatusVerifikasiKarya.TERVERIFIKASI)
        .order_by(KoleksiFavorit.created_at.desc()).limit(MAKS_FAVORIT)
    )).scalars().all()
    items = [to_list_item(k) for k in rows]
    await tandai_terjual(db, items)
    return items


@router.get("/ids", response_model=IdList)
async def ids(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Id karya yang sudah kamu favoritkan (untuk menandai ikon hati di daftar mana pun)."""
    rows = (await db.execute(select(KoleksiFavorit.karya_id).where(KoleksiFavorit.user_id == user.id))).scalars().all()
    return IdList(ids=[str(r) for r in rows])


@router.post("/{karya_id}", response_model=IdList, status_code=201)
async def tambah(karya_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Favoritkan karya (idempoten: memfavoritkan dua kali tidak membuat dobel)."""
    kid = _kid(karya_id)
    karya = await db.get(Karya, kid)
    if karya is None or karya.deleted_at is not None or karya.status_verifikasi != StatusVerifikasiKarya.TERVERIFIKASI:
        raise HTTPException(404, "Karya tidak ditemukan")
    jumlah = (await db.execute(select(func.count()).select_from(KoleksiFavorit).where(KoleksiFavorit.user_id == user.id))).scalar_one()
    if jumlah >= MAKS_FAVORIT:
        raise HTTPException(409, f"Favorit penuh (maksimal {MAKS_FAVORIT}). Hapus beberapa dulu.")
    await db.execute(pg_insert(KoleksiFavorit).values(user_id=user.id, karya_id=kid).on_conflict_do_nothing())
    await db.commit()
    return await ids(user, db)


@router.delete("/{karya_id}", response_model=IdList)
async def hapus(karya_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    kid = _kid(karya_id)
    fav = await db.get(KoleksiFavorit, (user.id, kid))
    if fav is not None:
        await db.delete(fav)
        await db.commit()
    return await ids(user, db)
