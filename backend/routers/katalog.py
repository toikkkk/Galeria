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
from models.karya import Karya, StatusVerifikasiKarya
from models.verification import KaryaFingerprint
from schemas.katalog import KaryaDetail, KaryaListItem, KatalogPage

router = APIRouter(prefix="/api", tags=["katalog"])


def _to_list_item(karya: Karya, fp: KaryaFingerprint | None = None) -> KaryaListItem:
    return KaryaListItem(
        seniman_id=str(karya.seniman_id) if karya.seniman_id else None,
        ai_generated_probability=fp.ai_generated_probability if fp else None,
        model_version_arttoart=fp.model_version_arttoart if fp else None,
        model_version_arttoai=fp.model_version_arttoai if fp else None,
        id=str(karya.id),
        title=karya.title,
        artist_name=karya.artist_name,
        style_name=karya.style_name,
        gallery_name=karya.gallery_name,
        price_idr=karya.price_idr,
        is_promoted=karya.is_promoted,
        image_filename=karya.image_filename,
        # image_key diisi relatif (mis. "uploads/karya/<uuid>.jpg") oleh
        # POST /api/karya -- jadikan path absolut "/uploads/..." di sini,
        # client (mobile) yang prepend base URL (lihat schemas/katalog.py).
        image_url=f"/{karya.image_key}" if karya.image_key else None,
    )


@router.get("/katalog", response_model=KatalogPage)
async def list_katalog(
    page: int = 1,
    page_size: int = 20,
    seniman_id: str | None = None,
    q: str | None = None,
    db: AsyncSession = Depends(get_db),
):
    """List karya (paginated) -- HANYA yang `status_verifikasi=terverifikasi`
    dan belum di-soft-delete. Karya "menunggu"/"ditolak"/"perlu_ditinjau"
    TIDAK boleh tampil di katalog publik (lihat models/karya.py).

    - `seniman_id`: filter "milik saya" -- hanya karya seniman itu. Setelah
      Auth ada, nilai ini diambil dari JWT, bukan query param.
    - `q`: cari di judul / nama seniman / galeri (case-insensitive).
    """
    if page < 1 or page_size < 1:
        raise HTTPException(400, "page dan page_size harus >= 1")

    base_filter = (
        Karya.status_verifikasi == StatusVerifikasiKarya.TERVERIFIKASI
    ) & (Karya.deleted_at.is_(None))
    if seniman_id:
        try:
            base_filter = base_filter & (Karya.seniman_id == uuid.UUID(seniman_id))
        except ValueError:
            raise HTTPException(400, "seniman_id bukan UUID valid")
    if q and q.strip():
        like = f"%{q.strip()}%"
        base_filter = base_filter & (
            Karya.title.ilike(like) | Karya.artist_name.ilike(like) | Karya.gallery_name.ilike(like)
        )

    total = (
        await db.execute(select(func.count()).select_from(Karya).where(base_filter))
    ).scalar_one()
    rows = (
        await db.execute(
            select(Karya, KaryaFingerprint)
            .outerjoin(KaryaFingerprint, KaryaFingerprint.karya_id == Karya.id)
            .where(base_filter)
            .order_by(Karya.created_at.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
    ).all()

    return KatalogPage(
        items=[_to_list_item(k, fp) for k, fp in rows],
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

    fp = await db.get(KaryaFingerprint, karya_uuid)
    item = _to_list_item(karya, fp)
    return KaryaDetail(**item.model_dump())
