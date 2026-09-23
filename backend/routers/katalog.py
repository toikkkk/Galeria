"""Endpoint katalog: list karya & detail 1 karya.

Baca dari tabel ``karya`` (Postgres/Neon, lihat ``models/karya.py``) -- bukan
lagi placeholder/metadata riset WikiArt.
"""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models.karya import Karya
from schemas.katalog import KaryaDetail, KaryaListItem, KatalogPage

router = APIRouter(prefix="/api", tags=["katalog"])


def _to_list_item(karya: Karya) -> KaryaListItem:
    return KaryaListItem(
        id=str(karya.id),
        title=karya.title,
        artist_name=karya.artist_name,
        style_name=karya.style_name,
        gallery_name=karya.gallery_name,
        price_idr=karya.price_idr,
        is_promoted=karya.is_promoted,
        image_filename=karya.image_filename,
    )


@router.get("/katalog", response_model=KatalogPage)
async def list_katalog(page: int = 1, page_size: int = 20, db: AsyncSession = Depends(get_db)):
    """List karya (paginated)."""
    if page < 1 or page_size < 1:
        raise HTTPException(400, "page dan page_size harus >= 1")

    total = (await db.execute(select(func.count()).select_from(Karya))).scalar_one()
    rows = (
        await db.execute(
            select(Karya)
            .order_by(Karya.created_at.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
    ).scalars()

    return KatalogPage(
        items=[_to_list_item(k) for k in rows],
        page=page,
        page_size=page_size,
        total=total,
    )


@router.get("/karya/{karya_id}", response_model=KaryaDetail)
async def get_karya(karya_id: str, db: AsyncSession = Depends(get_db)):
    """Detail 1 karya."""
    try:
        karya_uuid = uuid.UUID(karya_id)
    except ValueError:
        raise HTTPException(404, "Karya tidak ditemukan")

    karya = await db.get(Karya, karya_uuid)
    if karya is None:
        raise HTTPException(404, "Karya tidak ditemukan")

    item = _to_list_item(karya)
    return KaryaDetail(**item.model_dump())
