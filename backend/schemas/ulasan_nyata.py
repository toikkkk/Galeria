"""Skema ulasan pembeli (ulasan atas pesanan yang sudah diterima)."""

from __future__ import annotations

from pydantic import BaseModel, Field, field_validator

TEKS_MIN, TEKS_MAKS = 10, 500


class UlasanPesananIn(BaseModel):
    rating: int = Field(ge=1, le=5)
    teks: str

    @field_validator("teks")
    @classmethod
    def _teks(cls, v: str) -> str:
        v = " ".join(v.split())
        if not (TEKS_MIN <= len(v) <= TEKS_MAKS):
            raise ValueError(f"teks ulasan harus {TEKS_MIN}-{TEKS_MAKS} karakter")
        return v


class UlasanOut(BaseModel):
    id: str
    karya_id: str
    rating: int
    status: str  # "menunggu_analisis" | "dianalisis"


class UlasanKaryaItem(BaseModel):
    nama: str
    rating: int
    teks: str
    tanggal: str  # ISO 8601
    sentimen: str | None = None


class UlasanKaryaOut(BaseModel):
    jumlah: int
    rata2: float | None
    sebaran: dict[str, int]  # "1".."5" -> jumlah
    items: list[UlasanKaryaItem]
