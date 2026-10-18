"""Clustering kolektor -- segmentasi perilaku belanja (bagian Thoriq), versi ``clustering-v2``.

ALGORITMA: **UMAP + HDBSCAN** (menggantikan K-Means pada ``clustering-v1``).
  * UMAP (2018) memetakan fitur perilaku ke ruang rendah-dimensi yang mempertahankan struktur tetangga.
  * HDBSCAN (2013/2015) adalah clustering berbasis kepadatan: jumlah klaster DITEMUKAN sendiri (tanpa menebak K),
    bentuk klaster bebas, dan titik yang tak masuk klaster mana pun ditandai noise (``-1``).
  * Kolektor BARU ditetapkan lewat ``umap.transform`` + ``hdbscan.approximate_predict`` (bukan melatih ulang).

KEPUTUSAN METODOLOGI (dan alasannya)
------------------------------------
1. **Fitur = 5 dimensi perilaku yang bersih**: nilai belanja (harga rata-rata), frekuensi beli, keikutan tren
   (persentil tren seniman saat beli), serta profil seniman yang dibeli (porsi mapan, porsi pemula). Keterpusatan selera
   aliran (``porsi_gaya_teratas``, ``entropi``) SENGAJA tidak dipakai memisahkan klaster: dgn ~3-10 pembelian per kolektor
   nilainya hanya 0,33/0,5/1,0 (berisik) dan percobaan menunjukkan memasukkannya menurunkan silhouette (~0,62 -> ~0,43).
   Kolom ``porsi_gaya_*`` tetap dipakai utk PROFIL segmen (aliran favorit) dan utk model klasifikasi.
2. **Transformasi:** ``log1p`` pada harga & frekuensi, lalu ``StandardScaler``.
3. **Silhouette dihitung di RUANG FITUR ASLI (terstandarisasi), bukan di ruang UMAP.** Di ruang UMAP skornya hampir
   selalu menggelembung (UMAP memang menarik titik sejenis berdekatan) sehingga tak adil dibandingkan dgn K-Means.
4. **Hiperparameter dipilih dgn aturan yang ditetapkan SEBELUM melihat label asli generator:** di antara konfigurasi
   dgn noise <= 10% dan 3 <= K <= 8, ambil silhouette (ruang fitur) tertinggi; seri -> noise lebih sedikit. Label asli
   (``kolektor_label_asli``) hanya utk VALIDASI setelah model final.
5. **Noise** tidak dibuang diam-diam: dilaporkan, lalu ditetapkan ke klaster terdekat (kepastian = 0).
6. **Nama segmen berasal dari karakteristik centroid**, bukan dari label generator.

Artefak ``models/clustering_kolektor.joblib`` memuat objek UMAP/HDBSCAN/scikit-learn (butuh ``umap-learn`` &
``hdbscan`` terpasang utk memuatnya). Backend TIDAK memuatnya -- backend hanya membaca tabel hasil di Neon.
"""

from __future__ import annotations

import warnings
from datetime import datetime, timezone

import numpy as np
import pandas as pd
from sklearn.metrics import (adjusted_rand_score, calinski_harabasz_score, completeness_score, davies_bouldin_score,
                             homogeneity_score, normalized_mutual_info_score, silhouette_samples, silhouette_score,
                             v_measure_score)
from sklearn.preprocessing import StandardScaler

VERSI = "clustering-v2"
ALGORITMA = "UMAP + HDBSCAN"
SEED = 42
MIN_PEMBELIAN_SEGMEN = 3          # riwayat minimum agar kolektor bisa ditetapkan ke segmen
NAMA_BELUM_ADA = "Belum Cukup Riwayat"
NOISE_MAKS = 0.10
K_MIN, K_MAKS = 3, 8
STABIL_BAIK = 0.80
GRID_NN = (10, 15, 25)            # n_neighbors UMAP
GRID_MCS = (5, 8, 10, 15)         # min_cluster_size HDBSCAN (kecil dibutuhkan: segmen langka mis. premium bisa < 15 orang)
UMAP_DIM = 5
MIN_SAMPLES = 5
TOL_TREN = 0.03                  # toleransi penamaan "Pemburu Tren": persentil tren tidak lebih dari ini di bawah median populasi

KOLOM_FITUR = ["harga_rata2_idr", "frekuensi_beli_per_bulan", "rata2_persentil_tren_saat_beli",
               "porsi_beli_seniman_mapan", "porsi_beli_seniman_pemula"]
KOLOM_LOG = ["harga_rata2_idr", "frekuensi_beli_per_bulan"]
KOLOM_PROFIL = ["n_pembelian", "harga_rata2_idr", "frekuensi_beli_per_bulan", "rata2_persentil_tren_saat_beli",
                "porsi_beli_seniman_mapan", "porsi_beli_seniman_menengah", "porsi_beli_seniman_pemula",
                "porsi_gaya_teratas", "entropi_gaya_norm", "harga_std_log", "rata2_lonjakan_saat_beli", "rata2_diskon_negosiasi"]


def _impor():
    """Impor lambat: umap/hdbscan berat (numba) dan tak dibutuhkan oleh yang hanya memuat tabel."""
    import hdbscan
    import umap
    return umap, hdbscan


# ----------------------------------------------------------------------------- fitur
def kolom_porsi_aliran(df: pd.DataFrame) -> list[str]:
    return [c for c in df.columns if c.startswith("porsi_gaya_") and c != "porsi_gaya_teratas"]


def matriks(df: pd.DataFrame, fitur: list[str] = KOLOM_FITUR, kol_log: list[str] = KOLOM_LOG) -> pd.DataFrame:
    x = df[fitur].astype(float).copy()
    x[kol_log] = np.log1p(x[kol_log])
    return x


# ----------------------------------------------------------------------- inti model
def _fit_umap_hdbscan(z: np.ndarray, nn: int, mcs: int, seed: int = SEED):
    umap, hdbscan = _impor()
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        um = umap.UMAP(n_neighbors=min(nn, len(z) - 1), n_components=UMAP_DIM, min_dist=0.0, random_state=seed, n_jobs=1).fit(z)
        emb = um.embedding_
        hd = hdbscan.HDBSCAN(min_cluster_size=mcs, min_samples=MIN_SAMPLES, prediction_data=True).fit(emb)
    return um, hd, emb


def _pusat(emb: np.ndarray, lab: np.ndarray) -> dict[int, np.ndarray]:
    return {int(k): emb[lab == k].mean(axis=0) for k in sorted(set(lab)) if k >= 0}


def _isi_noise(emb: np.ndarray, lab: np.ndarray, pusat: dict[int, np.ndarray]) -> np.ndarray:
    """Titik noise (-1) -> klaster dgn pusat terdekat di ruang embedding."""
    lab = lab.copy()
    bad = lab < 0
    if bad.any() and pusat:
        ks = np.array(list(pusat))
        m = np.stack([pusat[int(k)] for k in ks])
        lab[bad] = ks[np.linalg.norm(emb[bad][:, None] - m[None], axis=-1).argmin(axis=1)]
    return lab


def cari_konfigurasi(z: np.ndarray, seed: int = SEED) -> pd.DataFrame:
    """Sapu grid (n_neighbors x min_cluster_size). Silhouette dihitung di ruang fitur ASLI ``z`` (setelah noise ditetapkan)."""
    baris = []
    for nn in GRID_NN:
        for mcs in GRID_MCS:
            _, hd, emb = _fit_umap_hdbscan(z, nn, mcs, seed)
            lab = hd.labels_
            noise = float((lab < 0).mean())
            penuh = _isi_noise(emb, lab, _pusat(emb, lab))
            k = len(set(penuh[penuh >= 0])) if (penuh >= 0).any() else 0
            sil = float(silhouette_score(z, penuh)) if k > 1 else float("nan")
            baris.append({"n_neighbors": nn, "min_cluster_size": mcs, "k": k, "noise_pct": 100 * noise, "silhouette": sil})
    return pd.DataFrame(baris)


def pilih_konfigurasi(tabel: pd.DataFrame) -> dict:
    """Aturan (ditetapkan sebelum melihat label asli): noise <= 10%, 3 <= K <= 8 -> silhouette tertinggi;
    seri -> noise lebih sedikit -> min_cluster_size lebih besar. Bila tak ada yang layak: silhouette tertinggi saja."""
    layak = tabel[(tabel["noise_pct"] <= 100 * NOISE_MAKS) & tabel["k"].between(K_MIN, K_MAKS)]
    pool = layak if not layak.empty else tabel.dropna(subset=["silhouette"])
    r = pool.sort_values(["silhouette", "noise_pct", "min_cluster_size"], ascending=[False, True, False]).iloc[0]
    return {"n_neighbors": int(r["n_neighbors"]), "min_cluster_size": int(r["min_cluster_size"]), "layak": not layak.empty}


def stabilitas_bootstrap(z: np.ndarray, nn: int, mcs: int, n: int = 30, frac: float = 0.8, seed: int = SEED) -> tuple[float, float]:
    """(rata-rata, simpangan baku) ARI antara klaster acuan (data penuh) dan klaster dari model yang dilatih ulang
    pada subsampel ``frac`` (tanpa pengembalian). ARI dihitung pada titik yang sama (setelah noise ditetapkan)."""
    _, hd, emb = _fit_umap_hdbscan(z, nn, mcs, seed)
    acuan = _isi_noise(emb, hd.labels_, _pusat(emb, hd.labels_))
    rng = np.random.default_rng(seed)
    skor = []
    for _ in range(n):
        idx = np.sort(rng.choice(len(z), int(frac * len(z)), replace=False))
        _, h2, e2 = _fit_umap_hdbscan(z[idx], nn, mcs, seed)
        lab2 = _isi_noise(e2, h2.labels_, _pusat(e2, h2.labels_))
        skor.append(adjusted_rand_score(acuan[idx], lab2))
    return float(np.mean(skor)), float(np.std(skor))


# ----------------------------------------------------------------------- penamaan
def _juta(x: float) -> str:
    return f"{x / 1e6:,.0f}".replace(",", ".")


def beri_nama(profil: pd.DataFrame, populasi: pd.Series) -> dict[int, str]:
    """Nama segmen dari karakteristik centroid (median fitur per klaster). Aturan deterministik, tanpa label generator:
      rasio_harga = harga rata-rata klaster / median populasi; rasio_frek = frekuensi klaster / median populasi
      rasio_harga >= 2,5 : frekuensi di bawah median -> "Kolektor Premium", selain itu "Kolektor Aktif Bernilai Tinggi"
      rasio_harga <= 0,4 : "Pemula Hemat"
      selain itu         : frekuensi >= 1,5x median DAN persentil tren tidak lebih dari 0,03 di bawah median -> "Pemburu Tren",
                           selain itu "Kolektor Menengah Rutin"
    Nama kembar diberi nomor supaya tetap unik."""
    urut = profil["harga_rata2_idr"].sort_values(ascending=False).index.tolist()
    nama: dict[int, str] = {}
    for kid in urut:
        p = profil.loc[kid]
        rh = p["harga_rata2_idr"] / populasi["harga_rata2_idr"]
        rf = p["frekuensi_beli_per_bulan"] / populasi["frekuensi_beli_per_bulan"]
        if rh >= 2.5:
            n = "Kolektor Premium" if rf < 1.0 else "Kolektor Aktif Bernilai Tinggi"
        elif rh <= 0.4:
            n = "Pemula Hemat"
        elif rf >= 1.5 and p["rata2_persentil_tren_saat_beli"] >= populasi["rata2_persentil_tren_saat_beli"] - TOL_TREN:
            n = "Pemburu Tren"
        else:
            n = "Kolektor Menengah Rutin"
        nama[kid] = n
    hitung: dict[str, int] = {}
    for kid in urut:
        hitung[nama[kid]] = hitung.get(nama[kid], 0) + 1
    pakai: dict[str, int] = {}
    for kid in urut:
        if hitung[nama[kid]] > 1:
            pakai[nama[kid]] = pakai.get(nama[kid], 0) + 1
            nama[kid] = f"{nama[kid]} ({pakai[nama[kid]]})"
    return nama


def _deskripsi(p: pd.Series, ukuran: int, total: int, aliran: str) -> str:
    level = max(("mapan", "menengah", "pemula"), key=lambda l: p[f"porsi_beli_seniman_{l}"])
    tren = "cenderung membeli seniman yang sedang ramai" if p["rata2_persentil_tren_saat_beli"] >= 0.70 else (
        "cenderung membeli seniman yang tidak sedang ramai" if p["rata2_persentil_tren_saat_beli"] <= 0.45 else "tidak terlalu mengikuti tren")
    return (f"{ukuran} kolektor ({100 * ukuran / total:.0f}%). Median {p['n_pembelian']:.0f} pembelian, harga rata-rata sekitar "
            f"Rp{_juta(p['harga_rata2_idr'])} jt, {p['frekuensi_beli_per_bulan']:.2f} pembelian/bulan; {tren}; paling sering "
            f"membeli dari seniman {level}. Aliran terbanyak: {aliran}.")


# ---------------------------------------------------------------------------- latih
def latih(df: pd.DataFrame, seed: int = SEED, konfigurasi: dict | None = None, tabel_grid: pd.DataFrame | None = None,
          t_data: str | None = None) -> dict:
    """Latih UMAP + HDBSCAN dan bungkus jadi dict (mudah di-joblib).

    ``df`` = fitur klaster per kolektor (kolom sama dgn ``clustering_kolektor.csv``). ``konfigurasi=None`` -> dipilih
    lewat ``cari_konfigurasi`` + ``pilih_konfigurasi``. ``t_data`` = catatan waktu snapshot data (utk laporan)."""
    if "n_pembelian" in df.columns:        # hanya kolektor dgn riwayat cukup yang dipakai melatih (sama dgn aturan penetapan)
        df = df[df["n_pembelian"] >= MIN_PEMBELIAN_SEGMEN].reset_index(drop=True)
    scaler = StandardScaler().fit(matriks(df))
    z = scaler.transform(matriks(df))
    if konfigurasi is None:
        tabel_grid = tabel_grid if tabel_grid is not None else cari_konfigurasi(z, seed)
        konfigurasi = pilih_konfigurasi(tabel_grid)
    nn, mcs = konfigurasi["n_neighbors"], konfigurasi["min_cluster_size"]
    um, hd, emb = _fit_umap_hdbscan(z, nn, mcs, seed)
    lab_mentah = hd.labels_
    pusat = _pusat(emb, lab_mentah)
    lab = _isi_noise(emb, lab_mentah, pusat)

    d = df.copy()
    d["_raw"] = lab
    profil = d.groupby("_raw")[KOLOM_PROFIL].median()
    populasi = df[KOLOM_PROFIL].median()
    nama = beri_nama(profil, populasi)
    urut = profil["harga_rata2_idr"].sort_values(ascending=False).index.tolist()
    peta = {int(raw): i + 1 for i, raw in enumerate(urut)}            # id 1 = harga rata-rata tertinggi
    porsi = kolom_porsi_aliran(df)
    segmen = {}
    for raw in urut:
        sid = peta[int(raw)]
        sub = d[d["_raw"] == raw]
        aliran = sub[porsi].mean().idxmax().replace("porsi_gaya_", "") if porsi else "-"
        segmen[sid] = {"nama": nama[raw], "deskripsi": _deskripsi(profil.loc[raw], len(sub), len(df), aliran),
                       "ukuran": int(len(sub)), "aliran_favorit": aliran,
                       "profil": {c: float(profil.loc[raw, c]) for c in KOLOM_PROFIL}}
    bundle = {
        "versi": VERSI, "algoritma": ALGORITMA, "dilatih_pada": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "t_data": t_data, "n_latih": int(len(df)), "seed": int(seed), "konfigurasi": konfigurasi,
        "fitur": list(KOLOM_FITUR), "kolom_log": list(KOLOM_LOG),
        "scaler": scaler, "umap": um, "hdbscan": hd, "pusat_embedding": pusat, "peta_label": peta, "segmen": segmen,
        "noise_latih_pct": float(100 * (lab_mentah < 0).mean()),
        "populasi_median": {c: float(populasi[c]) for c in KOLOM_PROFIL},
        "grid": None if tabel_grid is None else tabel_grid.to_dict("records"),
    }
    # kesesuaian label latih dgn penugasan out-of-sample (tetapkan) -- harus ~1
    ass = tetapkan(bundle, df)
    sid_latih = np.array([peta[int(r)] for r in lab])
    bundle["kesesuaian_latih"] = float((ass["segmen_id"].to_numpy() == sid_latih).mean())
    return bundle


def tetapkan(bundle: dict, df: pd.DataFrame) -> pd.DataFrame:
    """Tetapkan segmen utk kolektor di ``df`` (kolom sama dgn ``clustering_kolektor.csv``).
    Kolektor dgn ``n_pembelian < MIN_PEMBELIAN_SEGMEN`` -> ``segmen_id = 0`` & nama ``NAMA_BELUM_ADA``.
    Kolom ``kepastian`` (0-1) = kekuatan keanggotaan HDBSCAN; 0 utk titik noise yang ditetapkan ke klaster terdekat."""
    hilang = [c for c in bundle["fitur"] if c not in df.columns]
    if hilang:
        raise ValueError(f"kolom fitur hilang: {hilang}")
    _, hdbscan = _impor()
    z = bundle["scaler"].transform(matriks(df, bundle["fitur"], bundle["kolom_log"]))
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        emb = bundle["umap"].transform(z)
        lab, kuat = hdbscan.approximate_predict(bundle["hdbscan"], emb)
    lab = np.asarray(lab).copy()
    kuat = np.asarray(kuat, dtype=float).copy()
    bad = lab < 0
    if bad.any():
        lab[bad] = _isi_noise(emb, lab, bundle["pusat_embedding"])[bad]
        kuat[bad] = 0.0
    sid = np.array([bundle["peta_label"][int(r)] for r in lab])
    if "n_pembelian" in df.columns:
        kurang = df["n_pembelian"].to_numpy() < MIN_PEMBELIAN_SEGMEN
        sid = np.where(kurang, 0, sid)
        kuat = np.where(kurang, 0.0, kuat)
    nama = [NAMA_BELUM_ADA if s == 0 else bundle["segmen"][int(s)]["nama"] for s in sid]
    return pd.DataFrame({"kolektor_id": df["kolektor_id"].astype(str).to_numpy() if "kolektor_id" in df.columns else np.arange(len(df)).astype(str),
                         "segmen_id": sid, "segmen_nama": nama, "kepastian": np.round(kuat, 4)})


# -------------------------------------------------------------------------- evaluasi
def tafsir_silhouette(x: float) -> str:
    """Skala Kaufman & Rousseeuw (1990)."""
    if x > 0.70:
        return "struktur klaster kuat"
    if x > 0.50:
        return "struktur klaster wajar"
    if x > 0.25:
        return "struktur klaster lemah"
    return "tidak ada struktur klaster yang berarti"


def evaluasi_model(bundle: dict, df: pd.DataFrame, label: pd.DataFrame | None = None) -> dict:
    """Skor evaluasi model akhir pada ``df``. Silhouette dihitung di ruang FITUR ASLI terstandarisasi (bukan ruang UMAP).
    Metrik eksternal (butuh ``kolektor_label_asli``) hanya bila ``label`` diberikan -- hanya utk VALIDASI."""
    z = bundle["scaler"].transform(matriks(df, bundle["fitur"], bundle["kolom_log"]))
    ass = tetapkan(bundle, df)
    sid = ass["segmen_id"].to_numpy()
    ada = sid > 0
    ss = silhouette_samples(z[ada], sid[ada])
    hasil = {
        "n": int(len(df)), "n_dinilai": int(ada.sum()), "k": int(len(set(sid[ada]))), "n_fitur": len(bundle["fitur"]),
        "silhouette": float(ss.mean()), "tafsir_silhouette": tafsir_silhouette(float(ss.mean())),
        "pct_silhouette_negatif": float((ss < 0).mean() * 100),
        "calinski_harabasz": float(calinski_harabasz_score(z[ada], sid[ada])),
        "davies_bouldin": float(davies_bouldin_score(z[ada], sid[ada])),
        "noise_latih_pct": bundle["noise_latih_pct"], "kesesuaian_latih": bundle.get("kesesuaian_latih"),
        "kepastian_median": float(np.median(ass.loc[ada, "kepastian"])), "pct_kepastian_nol": float((ass.loc[ada, "kepastian"] == 0).mean() * 100),
        "per_segmen": {int(k): {"nama": bundle["segmen"][int(k)]["nama"], "n": int((sid == k).sum()),
                                "silhouette": float(ss[sid[ada] == k].mean()), "pct_negatif": float((ss[sid[ada] == k] < 0).mean() * 100)}
                       for k in sorted(set(sid[ada]))},
        "sampel_silhouette": ss, "segmen_sampel": sid[ada],
    }
    if label is not None:
        peta_lab = dict(zip(label["kolektor_id"].astype(str), label["segmen_asli"]))
        y = np.array([peta_lab[k] for k in ass["kolektor_id"]])
        ya, sa = y[ada], sid[ada]
        tab = pd.crosstab(sa, ya)
        hasil["eksternal"] = {
            "ari": float(adjusted_rand_score(ya, sa)),
            "nmi": float(normalized_mutual_info_score(ya, sa)),
            "homogenitas": float(homogeneity_score(ya, sa)),
            "kelengkapan": float(completeness_score(ya, sa)),
            "v_measure": float(v_measure_score(ya, sa)),
            "purity": float(tab.max(axis=1).sum() / tab.values.sum()),
            "silhouette_label_asli": float(silhouette_score(z[ada], ya)),   # plafon: jawaban benar generator di ruang fitur yang sama
            "tabel_silang": tab,
        }
    return hasil
