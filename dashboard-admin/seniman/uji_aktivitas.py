"""Uji cepat fungsi murni keaktifan seniman (tanpa database).

    cd dashboard-admin
    .venv\\Scripts\\python seniman\\uji_aktivitas.py
"""

from __future__ import annotations

import sys
import warnings
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))
warnings.filterwarnings("ignore")
import aktivitas as a  # noqa: E402


def cek(nama: str, kondisi: bool) -> None:
    print(("LULUS  " if kondisi else "GAGAL  ") + nama)
    if not kondisi:
        raise SystemExit(1)


def contoh(n=60) -> pd.DataFrame:
    rng = np.random.default_rng(3)
    kerja = rng.integers(0, 6, n)
    jual_terakhir = [a.ACUAN - pd.Timedelta(days=int(d)) if k > 0 else pd.NaT
                     for k, d in zip(kerja, rng.integers(1, 400, n))]
    return pd.DataFrame({
        "seniman_id": [f"s{i}" for i in range(n)], "display_name": [f"Seniman {i}" for i in range(n)],
        "created_at": [a.ACUAN - pd.Timedelta(days=int(d)) for d in rng.integers(450, 900, n)],
        "n_jual_90d": np.where(kerja > 3, kerja, 0), "omzet_90d": np.where(kerja > 3, kerja * 2_000_000, 0),
        "n_jual_12b": kerja, "omzet_12b": kerja * 2_000_000, "n_jual_total": kerja,
        "terakhir_jual": jual_terakhir, "pro": rng.random(n) < 0.2,
    })


df = a.siapkan_fitur(contoh())
cek("skor keaktifan 0-100 dan tanpa NaN", df["skor_keaktifan"].between(0, 100).all() and df["skor_keaktifan"].notna().all())
cek("seniman yang menjual baru-baru ini bernilai lebih tinggi daripada yang tidak pernah menjual",
    df.loc[df.n_jual_90d > 0, "skor_keaktifan"].min() > df.loc[df.n_jual_total == 0, "skor_keaktifan"].max())
cek("yang belum pernah menjual: hari_sejak_jual = umur akun",
    (df.loc[~df.pernah_jual, "hari_sejak_jual"] >= 450).all())
cek("matriks fitur: bentuk (n, 4) dan berhingga", a.matriks(df).shape == (60, 4) and np.isfinite(a.matriks(df)).all())

lab = np.repeat(np.arange(6), 10)
skor = pd.Series(np.concatenate([np.full(10, v) for v in (95, 90, 55, 50, 12, 8)]).astype(float))
peta = a.gabung_ke_tiga(skor, lab)
cek("penggabungan: 6 kelompok -> tepat 3 tingkat bernama", set(peta.values()) == set(a.LABEL))
cek("penggabungan: skor tertinggi = Aktif, terendah = Tidak Aktif, tengah = Kurang Aktif",
    peta[0] == peta[1] == "Aktif" and peta[2] == peta[3] == "Kurang Aktif" and peta[4] == peta[5] == "Tidak Aktif")

arah = pd.Series([90.0] * 5 + [10.0] * 5)
peta3 = a.gabung_ke_tiga(arah, np.array([0] * 5 + [1] * 5))
cek("penggabungan: hanya 2 kelompok tetap menghasilkan Aktif dan Tidak Aktif", set(peta3.values()) == {"Aktif", "Tidak Aktif"})

emb = np.array([[0.0, 0], [0.1, 0], [5, 5], [5.1, 5], [0.05, 0.05]])
isi = a.tetapkan_noise(emb, np.array([0, 0, 1, 1, -1]))
cek("noise ditetapkan ke kelompok terdekat", isi[4] == 0)
print("\nSemua uji lulus.")
