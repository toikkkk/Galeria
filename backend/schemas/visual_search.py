"""Skema request/response Pydantic untuk endpoint Visual Search.

Bentuknya mengikuti persis output ``ml-visual-search/src/embedding.py`` +
``confidence_verdict`` (lihat ``notebooks/03_demo_inference.ipynb`` di sana
untuk contoh nilai asli) -- supaya konversi hasil model -> response API
tinggal isi field, tidak perlu redesain skema.
"""

from __future__ import annotations

from pydantic import BaseModel, Field


class StylePrediction(BaseModel):
    style: str
    confidence: float = Field(ge=0, le=1)


class CatalogMatch(BaseModel):
    karya_id: str           # UUID baris `karya` di database
    similarity: float = Field(ge=-1, le=1)
    title: str
    artist_name: str
    style_name: str
    gallery_name: str       # nama galeri/sanggar penjual
    price_idr: int          # contoh/placeholder, lihat models/karya.py
    # Nama file gambar -- dicocokkan ke aset lokal di
    # mobile/assets/images/catalog/ (belum ada hosting gambar/R2, lihat
    # CLAUDE.md "Di Luar Scope Fase Ini").
    image_filename: str


class VisualSearchResponse(BaseModel):
    """Respons ``POST /api/visual-search``."""

    # Selalu [] untuk sekarang -- model.onnx cuma expose embedding, TIDAK
    # expose logit klasifikasi style. Butuh re-export model dgn output
    # tambahan kalau nanti field ini mau diisi. Field tetap dipertahankan
    # di schema supaya tidak breaking change buat mobile begitu diisi nanti.
    style_predictions: list[StylePrediction]
    catalog_matches: list[CatalogMatch]
    verdict: str    # "confirmed" | "ambiguous" | "not_found" -- lihat
                    # ml-visual-search/src/embedding.py::confidence_verdict
    verdict_message: str   # teks siap-tampil utk user, JANGAN overclaim kalau ambiguous
