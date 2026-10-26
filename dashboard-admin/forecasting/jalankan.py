"""Backtest bergulir + forecast pendapatan platform -> tabel dummy_admin.forecast_*.

Target: total (komisi 2,5% + langganan Pro kolektor + langganan Pro seniman), komisi,
langganan_kolektor, langganan_seniman -- masing-masing punya pemenang backtest sendiri.

    cd dashboard-admin
    .venv\\Scripts\\python forecasting\\jalankan.py              # backtest + forecast + tulis ke Neon
    .venv\\Scripts\\python forecasting\\jalankan.py --tanpa-db   # hanya cetak (tanpa menulis)

Alur: tiap model di-fit ulang pada tiap titik potong (T = 24..30 bulan), diprediksi
H=6 bulan ke depan, dibandingkan dgn aktual -> metrik. Model dgn WAPE terkecil dipilih;
lalu semua model di-fit pada seluruh 36 bulan utk forecast 6 bulan ke depan.
Backend hanya MEMBACA hasilnya (tanpa torch/sklearn di server).
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
from dataset import SCHEMA, TARGET, kalender_masa_depan, muat_bulanan  # noqa: E402
from modelku import MODEL, MODEL_DIBANDINGKAN, MODEL_ID, MODEL_UTAMA  # noqa: E402

warnings.filterwarnings("ignore")

H = 6
TITIK_POTONG = list(range(24, 31))  # train = bulan[:T]; uji = bulan[T:T+H]


def _kalender_uji(df: pd.DataFrame, t: int) -> pd.DataFrame:
    return df.iloc[t:t + H][["bulan", "flag_ramadan", "flag_desember", "musim"]].reset_index(drop=True)


def backtest(df: pd.DataFrame, nama_model: list[str]) -> dict:
    hasil = {}
    for nama in nama_model:
        fn = MODEL[nama]
        galat, aktual, prediksi, mase_list, dalam, total = [], [], [], [], 0, 0
        for t in TITIK_POTONG:
            train = df.iloc[:t].reset_index(drop=True)
            uji = _kalender_uji(df, t)
            y = df["y"].to_numpy(float)[t:t + H]
            r = fn(train, uji)
            p = np.maximum(r["p50"], 0)
            skala = np.mean(np.abs(np.diff(train["y"].to_numpy(float))))
            mase_list.append(np.mean(np.abs(y - p)) / max(skala, 1.0))
            aktual.append(y)
            prediksi.append(p)
            if r["p10"] is not None:
                dalam += int(((y >= r["p10"]) & (y <= r["p90"])).sum())
                total += len(y)
        a, p = np.concatenate(aktual), np.concatenate(prediksi)
        ada = a > 0  # MAPE tidak terdefinisi utk aktual 0
        hasil[nama] = {
            "mape_pct": float(np.mean(np.abs(a[ada] - p[ada]) / a[ada]) * 100) if ada.any() else float("inf"),
            "rmse_idr": float(np.sqrt(np.mean((a - p) ** 2))),
            "wape_pct": float(np.abs(a - p).sum() / a.sum() * 100),
            "smape_pct": float(np.mean(2 * np.abs(a - p) / (np.abs(a) + np.abs(p) + 1e-9)) * 100),
            "mase": float(np.mean(mase_list)),
            "cakupan_p80": (dalam / total) if total else None,
            "n_evaluasi": int(len(a)),
            "rasio": np.clip(a / np.maximum(p, 1.0), 0.2, 5.0),  # aktual/prediksi -> utk interval
        }
        print(f"  {nama:24s} MAPE {hasil[nama]['mape_pct']:6.1f}%  RMSE Rp{hasil[nama]['rmse_idr']:>14,.0f}"
              f"  (WAPE {hasil[nama]['wape_pct']:5.1f}%  sMAPE {hasil[nama]['smape_pct']:5.1f}%  MASE {hasil[nama]['mase']:4.2f})"
              + (f"  cakupan P10-P90 {hasil[nama]['cakupan_p80']:.0%}" if total else ""), flush=True)
    return hasil


def forecast_akhir(df: pd.DataFrame, hasil_bt: dict) -> dict:
    masa_depan = kalender_masa_depan(df["bulan"].iloc[-1], H)
    keluar = {}
    for nama in hasil_bt:  # hanya model yang di-backtest
        r = MODEL[nama](df, masa_depan)
        p50 = np.maximum(r["p50"], 0)
        if r["p10"] is None:  # model titik -> interval dari galat backtest (conformal sederhana)
            q10, q90 = np.quantile(hasil_bt[nama]["rasio"], [0.1, 0.9])
            p10, p90 = p50 * q10, p50 * q90
        else:
            p10, p90 = np.maximum(r["p10"], 0), np.maximum(r["p90"], 0)
        p10, p90 = np.minimum(p10, p50), np.maximum(p90, p50)
        keluar[nama] = (masa_depan["bulan"].dt.date.tolist(), p10, p50, p90)
    return keluar


async def tulis(df, hasil, fc, terpilih, pilih_manual=False):
    """hasil/fc/terpilih: dict per target."""
    engine = create_async_engine(os.environ["DATABASE_URL"])
    async with engine.begin() as conn:
        # migrasi idempotent: kolom MAPE & RMSE (permintaan dosen) pada tabel yang sudah ada
        await conn.execute(text(f"ALTER TABLE {SCHEMA}.forecast_backtest ADD COLUMN IF NOT EXISTS mape_pct double precision"))
        await conn.execute(text(f"ALTER TABLE {SCHEMA}.forecast_backtest ADD COLUMN IF NOT EXISTS rmse_idr double precision"))
        for tbl in ("forecast_pendapatan", "forecast_backtest", "forecast_meta"):
            await conn.execute(text(f"DELETE FROM {SCHEMA}.{tbl}"))
        for target in fc:
            for nama, (bulan, p10, p50, p90) in fc[target].items():
                for i, b in enumerate(bulan):
                    await conn.execute(text(
                        f"INSERT INTO {SCHEMA}.forecast_pendapatan (target, bulan, model, p10_idr, p50_idr, p90_idr) "
                        "VALUES (:tg, :b, :m, :a, :c, :d)"),
                        {"tg": target, "b": b, "m": nama, "a": int(p10[i]), "c": int(p50[i]), "d": int(p90[i])})
            for nama, m in hasil[target].items():
                await conn.execute(text(
                    f"INSERT INTO {SCHEMA}.forecast_backtest "
                    "(target, model, wape_pct, smape_pct, mase, cakupan_p80, n_evaluasi, terpilih, mape_pct, rmse_idr) "
                    "VALUES (:tg, :m, :w, :s, :ma, :c, :n, :t, :mp, :rm)"),
                    {"tg": target, "m": nama, "w": m["wape_pct"], "s": m["smape_pct"], "ma": m["mase"],
                     "mp": m["mape_pct"] if np.isfinite(m["mape_pct"]) else None, "rm": m["rmse_idr"],
                     "c": m["cakupan_p80"], "n": m["n_evaluasi"], "t": nama == terpilih[target]})
        meta = {"horizon_bulan": str(H),
                "titik_potong_backtest": json.dumps(TITIK_POTONG),
                "bulan_data_terakhir": str(df["bulan"].iloc[-1].date()),
                "chronos_model_id": MODEL_ID,
                "tarif_komisi": "0.025",
                "harga_pro_kolektor": "50000", "harga_pro_seniman": "150000",
                "aturan_pilih": "manual" if pilih_manual else "MAPE terkecil di antara semua model yang diuji (RMSE sebagai pembanding), per target",
                "model_diminta_dosen": json.dumps(MODEL_UTAMA),
                "catatan": "Data sintetis; skor mencerminkan desain simulasi, bukan performa produksi."}
        for k, v in meta.items():
            await conn.execute(text(f"INSERT INTO {SCHEMA}.forecast_meta (kunci, nilai) VALUES (:k, :v)"),
                               {"k": k, "v": v})
    await engine.dispose()


def main(tanpa_db: bool, hanya: list[str] | None, pilih: str | None = None, target_uji: list[str] | None = None):
    df0 = muat_bulanan()
    total = int(df0["total_idr"].sum())
    print(f"Deret: {len(df0)} bulan, {df0['bulan'].iloc[0].date()} .. {df0['bulan'].iloc[-1].date()}, "
          f"total pendapatan platform Rp{total:,} (komisi Rp{int(df0['komisi_idr'].sum()):,}, "
          f"langganan Rp{int(df0['langganan_kolektor_idr'].sum() + df0['langganan_seniman_idr'].sum()):,})")
    nama_model = hanya or MODEL_DIBANDINGKAN
    hasil, fc, terpilih = {}, {}, {}
    for target, kolom in TARGET.items():
        if target_uji and target not in target_uji:
            continue
        df = df0.assign(y=df0[kolom].astype(float))
        print(f"\n=== Target: {target} ===  backtest bergulir (T={TITIK_POTONG[0]}..{TITIK_POTONG[-1]}, horizon {H})")
        hasil[target] = backtest(df, nama_model)
        terpilih[target] = pilih or min(
            hasil[target], key=lambda n: (hasil[target][n]["mape_pct"], hasil[target][n]["rmse_idr"]))
        if terpilih[target] not in hasil[target]:
            raise SystemExit(f"--pilih {terpilih[target]} tidak ada di {list(hasil[target])}")
        print(f"Model terpilih ({'manual' if pilih else 'MAPE terkecil'}): {terpilih[target]}")
        if not (tanpa_db or hanya):
            fc[target] = forecast_akhir(df, hasil[target])
            b, p10, p50, p90 = fc[target][terpilih[target]]
            print(f"  total 6 bln (P50): Rp{int(p50.sum()):,}   P10 Rp{int(p10.sum()):,}   P90 Rp{int(p90.sum()):,}")
    if tanpa_db or hanya or target_uji:
        return
    asyncio.run(tulis(df0, hasil, fc, terpilih, bool(pilih)))
    print("\nDitulis ke", SCHEMA + ".forecast_*")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--tanpa-db", action="store_true")
    ap.add_argument("--pilih", help="paksa model yang ditampilkan dashboard utk SEMUA target (default: WAPE terkecil per target)")
    ap.add_argument("--hanya", nargs="*", help="uji sebagian model saja (tidak menulis ke DB)")
    ap.add_argument("--target", nargs="*", choices=list(TARGET), help="uji sebagian target saja (tidak menulis ke DB)")
    a = ap.parse_args()
    main(a.tanpa_db, a.hanya, a.pilih, a.target)
