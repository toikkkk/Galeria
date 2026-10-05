"""Uji kewajaran dataset training (BUKAN hasil model utk laporan).

Dua tujuan:
1. AUDIT KEBOCORAN: hitung ulang beberapa fitur riwayat dgn cara BERBEDA (filter pandas
   langsung dari tabel mentah) dan pastikan sama dgn kolom di CSV.
2. KEWAJARAN SINYAL: data sintetis terlalu rapi -> skor ~1.0 (tak bermakna); terlalu acak
   -> tak ada yg bisa dipelajari. Model sederhana harus berada di antaranya.

Angka di sini hanya menunjukkan "generator terbaca model", BUKAN performa di dunia nyata.

    python scripts/cek_sinyal_data.py
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.cluster import KMeans
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.metrics import adjusted_rand_score, roc_auc_score, silhouette_score
from sklearn.preprocessing import StandardScaler

ROOT = Path(__file__).resolve().parent.parent
TR, EX = ROOT / "data" / "training", ROOT / "data" / "export"
ID_COLS = ["grup_id", "split", "waktu", "transaksi_id", "kolektor_id", "karya_id", "seniman_id", "dibeli"]


def audit_kebocoran() -> None:
    kls = pd.read_csv(TR / "klasifikasi_pembelian.csv", parse_dates=["waktu"])
    tx = pd.read_csv(EX / "transaksi.csv", parse_dates=["created_at"])
    pos = kls[kls["dibeli"] == 1].sample(300, random_state=0)
    salah = 0
    for r in pos.itertuples():
        sebelum = tx[(tx["pembeli_id"] == r.kolektor_id) & (tx["created_at"] < r.waktu)]
        salah += int(len(sebelum) != r.kolektor_n_beli_sebelumnya)
        if len(sebelum):
            salah += int(abs(sebelum["harga_final_idr"].mean() - r.kolektor_harga_rata2_idr) > 1)
        s30 = tx[(tx["penjual_id"] == r.seniman_id) & (tx["created_at"] < r.waktu)
                 & (tx["created_at"] >= r.waktu - pd.Timedelta(days=30))]
        salah += int(len(s30) != r.seniman_n_terjual_30hari)
    # pembelian itu sendiri tidak boleh ikut dihitung: pembelian pertama kolektor harus n_beli_sebelumnya == 0
    pertama = kls[(kls["dibeli"] == 1)].sort_values("waktu").groupby("kolektor_id").head(1)
    salah += int((pertama["kolektor_n_beli_sebelumnya"] != 0).sum())
    # 1 positif per grup, split tidak terpecah
    salah += int((kls.groupby("grup_id")["dibeli"].sum() != 1).sum())
    salah += int((kls.groupby("grup_id")["split"].nunique() != 1).sum())
    # urutan waktu antar split
    w = kls.drop_duplicates("grup_id").groupby("split")["waktu"].agg(["min", "max"])
    salah += int(not (w.loc["train", "max"] <= w.loc["val", "min"] and w.loc["val", "max"] <= w.loc["test", "min"]))
    print(f"[audit kebocoran] ketidakcocokan: {salah}  -> {'OK' if salah == 0 else 'ADA MASALAH'}")
    assert salah == 0


def sinyal_klasifikasi() -> None:
    kls = pd.read_csv(TR / "klasifikasi_pembelian.csv")
    fitur = [c for c in kls.columns if c not in ID_COLS]
    X = kls[fitur].copy()
    for c in ("karya_gaya", "seniman_level_reputasi"):
        X[c] = X[c].astype("category")
    tr, va, te = (kls["split"] == s for s in ("train", "val", "test"))
    m = HistGradientBoostingClassifier(max_iter=200, learning_rate=0.05, categorical_features="from_dtype", random_state=0)
    m.fit(X[tr], kls.loc[tr, "dibeli"])

    def evaluasi(mask, nama):
        d = kls[mask].copy()
        d["skor"] = m.predict_proba(X[mask])[:, 1]
        auc = roc_auc_score(d["dibeli"], d["skor"])
        d["rank"] = d.groupby("grup_id")["skor"].rank(ascending=False, method="first")
        hit1 = (d[d["dibeli"] == 1]["rank"] <= 1).mean()
        hit3 = (d[d["dibeli"] == 1]["rank"] <= 3).mean()
        print(f"[klasifikasi {nama:4s}] AUC {auc:.3f} | HitRate@1 {hit1:.3f} | HitRate@3 {hit3:.3f}")

    n_neg = int((kls["dibeli"] == 0).sum() / kls["grup_id"].nunique())
    print(f"  (acak: HitRate@1 {1 / (1 + n_neg):.2f}, HitRate@3 {3 / (1 + n_neg):.2f}, AUC 0.50)")
    evaluasi(va, "val")
    evaluasi(te, "test")


def sinyal_clustering() -> None:
    clu = pd.read_csv(TR / "clustering_kolektor.csv")
    lab = pd.read_csv(TR / "kolektor_label_asli.csv")
    d = clu.merge(lab, on="kolektor_id")
    fitur = [c for c in clu.columns if c != "kolektor_id"]
    X = clu[fitur].copy()
    for c in [c for c in fitur if c.endswith("_idr")]:
        X[c] = np.log1p(X[c])
    Z = StandardScaler().fit_transform(X)   # RobustScaler memperbesar outlier harga -> klaster kecil berisi outlier (ARI ~0.2)
    print("[clustering] k : silhouette | ARI vs segmen_asli")
    for k in (3, 4, 5, 6, 7):
        km = KMeans(n_clusters=k, n_init=10, random_state=0).fit(Z)
        print(f"  k={k}: {silhouette_score(Z, km.labels_):.3f} | {adjusted_rand_score(d['segmen_asli'], km.labels_):.3f}")


if __name__ == "__main__":
    audit_kebocoran()
    sinyal_klasifikasi()
    sinyal_clustering()
