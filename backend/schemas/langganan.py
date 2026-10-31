"""Skema langganan, promosi karya, dan tagihan."""

from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field, field_validator

from schemas.pesanan import InstruksiBayar, MetodeBayar

Plan = Literal["komunitas_pro", "ar_akses"]


class PaketOut(BaseModel):
    plan: str
    nama: str
    harga_idr: int
    durasi_hari: int
    untuk: list[str]  # peran akun yang boleh membeli
    manfaat: list[str]


class PromosiHarga(BaseModel):
    durasi_hari: int
    harga_idr: int


class PaketList(BaseModel):
    paket: list[PaketOut]
    promosi: list[PromosiHarga]


class LanggananAktif(BaseModel):
    plan: str
    nama: str
    mulai_at: datetime
    berakhir_at: datetime
    sisa_hari: int


class LanggananSaya(BaseModel):
    aktif: list[LanggananAktif]
    pro: bool  # komunitas_pro aktif
    ar: bool  # ar_akses aktif


class BeliLangganan(BaseModel):
    plan: Plan


class BeliPromosi(BaseModel):
    karya_id: str
    durasi_hari: int
    di_beranda: bool = True
    di_lelang: bool = True

    @field_validator("durasi_hari")
    @classmethod
    def _durasi(cls, v: int) -> int:
        if v not in (7, 14, 30):
            raise ValueError("durasi promosi harus 7, 14, atau 30 hari")
        return v


class BayarTagihanIn(BaseModel):
    metode: MetodeBayar


class TagihanOut(BaseModel):
    id: str
    jenis: str
    judul: str
    jumlah_idr: int
    status: str
    status_label: str
    instruksi_bayar: InstruksiBayar | None = None
    batas_bayar_at: datetime | None = None
    dibayar_at: datetime | None = None
    aksi: list[str] = Field(default_factory=list)


class PromosiOut(BaseModel):
    id: str
    karya_id: str
    judul_karya: str
    durasi_hari: int
    harga_idr: int
    di_beranda: bool
    di_lelang: bool
    mulai_at: datetime
    berakhir_at: datetime
    aktif: bool


class PromosiList(BaseModel):
    items: list[PromosiOut]
