"""Skema response `POST /api/karya` (lihat routers/karya_upload.py)."""

from __future__ import annotations

from pydantic import BaseModel

from schemas.katalog import KaryaListItem


class KaryaCreated(BaseModel):
    id: str
    status_verifikasi: str


class KaryaSayaPage(BaseModel):
    """Respons ``GET /api/karya-saya``."""

    items: list[KaryaListItem]
    page: int
    page_size: int
    total: int
