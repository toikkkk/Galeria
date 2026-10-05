"""Uji WAJIB genda.md Tugas 2 poin 4: untuk N baris acak dari
``klasifikasi_pembelian.csv``, fitur yang dihitung ulang via ``fitur_pasangan()``
(fungsi yang sama dipakai ``src/inference.py`` saat live) harus SAMA dengan
kolom fitur di baris CSV tsb (toleransi pembulatan 4 desimal / 1 rupiah utk
kolom ``*_idr``, krn CSV sudah dibulatkan saat ditulis -- lihat
``src/features.py::bangun_klasifikasi`` baris pembulatan akhir).

Tujuan: membuktikan TIDAK ADA *train/serve skew* -- rumus fitur yang dipakai
saat training (bangun_klasifikasi) dan saat inferensi live (skor_kandidat)
genuinely satu fungsi yang sama, bukan 2 implementasi yang kebetulan mirip.

    python scripts/uji_paritas_fitur.py [--n 50] [--seed 0]
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))  # supaya "from src..." bisa diimpor walau dijalankan dari scripts/

from src.features import FITUR, FITUR_KATEGORIKAL, _Konteks, fitur_pasangan  # noqa: E402
from src.generate import SEED, generate  # noqa: E402

TRAINING = ROOT / "data" / "training"


def _cocok(a, b, kolom: str) -> bool:
    if pd.isna(a) and pd.isna(b):
        return True
    if pd.isna(a) or pd.isna(b):
        return False
    if kolom in FITUR_KATEGORIKAL:
        return str(a) == str(b)
    if kolom.endswith("_idr"):
        # kolom _idr di CSV sudah dibulatkan ke integer terdekat (.round().astype("Int64"))
        return abs(round(float(a)) - round(float(b))) <= 1
    # fitur float lain: CSV sudah dibulatkan 4 desimal (.round(4))
    return abs(round(float(a), 4) - round(float(b), 4)) < 1e-6


def main(n: int, seed: int) -> int:
    kls = pd.read_csv(TRAINING / "klasifikasi_pembelian.csv")
    # PENTING: pakai generate() LANGSUNG (data presisi penuh di memori), BUKAN
    # baca ulang data/export/*.csv -- file CSV export menulis timestamp
    # dibulatkan ke level DETIK (lihat jalankan_pipeline.py::tulis_csv, format
    # "%Y-%m-%dT%H:%M:%SZ"), sedangkan klasifikasi_pembelian.csv yang mau
    # dicocokkan dibangun dari data memori presisi PENUH (sub-detik) oleh
    # jalankan_pipeline.py --dry-run. Baca dari CSV export akan salah diagnosa
    # "train/serve skew" padahal cuma pembulatan timestamp saat ekspor.
    tabel = generate(n_transaksi=1400, n_kolektor=200, n_seniman=23, n_karya=2000, seed=SEED)
    cx = _Konteks(tabel["seniman"], tabel["kolektor"], tabel["karya"], tabel["transaksi"])

    sampel = kls.sample(n=n, random_state=seed)
    n_baris_salah = 0
    n_kolom_salah = 0
    detail_salah = []

    # "waktu" di CSV dibulatkan ke detik (lihat features._iso()) -- kalau t
    # direkonstruksi dari string itu, presisinya beda tipis dari t ASLI (sub-detik)
    # yang dipakai saat training, bisa salah diagnosa sbg "train/serve skew".
    # t presisi penuh diambil langsung dari cx.tx via grup_id (grup ke-N <-> baris
    # ke-(N-1) di cx.tx, krn grup dibuat via enumerate(tx.itertuples(...), start=1)
    # persis urutan itu -- lihat bangun_klasifikasi()).
    t_presisi_per_grup = cx.tx["t"].to_numpy()

    cache_n30 = {}  # t sama (1 grup) dipakai banyak baris -- hemat hitung ulang
    for row in sampel.itertuples(index=False):
        t = float(t_presisi_per_grup[row.grup_id - 1])
        if t not in cache_n30:
            cache_n30[t] = cx.n30_semua(t)
        n30_semua = cache_n30[t]

        idx = cx.idx_karya[str(row.karya_id)]
        fitur_hitung = fitur_pasangan(cx, str(row.kolektor_id), int(idx), t, n30_semua)

        salah_di_baris_ini = []
        for kolom in FITUR:
            nilai_csv = getattr(row, kolom)
            nilai_hitung = fitur_hitung[kolom]
            if not _cocok(nilai_csv, nilai_hitung, kolom):
                salah_di_baris_ini.append((kolom, nilai_csv, nilai_hitung))

        if salah_di_baris_ini:
            n_baris_salah += 1
            n_kolom_salah += len(salah_di_baris_ini)
            detail_salah.append((row.grup_id, row.karya_id, salah_di_baris_ini))

    print(f"[uji paritas fitur] {n} baris diuji, {len(FITUR)} kolom fitur/baris")
    print(f"[uji paritas fitur] baris dgn ketidakcocokan: {n_baris_salah}  |  total sel tidak cocok: {n_kolom_salah}")
    if detail_salah:
        print("\nDetail 5 ketidakcocokan pertama:")
        for grup_id, karya_id, salah in detail_salah[:5]:
            print(f"  grup_id={grup_id} karya_id={karya_id}")
            for kolom, csv_v, hitung_v in salah[:5]:
                print(f"    {kolom}: csv={csv_v!r}  fitur_pasangan={hitung_v!r}")
        print("\n-> GAGAL -- ada train/serve skew, JANGAN lanjut ke Tugas 3 sebelum ini 0.")
        return 1

    print("-> OK -- fitur_pasangan() identik dgn CSV training (toleransi pembulatan).")
    return 0


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--n", type=int, default=50)
    ap.add_argument("--seed", type=int, default=0)
    args = ap.parse_args()
    raise SystemExit(main(args.n, args.seed))
