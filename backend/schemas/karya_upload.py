"""Skema response `POST /api/karya` (lihat routers/karya_upload.py)."""

from __future__ import annotations

from pydantic import BaseModel


class KaryaCreated(BaseModel):
    id: str
    status_verifikasi: str
