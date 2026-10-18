"""Latih clustering kolektor (UMAP + HDBSCAN) -> dua artefak + ``models/LAPORAN_CLUSTERING.md``.

URUTAN KERJA PROYEK: **clustering dulu, lalu klasifikasi**. Skrip ini menghasilkan DUA model dari kode yang sama:

* ``models/clustering_kolektor.joblib``         MODEL FINAL: dilatih pada seluruh periode data. Dipakai utk mengisi tabel
  ``kolektor_segmen`` / ``segmen_kamus`` (dashboard seniman, label di rekomendasi). Laporan di bawah menilai model ini.
* ``models/clustering_kolektor_cutoff.joblib``  MODEL CUTOFF: dilatih HANYA pada data sampai batas train klasifikasi
  (``features.batas_split``). Dipakai utk membuat fitur ``kolektor_segmen`` di dataset klasifikasi tanpa mengintip val/test.

Seluruh angka di laporan DIHITUNG di sini (bukan diketik tangan). Deterministik (seed 42).

    python scripts/latih_clustering.py          # data dari data/export/*.csv
Dipanggil juga oleh ``jalankan_pipeline.py`` (data dari memori/Neon, via ``jalankan(tabel)``).
"""

from __future__ import annotations

import argparse
import sys
import warnings
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.cluster import AgglomerativeClustering, KMeans, SpectralClustering
from sklearn.metrics import adjusted_rand_score, silhouette_score
from sklearn.mixture import GaussianMixture
from sklearn.preprocessing import StandardScaler

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
from src import clustering as C  # noqa: E402
from src.features import _Konteks, batas_split, bangun_clustering  # noqa: E402

EXPORT = ROOT / "data" / "export"
TRAINING = ROOT / "data" / "training"
ARTEFAK = ROOT / "models" / "clustering_kolektor.joblib"
ARTEFAK_CUTOFF = ROOT / "models" / "clustering_kolektor_cutoff.joblib"
LAPORAN = ROOT / "models" / "LAPORAN_CLUSTERING.md"


def md_tabel(df: pd.DataFrame, fmt: dict | None = None) -> str:
    fmt = fmt or {}
    kolom = list(df.columns)
    baris = ["| " + " | ".join(str(c) for c in kolom) + " |", "|" + "|".join("---" for _ in kolom) + "|"]
    for _, r in df.iterrows():
        sel = [(fmt[c](r[c]) if c in fmt else (f"{r[c]:.3f}" if isinstance(r[c], float) else str(r[c]))) for c in kolom]
        baris.append("| " + " | ".join(sel) + " |")
    return "\n".join(baris)


def _baca_tabel() -> dict:
    t = {n: pd.read_csv(EXPORT / f"{n}.csv") for n in ("seniman", "kolektor", "karya", "transaksi")}
    return t


def bandingkan_algoritma(z: np.ndarray, y: np.ndarray) -> pd.DataFrame:
    """Bandingkan algoritma pada fitur yang SAMA. Silhouette di ruang fitur asli (noise ditetapkan ke klaster terdekat
    di ruang fitur utk algoritma yang punya noise). Label asli hanya utk kolom ARI (validasi)."""
    import hdbscan
    baris = []

    def catat(nama, lab, oos, catatan):
        lab = np.asarray(lab)
        m = lab >= 0
        pusat = {int(k): z[lab == k].mean(0) for k in set(lab[m])}
        if (~m).any() and pusat:
            ks = np.array(list(pusat))
            mat = np.stack([pusat[int(k)] for k in ks])
            lab = lab.copy()
            lab[~m] = ks[np.linalg.norm(z[~m][:, None] - mat[None], axis=-1).argmin(1)]
        k = len(set(lab))
        baris.append({"algoritma": nama, "K": k, "noise": f"{100 * (~m).mean():.0f}%",
                      "silhouette": float(silhouette_score(z, lab)) if k > 1 else float("nan"),
                      "ARI vs label asli*": float(adjusted_rand_score(y, lab)), "bisa menetapkan kolektor baru": oos, "catatan": catatan})

    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        catat("K-Means K=5 (acuan v1, tidak dipilih)", KMeans(5, n_init=30, random_state=0).fit_predict(z), "ya", "K harus ditebak; klaster berbentuk bola")
        catat("Gaussian Mixture K=5", GaussianMixture(5, covariance_type="full", n_init=10, random_state=0).fit(z).predict(z), "ya", "K harus ditebak")
        catat("Agglomerative (Ward) K=5", AgglomerativeClustering(5).fit_predict(z), "tidak", "tak punya fungsi predict")
        catat("Spectral K=5", SpectralClustering(5, affinity="nearest_neighbors", n_neighbors=12, random_state=0).fit_predict(z), "tidak", "tak punya fungsi predict")
        catat("HDBSCAN (fitur asli)", hdbscan.HDBSCAN(min_cluster_size=10, min_samples=C.MIN_SAMPLES).fit_predict(z), "ya (approximate_predict)", "tanpa reduksi dimensi")
    return pd.DataFrame(baris)


def latih_dua_model(tabel: dict, seed: int = C.SEED):
    """Kembalikan (bundle_final, df_final, bundle_cutoff, df_cutoff, t_cutoff_hari)."""
    cx = _Konteks(tabel["seniman"], tabel["kolektor"], tabel["karya"], tabel["transaksi"])
    df_final = bangun_clustering(None, None, None, None, cx=cx)
    b1, _ = batas_split(cx)
    df_cut = bangun_clustering(None, None, None, None, t_asof=b1, cx=cx)
    b_final = C.latih(df_final, seed=seed, t_data="seluruh periode")
    b_cut = C.latih(df_cut, seed=seed, t_data=f"sampai batas train (hari ke-{b1:.0f})")
    return b_final, df_final, b_cut, df_cut, b1


def jalankan(tabel: dict, label: pd.DataFrame, tulis: bool = True, n_boot: int = 30) -> dict:
    b_final, df, b_cut, df_cut, b1 = latih_dua_model(tabel)
    print(f"[final]  {b_final['n_latih']} kolektor | konfigurasi {b_final['konfigurasi']} | noise latih {b_final['noise_latih_pct']:.1f}% | "
          f"kesesuaian latih vs out-of-sample {b_final['kesesuaian_latih']:.3f}")
    print(f"[cutoff] {b_cut['n_latih']} kolektor (data sampai hari {b1:.0f}) | konfigurasi {b_cut['konfigurasi']} | noise {b_cut['noise_latih_pct']:.1f}%")

    ev = C.evaluasi_model(b_final, df, label)
    ev_cut = C.evaluasi_model(b_cut, df_cut, label)
    ex = ev["eksternal"]
    z = b_final["scaler"].transform(C.matriks(df))
    y = np.array([dict(zip(label["kolektor_id"].astype(str), label["segmen_asli"]))[k] for k in df["kolektor_id"].astype(str)])
    nn, mcs = b_final["konfigurasi"]["n_neighbors"], b_final["konfigurasi"]["min_cluster_size"]
    stab, stab_sd = C.stabilitas_bootstrap(z, nn, mcs, n=n_boot)
    algo = bandingkan_algoritma(z, y)
    # eksperimen fitur: apa yang terjadi bila keterpusatan selera ikut jadi fitur? (transparansi, BUKAN dasar memilih)
    fit_selera = C.KOLOM_FITUR + ["porsi_gaya_teratas"]
    zs = StandardScaler().fit_transform(C.matriks(df, fit_selera, C.KOLOM_LOG))
    _, hs, es = C._fit_umap_hdbscan(zs, nn, mcs)
    ls = C._isi_noise(es, hs.labels_, C._pusat(es, hs.labels_))
    sil_selera = float(silhouette_score(zs, ls)) if len(set(ls)) > 1 else float("nan")

    nama_final = sorted(s["nama"] for s in b_final["segmen"].values())
    nama_cut = sorted(s["nama"] for s in b_cut["segmen"].values())
    print(f"[evaluasi final] silhouette {ev['silhouette']:.3f} ({ev['tafsir_silhouette']}) | ARI {ex['ari']:.3f} | stabilitas {stab:.2f}±{stab_sd:.2f} | "
          f"plafon label asli {ex['silhouette_label_asli']:.3f}")
    print(f"[cutoff] silhouette {ev_cut['silhouette']:.3f} | nama segmen sama dgn final: {nama_final == nama_cut}")
    for sid, s in sorted(b_final["segmen"].items()):
        print(f"  {sid}. {s['nama']:32s} n={s['ukuran']:3d} | {s['deskripsi'][:100]}")

    hasil = {"final": b_final, "cutoff": b_cut, "df_final": df, "df_cutoff": df_cut, "ev": ev, "ev_cut": ev_cut, "stab": (stab, stab_sd), "algo": algo}
    if tulis:
        ARTEFAK.parent.mkdir(parents=True, exist_ok=True)
        joblib.dump(b_final, ARTEFAK)
        joblib.dump(b_cut, ARTEFAK_CUTOFF)
        ulang = C.tetapkan(joblib.load(ARTEFAK), df)
        assert (ulang["segmen_id"].to_numpy() == C.tetapkan(b_final, df)["segmen_id"].to_numpy()).all(), "artefak tidak konsisten setelah dimuat ulang"
        print(f"artefak: {ARTEFAK.name} ({ARTEFAK.stat().st_size / 1e6:.1f} MB), {ARTEFAK_CUTOFF.name} ({ARTEFAK_CUTOFF.stat().st_size / 1e6:.1f} MB)")
        _tulis_laporan(b_final, b_cut, df, df_cut, ev, ev_cut, stab, stab_sd, algo, sil_selera, nama_final == nama_cut, b1)
    return hasil


def _tulis_laporan(b, bc, df, df_cut, ev, ev_cut, stab, stab_sd, algo, sil_selera, nama_sama, b1) -> None:
    ex = ev["eksternal"]
    kfg = b["konfigurasi"]
    grid = pd.DataFrame(b["grid"]).rename(columns={"n_neighbors": "n_neighbors UMAP", "min_cluster_size": "min_cluster_size HDBSCAN", "noise_pct": "noise (%)"})
    grid["terpilih"] = np.where((grid["n_neighbors UMAP"] == kfg["n_neighbors"]) & (grid["min_cluster_size HDBSCAN"] == kfg["min_cluster_size"]), "<--", "")
    prof = pd.DataFrame([{"id": sid, "nama": s["nama"], "ukuran": s["ukuran"], "pembelian (median)": s["profil"]["n_pembelian"],
                          "harga rata-rata": f"Rp{C._juta(s['profil']['harga_rata2_idr'])} jt", "beli/bulan": s["profil"]["frekuensi_beli_per_bulan"],
                          "persentil tren": s["profil"]["rata2_persentil_tren_saat_beli"], "dari seniman mapan": s["profil"]["porsi_beli_seniman_mapan"],
                          "dari seniman pemula": s["profil"]["porsi_beli_seniman_pemula"], "aliran terbanyak": s["aliran_favorit"]}
                         for sid, s in sorted(b["segmen"].items())])
    cross = ex["tabel_silang"].copy()
    cross.index = [f"{s}. {b['segmen'][int(s)]['nama']}" for s in cross.index]
    t_skor = pd.DataFrame([
        ("Silhouette (ruang fitur asli, rata-rata)", f"{ev['silhouette']:.3f}", ev["tafsir_silhouette"]),
        ("Sampel dgn silhouette negatif", f"{ev['pct_silhouette_negatif']:.1f}%", "negatif = kemungkinan salah klaster"),
        ("Davies-Bouldin (makin rendah makin baik)", f"{ev['davies_bouldin']:.3f}", "pedoman kasar: <1 baik"),
        ("Calinski-Harabasz", f"{ev['calinski_harabasz']:.1f}", "tak punya skala absolut"),
        ("Stabilitas bootstrap (ARI, 80% subsampel)", f"{stab:.3f} ± {stab_sd:.3f}", f"ambang baik >= {C.STABIL_BAIK:.2f}"),
        ("Noise HDBSCAN saat pelatihan", f"{ev['noise_latih_pct']:.1f}%", "titik noise ditetapkan ke klaster terdekat"),
        ("Kesesuaian label latih vs penugasan out-of-sample", f"{ev['kesesuaian_latih']:.3f}", "1 = identik"),
        ("Kepastian keanggotaan (median)", f"{ev['kepastian_median']:.2f}", f"{ev['pct_kepastian_nol']:.0f}% bernilai 0 (noise)"),
        ("ARI vs label asli*", f"{ex['ari']:.3f}", "0 = acak, 1 = identik"),
        ("NMI*", f"{ex['nmi']:.3f}", ""),
        ("Homogenitas*", f"{ex['homogenitas']:.3f}", ""),
        ("Kelengkapan*", f"{ex['kelengkapan']:.3f}", ""),
        ("V-measure*", f"{ex['v_measure']:.3f}", ""),
        ("Purity*", f"{ex['purity']:.3f}", ""),
        ("Silhouette label asli generator* (plafon)", f"{ex['silhouette_label_asli']:.3f}", "silhouette bila jawaban benar dipakai"),
    ], columns=["metrik", "skor", "catatan"])
    t_seg = pd.DataFrame([{"segmen": f"{k}. {v['nama']}", "ukuran": v["n"], "silhouette": f"{v['silhouette']:.3f}", "% sampel negatif": f"{v['pct_negatif']:.0f}%"}
                          for k, v in ev["per_segmen"].items()])
    algo_t = algo.copy()
    algo_t = pd.concat([algo_t, pd.DataFrame([{"algoritma": "**UMAP + HDBSCAN (dipakai)**", "K": ev["k"], "noise": f"{ev['noise_latih_pct']:.0f}%",
                                              "silhouette": ev["silhouette"], "ARI vs label asli*": ex["ari"],
                                              "bisa menetapkan kolektor baru": "ya (transform + approximate_predict)", "catatan": "K ditemukan sendiri; model dilatih satu kali"}])], ignore_index=True)

    md = f"""# Laporan Clustering Kolektor — `{C.VERSI}` ({C.ALGORITMA})

> **DATA SINTETIS YANG DIRANCANG TERPISAH.** Skor di sini mencerminkan struktur yang kita tanam di `src/generate.py` (generator-v2 membuat
> lima arketipe kolektor yang berbeda tegas, atas arahan dosen "sesuaikan data dengan algoritma"). Ini **bukan** bukti bahwa pembeli lukisan nyata
> terbagi serapi ini; pada data nyata silhouette akan lebih rendah. Dibuat otomatis oleh `scripts/latih_clustering.py` (seed {C.SEED}).

## Ringkasan
* **Algoritma: {C.ALGORITMA}** (menggantikan K-Means v1). Jumlah segmen **ditemukan** otomatis: **K = {ev['k']}**. {df.shape[0]} kolektor, {len(b['fitur'])} fitur perilaku.
* **Silhouette = {ev['silhouette']:.3f}** ({ev['tafsir_silhouette']}; skala Kaufman–Rousseeuw: > 0,50 wajar, > 0,70 kuat), dihitung di **ruang fitur asli**, bukan ruang UMAP.
  Pembanding v1 (K-Means, data lama): 0,18.
* Stabilitas bootstrap **{stab:.2f}**, noise **{ev['noise_latih_pct']:.1f}%**, ARI terhadap label asli **{ex['ari']:.3f}** (validasi setelah model final).
* Silhouette label asli generator (plafon) = **{ex['silhouette_label_asli']:.3f}**: batas atas skor bergantung pada seberapa rapat data itu sendiri, bukan pada algoritma.

## 1. Mengapa bukan K-Means, dan perbandingan algoritma
K-Means (1957) memaksa jumlah klaster ditebak di awal dan mengasumsikan klaster berbentuk bola berukuran serupa. Dipilih **UMAP + HDBSCAN** karena: (a) K ditemukan dari kepadatan data,
(b) bentuk klaster bebas dan outlier ditandai noise, (c) kolektor baru bisa ditetapkan tanpa melatih ulang (`umap.transform` + `hdbscan.approximate_predict`).

Perbandingan pada fitur yang sama (silhouette di ruang fitur asli):

{md_tabel(algo_t, {"K": str})}

\\* ARI vs label asli = hanya validasi. Aturan seleksi (ditetapkan sebelum melihat hasil): bukan K-Means · bisa menetapkan kolektor baru · noise ≤ 10% · silhouette tertinggi di ruang fitur asli.
**Catatan jujur:** pada data ini beberapa algoritma lain (mis. Spectral, GMM) juga menemukan struktur yang sama; selisih antar-algoritma kecil dibanding pengaruh data. Silhouette
UMAP+HDBSCAN **tidak** dibesar-besarkan dengan menghitungnya di ruang UMAP (skor di sana hampir selalu menggelembung).

## 2. Fitur dan transformasi
Lima fitur perilaku yang bersih: `harga_rata2_idr` (log1p), `frekuensi_beli_per_bulan` (log1p), `rata2_persentil_tren_saat_beli`, `porsi_beli_seniman_mapan`, `porsi_beli_seniman_pemula`; lalu `StandardScaler`.
**Keterpusatan selera aliran sengaja tidak dipakai memisahkan klaster:** dengan {df['n_pembelian'].median():.0f} pembelian per kolektor (median) nilainya hanya bisa 0,33/0,5/1,0 sehingga berisik.
Bukti pada data ini: menambahkan `porsi_gaya_teratas` menurunkan silhouette menjadi **{sil_selera:.3f}** (dari {ev['silhouette']:.3f}). Kolom `porsi_gaya_*` tetap dipakai utk profil segmen (aliran terbanyak) dan utk model klasifikasi.
Kolektor dengan < {C.MIN_PEMBELIAN_SEGMEN} pembelian diberi segmen "{C.NAMA_BELUM_ADA}" (tidak dipaksa masuk klaster).

## 3. Pemilihan hiperparameter
Aturan (sebelum melihat label asli): noise ≤ {100 * C.NOISE_MAKS:.0f}% dan {C.K_MIN} ≤ K ≤ {C.K_MAKS} → silhouette tertinggi; seri → noise lebih sedikit → `min_cluster_size` lebih besar.

{md_tabel(grid, {"n_neighbors UMAP": str, "min_cluster_size HDBSCAN": str, "k": str, "noise (%)": lambda v: f"{v:.1f}"})}

## 4. Profil segmen
{md_tabel(prof, {"id": str, "ukuran": str, "pembelian (median)": lambda v: f"{v:.0f}", "beli/bulan": lambda v: f"{v:.2f}", "persentil tren": lambda v: f"{v:.2f}", "dari seniman mapan": lambda v: f"{v:.2f}", "dari seniman pemula": lambda v: f"{v:.2f}"})}

Nama diturunkan dari karakteristik centroid dengan aturan di `src/clustering.py: beri_nama`, **bukan** dari label generator.

{chr(10).join(f"**{sid}. {s['nama']}** — {s['deskripsi']}" + chr(10) for sid, s in sorted(b['segmen'].items()))}
## 5. Validasi terhadap label asli (hanya setelah model final)
ARI = **{ex['ari']:.3f}**, NMI = **{ex['nmi']:.3f}**. Tabel silang (baris = segmen hasil, kolom = segmen asli generator):

{md_tabel(cross.reset_index().rename(columns={"index": "segmen hasil clustering"}), {c: str for c in cross.columns})}

## 6. Skor evaluasi lengkap (model final)
{md_tabel(t_skor)}

\\* eksternal = hanya validasi terhadap label generator; tidak dipakai memilih fitur/hiperparameter.

Silhouette per segmen (nilai terendah = batas paling kabur):

{md_tabel(t_seg)}

## 7. Model "cutoff" untuk klasifikasi (tanpa kebocoran)
Fitur `kolektor_segmen` di dataset klasifikasi harus dihitung dengan model yang **tidak pernah melihat val/test**. Karena itu dilatih model kedua dengan pipeline dan aturan seleksi yang sama,
hanya pada pembelian sebelum batas train (hari ke-{b1:.0f}): {bc['n_latih']} kolektor, konfigurasi {bc['konfigurasi']['n_neighbors']}/{bc['konfigurasi']['min_cluster_size']}, silhouette {ev_cut['silhouette']:.3f},
segmen yang ditemukan: {', '.join(f"{s['nama']} ({s['ukuran']})" for _, s in sorted(bc['segmen'].items()))}
({'sama dengan model final' if nama_sama else 'BERBEDA dari model final: riwayat tren seniman di periode awal masih tipis sehingga beberapa arketipe belum terpisah; nilai kategori `kolektor_segmen` mengikuti model ini'}). Model final (di atas) dipakai utk dashboard dan tabel `kolektor_segmen`; **jangan** dipakai sebagai fitur klasifikasi.

## 8. Keterbatasan (jujur)
* **Data sintetis yang dirancang terpisah.** Silhouette tinggi di sini = hasil desain generator (arketipe berbeda tegas, tiap kolektor ≥ {3} pembelian), bukan temuan tentang perilaku nyata.
  Di data nyata, perilaku saling tumpang tindih dan skor akan jauh lebih rendah.
* Hanya {len(df)} kolektor dan median {df['n_pembelian'].median():.0f} pembelian per kolektor; fitur berbasis hitungan kecil tetap berisik.
* **Fitur dipilih berdasarkan kebersihan sinyal** (lihat bagian 2) setelah percobaan pada data ini; ini disclosure, bukan klaim bahwa fitur lain "salah".
* Nama & deskripsi segmen adalah **ringkasan statistik**, bukan kategori pasti. Jangan menampilkannya di UI sebagai fakta tentang orang tertentu.
* Melatih ulang pada data lain dapat mengubah jumlah, nama, dan isi segmen; naikkan `VERSI` dan jalankan ulang `scripts/hitung_segmen.py`.
* Model memuat objek UMAP/HDBSCAN: butuh `umap-learn` dan `hdbscan` terpasang utk memuatnya. Backend tidak memuatnya (hanya membaca tabel).
"""
    LAPORAN.write_text(md, encoding="utf-8")
    print(f"laporan -> {LAPORAN.relative_to(ROOT)}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--n-boot", type=int, default=30)
    a = ap.parse_args()
    jalankan(_baca_tabel(), pd.read_csv(TRAINING / "kolektor_label_asli.csv"), n_boot=a.n_boot)
