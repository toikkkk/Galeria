"""Keaktifan seniman: skor keaktifan, cluster (Aktif / Kurang Aktif / Tidak Aktif), dan peringkat Top 10.

Data: schema dummy_admin (1.740 seniman). Alur batch; backend hanya MEMBACA tabel hasil.

    cd dashboard-admin
    .venv\\Scripts\\python seniman\\aktivitas.py              # hitung + tulis ke Neon
    .venv\\Scripts\\python seniman\\aktivitas.py --tanpa-db   # hanya cetak

DEFINISI KEAKTIFAN (satu definisi dipakai Top 10, cluster, notifikasi, reward):
  skor_keaktifan (0-100) = 50% peringkat-persentil jumlah penjualan 90 hari terakhir
                         + 30% peringkat-persentil omzet 90 hari terakhir
                         + 20% (1 - peringkat-persentil hari sejak penjualan terakhir)
  Peringkat-persentil dipakai (bukan nilai mentah) karena sebaran penjualan sangat miring dan ties banyak di nol.
  Seniman yang belum pernah menjual: hari sejak penjualan terakhir = umur akun.
  Keterbatasan: data admin tidak mencatat unggahan karya, jadi keaktifan di sini = keaktifan MENJUAL.

CLUSTER (dua tahap; K-Means tidak dipakai, arahan dosen):
  1. UMAP + HDBSCAN menemukan kelompok perilaku. Fitur = log1p dari penjualan 90 hari, omzet 90 hari, hari sejak
     penjualan terakhir, dan penjualan seumur hidup; lalu StandardScaler. Hiperparameter dipilih dgn aturan yang
     ditetapkan SEBELUM melihat hasil: di antara konfigurasi dgn noise <= 10% dan K >= 3, ambil silhouette
     (di ruang fitur asli, bukan ruang UMAP) tertinggi. Titik noise ditetapkan ke kelompok terdekat di ruang UMAP.
  2. TEMUAN: pada data ini HDBSCAN menemukan 10-36 kelompok kecil (perilaku penjualan bersifat kontinu), BUKAN 3, dan
     jumlahnya tidak bisa dipaksa. Karena kebutuhan bisnisnya tiga tingkat bernama, kelompok-kelompok itu digabung
     hierarkis (Ward, 1 dimensi pada rata-rata skor_keaktifan tiap kelompok) menjadi 3 tingkat; nama diberikan dari
     rata-rata skor: tertinggi = Aktif, tengah = Kurang Aktif, terendah = Tidak Aktif.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import re
import sys
import warnings
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine

RAIZ = Path(__file__).resolve().parents[1]
load_dotenv(RAIZ.parent / "backend" / ".env")
warnings.filterwarnings("ignore")

SCHEMA = os.environ.get("ADMIN_SCHEMA", "dummy_admin")
if not re.fullmatch(r"[a-z_][a-z0-9_]*", SCHEMA):
    raise SystemExit("ADMIN_SCHEMA tidak valid")

MODEL_VERSION = "keaktifan-v1"
SEED = 42
ACUAN = pd.Timestamp(os.environ.get("ADMIN_WAKTU_ACUAN", "2026-09-30T23:59:59Z"))
LABEL = ("Aktif", "Kurang Aktif", "Tidak Aktif")
FITUR = ["n_jual_90d", "omzet_90d", "hari_sejak_jual", "n_jual_total"]

SQL = f"""
SELECT u.id AS seniman_id, u.display_name, u.created_at,
  count(t.id) FILTER (WHERE t.created_at >= :t90 AND t.created_at <= :acuan)::int AS n_jual_90d,
  COALESCE(sum(t.harga_final_idr) FILTER (WHERE t.created_at >= :t90 AND t.created_at <= :acuan), 0)::bigint AS omzet_90d,
  count(t.id) FILTER (WHERE t.created_at >= :t365 AND t.created_at <= :acuan)::int AS n_jual_12b,
  COALESCE(sum(t.harga_final_idr) FILTER (WHERE t.created_at >= :t365 AND t.created_at <= :acuan), 0)::bigint AS omzet_12b,
  count(t.id) FILTER (WHERE t.created_at <= :acuan)::int AS n_jual_total,
  max(t.created_at) FILTER (WHERE t.created_at <= :acuan) AS terakhir_jual,
  EXISTS (SELECT 1 FROM {SCHEMA}.subscriptions s WHERE s.user_id = u.id AND s.plan_type = 'seniman_pro'
          AND s.mulai_at <= :acuan AND s.berakhir_at > :acuan) AS pro
FROM {SCHEMA}.users u LEFT JOIN {SCHEMA}.transaksi t ON t.penjual_id = u.id
WHERE u.role = 'seniman' AND u.created_at <= :acuan
GROUP BY u.id, u.display_name, u.created_at
"""


async def _muat() -> pd.DataFrame:
    url = os.environ.get("DATABASE_URL")
    if not url:
        raise SystemExit("DATABASE_URL belum di-set (backend/.env)")
    engine = create_async_engine(url)
    try:
        async with engine.connect() as conn:
            rows = (await conn.execute(text(SQL), {
                "acuan": ACUAN.to_pydatetime(), "t90": (ACUAN - pd.Timedelta(days=90)).to_pydatetime(),
                "t365": (ACUAN - pd.Timedelta(days=365)).to_pydatetime()})).mappings().all()
    finally:
        await engine.dispose()
    return pd.DataFrame(rows)


def siapkan_fitur(df: pd.DataFrame) -> pd.DataFrame:
    """Kolom turunan + skor keaktifan. Murni fungsi pandas (mudah diuji tanpa database)."""
    df = df.copy()
    df["created_at"] = pd.to_datetime(df["created_at"], utc=True)
    df["terakhir_jual"] = pd.to_datetime(df["terakhir_jual"], utc=True)
    df["pernah_jual"] = df["n_jual_total"] > 0
    umur = (ACUAN - df["created_at"]).dt.days.clip(lower=0)
    sejak = (ACUAN - df["terakhir_jual"]).dt.days
    df["hari_sejak_jual"] = sejak.where(df["pernah_jual"], umur).astype(int)       # belum pernah jual -> umur akun
    pr = lambda s: s.rank(method="average", pct=True)                              # peringkat-persentil 0..1
    df["skor_keaktifan"] = (100 * (0.5 * pr(df["n_jual_90d"]) + 0.3 * pr(df["omzet_90d"])
                                   + 0.2 * (1 - pr(df["hari_sejak_jual"])))).round(2)
    return df


def matriks(df: pd.DataFrame) -> np.ndarray:
    from sklearn.preprocessing import StandardScaler

    x = pd.DataFrame({
        "n_jual_90d": np.log1p(df["n_jual_90d"]), "omzet_90d": np.log1p(df["omzet_90d"] / 1e6),
        "hari_sejak_jual": np.log1p(df["hari_sejak_jual"]), "n_jual_total": np.log1p(df["n_jual_total"])})
    return StandardScaler().fit_transform(x[FITUR].to_numpy(float))


def _umap_hdbscan(z: np.ndarray, nn: int, mcs: int, seed: int = SEED):
    import hdbscan
    import umap

    emb = umap.UMAP(n_neighbors=nn, n_components=5, min_dist=0.0, random_state=seed).fit_transform(z)
    lab = hdbscan.HDBSCAN(min_cluster_size=mcs, min_samples=max(5, mcs // 4), cluster_selection_method="eom").fit_predict(emb)
    return emb, lab


def _silhouette(z: np.ndarray, lab: np.ndarray) -> float:
    from sklearn.metrics import silhouette_score

    ok = lab >= 0
    if ok.sum() < 3 or len(set(lab[ok])) < 2:
        return float("nan")
    return float(silhouette_score(z[ok], lab[ok]))


def cari_konfigurasi(z: np.ndarray) -> tuple[pd.DataFrame, dict]:
    baris = []
    for nn in (15, 30, 50):
        for mcs in (20, 40, 80):
            emb, lab = _umap_hdbscan(z, nn, mcs)
            k = len(set(lab[lab >= 0]))
            baris.append({"n_neighbors": nn, "min_cluster_size": mcs, "k": k, "noise_pct": round(float((lab < 0).mean() * 100), 2),
                          "silhouette": round(_silhouette(z, lab), 4)})
    tabel = pd.DataFrame(baris)
    layak = tabel[(tabel.noise_pct <= 10) & (tabel.k >= 3) & tabel.silhouette.notna()]
    if layak.empty:
        raise SystemExit("Tidak ada konfigurasi dgn K >= 3 dan noise <= 10%:\n" + tabel.to_string())
    pilih = layak.sort_values(["silhouette", "noise_pct"], ascending=[False, True]).iloc[0]
    return tabel, {"n_neighbors": int(pilih.n_neighbors), "min_cluster_size": int(pilih.min_cluster_size)}


def gabung_ke_tiga(skor: pd.Series, lab: np.ndarray) -> dict[int, str]:
    """Gabungkan kelompok HDBSCAN menjadi 3 tingkat (Ward 1-D pada rata-rata skor_keaktifan tiap kelompok), lalu
    namai dari rata-rata skor gabungan: tertinggi = Aktif, tengah = Kurang Aktif, terendah = Tidak Aktif."""
    from sklearn.cluster import AgglomerativeClustering

    rata = skor.groupby(lab).mean()
    ids = list(rata.index)
    if len(ids) <= 3:
        urut = list(rata.sort_values(ascending=False).index)
        return {c: LABEL[min(i, 2) if len(urut) == 3 else (0 if i == 0 else 2)] for i, c in enumerate(urut)}
    grup = AgglomerativeClustering(n_clusters=3, linkage="ward").fit_predict(rata.to_numpy().reshape(-1, 1))
    skor_grup = pd.Series(rata.to_numpy()).groupby(grup).mean().sort_values(ascending=False)
    nama_grup = {g: LABEL[i] for i, g in enumerate(skor_grup.index)}
    return {c: nama_grup[g] for c, g in zip(ids, grup)}


def tetapkan_noise(emb: np.ndarray, lab: np.ndarray) -> np.ndarray:
    """Titik noise -> cluster dgn pusat terdekat di ruang UMAP."""
    lab = lab.copy()
    ada = np.flatnonzero(lab < 0)
    if len(ada) == 0:
        return lab
    pusat = {c: emb[lab == c].mean(axis=0) for c in set(lab[lab >= 0])}
    for i in ada:
        lab[i] = min(pusat, key=lambda c: np.linalg.norm(emb[i] - pusat[c]))
    return lab


def stabilitas(z: np.ndarray, lab_penuh: np.ndarray, konf: dict, n: int = 8, frac: float = 0.8) -> tuple[float, float]:
    """Rata-rata dan simpangan ARI antara label penuh dan label subsampel 80% (titik yang sama)."""
    from sklearn.metrics import adjusted_rand_score

    rng = np.random.default_rng(SEED)
    skor = []
    for i in range(n):
        idx = np.sort(rng.choice(len(z), int(frac * len(z)), replace=False))
        _, lab = _umap_hdbscan(z[idx], konf["n_neighbors"], konf["min_cluster_size"], seed=SEED + i + 1)
        ok = lab >= 0
        if ok.sum() > 10:
            skor.append(adjusted_rand_score(lab_penuh[idx][ok], lab[ok]))
    return (float(np.mean(skor)), float(np.std(skor))) if skor else (float("nan"), float("nan"))


def hitung(df_mentah: pd.DataFrame) -> tuple[pd.DataFrame, dict]:
    df = siapkan_fitur(df_mentah)
    z = matriks(df)
    tabel, konf = cari_konfigurasi(z)
    emb, lab = _umap_hdbscan(z, konf["n_neighbors"], konf["min_cluster_size"])
    noise_awal = lab < 0
    lab_penuh = tetapkan_noise(emb, lab)
    peta = gabung_ke_tiga(df["skor_keaktifan"], lab_penuh)
    df["cluster_id_asal"] = lab_penuh
    df["noise_diisi"] = noise_awal
    df["cluster"] = [peta[c] for c in lab_penuh]
    sil = _silhouette(z, lab)                                   # kelompok HDBSCAN (tanpa noise), ruang fitur asli
    lab_tiga = np.array([LABEL.index(c) for c in df["cluster"]])
    sil_tiga = _silhouette(z, lab_tiga)                         # 3 tingkat hasil penggabungan
    ari_m, ari_s = stabilitas(z, lab_penuh, konf)
    meta = {
        "model_version": MODEL_VERSION, "algoritma": "UMAP + HDBSCAN", "n_seniman": int(len(df)),
        "k_ditemukan": int(len(set(lab_penuh))), "k_akhir": 3, "noise_pct": round(float(noise_awal.mean() * 100), 2),
        "silhouette_ruang_fitur": round(sil, 4), "silhouette_tiga_tingkat": round(sil_tiga, 4), "stabilitas_ari_rata2": round(ari_m, 3), "stabilitas_ari_sd": round(ari_s, 3),
        "hiperparameter": konf, "fitur": FITUR, "waktu_acuan": ACUAN.isoformat(),
        "grid": tabel.to_dict("records"),
        "pemetaan_cluster": {str(k): v for k, v in sorted(peta.items())},
        "catatan": ("Data sintetis. Cluster sebagian besar mencerminkan 'pernah/masih menjual', sehingga silhouette tinggi adalah akibat "
                    "desain data, bukan temuan nyata. Keaktifan = keaktifan MENJUAL (unggahan karya tidak tercatat di data admin)."),
    }
    return df, meta


def profil(df: pd.DataFrame) -> dict[str, dict]:
    keluar = {}
    for nama in LABEL:
        g = df[df["cluster"] == nama]
        if g.empty:
            continue
        keluar[nama] = {
            "ukuran": int(len(g)), "persen": round(len(g) / len(df) * 100, 1),
            "skor_rata2": round(float(g["skor_keaktifan"].mean()), 1),
            "n_jual_90d_median": float(g["n_jual_90d"].median()), "omzet_90d_median_idr": int(g["omzet_90d"].median()),
            "hari_sejak_jual_median": int(g["hari_sejak_jual"].median()), "n_jual_total_median": float(g["n_jual_total"].median()),
            "pernah_jual_pct": round(float(g["pernah_jual"].mean() * 100), 1), "pro_pct": round(float(g["pro"].mean() * 100), 1),
        }
    return keluar


DDL = [
    f"""CREATE TABLE IF NOT EXISTS {SCHEMA}.seniman_aktivitas (
        seniman_id uuid PRIMARY KEY, display_name text NOT NULL,
        cluster text NOT NULL CHECK (cluster IN ('Aktif','Kurang Aktif','Tidak Aktif')),
        skor_keaktifan real NOT NULL, n_jual_90d integer NOT NULL, omzet_90d bigint NOT NULL,
        n_jual_12b integer NOT NULL, omzet_12b bigint NOT NULL, n_jual_total integer NOT NULL,
        hari_sejak_jual integer NOT NULL, pernah_jual boolean NOT NULL, pro boolean NOT NULL,
        cluster_id_asal integer NOT NULL, noise_diisi boolean NOT NULL,
        model_version text NOT NULL, dihitung_at timestamptz NOT NULL DEFAULT now())""",
    f"CREATE INDEX IF NOT EXISTS ix_dadm_senak_cluster ON {SCHEMA}.seniman_aktivitas(cluster)",
    f"CREATE TABLE IF NOT EXISTS {SCHEMA}.seniman_cluster_info (kunci text PRIMARY KEY, nilai jsonb NOT NULL, dihitung_at timestamptz NOT NULL DEFAULT now())",
]


async def tulis(df: pd.DataFrame, meta: dict, prof: dict) -> None:
    engine = create_async_engine(os.environ["DATABASE_URL"])
    kolom = ["seniman_id", "display_name", "cluster", "skor_keaktifan", "n_jual_90d", "omzet_90d", "n_jual_12b", "omzet_12b",
             "n_jual_total", "hari_sejak_jual", "pernah_jual", "pro", "cluster_id_asal", "noise_diisi"]
    baris = [{**{k: (v.item() if hasattr(v, "item") else v) for k, v in r.items()}, "mv": MODEL_VERSION}
             for r in df[kolom].astype({"seniman_id": str}).to_dict("records")]
    async with engine.begin() as conn:
        for s in DDL:
            await conn.execute(text(s))
        await conn.execute(text(f"DELETE FROM {SCHEMA}.seniman_aktivitas"))
        await conn.execute(text(
            f"INSERT INTO {SCHEMA}.seniman_aktivitas (seniman_id, display_name, cluster, skor_keaktifan, n_jual_90d, omzet_90d, "
            "n_jual_12b, omzet_12b, n_jual_total, hari_sejak_jual, pernah_jual, pro, cluster_id_asal, noise_diisi, model_version) "
            "VALUES (CAST(:seniman_id AS uuid), :display_name, :cluster, :skor_keaktifan, :n_jual_90d, :omzet_90d, :n_jual_12b, "
            ":omzet_12b, :n_jual_total, :hari_sejak_jual, :pernah_jual, :pro, :cluster_id_asal, :noise_diisi, :mv)"), baris)
        await conn.execute(text(f"DELETE FROM {SCHEMA}.seniman_cluster_info"))
        for kunci, nilai in {"meta": meta, **prof}.items():
            await conn.execute(text(f"INSERT INTO {SCHEMA}.seniman_cluster_info (kunci, nilai) VALUES (:k, CAST(:v AS jsonb))"),
                               {"k": kunci, "v": json.dumps(nilai, ensure_ascii=False, default=str)})
    await engine.dispose()


def main(tanpa_db: bool) -> None:
    df, meta = hitung(asyncio.run(_muat()))
    prof = profil(df)
    print(f"{meta['n_seniman']} seniman | HDBSCAN menemukan {meta['k_ditemukan']} kelompok -> digabung jadi 3 tingkat | noise {meta['noise_pct']}%")
    print(f"silhouette: kelompok HDBSCAN {meta['silhouette_ruang_fitur']} | 3 tingkat {meta['silhouette_tiga_tingkat']} | "
          f"stabilitas ARI (kelompok HDBSCAN) {meta['stabilitas_ari_rata2']} ± {meta['stabilitas_ari_sd']}")
    print("konfigurasi terpilih:", meta["hiperparameter"])
    for nama, p in prof.items():
        print(f"  {nama:13s} {p['ukuran']:5d} ({p['persen']}%)  skor {p['skor_rata2']}  jual90d med {p['n_jual_90d_median']}  "
              f"sejak jual med {p['hari_sejak_jual_median']} hr  pernah jual {p['pernah_jual_pct']}%  Pro {p['pro_pct']}%")
    top = df.sort_values("skor_keaktifan", ascending=False).head(3)[["display_name", "skor_keaktifan", "n_jual_90d", "cluster"]]
    print(top.to_string(index=False))
    if not tanpa_db:
        asyncio.run(tulis(df, meta, prof))
        print(f"\nDitulis ke {SCHEMA}.seniman_aktivitas dan seniman_cluster_info")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--tanpa-db", action="store_true")
    main(ap.parse_args().tanpa_db)
