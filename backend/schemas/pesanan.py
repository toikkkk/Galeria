"""Skema request/response alamat pengiriman & pesanan (checkout)."""

from __future__ import annotations

import re
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field, field_validator

MetodeBayar = Literal["va_bca", "va_mandiri", "va_bni", "qris"]


def _telepon(v: str) -> str:
    digit = "".join(c for c in v if c.isdigit())
    if digit.startswith("62"):
        digit = digit[2:]
    digit = digit.lstrip("0")
    if not (8 <= len(digit) <= 13):
        raise ValueError("nomor telepon tidak valid")
    return "+62" + digit


class AlamatIn(BaseModel):
    label: str = Field(min_length=1, max_length=40)
    nama_penerima: str = Field(min_length=2, max_length=80)
    telepon: str
    alamat_lengkap: str = Field(min_length=10, max_length=300)
    kota: str = Field(min_length=2, max_length=80)
    kode_pos: str

    @field_validator("telepon")
    @classmethod
    def _v_tel(cls, v: str) -> str:
        return _telepon(v)

    @field_validator("kode_pos")
    @classmethod
    def _v_pos(cls, v: str) -> str:
        v = v.strip()
        if not re.fullmatch(r"\d{5}", v):
            raise ValueError("kode pos harus 5 digit")
        return v

    @field_validator("label", "nama_penerima", "alamat_lengkap", "kota")
    @classmethod
    def _v_spasi(cls, v: str) -> str:
        return " ".join(v.split())


class AlamatOut(BaseModel):
    id: str
    label: str
    nama_penerima: str
    telepon: str
    alamat_lengkap: str
    kota: str
    kode_pos: str
    is_utama: bool


class PesananBuat(BaseModel):
    karya_id: str
    alamat_id: str


class BayarReq(BaseModel):
    metode: MetodeBayar


class KirimReq(BaseModel):
    kurir: str = Field(min_length=2, max_length=40)
    no_resi: str = Field(min_length=4, max_length=60)

    @field_validator("kurir", "no_resi")
    @classmethod
    def _v_spasi(cls, v: str) -> str:
        return " ".join(v.split())


class KaryaRingkas(BaseModel):
    id: str
    title: str
    artist_name: str
    style_name: str
    image_url: str | None = None
    image_filename: str | None = None


class InstruksiBayar(BaseModel):
    metode: str
    nama_metode: str
    nomor: str  # nomor virtual account / kode QRIS
    jumlah_idr: int
    batas_bayar_at: datetime | None
    mode: str  # "sandbox" = uang tidak sungguhan


class PesananOut(BaseModel):
    id: str
    status: str
    status_label: str
    karya: KaryaRingkas
    pembeli_nama: str
    penjual_nama: str
    harga_final_idr: int
    komisi_platform_idr: int
    pendapatan_seniman_idr: int
    alamat: dict | None = None
    instruksi_bayar: InstruksiBayar | None = None
    metode_pembayaran: str | None = None
    kurir: str | None = None
    no_resi: str | None = None
    sudah_dikirim: bool
    sudah_diulas: bool = False
    created_at: datetime
    batas_bayar_at: datetime | None = None
    dibayar_at: datetime | None = None
    dikonfirmasi_at: datetime | None = None
    dikirim_at: datetime | None = None
    selesai_at: datetime | None = None
    dibatalkan_at: datetime | None = None
    # Tombol apa yang boleh muncul untuk PENGGUNA YANG MELIHAT (dihitung server, bukan ditebak aplikasi).
    aksi: list[str] = []


class PesananList(BaseModel):
    items: list[PesananOut]
    total: int
