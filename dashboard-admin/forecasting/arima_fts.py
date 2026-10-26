"""Dua model yang dibandingkan di dashboard admin: ARIMA (univariat) dan Fuzzy Time Series (multivariat).

Antarmuka sama dengan ``modelku.py``:  fn(train, masa_depan) -> {"p50": array[h], "p10": None, "p90": None}
  train      : kolom bulan, y (target) + kovariat historis (n_transaksi, n_pro_kolektor, n_pro_seniman, pengguna_baru, ...)
  masa_depan : kolom bulan (+ kalender); hanya panjangnya (horizon h) yang dipakai di sini.

Praproses (sama utk keduanya): bulan-bulan AWAL yang nilainya < 5% median deret (bulan peluncuran) dibuang; deret dimodelkan pada skala log1p karena pendapatan bertumbuh eksponensial.
ARIMA   : univariat pada log1p(y); orde d = 0 bila ADF dan KPSS sama-sama menyatakan level stasioner, selain itu 1 (d=2 tidak dipakai agar
          tidak over-differencing pada deret pendek), (p, q) 0..1 dipilih dari AICc terkecil (model hemat utk ±30 titik data;
          orde yang lebih besar terbukti overfit dan meledak saat diekstrapolasi). Untuk d=1, ARMA dengan konstanta (drift)
          dipasang pada selisih lalu diintegrasikan kembali. Rata-rata (drift) dimodelkan langsung dengan mengurangi rata-rata
          sampel (parameterisasi "include.mean"), bukan lewat konstanta regresi yang sulit diidentifikasi bila AR mendekati 1.
FTS     : multivariat 2 faktor (y + satu faktor pengaruh). Himpunan fuzzy = interval sama lebar; relasi fuzzy
          (A_y(t), A_x(t)) -> A_y(t+1); prediksi = rata-rata titik tengah konsekuen. Dikerjakan pada SELISIH
          (differencing, skala log) karena FTS tidak bisa mengekstrapolasi keluar dari rentang universe, sedangkan
          deret pendapatan bertumbuh. Faktor kedua dipilih otomatis dari kandidat berdasarkan korelasi
          dx(t) dengan dy(t+1) PADA DATA LATIH SAJA (tanpa kebocoran masa depan). Untuk horizon > 1 bulan,
          faktor kedua diramal dengan FTS univariat miliknya sendiri.
"""

from __future__ import annotations

import warnings

import numpy as np

KANDIDAT_FAKTOR = ["n_transaksi", "n_pro_kolektor", "n_pro_seniman", "pengguna_baru"]


AMBANG_PELUNCURAN = 0.05   # bulan awal dgn nilai < 5% median deret dianggap bulan peluncuran/ramp-up


def pangkas_awal(train):
    """Buang bulan-bulan AWAL yang nilainya < 5% median deret (bulan peluncuran: nol atau nyaris nol, mis.
    Rp0,2 juta lalu Rp15 juta). Satu loncatan log sebesar itu mendominasi rata-rata pertumbuhan dan merusak
    kedua model. Nilai kecil di tengah deret dibiarkan."""
    nilai = train["y"].to_numpy(float)
    positif = nilai[nilai > 0]
    if len(positif) == 0:
        return train
    ambang = AMBANG_PELUNCURAN * float(np.median(positif))
    ada = np.flatnonzero(nilai >= ambang)
    return train.iloc[ada[0]:].reset_index(drop=True) if len(ada) else train


# ------------------------------------------------------------------- ARIMA
def uji_stasioner(seri: np.ndarray, alfa: float = 0.05) -> dict:
    """ADF (H0: akar unit) + KPSS (H0: stasioner, regresi konstanta). Stasioner bila ADF menolak H0 DAN KPSS tidak."""
    from statsmodels.tsa.stattools import adfuller, kpss

    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        adf_p = float(adfuller(seri, autolag="AIC")[1])
        kpss_p = float(kpss(seri, regression="c", nlags="auto")[1])
    return {"adf_p": adf_p, "kpss_p": kpss_p, "adf_tolak_akar_unit": adf_p < alfa,
            "stasioner": bool(adf_p < alfa and kpss_p >= alfa)}


def orde_diferensiasi(y: np.ndarray, alfa: float = 0.05) -> int:
    """d = 0 bila level stasioner menurut ADF dan KPSS sekaligus; selain itu d = 1. d = 2 sengaja tidak dipakai
    (over-differencing pada deret ±30 titik)."""
    y = np.asarray(y, float)
    if len(y) < 8 or np.ptp(y) == 0:
        return 1
    try:
        return 0 if uji_stasioner(y, alfa)["stasioner"] else 1
    except Exception:
        return 1


def arima(train, masa_depan):
    from statsmodels.tsa.arima.model import ARIMA

    train = pangkas_awal(train)
    y = np.log1p(train["y"].to_numpy(float))
    h = len(masa_depan)
    d = orde_diferensiasi(y)
    w = np.diff(y) if d == 1 else y            # d=1: dimodelkan pada selisih, lalu diintegrasikan kembali
    rata = float(np.mean(w))
    wc = w - rata                              # model dipasang pada deret terpusat; rata-rata ditambahkan kembali
    terbaik, aic_terbaik = None, np.inf
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        n = len(w)
        for p in range(2):
            for q in range(2):
                try:
                    fit = ARIMA(wc, order=(p, 0, q), trend="n").fit()
                except Exception:
                    continue
                k = p + q + 2                                  # AR + MA + rata-rata + varians
                aicc = fit.aic + 2 * k * (k + 1) / max(n - k - 1, 1)
                if np.isfinite(aicc) and aicc < aic_terbaik:
                    terbaik, aic_terbaik = fit, aicc
        if terbaik is None:                    # semua gagal -> lanjutkan selisih rata-rata
            f = np.repeat(rata, h)
        else:
            f = np.asarray(terbaik.forecast(h)) + rata
    pred = (y[-1] + np.cumsum(f)) if d == 1 else f
    return {"p50": np.expm1(pred), "p10": None, "p90": None}


# ------------------------------------------------------- Fuzzy Time Series
def _k_interval(n: int) -> int:
    """Jumlah himpunan fuzzy untuk faktor utama (aturan Sturges, minimal 5)."""
    return max(5, int(round(1 + 3.3 * np.log10(max(n, 2)))))


class _Partisi:
    """Universe of discourse dibagi k interval sama lebar; himpunan fuzzy diwakili titik tengah interval."""

    def __init__(self, nilai: np.ndarray, k: int):
        lo, hi = float(np.min(nilai)), float(np.max(nilai))
        rentang = hi - lo if hi > lo else max(abs(hi), 1.0)
        self.tepi = np.linspace(lo - 0.1 * rentang, hi + 0.1 * rentang, k + 1)
        self.tengah = (self.tepi[:-1] + self.tepi[1:]) / 2
        self.k = k

    def fuzzifikasi(self, v: float) -> int:
        return int(np.clip(np.searchsorted(self.tepi, v, side="right") - 1, 0, self.k - 1))


def _rata_konsekuen(daftar: list[int], tengah: np.ndarray) -> float:
    return float(np.mean([tengah[j] for j in daftar]))


class _FTS:
    """FTS orde-1. Anteseden = (himpunan y, himpunan x) bila ada faktor kedua, selain itu hanya himpunan y.
    Anteseden tak dikenal -> kembali ke relasi y saja -> kembali ke titik tengah himpunan saat ini."""

    def __init__(self, dy: np.ndarray, dx: np.ndarray | None, k_y: int, k_x: int = 3):
        self.py = _Partisi(dy, k_y)
        self.px = _Partisi(dx, k_x) if dx is not None else None
        iy = [self.py.fuzzifikasi(v) for v in dy]
        ix = [self.px.fuzzifikasi(v) for v in dx] if dx is not None else None
        self.rel_gabungan: dict[tuple[int, int], list[int]] = {}
        self.rel_y: dict[int, list[int]] = {}
        for t in range(len(dy) - 1):
            self.rel_y.setdefault(iy[t], []).append(iy[t + 1])
            if ix is not None:
                self.rel_gabungan.setdefault((iy[t], ix[t]), []).append(iy[t + 1])

    def prediksi(self, dy_t: float, dx_t: float | None = None) -> float:
        a = self.py.fuzzifikasi(dy_t)
        if self.px is not None and dx_t is not None:
            kunci = (a, self.px.fuzzifikasi(dx_t))
            if kunci in self.rel_gabungan:
                return _rata_konsekuen(self.rel_gabungan[kunci], self.py.tengah)
        if a in self.rel_y:
            return _rata_konsekuen(self.rel_y[a], self.py.tengah)
        return float(self.py.tengah[a])


def pilih_faktor(train, dy: np.ndarray) -> str | None:
    """Faktor kedua = kandidat dgn |korelasi(dx[t], dy[t+1])| terbesar pada data latih (selisih log)."""
    terbaik, skor = None, 0.0
    for nama in KANDIDAT_FAKTOR:
        if nama not in train.columns:
            continue
        dx = np.diff(np.log1p(train[nama].to_numpy(float)))
        if len(dx) < 6 or np.std(dx[:-1]) == 0 or np.std(dy[1:]) == 0:
            continue
        r = abs(float(np.corrcoef(dx[:-1], dy[1:])[0, 1]))
        if np.isfinite(r) and r > skor:
            terbaik, skor = nama, r
    return terbaik


def fts_multivariat(train, masa_depan):
    train = pangkas_awal(train)
    y = np.log1p(train["y"].to_numpy(float))
    h = len(masa_depan)
    dy = np.diff(y)
    if len(dy) < 8 or np.ptp(dy) == 0:  # data terlalu pendek / datar -> lanjutkan selisih rata-rata
        laju = float(np.mean(dy)) if len(dy) else 0.0
        return {"p50": y[-1] + laju * np.arange(1, h + 1), "p10": None, "p90": None}
    nama_x = pilih_faktor(train, dy)
    k_y = _k_interval(len(dy))
    if nama_x is None:
        model, model_x, dx = _FTS(dy, None, k_y), None, None
    else:
        dx = np.diff(np.log1p(train[nama_x].to_numpy(float)))
        model = _FTS(dy, dx, k_y)
        model_x = _FTS(dx, None, _k_interval(len(dx)))   # peramal faktor kedua utk horizon > 1
    pred, nilai = [], float(y[-1])
    dy_t = float(dy[-1])
    dx_t = float(dx[-1]) if dx is not None else None
    for _ in range(h):
        d_next = model.prediksi(dy_t, dx_t)
        nilai = nilai + d_next
        pred.append(nilai)
        dy_t = d_next
        if model_x is not None:
            dx_t = model_x.prediksi(dx_t)
    return {"p50": np.expm1(np.asarray(pred)), "p10": None, "p90": None}
