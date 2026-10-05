"""Skema respons katalog dummy & rekomendasi.

Bentuk mengikuti kontrak di ``ml-recommender/README.md`` -- jangan diubah
sepihak. ``gallery_name`` non-null (``Karya.fromJson`` di Flutter mewajibkannya).
"""

from __future__ import annotations

from pydantic import BaseModel

from schemas.katalog import KaryaListItem


class KaryaDummyItem(KaryaListItem):
    """Karya dummy: bentuk ``KaryaListItem`` + gambar R2 & ukuran fisik."""

    image_url: str | None = None
    seniman_id: str
    lebar_cm: float | None = None
    tinggi_cm: float | None = None


class KatalogDummyPage(BaseModel):
    items: list[KaryaDummyItem]
    page: int
    page_size: int
    total: int


class KolektorDemo(BaseModel):
    id: str
    display_name: str
    segmen: str | None = None
    n_pembelian: int


class Alasan(BaseModel):
    kode: str
    teks: str


class SegmenInfo(BaseModel):
    id: int
    nama: str


class ItemRekomendasi(BaseModel):
    peringkat: int
    skor: float
    alasan: list[Alasan]
    karya: KaryaDummyItem


class RekomendasiResponse(BaseModel):
    kolektor_id: str
    strategi: str
    model_version: str
    dihitung_pada: str
    segmen: SegmenInfo | None = None
    items: list[ItemRekomendasi]
