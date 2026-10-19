"""Pipeline data sistem rekomendasi:  generate -> isi Neon -> baca ulang -> CSV training.

    python jalankan_pipeline.py              # pakai data yg sudah ada di Neon; kalau kosong, isi dulu
    python jalankan_pipeline.py --reset      # bangun ulang isi schema dari generator (seed tetap)
    python jalankan_pipeline.py --dry-run    # tanpa database: CSV dari memori (utk uji/tanpa akses Neon)

Semua yang ditulis ke database berada di schema ``dummy_rekomendasi`` (lihat src/db.py).
CSV training SELALU dibangun dari data yang dibaca ULANG dari database, jadi isinya
sama persis dgn yang ada di Neon (kecuali --dry-run).
"""

from __future__ import annotations

import argparse
import asyncio
import sys
import uuid
from pathlib import Path

import importlib.util

import pandas as pd
from sqlalchemy import text

from src import db
from src.features import (KAMUS_CLUSTERING, KAMUS_KLASIFIKASI, KAMUS_METRIK, bangun_clustering,
                          bangun_klasifikasi, bangun_metrik_seniman_bulanan, periksa_kamus)
from src.generate import GAYA, SEED, generate

ROOT = Path(__file__).resolve().parent
EXPORT = ROOT / "data" / "export"
TRAINING = ROOT / "data" / "training"


def tulis_csv(df: pd.DataFrame, path: Path) -> None:
    out = df.copy()
    for c in out.columns:
        if pd.api.types.is_datetime64_any_dtype(out[c]):
            out[c] = out[c].dt.tz_convert("UTC").dt.strftime("%Y-%m-%dT%H:%M:%SZ")
        elif out[c].dtype == object and len(out) and isinstance(out[c].iloc[0], uuid.UUID):
            out[c] = out[c].astype(str)
    path.parent.mkdir(parents=True, exist_ok=True)
    out.to_csv(path, index=False, encoding="utf-8", lineterminator="\n")
    print(f"  {path.relative_to(ROOT)}  ({len(out)} baris x {out.shape[1]} kolom)")


def tulis_kamus(path: Path, params: dict, kls: pd.DataFrame, clu: pd.DataFrame, met: pd.DataFrame) -> None:
    def tabel(kamus: dict) -> str:
        return "| Kolom | Arti |\n|---|---|\n" + "\n".join(f"| `{k}` | {v} |" for k, v in kamus.items())

    n_pos = int(kls["dibeli"].sum())
    md = f"""# Kamus Data -- Sistem Rekomendasi Lukisan GALERIA

> **DATA SINTETIS.** Gambar & aliran lukisan nyata (dataset Visual Search v1: 5.659 gambar, 11 kelas),
> tetapi kolektor, harga, dan riwayat pembelian dibangkitkan program (`src/generate.py` generator-v2, seed {params['seed']}); kolektor sengaja dirancang berkelompok tegas.
> Model yang dilatih di sini mempelajari aturan buatan kita, **bukan** perilaku pembeli nyata -- jangan
> mengklaim skornya sebagai performa produksi. File ini dibuat otomatis oleh `jalankan_pipeline.py`.

Parameter: {params['n_karya']} karya, {params['n_transaksi']} transaksi, {params['n_kolektor']} kolektor,
{params['n_seniman']} seniman, {params['neg_per_pos']} negatif per pembelian.

## 1. `klasifikasi_pembelian.csv` -- {len(kls)} baris ({n_pos} positif)

Tugas: **untuk kolektor X pada waktu t, karya mana yang akan dibeli?** (klasifikasi biner `dibeli`,
dievaluasi sebagai ranking).

Aturan penting:
* **Jangan pakai kolom pengenal sbg fitur**: `grup_id`, `split`, `waktu`, `transaksi_id`, `kolektor_id`, `karya_id`, `seniman_id`.
* **Tanpa kebocoran waktu**: semua fitur riwayat dihitung dari kejadian SEBELUM `waktu`.
* **Pakai kolom `split`** (berdasarkan waktu), bukan acak -- acak akan membocorkan masa depan ke masa lalu.
* **Evaluasi ranking per `grup_id`** (HitRate@K, NDCG@K). 1 grup = 1 positif + {params['neg_per_pos']} negatif, jadi tebakan acak
  HitRate@1 = {100 / (1 + params['neg_per_pos']):.0f}%. Akurasi biasa menyesatkan.
* Negatif = karya lain yang masih tersedia saat itu, dipilih seragam acak (asumsi; tak ada data "dilihat tapi tak dibeli").
* Kategorikal: `karya_gaya`, `seniman_level_reputasi`, `kolektor_segmen`. Kosong (NaN) berarti belum ada riwayat (mis. pembelian pertama kolektor) -- bukan error.
* **`kolektor_segmen` berasal dari CLUSTERING** (urutan kerja: clustering dulu, lalu klasifikasi). Dihitung as-of `waktu` dari riwayat SEBELUM `waktu`, memakai model clustering
  **"cutoff"** (`models/clustering_kolektor_cutoff.joblib`, dilatih hanya pada data sampai batas train), jadi tidak mengintip val/test. Kolektor dgn < 3 pembelian sebelum `waktu`
  bernilai `Belum Cukup Riwayat`. **Jangan** mengganti dengan segmen model "final" (`kolektor_segmen` di Neon) atau `kolektor_label_asli` -- keduanya membocorkan masa depan.

{tabel(KAMUS_KLASIFIKASI)}

## 2. `clustering_kolektor.csv` -- {len(clu)} baris (1 per kolektor)

Tugas: **segmentasi kolektor** (clustering, tanpa label) -- dikerjakan Thoriq dengan **UMAP + HDBSCAN** (`src/clustering.py`, laporan `models/LAPORAN_CLUSTERING.md`).
Snapshot di akhir periode data memakai seluruh riwayat. Fitur klaster = 5 kolom perilaku (`harga_rata2_idr`, `frekuensi_beli_per_bulan`, `rata2_persentil_tren_saat_beli`,
`porsi_beli_seniman_mapan`, `porsi_beli_seniman_pemula`; log1p utk dua kolom pertama lalu StandardScaler); kolom lain dipakai utk profil segmen. Tidak ada NaN. `kolektor_id` bukan fitur.

{tabel(KAMUS_CLUSTERING)}

### `kolektor_label_asli.csv` -- HANYA utk validasi
Segmen yang dipakai generator-v2 (`premium_mapan`, `pemburu_tren`, `kakap_aktif`, `menengah_rutin`, `pemula_hemat`).
**Jangan dipakai sbg fitur atau target latihan.** Gunakan setelah clustering selesai utk membandingkan (mis. Adjusted Rand Index).
Di data nyata label ini tidak ada. Segmen ini hasil rancangan kita, jadi cocok/tidaknya dgn cluster hanya menunjukkan
generator terbaca model, bukan kebenaran tentang kolektor sungguhan.

## 3. `seniman_metrik_bulanan.csv` -- {len(met)} baris

Isi dashboard seniman: penjualan per seniman per bulan. Berasal dari view `dummy_rekomendasi.v_seniman_metrik_bulanan`.

{tabel(KAMUS_METRIK)}

## 4. `data/export/*.csv`

Salinan mentah 4 tabel dari Neon (`seniman`, `kolektor`, `karya`, `transaksi`) -- bahan feature engineering sendiri.
`karya.image_filename` = nama file gambar di `ml-visual-search/data/raw/` (dataset v1), jadi embedding Visual Search
(`ml-visual-search/data/cache/v1_11class_backup/catalog_embeddings.npz`) bisa di-join lewat nama file itu.
"""
    path.write_text(md, encoding="utf-8")
    print(f"  {path.relative_to(ROOT)}")


async def jalankan(args) -> int:
    params = dict(seed=args.seed, n_karya=args.n_karya, n_transaksi=args.n_transaksi,
                  n_kolektor=args.n_kolektor, n_seniman=args.n_seniman, neg_per_pos=args.neg_per_pos)
    print("[1/5] membangkitkan data dummy (seed %d)..." % args.seed)
    data = generate(n_transaksi=args.n_transaksi, n_kolektor=args.n_kolektor, n_seniman=args.n_seniman,
                    n_karya=args.n_karya, seed=args.seed)
    print("      " + ", ".join(f"{k}={len(v)}" for k, v in data.items()))

    view = None
    if args.dry_run:
        print("[2/5] --dry-run: database dilewati")
        tabel = data
    else:
        eng = db.buat_engine()
        async with eng.begin() as conn:
            public_sebelum = await db.hitung_public(conn)
            await db.pastikan_schema(conn)
            ada = await db.hitung(conn)
            if sum(ada.values()) and not args.reset:
                print(f"[2/5] schema {db.SCHEMA} sudah berisi data {ada} -- dipakai apa adanya (--reset utk membangun ulang)")
            else:
                if sum(ada.values()):
                    await db.kosongkan(conn)
                await db.isi(conn, data)
                print(f"[2/5] Neon: schema {db.SCHEMA} diisi -> {await db.hitung(conn)}")
        async with eng.connect() as conn:
            print("[3/5] membaca ulang semua tabel dari Neon...")
            tabel = await db.baca_semua(conn)
            view = await db.baca(conn, "v_seniman_metrik_bulanan")
            public_sesudah = await db.hitung_public(conn)
        await eng.dispose()
        if public_sebelum != public_sesudah:
            print("GAGAL: tabel public berubah!", public_sebelum, public_sesudah)
            return 1
        print(f"      tabel public tidak berubah: {public_sesudah}")

    seniman, kolektor, karya, transaksi = (tabel[k] for k in ("seniman", "kolektor", "karya", "transaksi"))
    print("[4/5] membangun CSV training dari data tsb...")
    # URUTAN KERJA: CLUSTERING DULU, lalu klasifikasi (fitur kolektor_segmen berasal dari clustering).
    clu = bangun_clustering(seniman, kolektor, karya, transaksi)
    print("      clustering (UMAP + HDBSCAN): melatih model final + model cutoff, menulis models/ + LAPORAN_CLUSTERING.md ...")
    spec = importlib.util.spec_from_file_location("latih_clustering", ROOT / "scripts" / "latih_clustering.py")
    latih_clustering = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(latih_clustering)
    hasil_klaster = latih_clustering.jalankan(tabel, tabel["kolektor_label_asli"], tulis=True)
    kls = bangun_klasifikasi(seniman, kolektor, karya, transaksi, neg_per_pos=args.neg_per_pos, seed=args.seed,
                             bundle_klaster=hasil_klaster["cutoff"])
    met = bangun_metrik_seniman_bulanan(karya, transaksi)
    periksa_kamus(kls, KAMUS_KLASIFIKASI, "klasifikasi")
    periksa_kamus(clu, KAMUS_CLUSTERING, "clustering")
    periksa_kamus(met, KAMUS_METRIK, "metrik")

    if view is not None:   # view SQL harus menghitung hal yang sama dgn pandas
        v = view.sort_values(["seniman_id", "bulan"]).reset_index(drop=True)
        v["seniman_id"] = v["seniman_id"].astype(str)
        assert len(v) == len(met), (len(v), len(met))
        assert (v["seniman_id"].to_numpy() == met["seniman_id"].to_numpy()).all()
        assert (v["bulan"].to_numpy() == met["bulan"].to_numpy()).all()
        for c in ("n_terjual", "omzet_idr", "komisi_platform_idr", "pendapatan_bersih_idr", "harga_maks_idr", "n_pembeli_unik"):
            assert (v[c].astype("int64").to_numpy() == met[c].astype("int64").to_numpy()).all(), c
        assert (v["harga_rata2_idr"].astype("int64") - met["harga_rata2_idr"]).abs().max() <= 1
        assert (v["gaya_terlaris"].to_numpy() == met["gaya_terlaris"].to_numpy()).all()
        print("      view SQL v_seniman_metrik_bulanan == hitungan pandas (OK)")

    for nama in ("seniman", "kolektor", "karya", "transaksi"):
        if args.dry_run and nama == "karya" and (EXPORT / "karya.csv").exists():
            # mode --dry-run membangun dari memori yang tak punya kolom image_key (diisi saat unggah ke R2) -- jangan timpa
            print("  data/export/karya.csv dilewati (dry-run; mempertahankan kolom image_key dari export database)")
            continue
        tulis_csv(tabel[nama], EXPORT / f"{nama}.csv")
    tulis_csv(kls, TRAINING / "klasifikasi_pembelian.csv")
    tulis_csv(clu, TRAINING / "clustering_kolektor.csv")
    tulis_csv(tabel["kolektor_label_asli"], TRAINING / "kolektor_label_asli.csv")
    tulis_csv(met, TRAINING / "seniman_metrik_bulanan.csv")
    print("[5/5] kamus data...")
    tulis_kamus(TRAINING / "KAMUS_DATA.md", params, kls, clu, met)

    n_grup = kls["grup_id"].nunique()
    print(f"\nRingkasan: {len(kls)} baris klasifikasi = {n_grup} grup, split "
          f"{kls.drop_duplicates('grup_id')['split'].value_counts().to_dict()}; {len(clu)} kolektor utk clustering; "
          f"{len(GAYA)} aliran.")
    return 0


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--n-karya", type=int, default=2000, help="jumlah karya (gambar dari dataset v1)")
    ap.add_argument("--n-transaksi", type=int, default=1400, help="jumlah penjualan (<= n-karya/1.1)")
    ap.add_argument("--n-kolektor", type=int, default=200)
    ap.add_argument("--n-seniman", type=int, default=23, help="maks 23 (pelukis bernama di dataset v1)")
    ap.add_argument("--neg-per-pos", type=int, default=4)
    ap.add_argument("--seed", type=int, default=SEED)
    ap.add_argument("--reset", action="store_true", help="kosongkan & isi ulang schema dummy_rekomendasi")
    ap.add_argument("--dry-run", action="store_true", help="tanpa database")
    sys.exit(asyncio.run(jalankan(ap.parse_args())))
