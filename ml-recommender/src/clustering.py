"""Clustering kolektor -- segmentasi perilaku belanja (bagian Thoriq).

Dipakai bersama oleh ``notebooks/02_clustering.ipynb``, ``scripts/latih_clustering.py`` dan
``scripts/hitung_segmen.py`` supaya logikanya tidak ganda.

KEPUTUSAN METODOLOGI (dan alasannya)
------------------------------------
1. **Fitur = perilaku belanja, BUKAN selera aliran.** 11 kolom ``porsi_gaya_<aliran>`` dikeluarkan dari
   fitur klaster: dengan kolom itu klaster terbentuk menurut "penggemar Impresionisme/Realisme", bukan
   menurut perilaku (anggaran, frekuensi, kepatuhan pada satu aliran, minat pada seniman besar/tren).
   Terbukti lebih buruk di semua kriteria tanpa label: pada K=5 silhouette 0,124 vs 0,182 dan stabilitas
   bootstrap 0,57 vs 0,72. Kolom itu tetap dipakai utk MEMBERI PROFIL tiap segmen (aliran favorit).
2. **Transformasi:** ``log1p`` pada semua kolom ``*_idr`` dan kolom bersifat hitungan/durasi, lalu
   ``StandardScaler``. ``RobustScaler`` TIDAK dipakai: memperbesar outlier harga -> klaster kecil berisi outlier.
3. **Pemilihan K ditentukan SEBELUM melihat label asli:** di antara K yang stabil (ARI bootstrap >= 0,70),
   pilih yang BIC GMM-nya terendah. Label asli generator (``kolektor_label_asli``) hanya untuk validasi
   setelah K final, tidak pernah ikut memilih apa pun.
4. **Nama segmen berasal dari karakteristik centroid** (tingkat harga, frekuensi, keterpusatan selera),
   bukan dari label generator -- di dunia nyata label itu tidak ada.
5. Model akhir = K-Means (centroid mudah dijelaskan, penugasan deterministik utk kolektor baru).

Artefak ``models/clustering_kolektor.joblib`` hanya berisi tipe bawaan Python + objek scikit-learn, jadi
bisa dimuat tanpa mengimpor modul ini.
"""

from __future__ import annotations

from datetime import datetime, timezone

import numpy as np
import pandas as pd
from sklearn.cluster import KMeans
from sklearn.metrics import (adjusted_rand_score, calinski_harabasz_score, completeness_score, davies_bouldin_score,
                             homogeneity_score, normalized_mutual_info_score, silhouette_samples, silhouette_score, v_measure_score)
from sklearn.mixture import GaussianMixture
from sklearn.preprocessing import StandardScaler

VERSI = "clustering-v1"
SEED = 42
STABIL_MIN = 0.70
KOLOM_HITUNGAN = ["n_pembelian", "frekuensi_beli_per_bulan", "hari_sejak_beli_terakhir", "hari_sejak_bergabung"]
KOLOM_PROFIL = ["n_pembelian", "harga_rata2_idr", "harga_std_log", "frekuensi_beli_per_bulan", "porsi_gaya_teratas",
                "entropi_gaya_norm", "porsi_beli_seniman_mapan", "porsi_beli_seniman_menengah",
                "porsi_beli_seniman_pemula", "rata2_persentil_tren_saat_beli", "rata2_lonjakan_saat_beli",
                "rata2_diskon_negosiasi"]


# ----------------------------------------------------------------------------- fitur
def kolom_porsi_aliran(df: pd.DataFrame) -> list[str]:
    return [c for c in df.columns if c.startswith("porsi_gaya_") and c != "porsi_gaya_teratas"]


def kolom_fitur(df: pd.DataFrame, termasuk_porsi_aliran: bool = False) -> list[str]:
    porsi = set() if termasuk_porsi_aliran else set(kolom_porsi_aliran(df))
    return [c for c in df.columns if c != "kolektor_id" and c not in porsi]


def kolom_log(fitur: list[str]) -> list[str]:
    return [c for c in fitur if c.endswith("_idr") or c in KOLOM_HITUNGAN]


def matriks(df: pd.DataFrame, fitur: list[str], kol_log: list[str]) -> pd.DataFrame:
    x = df[fitur].astype(float).copy()
    x[kol_log] = np.log1p(x[kol_log])
    return x


# ----------------------------------------------------------------- evaluasi & pilih K
def stabilitas_bootstrap(z: np.ndarray, k: int, n: int = 100, seed: int = SEED) -> tuple[float, float]:
    """(rata-rata, simpangan baku) ARI antara klaster acuan dan klaster dari model yang dilatih ulang pada
    sampel bootstrap. ``n`` besar (100) supaya estimasi tidak berisik di dekat ambang pemilihan K."""
    rng = np.random.default_rng(seed)
    acuan = KMeans(k, n_init=10, random_state=0).fit(z).labels_
    skor = []
    for _ in range(n):
        idx = rng.choice(len(z), len(z), replace=True)
        m = KMeans(k, n_init=10, random_state=int(rng.integers(1_000_000))).fit(z[idx])
        skor.append(adjusted_rand_score(acuan, m.predict(z)))
    return float(np.mean(skor)), float(np.std(skor))


def evaluasi_k(z: np.ndarray, rentang=range(2, 9), seed: int = SEED, n_boot: int = 100) -> pd.DataFrame:
    baris = []
    for k in rentang:
        km = KMeans(k, n_init=20, random_state=seed).fit(z)
        gm = GaussianMixture(k, n_init=5, random_state=seed, covariance_type="diag").fit(z)
        stab, sd = stabilitas_bootstrap(z, k, n_boot, seed)
        baris.append({
            "k": k,
            "silhouette": silhouette_score(z, km.labels_),
            "calinski_harabasz": calinski_harabasz_score(z, km.labels_),
            "davies_bouldin": davies_bouldin_score(z, km.labels_),
            "stabilitas_bootstrap": stab,
            "stabilitas_sd": sd,
            "bic_gmm": gm.bic(z),
        })
    return pd.DataFrame(baris)


def pilih_k(tabel: pd.DataFrame, stabil_min: float = STABIL_MIN) -> int:
    """Aturan (ditetapkan sebelum melihat label asli): di antara K yang stabil, ambil BIC GMM terendah."""
    layak = tabel[tabel["stabilitas_bootstrap"] >= stabil_min]
    if layak.empty:                      # tak ada yang stabil -> ambil yang paling stabil
        return int(tabel.loc[tabel["stabilitas_bootstrap"].idxmax(), "k"])
    return int(layak.loc[layak["bic_gmm"].idxmin(), "k"])


# ----------------------------------------------------------------------- penamaan
def _juta(x: float) -> str:
    return f"{x / 1e6:,.0f}".replace(",", ".")


def beri_nama(profil: pd.DataFrame, populasi: pd.Series) -> dict[int, str]:
    """Nama segmen dari karakteristik centroid. ``profil``: median fitur per klaster (indeks = id klaster).

    Aturan (deterministik, tanpa label generator, tidak bergantung pada jumlah K):
      tingkat harga = harga rata-rata klaster / median harga rata-rata populasi
          >= 2,5 kali -> Premium;  <= 0,5 kali -> Terjangkau;  selain itu Menengah
      Premium    -> "Kolektor Premium"
      Terjangkau -> frekuensi beli di bawah median populasi: "Pemula Hemat", selain itu "Pemburu Karya Terjangkau"
      Menengah   -> selera terpusat (porsi aliran teratas di atas median populasi): "Spesialis Aliran",
                    selain itu "Kolektor Menengah Aktif"
    Nama kembar diberi nomor supaya tetap unik.
    """
    urut = profil["harga_rata2_idr"].sort_values(ascending=False).index.tolist()
    nama: dict[int, str] = {}
    for kid in urut:
        p = profil.loc[kid]
        rasio = p["harga_rata2_idr"] / populasi["harga_rata2_idr"]
        if rasio >= 2.5:
            n = "Kolektor Premium"
        elif rasio <= 0.5:
            n = "Pemula Hemat" if p["frekuensi_beli_per_bulan"] < populasi["frekuensi_beli_per_bulan"] else "Pemburu Karya Terjangkau"
        else:
            n = "Spesialis Aliran" if p["porsi_gaya_teratas"] > populasi["porsi_gaya_teratas"] else "Kolektor Menengah Aktif"
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
    terpusat = "terpusat pada sedikit aliran" if p["porsi_gaya_teratas"] >= 0.55 else "beragam antar aliran"
    level = max(("mapan", "menengah", "pemula"), key=lambda l: p[f"porsi_beli_seniman_{l}"])
    return (f"{ukuran} kolektor ({100 * ukuran / total:.0f}%). Median {p['n_pembelian']:.0f} pembelian, harga rata-rata sekitar "
            f"Rp{_juta(p['harga_rata2_idr'])} jt, {p['frekuensi_beli_per_bulan']:.2f} pembelian/bulan. Selera {terpusat} "
            f"(aliran terbanyak: {aliran}); paling sering membeli dari seniman {level}.")


# ---------------------------------------------------------------------------- latih
def latih(df: pd.DataFrame, k: int | None = None, seed: int = SEED, tabel_k: pd.DataFrame | None = None) -> dict:
    """Latih K-Means final dan bungkus jadi dict (mudah di-joblib). ``k=None`` -> dipilih lewat ``pilih_k``."""
    fitur = kolom_fitur(df)
    kl = kolom_log(fitur)
    scaler = StandardScaler().fit(matriks(df, fitur, kl))
    z = scaler.transform(matriks(df, fitur, kl))
    if k is None:
        tabel_k = tabel_k if tabel_k is not None else evaluasi_k(z, seed=seed)
        k = pilih_k(tabel_k)
    km = KMeans(k, n_init=50, random_state=seed).fit(z)

    d = df.copy()
    d["_raw"] = km.labels_
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
    return {
        "versi": VERSI, "dilatih_pada": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "k": int(k), "seed": int(seed), "fitur": fitur, "kolom_log": kl,
        "scaler": scaler, "model": km, "peta_label": peta, "segmen": segmen,
        "populasi_median": {c: float(populasi[c]) for c in KOLOM_PROFIL},
        "metrik_k": None if tabel_k is None else tabel_k.to_dict("records"),
    }


def tetapkan(bundle: dict, df: pd.DataFrame) -> pd.DataFrame:
    """Tetapkan segmen utk kolektor di ``df`` (kolom sama dgn ``clustering_kolektor.csv``)."""
    hilang = [c for c in bundle["fitur"] if c not in df.columns]
    if hilang:
        raise ValueError(f"kolom fitur hilang: {hilang}")
    z = bundle["scaler"].transform(matriks(df, bundle["fitur"], bundle["kolom_log"]))
    raw = bundle["model"].predict(z)
    sid = np.array([bundle["peta_label"][int(r)] for r in raw])
    return pd.DataFrame({
        "kolektor_id": df["kolektor_id"].astype(str).to_numpy(),
        "segmen_id": sid,
        "segmen_nama": [bundle["segmen"][int(s)]["nama"] for s in sid],
    })


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
    """Skor evaluasi model akhir. Metrik internal (tanpa label) selalu dihitung; metrik eksternal (butuh
    ``kolektor_label_asli``) hanya bila ``label`` diberikan -- dan hanya utk VALIDASI, bukan seleksi model."""
    z = bundle["scaler"].transform(matriks(df, bundle["fitur"], bundle["kolom_log"]))
    sid = np.array([bundle["peta_label"][int(r)] for r in bundle["model"].predict(z)])
    ss = silhouette_samples(z, sid)
    pusat = bundle["model"].cluster_centers_
    jarak = np.linalg.norm(pusat[:, None] - pusat[None], axis=-1)
    jarak_min = float(jarak[np.triu_indices(len(pusat), 1)].min())
    hasil = {
        "n": int(len(df)), "k": int(bundle["k"]), "n_fitur": len(bundle["fitur"]),
        "silhouette": float(ss.mean()), "tafsir_silhouette": tafsir_silhouette(float(ss.mean())),
        "pct_silhouette_negatif": float((ss < 0).mean() * 100),
        "calinski_harabasz": float(calinski_harabasz_score(z, sid)),
        "davies_bouldin": float(davies_bouldin_score(z, sid)),
        "inertia": float(bundle["model"].inertia_), "jarak_pusat_terdekat": jarak_min,
        "per_segmen": {int(k): {"nama": bundle["segmen"][int(k)]["nama"], "n": int((sid == k).sum()),
                                "silhouette": float(ss[sid == k].mean()), "pct_negatif": float((ss[sid == k] < 0).mean() * 100)}
                       for k in sorted(set(sid))},
        "sampel_silhouette": ss, "segmen_sampel": sid,
    }
    if label is not None:
        m = pd.DataFrame({"kolektor_id": df["kolektor_id"].astype(str).to_numpy(), "seg": sid}).merge(
            label.assign(kolektor_id=label["kolektor_id"].astype(str)), on="kolektor_id")
        tab = pd.crosstab(m["seg"], m["segmen_asli"])
        hasil["eksternal"] = {
            "ari": float(adjusted_rand_score(m["segmen_asli"], m["seg"])),
            "nmi": float(normalized_mutual_info_score(m["segmen_asli"], m["seg"])),
            "homogenitas": float(homogeneity_score(m["segmen_asli"], m["seg"])),
            "kelengkapan": float(completeness_score(m["segmen_asli"], m["seg"])),
            "v_measure": float(v_measure_score(m["segmen_asli"], m["seg"])),
            "purity": float(tab.max(axis=1).sum() / tab.values.sum()),
        }
    return hasil


def diagnosa_silhouette(bundle: dict, df: pd.DataFrame, label: pd.DataFrame, n_ulang: int = 30, seed: int = 0) -> dict:
    """Mengapa silhouette rendah? Bandingkan skor model dengan (a) plafon -- silhouette dari label asli generator
    pada fitur yang sama, (b) baseline tanpa struktur -- data Gaussian berkovarians sama, dan (c) pengaruh jumlah fitur.

    PERINGATAN: butir (c) hanya ILUSTRASI. Memilih fitur/K demi menaikkan silhouette adalah sirkular (seleksi atas
    metrik yang sama yang dilaporkan) dan tidak boleh dipakai sebagai dasar memilih model.
    """
    z = bundle["scaler"].transform(matriks(df, bundle["fitur"], bundle["kolom_log"]))
    yt = df[["kolektor_id"]].astype(str).merge(label.assign(kolektor_id=label["kolektor_id"].astype(str)), on="kolektor_id")["segmen_asli"].to_numpy()
    k = int(bundle["k"])
    km = lambda x, kk: KMeans(kk, n_init=50, random_state=SEED).fit(x).labels_
    rng = np.random.default_rng(seed)
    cov = np.cov(z.T)
    null = []
    for _ in range(n_ulang):
        g = rng.multivariate_normal(np.zeros(z.shape[1]), cov, size=len(z))
        null.append(silhouette_score(g, KMeans(k, n_init=10, random_state=0).fit(g).labels_))
    kuat = [c for c in ("harga_rata2_idr", "frekuensi_beli_per_bulan", "porsi_beli_seniman_mapan", "porsi_beli_seniman_pemula") if c in bundle["fitur"]]
    idx = [bundle["fitur"].index(c) for c in kuat]
    return {
        "label_asli": float(silhouette_score(z, yt)),
        "model": float(silhouette_score(z, km(z, k))),
        "baseline_tanpa_struktur": float(np.mean(null)), "baseline_sd": float(np.std(null)),
        "k2": float(silhouette_score(z, km(z, 2))), "k3": float(silhouette_score(z, km(z, 3))),
        "fitur_kuat": kuat, "model_fitur_kuat": float(silhouette_score(z[:, idx], km(z[:, idx], k))),
        "label_asli_fitur_kuat": float(silhouette_score(z[:, idx], yt)),
        "n_fitur": len(bundle["fitur"]),
        "pembelian_median": float(df["n_pembelian"].median()),
        "n_kolektor_le3": int((df["n_pembelian"] <= 3).sum()), "n": int(len(df)),
    }
