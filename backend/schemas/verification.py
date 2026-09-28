"""Skema request/response Pydantic untuk endpoint verification engine
(Art-to-Art + Art-to-AI). Bentuknya mengikuti persis output
``DigitalArtIdentityService.verify()`` -- lihat
``services/digital_art_identity_service.py``.
"""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field


class DuplicateMatch(BaseModel):
    karya_id: str            # UUID baris `karya` di database
    distance: float = Field(ge=0)   # jarak Euclidean (Art-to-Art), BUKAN cosine similarity
    title: str
    artist_name: str
    image_filename: str


class VerificationResult(BaseModel):
    """Respons ``POST /api/verification/check`` dan ``POST /api/karya/{karya_id}/verify``."""

    art_to_art_result: Literal["lolos", "duplikat_terdeteksi"]
    ai_detection_result: Literal["lolos", "ai_generated_terdeteksi"]
    # Rekomendasi, BUKAN keputusan final -- lihat
    # DigitalArtIdentityService._decide_status untuk alasan tiap aturan.
    # "ai_generated_terdeteksi" TIDAK PERNAH menghasilkan "ditolak" otomatis.
    rekomendasi_status: Literal["terverifikasi", "ditolak", "perlu_ditinjau"]
    ai_generated_probability: float = Field(ge=0, le=1)
    phash: str
    duplicate_matches: list[DuplicateMatch]
    model_version_arttoart: str
    model_version_arttoai: str
    persisted: bool   # true kalau hasil ditulis ke karya_fingerprints/karya_verifikasi_log
