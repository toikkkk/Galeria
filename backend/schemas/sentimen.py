"""Skema respons sentimen ulasan (dashboard seniman). Data dummy -- lihat ``ml-sentiment/README.md``."""

from __future__ import annotations

from pydantic import BaseModel


class SentimenHitung(BaseModel):
    sentimen: str          # "positif" | "netral" | "negatif"
    jumlah: int
    persen: float


class SentimenBulan(BaseModel):
    bulan: str             # "YYYY-MM-01"
    positif: int
    netral: int
    negatif: int


class UlasanContoh(BaseModel):
    teks: str
    sentimen: str
    rating: int
    tanggal: str           # ISO 8601 (UTC)
    judul_karya: str | None = None


class SentimenSeniman(BaseModel):
    seniman_id: str
    n_ulasan: int
    model_version: str | None = None
    hitung: list[SentimenHitung]        # selalu 3 elemen, urut positif/netral/negatif
    indeks_sentimen: float | None = None  # (positif - negatif) / total * 100, rentang -100..100
    rating_rata2: float | None = None
    tren_bulanan: list[SentimenBulan]
    ulasan_terbaru: list[UlasanContoh]
