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
    karya_id: str          # = filename/ID di katalog (mis. "wikiart_00042.jpg")
    similarity: float = Field(ge=-1, le=1)
    artist_name: str
    genre_name: str
    style_name: str
    # TODO saat katalog nyata sudah ada (bukan WikiArt riset): tambah field
    # harga, link_beli, nama_penjual, dll dari database karya.


class VisualSearchResponse(BaseModel):
    """Respons ``POST /api/visual-search``."""

    style_predictions: list[StylePrediction]
    catalog_matches: list[CatalogMatch]
    verdict: str    # "confirmed" | "ambiguous" | "not_found" -- lihat
                    # ml-visual-search/src/embedding.py::confidence_verdict
    verdict_message: str   # teks siap-tampil utk user, JANGAN overclaim kalau ambiguous
