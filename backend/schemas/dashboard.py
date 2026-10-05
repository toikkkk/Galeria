"""Skema respons Pydantic untuk endpoint dashboard seniman.

Konvensi (lihat ``ml-recommender/aulya.md``): uang = integer Rupiah, persen =
angka biasa (``12.5``, bukan ``0.125``), ``None`` bila pembagi 0.
"""

from __future__ import annotations

from pydantic import BaseModel


class SenimanDemoItem(BaseModel):
    id: str
    display_name: str
    level_reputasi: str
    n_terjual: int


class SenimanInfo(BaseModel):
    id: str
    display_name: str
    level_reputasi: str


class PerubahanPct(BaseModel):
    n_terjual: float | None
    omzet_idr: float | None


class RingkasanSeniman(BaseModel):
    seniman: SenimanInfo
    periode_hari: int
    n_terjual: int
    omzet_idr: int
    komisi_platform_idr: int
    pendapatan_bersih_idr: int
    harga_rata2_idr: int
    n_pembeli_unik: int
    karya_tersedia: int
    karya_terjual_total: int
    perubahan_pct: PerubahanPct


class PenjualanBulan(BaseModel):
    bulan: str  # "YYYY-MM-01"
    n_terjual: int
    omzet_idr: int
    harga_rata2_idr: int
    n_pembeli_unik: int
    gaya_terlaris: str | None


class AliranSeniman(BaseModel):
    style_name: str
    n_terjual: int
    omzet_idr: int
    harga_rata2_idr: int
    harga_pasar_rata2_idr: int
    selisih_pct: float | None


class SegmenPembeli(BaseModel):
    segmen_id: int
    segmen_nama: str
    n_pembeli: int
    porsi_pct: float | None
    deskripsi: str | None = None


class SegmenPembeliResponse(BaseModel):
    tersedia: bool
    items: list[SegmenPembeli]


class SenimanRamai(BaseModel):
    seniman_id: str
    display_name: str
    n_terjual_30hari: int
    lonjakan: float
    harga_rata2_30hari_idr: int


class AliranRamai(BaseModel):
    style_name: str
    n_terjual_30hari: int
    porsi_penjualan_pct: float | None
    harga_rata2_30hari_idr: int


class TrenPasar(BaseModel):
    seniman_ramai: list[SenimanRamai]
    aliran_ramai: list[AliranRamai]
