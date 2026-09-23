"""Skema request/response Pydantic untuk endpoint katalog karya.

Field mirror persis ``mobile/lib/models/karya.dart`` (class ``Karya``) --
lihat catatan yang sama di ``models/karya.py``.
"""

from __future__ import annotations

from pydantic import BaseModel


class KaryaListItem(BaseModel):
    """Satu baris di ``GET /api/katalog``."""

    id: str
    title: str
    artist_name: str
    style_name: str
    gallery_name: str
    price_idr: int
    is_promoted: bool
    image_filename: str


class KaryaDetail(KaryaListItem):
    """Detail 1 karya di ``GET /api/karya/{karya_id}``.

    Sama seperti [KaryaListItem] untuk sekarang -- belum ada field tambahan
    (deskripsi, ukuran fisik cm utk AR, dll, lihat CLAUDE.md skema `karya`)
    karena tabel `karya` saat ini masih versi minimal (fase Visual Search).
    """


class KatalogPage(BaseModel):
    """Respons ``GET /api/katalog`` (paginated)."""

    items: list[KaryaListItem]
    page: int
    page_size: int
    total: int
