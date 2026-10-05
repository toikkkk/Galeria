"""Endpoint katalog dummy (2.000 karya, gambar dari R2) + rekomendasi kolektor.

Data sintetis dari schema ``REKOMENDASI_SCHEMA`` (lihat ``ml-recommender/README.md``).
``GET /api/katalog`` & ``POST /api/visual-search`` (Visual Search) tidak disentuh.

Mock: env ``REKOMENDASI_MOCK=1`` menyajikan ``fixtures/rekomendasi_mock.json``
supaya UI bisa dikerjakan walau tabel ``rekomendasi_kolektor`` belum terisi.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from schemas.rekomendasi import KatalogDummyPage, KolektorDemo, RekomendasiResponse
from services import rekomendasi_repo as repo

router = APIRouter(prefix="/api", tags=["katalog-dummy", "rekomendasi"])

_MOCK_PATH = Path(__file__).resolve().parent.parent / "fixtures" / "rekomendasi_mock.json"
_BELUM_DIHITUNG = "Rekomendasi belum dihitung"


def _mock_aktif() -> bool:
    return os.environ.get("REKOMENDASI_MOCK", "").strip() in ("1", "true", "True")


def _muat_mock() -> dict:
    try:
        return json.loads(_MOCK_PATH.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise HTTPException(503, _BELUM_DIHITUNG)


@router.get("/katalog-dummy", response_model=KatalogDummyPage)
async def katalog_dummy(
    page: int = 1,
    page_size: int = 20,
    gaya: str | None = None,
    harga_min: int | None = None,
    harga_maks: int | None = None,
    q: str | None = None,
    urut: Literal["terbaru", "harga_asc", "harga_desc"] = "terbaru",
    hanya_tersedia: bool = True,
    db: AsyncSession = Depends(get_db),
):
    """Katalog 2.000 karya dummy (paginated, filter, pencarian)."""
    if page < 1 or page_size < 1:
        raise HTTPException(400, "page dan page_size harus >= 1")
    page_size = min(page_size, 100)
    items, total = await repo.katalog(
        db,
        page=page,
        page_size=page_size,
        gaya=gaya,
        harga_min=harga_min,
        harga_maks=harga_maks,
        q=q.strip() if q else None,
        urut=urut,
        hanya_tersedia=hanya_tersedia,
    )
    return KatalogDummyPage(items=items, page=page, page_size=page_size, total=total)


@router.get("/rekomendasi/demo-kolektor", response_model=list[KolektorDemo])
async def demo_kolektor(db: AsyncSession = Depends(get_db)):
    """Kolektor contoh (pengganti login sampai Auth selesai)."""
    if _mock_aktif():
        return [_muat_mock()["kolektor"]]
    return await repo.kolektor_demo(db)


@router.get("/rekomendasi/{kolektor_id}", response_model=RekomendasiResponse)
async def get_rekomendasi(
    kolektor_id: str,
    top_k: int = Query(10, ge=1, le=20),
    db: AsyncSession = Depends(get_db),
):
    """Rekomendasi karya untuk satu kolektor (urut ``peringkat``)."""
    kid = repo.parse_uuid(kolektor_id)
    if kid is None or not await repo.kolektor_ada(db, kid):
        raise HTTPException(404, "Kolektor tidak ditemukan")

    if _mock_aktif():
        mock = _muat_mock()
        if mock["rekomendasi"]["kolektor_id"] != str(kid):
            raise HTTPException(503, _BELUM_DIHITUNG)
        hasil = dict(mock["rekomendasi"])
        hasil["items"] = hasil["items"][:top_k]
        return hasil

    hasil = await repo.rekomendasi(db, kid, top_k)
    if hasil is None:
        raise HTTPException(503, _BELUM_DIHITUNG)
    return hasil
