"""Skema response `POST /api/karya` (lihat routers/karya_upload.py)."""

from __future__ import annotations

from pydantic import BaseModel, Field, model_validator

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


class KaryaUbah(BaseModel):
    """Body ``PATCH /api/karya/{id}``: kirim HANYA field yang diubah. Gambar tidak bisa diganti di sini
    (gambar = dasar sertifikat keaslian; ganti gambar = unggah karya baru)."""

    title: str | None = Field(None, min_length=1, max_length=200)
    style_name: str | None = Field(None, min_length=1, max_length=100)
    gallery_name: str | None = Field(None, min_length=1, max_length=200)
    price_idr: int | None = Field(None, gt=0, le=100_000_000_000)
    lebar_cm: float | None = Field(None, gt=0, le=1000)
    tinggi_cm: float | None = Field(None, gt=0, le=1000)
    deskripsi: str | None = Field(None, max_length=2000)

    @model_validator(mode="after")
    def _minimal_satu(self):
        if not self.model_fields_set:
            raise ValueError("Tidak ada yang diubah.")
        return self
