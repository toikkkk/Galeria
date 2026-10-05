"""Latih clustering kolektor -> ``models/clustering_kolektor.joblib`` + ``models/LAPORAN_CLUSTERING.md``.

Seluruh angka di laporan DIHITUNG di sini (bukan diketik tangan), jadi laporan selalu cocok dengan artefak.
Deterministik (seed 42): dijalankan ulang pada CSV yang sama menghasilkan segmen yang sama.

    python scripts/latih_clustering.py            # K dipilih otomatis (aturan di src/clustering.py)
    python scripts/latih_clustering.py --k 4      # paksa K tertentu (utk eksperimen; catat di laporan)
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.metrics import adjusted_rand_score, normalized_mutual_info_score

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
from src import clustering as C  # noqa: E402

CSV = ROOT / "data" / "training" / "clustering_kolektor.csv"
LABEL = ROOT / "data" / "training" / "kolektor_label_asli.csv"
ARTEFAK = ROOT / "models" / "clustering_kolektor.joblib"
LAPORAN = ROOT / "models" / "LAPORAN_CLUSTERING.md"


def md_tabel(df: pd.DataFrame, fmt: dict | None = None) -> str:
    fmt = fmt or {}
    kolom = list(df.columns)
    baris = ["| " + " | ".join(str(c) for c in kolom) + " |", "|" + "|".join("---" for _ in kolom) + "|"]
    for _, r in df.iterrows():
        sel = [(fmt[c](r[c]) if c in fmt else (f"{r[c]:.3f}" if isinstance(r[c], float) else str(r[c]))) for c in kolom]
        baris.append("| " + " | ".join(sel) + " |")
    return "\n".join(baris)


def main(k_paksa: int | None) -> None:
    df = pd.read_csv(CSV)
    print(f"{len(df)} kolektor, {df.shape[1] - 1} kolom fitur mentah")

    # --- perbandingan kumpulan fitur (tanpa label) -------------------------------------------
    hasil = {}
    for nama, termasuk in (("A: semua fitur", True), ("B: perilaku (tanpa porsi aliran)", False)):
        fitur = C.kolom_fitur(df, termasuk_porsi_aliran=termasuk)
        kl = C.kolom_log(fitur)
        from sklearn.preprocessing import StandardScaler
        z = StandardScaler().fit_transform(C.matriks(df, fitur, kl))
        hasil[nama] = (len(fitur), C.evaluasi_k(z))
        print(f"  evaluasi K utk kumpulan {nama} ({len(fitur)} fitur) selesai")
    n_b, tabel_b = hasil["B: perilaku (tanpa porsi aliran)"]

    # --- latih final (kumpulan B) -------------------------------------------------------------
    k_auto = C.pilih_k(tabel_b)
    k = k_paksa or k_auto
    bundle = C.latih(df, k=k, tabel_k=tabel_b)
    ARTEFAK.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump(bundle, ARTEFAK)
    print(f"K otomatis = {k_auto}" + (f" | DIPAKSA K = {k}" if k_paksa else "") + f" -> artefak: {ARTEFAK.relative_to(ROOT)} ({ARTEFAK.stat().st_size / 1e3:.0f} KB)")

    asign = C.tetapkan(bundle, df)
    # pastikan artefak yang disimpan bisa dimuat ulang & memberi hasil sama
    ulang = C.tetapkan(joblib.load(ARTEFAK), df)
    assert (ulang["segmen_id"].to_numpy() == asign["segmen_id"].to_numpy()).all(), "artefak tidak konsisten setelah dimuat ulang"

    # kestabilan terhadap seed (penugasan akhir vs 7 seed lain) -- mengukur sensitivitas inisialisasi K-Means
    from sklearn.cluster import KMeans
    from sklearn.preprocessing import StandardScaler as _SS
    z_final = _SS().fit_transform(C.matriks(df, bundle["fitur"], bundle["kolom_log"]))
    stab_seed = float(np.mean([adjusted_rand_score(KMeans(k, n_init=50, random_state=42).fit(z_final).labels_,
                                                   KMeans(k, n_init=50, random_state=s).fit(z_final).labels_) for s in range(1, 8)]))

    # --- validasi thd label asli (SETELAH K final) ---------------------------------------------
    m = asign.merge(pd.read_csv(LABEL), on="kolektor_id")
    ari = adjusted_rand_score(m["segmen_asli"], m["segmen_id"])
    nmi = normalized_mutual_info_score(m["segmen_asli"], m["segmen_id"])
    sil = float(tabel_b.loc[tabel_b["k"] == k, "silhouette"].iloc[0])
    stab = float(tabel_b.loc[tabel_b["k"] == k, "stabilitas_bootstrap"].iloc[0])
    cross = pd.crosstab(m["segmen_id"].map(lambda s: f"{s}. {bundle['segmen'][s]['nama']}"), m["segmen_asli"])

    ev = C.evaluasi_model(bundle, df, pd.read_csv(LABEL))
    assert abs(ev["eksternal"]["ari"] - ari) < 1e-9, "ARI laporan tidak konsisten dengan evaluasi_model"
    ex = ev["eksternal"]
    t_skor = pd.DataFrame([
        ("Silhouette (rata-rata)", f"{ev['silhouette']:.3f}", ev["tafsir_silhouette"]),
        ("Sampel dgn silhouette negatif", f"{ev['pct_silhouette_negatif']:.1f}%", "negatif = kemungkinan salah klaster"),
        ("Davies-Bouldin (makin rendah makin baik)", f"{ev['davies_bouldin']:.3f}", "pedoman kasar: <1 baik, 1-2 sedang, >2 kurang"),
        ("Calinski-Harabasz", f"{ev['calinski_harabasz']:.1f}", "tak punya skala absolut"),
        ("Inertia", f"{ev['inertia']:.1f}", "tak punya skala absolut"),
        ("Jarak dua pusat klaster terdekat", f"{ev['jarak_pusat_terdekat']:.2f}", "satuan z-score"),
        ("Stabilitas bootstrap (ARI)", f"{stab:.3f}", f"ambang >= {C.STABIL_MIN}"),
        ("Stabilitas antar seed (ARI)", f"{stab_seed:.3f}", "1 = identik"),
        ("ARI vs label asli*", f"{ex['ari']:.3f}", "0 = acak, 1 = identik"),
        ("NMI*", f"{ex['nmi']:.3f}", ""),
        ("Homogenitas*", f"{ex['homogenitas']:.3f}", ""),
        ("Kelengkapan*", f"{ex['kelengkapan']:.3f}", ""),
        ("V-measure*", f"{ex['v_measure']:.3f}", ""),
        ("Purity*", f"{ex['purity']:.3f}", ""),
    ], columns=["metrik", "skor", "catatan"])
    dg = C.diagnosa_silhouette(bundle, df, pd.read_csv(LABEL))
    t_dg = pd.DataFrame([
        ("Label ASLI generator (plafon: jawaban benar)", f"{dg['label_asli']:.3f}"),
        (f"Baseline TANPA struktur (Gaussian, K={k}, 30 ulangan)", f"{dg['baseline_tanpa_struktur']:.3f} ± {dg['baseline_sd']:.3f}"),
        (f"K-Means model ini (K={k}, {dg['n_fitur']} fitur)", f"{dg['model']:.3f}"),
        ("[ilustrasi] K-Means K=3, semua fitur", f"{dg['k3']:.3f}"),
        ("[ilustrasi] K-Means K=2, semua fitur", f"{dg['k2']:.3f}"),
        (f"[ilustrasi] K-Means K={k}, hanya 4 fitur terkuat", f"{dg['model_fitur_kuat']:.3f}"),
    ], columns=["pembanding", "silhouette"])
    z_skor = (dg["model"] - dg["baseline_tanpa_struktur"]) / dg["baseline_sd"]
    t_seg = pd.DataFrame([{"segmen": f"{k}. {v['nama']}", "ukuran": v["n"], "silhouette": f"{v['silhouette']:.3f}", "% sampel negatif": f"{v['pct_negatif']:.0f}%"}
                          for k, v in ev["per_segmen"].items()])

    # --- laporan -------------------------------------------------------------------------------
    t_fitur = []
    for nama, (n, t) in hasil.items():
        for _, r in t.iterrows():
            if int(r["k"]) in (3, 4, 5, 6):
                t_fitur.append({"kumpulan fitur": f"{nama} ({n})", "K": int(r["k"]), "silhouette": r["silhouette"], "stabilitas": f"{r['stabilitas_bootstrap']:.2f} ± {r['stabilitas_sd']:.2f}", "Davies-Bouldin": r["davies_bouldin"]})
    t_k = tabel_b.copy()
    t_k["stabilitas (ARI bootstrap ± sd)"] = [f"{a:.2f} ± {b:.2f}" for a, b in zip(tabel_b["stabilitas_bootstrap"], tabel_b["stabilitas_sd"])]
    t_k = t_k.drop(columns=["stabilitas_bootstrap", "stabilitas_sd"]).rename(columns={"k": "K", "calinski_harabasz": "Calinski-Harabasz", "davies_bouldin": "Davies-Bouldin", "bic_gmm": "BIC GMM"})
    dekat = tabel_b[(tabel_b["stabilitas_bootstrap"] - C.STABIL_MIN).abs() <= 0.03]["k"].astype(int).tolist()
    catatan_k = (f"* **Keputusan K sensitif.** Stabilitas K = {', '.join(map(str, dekat))} berada dalam ±0,03 dari ambang {C.STABIL_MIN:.2f}; "
                 "dengan data/seed lain pilihan bisa bergeser satu K. Perlakukan jumlah segmen sebagai perkiraan, bukan angka pasti.") if dekat else ""
    t_k["layak (stabil >= 0,70)"] = np.where(tabel_b["stabilitas_bootstrap"] >= C.STABIL_MIN, "ya", "tidak")
    t_k["terpilih"] = np.where(tabel_b["k"] == k_auto, "<--", "")
    prof = pd.DataFrame([{"id": sid, "nama": s["nama"], "ukuran": s["ukuran"], "pembelian (median)": s["profil"]["n_pembelian"],
                          "harga rata-rata": f"Rp{C._juta(s['profil']['harga_rata2_idr'])} jt", "beli/bulan": s["profil"]["frekuensi_beli_per_bulan"],
                          "porsi aliran teratas": s["profil"]["porsi_gaya_teratas"], "dari seniman mapan": s["profil"]["porsi_beli_seniman_mapan"],
                          "dari seniman pemula": s["profil"]["porsi_beli_seniman_pemula"], "aliran terbanyak": s["aliran_favorit"]}
                         for sid, s in sorted(bundle["segmen"].items())])
    poin = []
    for label in sorted(m["segmen_asli"].unique()):
        sub = m[m["segmen_asli"] == label]
        dom = sub["segmen_id"].value_counts()
        share = dom.iloc[0] / len(sub)
        kata = f"{share:.0%} masuk '{bundle['segmen'][int(dom.index[0])]['nama']}'" if share >= 0.6 else f"tersebar (terbesar hanya {share:.0%} di '{bundle['segmen'][int(dom.index[0])]['nama']}')"
        poin.append(f"* `{label}` ({len(sub)} kolektor): {kata}.")

    md = f"""# Laporan Clustering Kolektor — `{C.VERSI}`

> **DATA SINTETIS.** Segmen di sini menggambarkan struktur yang kita tanam di `src/generate.py`, **bukan** perilaku kolektor nyata.
> Dibuat otomatis oleh `scripts/latih_clustering.py` (seed {C.SEED}); semua angka dihitung dari data, bukan diketik tangan.

## Ringkasan
* **K = {k}**{' (dipaksa manual)' if k_paksa else ' (dipilih otomatis)'}, algoritma K-Means, {n_b} fitur perilaku, {len(df)} kolektor.
* Silhouette **{sil:.3f}** (rendah: batas antar segmen **tidak tegas**), stabilitas bootstrap **{stab:.2f}**, stabilitas antar seed inisialisasi **{stab_seed:.2f}** (ARI rata-rata 7 seed).
* Validasi terhadap label asli generator (dilakukan **setelah** K dipilih): **ARI {ari:.3f}**, **NMI {nmi:.3f}**.

## 1. Keputusan fitur
11 kolom `porsi_gaya_<aliran>` **dikeluarkan** dari fitur klaster agar segmen mewakili *perilaku belanja* (anggaran, frekuensi, keterpusatan selera,
minat pada seniman besar/tren), bukan "penggemar aliran X". Kolom itu tetap dipakai untuk profil (aliran terbanyak). Transformasi: `log1p` pada kolom `*_idr`
dan hitungan/durasi, lalu `StandardScaler` (`RobustScaler` memperbesar outlier harga dan menghasilkan klaster kecil berisi outlier).

{md_tabel(pd.DataFrame(t_fitur))}

Kumpulan B lebih baik di semua K pada semua kriteria tanpa label.

## 2. Pemilihan K
Aturan yang ditetapkan **sebelum** melihat label asli: *di antara K yang stabil (ARI bootstrap ≥ {C.STABIL_MIN:.2f}), pilih BIC GMM terendah.*

{md_tabel(t_k, {"K": str, "Calinski-Harabasz": lambda v: f"{v:.1f}", "BIC GMM": lambda v: f"{v:.0f}"})}

## 3. Profil segmen
{md_tabel(prof, {"id": str, "ukuran": str, "pembelian (median)": lambda v: f"{v:.0f}", "beli/bulan": lambda v: f"{v:.2f}", "porsi aliran teratas": lambda v: f"{v:.2f}", "dari seniman mapan": lambda v: f"{v:.2f}", "dari seniman pemula": lambda v: f"{v:.2f}"})}

Nama diturunkan dari karakteristik centroid dengan aturan di `src/clustering.py: beri_nama` (tingkat harga → frekuensi/keterpusatan selera), **bukan** dari label generator.

{chr(10).join(f"**{sid}. {s['nama']}** — {s['deskripsi']}" + chr(10) for sid, s in sorted(bundle['segmen'].items()))}
## 4. Validasi terhadap label asli (hanya setelah K final)
ARI = **{ari:.3f}**, NMI = **{nmi:.3f}**. Tabel silang (baris = segmen hasil clustering, kolom = segmen asli generator):

{md_tabel(cross.reset_index().rename(columns={cross.index.name: "segmen hasil clustering"}), {c: str for c in cross.columns})}

Ke mana tiap segmen asli pergi:
{chr(10).join(poin)}

## 5. Skor evaluasi lengkap (model akhir)
{md_tabel(t_skor)}

\* eksternal = hanya validasi terhadap label generator; tidak dipakai memilih K/fitur. Tafsir silhouette memakai skala Kaufman–Rousseeuw (> 0,70 kuat · 0,51–0,70 wajar · 0,26–0,50 lemah · ≤ 0,25 tidak ada struktur berarti).

Silhouette per segmen (segmen dengan nilai terendah = batasnya paling kabur):

{md_tabel(t_seg)}

## 6. Mengapa silhouette-nya rendah? (diagnosis)
Silhouette mengukur seberapa terpisah kelompok yang **memang ada di data**, bukan mutu pekerjaan. Pembanding:

{md_tabel(t_dg)}

* **Plafon rendah:** label asli generator hanya {dg['label_asli']:.2f} pada fitur yang sama — segmen yang ditanam saling tumpang tindih, jadi silhouette tinggi memang tidak mungkin dicapai.
* **Struktur ada tapi lemah:** model {dg['model']:.2f} vs data tanpa struktur {dg['baseline_tanpa_struktur']:.2f} (selisih ±{z_skor:.1f} simpangan baku).
* **Data per orang berisik:** median {dg['pembelian_median']:.0f} pembelian per kolektor; {dg['n_kolektor_le3']} dari {dg['n']} kolektor hanya ≤ 3 pembelian.
* Baris `[ilustrasi]` **bukan** dasar memilih model: memilih fitur/K demi menaikkan silhouette itu sirkular. Jangan melaporkan K=2/3 atau subset fitur hanya karena angkanya lebih tinggi.

## 7. Keterbatasan (jujur)
* Data **sintetis** dengan hanya {len(df)} kolektor dan median ±{df['n_pembelian'].median():.0f} pembelian per kolektor: fitur per kolektor berisik, sehingga batas segmen kabur (silhouette rendah).
* Kecocokan dengan label asli hanya **sebagian** (ARI {ari:.2f}). Segmen yang tumpang tindih di generator tidak akan terpisah hanya dari ukuran perilaku ini; dan satu segmen asli bisa terbelah menjadi beberapa klaster (mis. menurut frekuensi beli).
{catatan_k}
* Nama & deskripsi segmen adalah **ringkasan statistik**, bukan kategori yang pasti. Jangan menampilkannya di UI sebagai fakta tentang orang tertentu.
* Segmen dihitung dari **seluruh riwayat sampai akhir periode data**. Jangan dipakai sebagai fitur model klasifikasi (membocorkan masa depan).
* Melatih ulang pada data berbeda dapat mengubah jumlah, nama, dan isi segmen. Naikkan versi (`clustering-v2`) bila itu terjadi, dan jalankan ulang `scripts/hitung_segmen.py`.
"""
    LAPORAN.write_text(md, encoding="utf-8")
    print(f"laporan -> {LAPORAN.relative_to(ROOT)} | ARI {ari:.3f} NMI {nmi:.3f} | silhouette {sil:.3f} stabilitas bootstrap {stab:.2f} antar-seed {stab_seed:.2f}")
    for sid, s in sorted(bundle["segmen"].items()):
        print(f"  {sid}. {s['nama']:26s} n={s['ukuran']:3d} | {s['deskripsi'][:110]}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--k", type=int, default=None, help="paksa K (default: otomatis)")
    main(ap.parse_args().k)
