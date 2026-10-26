"""Kumpulan model forecasting deret bulanan komisi.

Semua model punya antarmuka sama:  fn(train: DataFrame, masa_depan: DataFrame) -> dict
  train       : kolom bulan, y (target yg diramal), + kovariat (s/d bulan terakhir yang diketahui)
  masa_depan  : kolom bulan + kovariat KALENDER (flag_ramadan, flag_desember, musim)
  hasil       : {"p50": array[h], "p10": array[h] | None, "p90": array[h] | None}
Model titik (tanpa kuantil) mengembalikan p10/p90 = None; interval dibuat dari
galat backtest (conformal sederhana) di jalankan.py.
"""

from __future__ import annotations

import warnings

import numpy as np
import pandas as pd

KOVARIAT_MASA_LALU = ["n_pro_kolektor", "n_pro_seniman", "pro_share_kolektor", "pro_share_seniman",
                      "pengguna_baru"]
KOVARIAT_KALENDER = ["flag_ramadan", "flag_desember"]


# ---------------------------------------------------------------- baseline
def seasonal_naive_tren(train, masa_depan):
    """Nilai bulan yg sama tahun lalu x rasio pertumbuhan 6 bln terakhir vs setahun sebelumnya."""
    y = train["y"].to_numpy(float)
    h = len(masa_depan)
    if len(y) < 18:
        return {"p50": np.repeat(y[-3:].mean(), h), "p10": None, "p90": None}
    tren = y[-6:].sum() / max(y[-18:-12].sum(), 1.0)
    tren = float(np.clip(tren, 0.5, 3.0))
    pred = np.array([y[len(y) - 12 + i] * tren if len(y) - 12 + i < len(y) else y[-1] * tren
                     for i in range(h)])
    return {"p50": pred, "p10": None, "p90": None}


# ---------------------------------------------------------------- statistik
def ets(train, masa_depan):
    from statsmodels.tsa.holtwinters import ExponentialSmoothing

    ly = np.log1p(train["y"].to_numpy(float))
    h = len(masa_depan)
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        musiman = len(ly) >= 24
        fit = ExponentialSmoothing(
            ly, trend="add", damped_trend=True,
            seasonal="add" if musiman else None, seasonal_periods=12 if musiman else None,
            initialization_method="estimated").fit()
        pred = fit.forecast(h)
    return {"p50": np.expm1(np.asarray(pred)), "p10": None, "p90": None}


def theta(train, masa_depan):
    from statsmodels.tsa.forecasting.theta import ThetaModel

    s = pd.Series(np.log1p(train["y"].to_numpy(float)),
                  index=pd.PeriodIndex(train["bulan"], freq="M"))
    h = len(masa_depan)
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        fit = ThetaModel(s, period=12, deseasonalize=len(s) >= 24, method="additive").fit()
        pred = fit.forecast(h)
    return {"p50": np.expm1(pred.to_numpy()), "p10": None, "p90": None}


# ---------------------------------------------------------------- machine learning
def lightgbm_rekursif(train, masa_depan):
    """GBM pada selisih log bulanan, fitur: lag selisih, kalender, bulan-dalam-tahun."""
    import lightgbm as lgb

    ly = list(np.log1p(train["y"].to_numpy(float)))
    kal_tr = train[KOVARIAT_KALENDER].to_numpy(float)
    bln_tr = train["bulan"].dt.month.to_numpy()

    def fitur(d_hist, kal, bulan):
        lag = [d_hist[-k] if len(d_hist) >= k else 0.0 for k in (1, 2, 3)]
        return lag + list(kal) + [bulan, float(np.mean(d_hist[-6:])) if len(d_hist) else 0.0]

    d = np.diff(ly)
    X, Y = [], []
    for t in range(3, len(ly)):
        X.append(fitur(list(d[:t - 1]), kal_tr[t], bln_tr[t]))
        Y.append(d[t - 1])
    model = lgb.LGBMRegressor(n_estimators=150, learning_rate=0.05, num_leaves=7,
                              min_child_samples=3, subsample=0.9, colsample_bytree=0.9,
                              random_state=0, verbose=-1)
    model.fit(np.array(X), np.array(Y))
    d_hist = list(d)
    level = ly[-1]
    out = []
    kal_f = masa_depan[KOVARIAT_KALENDER].to_numpy(float)
    bln_f = masa_depan["bulan"].dt.month.to_numpy()
    for i in range(len(masa_depan)):
        nd = float(model.predict(np.array([fitur(d_hist, kal_f[i], bln_f[i])]))[0])
        d_hist.append(nd)
        level += nd
        out.append(np.expm1(level))
    return {"p50": np.array(out), "p10": None, "p90": None}


# ---------------------------------------------------------------- foundation model
_PIPELINE = None
MODEL_ID = "amazon/chronos-2"


def _pipeline():
    global _PIPELINE
    if _PIPELINE is None:
        from chronos import Chronos2Pipeline

        _PIPELINE = Chronos2Pipeline.from_pretrained(MODEL_ID, device_map="cpu")
    return _PIPELINE


def _chronos(train, masa_depan, pakai_kovariat: bool, log: bool = False):
    pipe = _pipeline()
    y = train["y"].to_numpy(float)
    ctx = pd.DataFrame({"item_id": "seri", "timestamp": train["bulan"].to_numpy(),
                        "target": np.log1p(y) if log else y})
    fut = None
    if pakai_kovariat:
        for c in KOVARIAT_MASA_LALU + KOVARIAT_KALENDER:  # masa lalu + kalender
            ctx[c] = train[c].to_numpy(float)
        fut = pd.DataFrame({"item_id": "seri", "timestamp": masa_depan["bulan"].to_numpy()})
        for c in KOVARIAT_KALENDER:  # hanya kalender yg diketahui di masa depan
            fut[c] = masa_depan[c].to_numpy(float)
    else:
        for c in KOVARIAT_KALENDER:
            ctx[c] = train[c].to_numpy(float)
        fut = pd.DataFrame({"item_id": "seri", "timestamp": masa_depan["bulan"].to_numpy()})
        for c in KOVARIAT_KALENDER:
            fut[c] = masa_depan[c].to_numpy(float)
    pred = pipe.predict_df(ctx, future_df=fut, prediction_length=len(masa_depan),
                           quantile_levels=[0.1, 0.5, 0.9], id_column="item_id",
                           timestamp_column="timestamp", target="target")
    pred = pred.sort_values("timestamp")
    balik = np.expm1 if log else (lambda v: v)
    return {"p50": balik(pred["0.5"].to_numpy(float)), "p10": balik(pred["0.1"].to_numpy(float)),
            "p90": balik(pred["0.9"].to_numpy(float))}


def chronos2_kalender(train, masa_depan):
    """Chronos-2 dgn kovariat kalender (Ramadan/Desember) saja."""
    return _chronos(train, masa_depan, pakai_kovariat=False)


def chronos2_kovariat_pro(train, masa_depan):
    """Chronos-2 + kalender + kovariat masa lalu (jumlah/pangsa Pro, pengguna baru)."""
    return _chronos(train, masa_depan, pakai_kovariat=True)


def chronos2_log_kalender(train, masa_depan):
    """Chronos-2 pada skala log (pertumbuhan multiplikatif) + kalender."""
    return _chronos(train, masa_depan, pakai_kovariat=False, log=True)


def chronos2_log_kovariat_pro(train, masa_depan):
    """Chronos-2 skala log + kalender + kovariat Pro/pengguna baru."""
    return _chronos(train, masa_depan, pakai_kovariat=True, log=True)


def ensemble_chronos_theta(train, masa_depan):
    """Rata-rata Chronos-2 (log, kovariat Pro) dan Theta -- statistik klasik + foundation model."""
    a = chronos2_log_kovariat_pro(train, masa_depan)["p50"]
    b = theta(train, masa_depan)["p50"]
    return {"p50": (a + b) / 2, "p10": None, "p90": None}


from arima_fts import arima, fts_multivariat  # noqa: E402  (dua model utama yang dibandingkan di dashboard)

# Dua metode yang DIMINTA dosen (ARIMA univariat vs FTS multivariat). Keduanya selalu masuk perbandingan.
MODEL_UTAMA = ["arima", "fts_multivariat"]

MODEL = {
    "arima": arima,
    "fts_multivariat": fts_multivariat,
    "seasonal_naive_tren": seasonal_naive_tren,
    "ets_redaman": ets,
    "theta": theta,
    "lightgbm": lightgbm_rekursif,
    "chronos2_kalender": chronos2_kalender,
    "chronos2_kovariat_pro": chronos2_kovariat_pro,
    "chronos2_log_kalender": chronos2_log_kalender,
    "chronos2_log_kovariat_pro": chronos2_log_kovariat_pro,
    "ensemble_chronos_theta": ensemble_chronos_theta,
}

# Semua model yang dibandingkan secara default: dua metode permintaan dosen + model pembanding lama (ETS, Theta,
# LightGBM, Chronos-2, ...). Yang ditampilkan di dashboard = MAPE terkecil di antara SEMUANYA.
MODEL_DIBANDINGKAN = list(MODEL)
