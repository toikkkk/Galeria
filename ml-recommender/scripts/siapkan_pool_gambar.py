"""Bangun ``data/sumber/pool_gambar.csv`` dari dataset gambar MODEL VISUAL SEARCH v1.

Kenapa file ini ada: katalog dummy HARUS memakai gambar yang sama dgn yang
dipakai melatih Visual Search v1 (5.659 gambar, 11 kelas -- BUKAN versi 33.937
gambar), tapi dataset itu ada di ``ml-visual-search/data/raw/`` yang di-gitignore
(lisensi riset non-komersial). Daripada membuat generator bergantung pada dataset
besar, kita simpan SATU KALI daftar gambar yang layak jadi karya (nama file +
pelukis + aliran + ukuran piksel) di CSV kecil yang ikut ter-commit.

Daftar gambar v1 diambil dari ``data/cache/v1_11class_backup/catalog_embeddings.npz``
(sumber paling akurat -- itu memang katalog yang diindeks v1).

Kriteria gambar yang masuk pool:
* termasuk 5.659 gambar v1 DAN aliran-nya salah satu dari 11 kelas v1,
* pelukisnya BERNAMA (bukan "Unknown Artist" -- tak bisa jadi seniman),
* pelukis punya >= ``--min-gambar`` gambar.

CATATAN: subset v1 hanya berasal dari 23 pelukis bernama (shard 0-4 WikiArt
didominasi sedikit pelukis), jadi sisi "seniman" di data dummy terbatas 23 orang.

Jalankan sekali (butuh dataset lokal):
    python scripts/siapkan_pool_gambar.py
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ML_DIR = ROOT.parent / "ml-visual-search"
OUT = ROOT / "data" / "sumber" / "pool_gambar.csv"


def main(min_gambar: int) -> None:
    cache_v1 = ML_DIR / "data" / "cache" / "v1_11class_backup"
    gambar_v1 = set(np.load(cache_v1 / "catalog_embeddings.npz")["filenames"].tolist())
    kelas = json.load(open(cache_v1 / "label_to_idx__style_name.json", encoding="utf-8"))
    meta = pd.read_csv(ML_DIR / "data" / "raw" / "metadata.csv")
    sub = meta[meta["filename"].isin(gambar_v1) & meta["style_name"].isin(kelas)
               & (meta["artist_name"] != "Unknown Artist")]
    jumlah = sub["artist_name"].value_counts()
    sub = sub[sub["artist_name"].isin(jumlah[jumlah >= min_gambar].index)].copy()

    lebar, tinggi = [], []
    for fn in sub["filename"]:
        with Image.open(ML_DIR / "data" / "raw" / fn) as im:  # baca header saja, cepat
            w, h = im.size
        lebar.append(w)
        tinggi.append(h)
    sub["lebar_px"], sub["tinggi_px"] = lebar, tinggi

    OUT.parent.mkdir(parents=True, exist_ok=True)
    sub[["filename", "artist_name", "style_name", "lebar_px", "tinggi_px"]].sort_values("filename").to_csv(
        OUT, index=False, encoding="utf-8"
    )
    print(f"{len(sub)} gambar, {sub['artist_name'].nunique()} pelukis, "
          f"{sub['style_name'].nunique()}/{len(kelas)} aliran -> {OUT}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--min-gambar", type=int, default=10)
    main(ap.parse_args().min_gambar)
