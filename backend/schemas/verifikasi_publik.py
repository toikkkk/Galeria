"""Skema respons ``GET /api/verifikasi/{artwork_id}`` -- lihat routers/verifikasi_publik.py."""

from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel


class RiwayatKepemilikan(BaseModel):
    pemilik_id: str
    sumber: str
    diperoleh_at: datetime
    dilepas_at: datetime | None


class HasilVerifikasiPublik(BaseModel):
    artwork_id: str
    karya_id: str
    title: str
    creator_name: str
    status_akhir: str
    file_hash: str
    verified_at: datetime

    # Dua pengecekan TERPISAH (bukan 1 boolean "valid" tunggal) -- lihat
    # routers/verifikasi_publik.py untuk alasan kenapa keduanya wajib dicek.
    hash_cocok: bool       # data sertifikat saat ini != waktu ditandatangani?
    signature_valid: bool  # signature matematis valid thd payload_hash tersimpan?

    status_keseluruhan: Literal["VALID", "INVALID"]
    peringatan_key_dicabut: bool  # True kalau signing_key_id sudah di-revoke (SPEC_PAYLOAD.md 1.5)

    current_owner_id: str | None
    riwayat_kepemilikan: list[RiwayatKepemilikan]
