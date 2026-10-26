"""Skema respons dashboard admin: pendapatan platform = komisi 2,5% penjualan karya
+ langganan Pro kolektor + langganan Pro seniman; forecasting; Pro vs non-Pro."""

from __future__ import annotations

from pydantic import BaseModel


class StatusPro(BaseModel):
    n_pro: int
    n_pengguna: int
    pro_share_pct: float | None


class RingkasanAdmin(BaseModel):
    periode_hari: int
    tarif_komisi_pct: float
    harga_pro_kolektor_idr: int
    harga_pro_seniman_idr: int
    pendapatan_total_idr: int
    komisi_idr: int
    langganan_kolektor_idr: int
    langganan_seniman_idr: int
    gmv_idr: int
    n_transaksi: int
    perubahan_pct: dict[str, float | None]  # total_idr, komisi_idr, langganan_idr vs periode sebelumnya
    pro: dict[str, StatusPro]  # kunci: kolektor, seniman
    data_contoh: bool = True


class PendapatanBulan(BaseModel):
    bulan: str  # YYYY-MM-01
    komisi_idr: int
    langganan_kolektor_idr: int
    langganan_seniman_idr: int
    total_idr: int
    gmv_idr: int
    n_transaksi: int


class NilaiBulan(BaseModel):
    bulan: str
    nilai_idr: int


class TitikForecast(BaseModel):
    bulan: str
    p10_idr: int
    p50_idr: int
    p90_idr: int


class MetrikModel(BaseModel):
    model: str
    mape_pct: float | None = None   # kriteria utama pemilihan model (backtest bergulir)
    rmse_idr: float | None = None   # kriteria pembanding
    wape_pct: float
    smape_pct: float
    mase: float
    cakupan_p80: float | None
    n_evaluasi: int
    terpilih: bool


class ForecastPendapatan(BaseModel):
    target: str
    tersedia: bool
    model_terpilih: str | None = None
    aturan_pilih: str | None = None
    horizon_bulan: int | None = None
    aktual: list[NilaiBulan] = []
    forecast: list[TitikForecast] = []
    total_p50_idr: int | None = None
    total_p10_idr: int | None = None
    total_p90_idr: int | None = None
    jumlah_komponen_p50_idr: int | None = None  # hanya target 'total': komisi + 2 langganan (P50 masing-masing)
    backtest: list[MetrikModel] = []
    catatan: str | None = None


class DiagnosaDeret(BaseModel):
    """Hasil cek data series sebelum memilih metode (lihat dashboard-admin/forecasting/diagnosa.py)."""
    target: str
    tersedia: bool
    dibuat_at: str | None = None
    hasil: dict | None = None


class SenimanPeringkat(BaseModel):
    seniman_id: str
    nama: str
    cluster: str
    skor_keaktifan: float
    n_jual_90d: int
    omzet_12b_idr: int
    n_jual_12b: int
    hari_sejak_jual: int
    pro: bool


class ClusterSeniman(BaseModel):
    cluster: str  # Aktif | Kurang Aktif | Tidak Aktif
    ukuran: int
    persen: float
    skor_rata2: float
    n_jual_90d_median: float
    hari_sejak_jual_median: int
    pernah_jual_pct: float
    pro_pct: float


class KeaktifanSeniman(BaseModel):
    """Cluster keaktifan + Top 10 (lihat dashboard-admin/seniman/aktivitas.py; data contoh)."""
    tersedia: bool
    meta: dict | None = None
    cluster: list[ClusterSeniman] = []
    top_terbaik: list[SenimanPeringkat] = []  # omzet 12 bulan terakhir
    top_aktif: list[SenimanPeringkat] = []    # skor keaktifan


class ProVsNonPro(BaseModel):
    bulan: str
    role: str
    n_pro: int
    n_non_pro: int
    pro_share_pct: float | None
    upgrade_baru: int
