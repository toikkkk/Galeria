"""Uji cepat ARIMA dan Fuzzy Time Series multivariat pada deret sintetis (tanpa database).

    cd dashboard-admin
    .venv\\Scripts\\python forecasting\\uji_model.py

Memeriksa: bentuk keluaran, tidak ada NaN/negatif, deterministik (dua kali jalan sama persis), bulan peluncuran
nyaris-nol tidak merusak ramalan, dan model tidak meledak pada deret datar atau terlalu pendek.
"""

from __future__ import annotations

import sys
import warnings
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))
from arima_fts import arima, fts_multivariat, pangkas_awal  # noqa: E402

warnings.filterwarnings("ignore")


def deret(n=30, tumbuh=0.05, derau=0.08, awal_kecil=True, seed=1) -> pd.DataFrame:
    rng = np.random.default_rng(seed)
    y = 10_000_000 * np.exp(tumbuh * np.arange(n) + rng.normal(0, derau, n))
    if awal_kecil:
        y[0] = 200_000                       # bulan peluncuran
    return pd.DataFrame({
        "bulan": pd.date_range("2023-10-01", periods=n, freq="MS"), "y": y,
        "n_transaksi": np.round(y / 1_000_000).astype(int) + rng.integers(0, 3, n),
        "n_pro_kolektor": np.arange(n) + 1, "n_pro_seniman": np.arange(n) // 2 + 1,
        "pengguna_baru": rng.integers(40, 80, n),
    })


def cek(nama: str, kondisi: bool) -> None:
    print(("LULUS  " if kondisi else "GAGAL  ") + nama)
    if not kondisi:
        raise SystemExit(1)


H = 6
for nama, fn in (("arima", arima), ("fts_multivariat", fts_multivariat)):
    df = deret()
    depan = pd.DataFrame({"bulan": pd.date_range("2026-04-01", periods=H, freq="MS")})
    p = fn(df, depan)["p50"]
    cek(f"{nama}: keluaran {H} nilai berhingga dan tidak negatif", len(p) == H and np.isfinite(p).all() and (p >= 0).all())
    cek(f"{nama}: deterministik", np.allclose(p, fn(df, depan)["p50"]))
    cek(f"{nama}: ramalan masuk akal (0,3x - 3x nilai terakhir)", 0.3 * df.y.iloc[-1] < p[0] < 3 * df.y.iloc[-1] and p[-1] < 5 * df.y.iloc[-1])
    tanpa = deret(awal_kecil=False)
    cek(f"{nama}: bulan peluncuran nyaris-nol tidak mengubah ramalan jauh (<35%)",
        abs(fn(df, depan)["p50"][0] / fn(tanpa, depan)["p50"][0] - 1) < 0.35)
    datar = df.assign(y=5_000_000.0)
    cek(f"{nama}: deret datar tidak meledak", np.isfinite(fn(datar, depan)["p50"]).all())
    pendek = deret(n=9)
    cek(f"{nama}: deret pendek (9 bulan) tetap menghasilkan ramalan", np.isfinite(fn(pendek, depan)["p50"]).all())

d = deret()
cek("pangkas_awal membuang tepat 1 bulan peluncuran", len(pangkas_awal(d)) == len(d) - 1)
cek("pangkas_awal tidak membuang apa pun bila tidak ada bulan peluncuran", len(pangkas_awal(deret(awal_kecil=False))) == 30)
print("\nSemua uji lulus.")
