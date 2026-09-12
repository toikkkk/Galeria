"""Endpoint katalog: list karya & detail 1 karya.

Skeleton -- sumber data (database karya asli platform) belum ada; sekarang
masih riset pakai metadata WikiArt (`ml-visual-search/data/raw/metadata.csv`).
Ganti ke database sungguhan begitu tabel karya/penjual/harga sudah dirancang.
"""

from __future__ import annotations

from fastapi import APIRouter, HTTPException

router = APIRouter(prefix="/api", tags=["katalog"])


@router.get("/katalog")
async def list_katalog(page: int = 1, page_size: int = 20):
    """List karya (paginated). TODO: baca dari database karya platform."""
    raise NotImplementedError


@router.get("/karya/{karya_id}")
async def get_karya(karya_id: str):
    """Detail 1 karya: pelukis, style, genre, harga, penjual, ukuran fisik (utk AR)."""
    # TODO: 404 kalau karya_id tidak ada
    raise NotImplementedError
