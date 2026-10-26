"""Diagnosa deret waktu SEBELUM memilih metode forecasting (permintaan dosen).

Tiap target (total, komisi, langganan_kolektor, langganan_seniman) diperiksa pada lima aspek:
  1. kelengkapan   bulan hilang / duplikat, nilai nol, nilai negatif
  2. outlier       robust z-score (MAD) pada sisa tren Theil-Sen dari log1p(y); + bulan peluncuran di awal deret
  3. tren          uji Mann-Kendall (kendalltau terhadap waktu) + laju pertumbuhan Theil-Sen per bulan
  4. musiman       kekuatan musiman STL (period=12) + autokorelasi selisih pada lag 12
  5. stasioneritas ADF (H0: akar unit) dan KPSS (H0: stasioner) pada level dan selisih pertama -> orde d
Hasil ditulis ke dummy_admin.diagnosa_deret (jsonb) dan dibaca backend /api/admin/diagnosa.

    cd dashboard-admin
    .venv\\Scripts\\python forecasting\\diagnosa.py              # tulis ke Neon
    .venv\\Scripts\\python forecasting\\diagnosa.py --tanpa-db   # hanya cetak

Keterbatasan (dicatat apa adanya): deret hanya 36 bulan = 3 siklus tahunan, jadi uji musiman dan
stasioneritas berdaya rendah; data sintetis, sehingga pola mencerminkan desain simulasi.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import sys
import warnings
from pathlib import Path

import numpy as np
import pandas as pd
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine

sys.path.insert(0, str(Path(__file__).resolve().parent))
from arima_fts import AMBANG_PELUNCURAN, orde_diferensiasi, pangkas_awal, uji_stasioner  # noqa: E402
from dataset import SCHEMA, TARGET, muat_bulanan  # noqa: E402

warnings.filterwarnings("ignore")
ALFA = 0.05
NAMA = {
    "total": "Total pendapatan", "komisi": "Komisi karya terjual",
    "langganan_kolektor": "Langganan Pro kolektor", "langganan_seniman": "Langganan Pro seniman",
}


def _stasioner(seri: np.ndarray) -> dict:
    h = uji_stasioner(seri, ALFA)
    return {"adf_p": round(h["adf_p"], 4), "kpss_p": round(h["kpss_p"], 4), "stasioner": h["stasioner"],
            "adf_tolak_akar_unit": h["adf_tolak_akar_unit"]}


def diagnosa_deret(bulan: pd.Series, y: np.ndarray) -> dict:
    from scipy import stats
    from statsmodels.tsa.seasonal import STL
    from statsmodels.tsa.stattools import acf

    n = len(y)
    # 1. kelengkapan ----------------------------------------------------------------------
    diharapkan = len(pd.period_range(bulan.iloc[0], bulan.iloc[-1], freq="M"))
    kelengkapan = {
        "n_titik": n, "n_diharapkan": int(diharapkan), "bulan_hilang": int(diharapkan - bulan.nunique()),
        "bulan_duplikat": int(n - bulan.nunique()), "n_nol": int((y == 0).sum()), "n_negatif": int((y < 0).sum()),
    }
    kelengkapan["lengkap"] = kelengkapan["bulan_hilang"] == 0 and kelengkapan["bulan_duplikat"] == 0 and kelengkapan["n_negatif"] == 0

    # bulan peluncuran = bulan awal yg dibuang praproses model (sama persis dgn arima_fts.pangkas_awal)
    df = pd.DataFrame({"bulan": bulan.reset_index(drop=True), "y": y.astype(float)})
    aktif = pangkas_awal(df)
    n_awal_dibuang = int(n - len(aktif))
    ya = aktif["y"].to_numpy(float)
    ly = np.log1p(ya)
    na = len(ya)

    # 2. outlier (sisa STL, robust z) -------------------------------------------------------
    outlier = {"metode": "robust z-score (MAD) pada sisa tren Theil-Sen log1p, ambang |z| > 3,5", "bulan_peluncuran_dibuang": n_awal_dibuang,
               "aturan_peluncuran": f"bulan awal bernilai < {int(AMBANG_PELUNCURAN * 100)}% median deret"}
    if na >= 8:
        ts_slope, ts_int = stats.theilslopes(ly, np.arange(na))[:2]
        sisa = ly - (ts_int + ts_slope * np.arange(na))
        mad = float(np.median(np.abs(sisa - np.median(sisa)))) or 1e-9
        z = 0.6745 * (sisa - np.median(sisa)) / mad
        idx = np.flatnonzero(np.abs(z) > 3.5)
        outlier["jumlah"] = int(len(idx))
        outlier["daftar"] = [{"bulan": str(aktif["bulan"].iloc[i].date()), "nilai_idr": int(ya[i]), "z": round(float(z[i]), 2)} for i in idx]
    else:
        outlier["jumlah"], outlier["daftar"] = None, []

    # 3. tren ----------------------------------------------------------------------------
    t = np.arange(na)
    tau, p_mk = stats.kendalltau(t, ya)
    slope = stats.theilslopes(ly, t)[0]
    tren = {
        "tau_kendall": round(float(tau), 3), "p_mann_kendall": float(f"{p_mk:.3g}"),
        "ada_tren": bool(p_mk < ALFA), "arah": "naik" if tau > 0 else "turun",
        "pertumbuhan_per_bulan_pct": round(float((np.exp(slope) - 1) * 100), 2),
    }

    # 4. musiman -------------------------------------------------------------------------
    musiman: dict = {"periode": 12}
    if na >= 24:
        st = STL(ly, period=12, robust=True).fit()
        kekuatan = float(max(0.0, 1 - np.var(st.resid) / np.var(st.seasonal + st.resid)))
        r12 = float(acf(np.diff(ly), nlags=12, fft=False)[12])
        batas = 1.96 / np.sqrt(na - 1)
        musiman.update({
            "kekuatan_stl": round(kekuatan, 3), "acf_lag12_selisih": round(r12, 3), "batas_95": round(float(batas), 3),
            "tingkat": "kuat" if kekuatan >= 0.64 else "sedang" if kekuatan >= 0.4 else "lemah",
            "acf_signifikan": bool(abs(r12) > batas),
        })
    else:
        musiman.update({"kekuatan_stl": None, "tingkat": "tidak dapat diuji (< 24 titik)"})

    # 5. stasioneritas ---------------------------------------------------------------------
    level = _stasioner(ly)
    selisih = _stasioner(np.diff(ly))
    d = orde_diferensiasi(ly, ALFA)
    stasioneritas = {"skala": "log1p", "level": level, "selisih_pertama": selisih, "d_disarankan": d}

    return {
        "kelengkapan": kelengkapan, "outlier": outlier, "tren": tren, "musiman": musiman, "stasioneritas": stasioneritas,
        "ringkasan": _ringkasan(kelengkapan, outlier, tren, musiman, stasioneritas),
    }


def _ringkasan(kel, out, tren, mus, sta) -> list[str]:
    baris = []
    baris.append(
        f"Kelengkapan: {kel['n_titik']} dari {kel['n_diharapkan']} bulan, "
        + ("tidak ada bulan hilang atau ganda" if kel["lengkap"] else "ADA bulan hilang/ganda/negatif")
        + (f"; {kel['n_nol']} bulan bernilai nol." if kel["n_nol"] else "."))
    if out["bulan_peluncuran_dibuang"]:
        baris.append(f"Bulan peluncuran: {out['bulan_peluncuran_dibuang']} bulan awal bernilai sangat kecil dibuang sebelum pemodelan.")
    if out.get("jumlah") is not None:
        baris.append(f"Outlier: {out['jumlah']} bulan menyimpang jauh dari tren." if out["jumlah"] else "Outlier: tidak ada yang menyimpang jauh dari pola.")
    baris.append(
        f"Tren: {'ada tren ' + tren['arah'] if tren['ada_tren'] else 'tidak ada tren yang jelas'} "
        f"(Mann-Kendall p={tren['p_mann_kendall']}), rata-rata {tren['pertumbuhan_per_bulan_pct']}% per bulan.")
    if mus.get("kekuatan_stl") is not None:
        baris.append(f"Musiman: {mus['tingkat']} (kekuatan STL {mus['kekuatan_stl']}); dengan hanya 3 siklus, uji ini berdaya rendah.")
    baris.append(
        f"Stasioneritas: level {'stasioner' if sta['level']['stasioner'] else 'tidak stasioner'} "
        f"(ADF p={sta['level']['adf_p']}, KPSS p={sta['level']['kpss_p']}); "
        f"selisih pertama {'stasioner' if sta['selisih_pertama']['stasioner'] else 'belum meyakinkan'} "
        f"(ADF p={sta['selisih_pertama']['adf_p']}). Orde diferensiasi d = {sta['d_disarankan']}.")
    return baris


async def tulis(hasil: dict[str, dict]) -> None:
    engine = create_async_engine(os.environ["DATABASE_URL"])
    async with engine.begin() as conn:
        await conn.execute(text(
            f"CREATE TABLE IF NOT EXISTS {SCHEMA}.diagnosa_deret ("
            "target text PRIMARY KEY, hasil jsonb NOT NULL, dibuat_at timestamptz NOT NULL DEFAULT now())"))
        for target, h in hasil.items():
            await conn.execute(text(
                f"INSERT INTO {SCHEMA}.diagnosa_deret (target, hasil, dibuat_at) VALUES (:t, CAST(:h AS jsonb), now()) "
                "ON CONFLICT (target) DO UPDATE SET hasil = EXCLUDED.hasil, dibuat_at = now()"),
                {"t": target, "h": json.dumps(h, ensure_ascii=False)})
    await engine.dispose()


def main(tanpa_db: bool) -> None:
    df = muat_bulanan()
    hasil = {}
    for target, kolom in TARGET.items():
        hasil[target] = diagnosa_deret(df["bulan"], df[kolom].to_numpy(float))
        print(f"\n== {NAMA[target]} ==")
        for b in hasil[target]["ringkasan"]:
            print(" -", b)
    if not tanpa_db:
        asyncio.run(tulis(hasil))
        print(f"\nDitulis ke {SCHEMA}.diagnosa_deret")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--tanpa-db", action="store_true")
    main(ap.parse_args().tanpa_db)
