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
    # Path relatif (mis. "/uploads/karya/<uuid>.jpg") kalau karya di-upload
    # lewat POST /api/karya (lihat routers/karya_upload.py) -- mobile
    # prepend base URL-nya sendiri. NULL = karya lama/seed, mobile fallback
    # ke asset lokal lewat `image_filename` (lihat models/karya.dart).
    image_url: str | None = None
    # Pemilik (kreator) karya -- NULL utk karya seed/upload sebelum Auth ada.
    # Dipakai filter "milik saya" (`GET /api/katalog?seniman_id=`).
    seniman_id: str | None = None
    # menunggu / terverifikasi / ditolak / perlu_ditinjau (di katalog publik selalu terverifikasi).
    status_verifikasi: str | None = None
    # Artwork ID sertifikat digital (GAL-ART-2026-000001); NULL = belum/tidak pernah lolos verifikasi.
    artwork_id: str | None = None
    # True bila karya sudah terjual / sedang dipesan (ada pesanan yang belum dibatalkan).
    terjual: bool = False
    # True bila karya sedang dalam lelang aktif (tidak bisa dibeli langsung); isi lelang_id utk membukanya.
    lelang_id: str | None = None
    # Ringkasan hasil verification engine (Art-to-Art + Art-to-AI) dari
    # tabel `karya_fingerprints`. NULL = karya belum pernah dicek engine
    # (mis. 8 karya seed lama).
    ai_generated_probability: float | None = None
    model_version_arttoart: str | None = None
    model_version_arttoai: str | None = None
    # Ukuran fisik (cm) utk AR; None = belum diisi seniman
    lebar_cm: float | None = None
    tinggi_cm: float | None = None


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
