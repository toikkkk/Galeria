"""Skema tulis ulasan kolektor. Sentimen TIDAK dihitung di server (tanpa torch): ulasan disimpan
dulu dengan status ``menunggu_analisis`` lalu dianalisis batch oleh ``ml-sentiment/scripts/analisis_ulasan_baru.py``."""

from __future__ import annotations

from pydantic import BaseModel, Field, field_validator

TEKS_MIN, TEKS_MAKS = 10, 500


class UlasanBaru(BaseModel):
    karya_id: str
    kolektor_id: str
    rating: int = Field(ge=1, le=5)
    teks: str

    @field_validator("teks")
    @classmethod
    def _teks(cls, v: str) -> str:
        v = " ".join(v.split())  # rapikan spasi/baris baru
        if not (TEKS_MIN <= len(v) <= TEKS_MAKS):
            raise ValueError(f"teks ulasan harus {TEKS_MIN}-{TEKS_MAKS} karakter")
        return v


class UlasanTersimpan(BaseModel):
    ulasan_id: str
    karya_id: str
    rating: int
    status: str = "menunggu_analisis"


class KolektorUlasan(BaseModel):
    id: str
    display_name: str
