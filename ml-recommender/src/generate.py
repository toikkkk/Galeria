"""Generator data DUMMY untuk sistem rekomendasi lukisan GALERIA.

GAMBAR & ALIRAN itu NYATA (dari dataset WikiArt yang sama dgn yang dipakai
melatih Visual Search v1: 5.659 gambar, 11 kelas -- lihat
``data/sumber/pool_gambar.csv`` & ``scripts/siapkan_pool_gambar.py``). Yang SINTETIS
adalah semua hal "ekonomi": kolektor, harga, siapa membeli apa, kapan.
Pelukisnya memang tokoh sungguhan (karena itu gambar mereka), tapi riwayat
penjualan/harganya fiktif -- jangan dibaca sebagai fakta tentang pelukis itu.

KONSEKUENSI JUJUR yang harus dibawa ke laporan: model yang dilatih di data ini
hanya mempelajari aturan perilaku yang ditulis di file ini (bagian "MODEL
PERILAKU"), BUKAN perilaku pembeli lukisan di dunia nyata. Skor model di data
ini tidak boleh diklaim sebagai performa sistem di produksi.

Deterministik: seed sama -> data (termasuk UUID) identik, jadi CSV di ``data/``
selalu bisa dibangun ulang dan dibandingkan.

MODEL PERILAKU (asumsi buatan kita, bukan fakta dunia nyata)
------------------------------------------------------------
* 5 segmen kolektor dgn anggaran, laju beli, selera aliran, dan sensitivitas
  tren yang berbeda (``SEGMEN``).
* Seniman punya reputasi (menentukan level harga, mengikuti jumlah gambarnya di
  WikiArt sbg proksi "seberapa dikenal"), popularitas, dan KURVA TREN yang
  berubah per waktu (random walk + sebagian "breakout" lalu meredup) -- inilah
  "pelukis yang lagi ramai".
* Tiap pembelian = pilihan diskrit (multinomial logit) dari karya yang SEDANG
  tersedia: utilitas = kecocokan aliran + kecocokan harga vs anggaran +
  sensitivitas_tren x tren_seniman + popularitas seniman + noise.
* 1 karya = 1 penjualan (lukisan = barang unik, tidak ada stok).
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import pandas as pd

SEED = 42
NAMESPACE = uuid.UUID("6f1c3a52-8c1e-4f6e-9a57-2d9d3e0c1a11")
POOL_PATH = Path(__file__).resolve().parent.parent / "data" / "sumber" / "pool_gambar.csv"

WINDOW_START = pd.Timestamp("2024-10-01", tz="UTC")
WINDOW_END = pd.Timestamp("2026-09-30 23:59:59", tz="UTC")
HARI_TOTAL = (WINDOW_END - WINDOW_START).total_seconds() / 86400.0

KOMISI_PLATFORM = 0.10  # ASUMSI dummy -- tarif komisi sebenarnya belum diputuskan

# 11 kelas style model Visual Search v1 (checkpoints/v1_11class_backup, 5.659 gambar).
GAYA = [
    "Art_Nouveau", "Baroque", "Cubism", "Expressionism", "Impressionism",
    "Naive_Art_Primitivism", "Northern_Renaissance", "Post_Impressionism", "Realism",
    "Romanticism", "Symbolism",
]
G = {n: i for i, n in enumerate(GAYA)}

# Kelompok selera (dipakai utk bias aliran per segmen kolektor). Tiap aliran tepat 1 kelompok.
KLASIK = ["Baroque", "Northern_Renaissance", "Romanticism"]
MODERN = ["Impressionism", "Post_Impressionism", "Expressionism", "Symbolism", "Art_Nouveau",
          "Realism", "Cubism"]
KONTEMPORER = ["Naive_Art_Primitivism"]
assert sorted(KLASIK + MODERN + KONTEMPORER) == sorted(GAYA)

# Pengali harga per aliran (ASUMSI buatan, kasar).
GAYA_HARGA = {
    "Art_Nouveau": 0.9, "Baroque": 1.8, "Cubism": 1.6, "Expressionism": 1.2, "Impressionism": 1.3,
    "Naive_Art_Primitivism": 0.7, "Northern_Renaissance": 1.6, "Post_Impressionism": 1.5,
    "Realism": 1.0, "Romanticism": 1.0, "Symbolism": 0.8,
}

LEVEL = ["pemula", "menengah", "mapan"]
LEVEL_HARGA_MEDIAN = {"pemula": 6e6, "menengah": 28e6, "mapan": 130e6}
LEVEL_POP = {"pemula": 0.8, "menengah": 1.0, "mapan": 1.4}


@dataclass(frozen=True)
class Segmen:
    nama: str
    porsi: float            # porsi populasi kolektor
    anggaran_median: float  # IDR, median harga yang nyaman dibeli
    anggaran_sigma: float   # sebaran log harga yang masih "nyaman"
    laju: float             # pengali frekuensi beli
    alpha: float            # konsentrasi Dirichlet selera aliran (kecil = terpusat)
    afinitas: tuple         # (klasik, modern, kontemporer) -- bias selera kelompok aliran
    sens_tren: float        # sensitivitas thd tren seniman


SEGMEN = [
    Segmen("premium_selektif", 0.10, 280e6, 0.45, 0.6, 0.6, (3.0, 2.0, 0.5), 0.2),
    Segmen("menengah_aktif", 0.30, 45e6, 0.55, 1.5, 0.9, (1.5, 1.5, 1.0), 0.5),
    Segmen("pemula_hemat", 0.30, 7e6, 0.45, 0.7, 0.7, (0.5, 1.5, 2.5), 0.5),
    Segmen("spesialis_aliran", 0.15, 70e6, 0.60, 1.1, 0.12, (1.0, 1.0, 1.0), 0.1),
    Segmen("pengikut_tren", 0.15, 28e6, 0.70, 1.3, 2.0, (1.0, 1.0, 1.0), 2.2),
]

KOTA = ["Surabaya", "Jakarta", "Bandung", "Yogyakarta", "Malang", "Denpasar", "Semarang",
        "Medan", "Makassar", "Solo", "Bogor", "Sidoarjo", "Balikpapan", "Palembang"]
NAMA_DEPAN = ["Adi", "Budi", "Citra", "Dewi", "Eko", "Fajar", "Gita", "Hadi", "Indah", "Joko",
              "Kartika", "Lestari", "Mega", "Nanda", "Okta", "Putri", "Rangga", "Sari", "Teguh",
              "Utami", "Vina", "Wahyu", "Yoga", "Zahra", "Alya", "Bayu", "Dinda", "Farhan",
              "Hana", "Irfan", "Jihan", "Kevin", "Laras", "Maya", "Nadia", "Raka", "Salsa"]
NAMA_BELAKANG = ["Pratama", "Santoso", "Wijaya", "Kusuma", "Hidayat", "Saputra", "Nugroho",
                 "Lestari", "Rahmawati", "Setiawan", "Permana", "Wibowo", "Handayani", "Susanto",
                 "Purnomo", "Maharani", "Gunawan", "Firmansyah", "Anggraini", "Utomo"]


def _uid(tabel: str, i: int) -> uuid.UUID:
    return uuid.uuid5(NAMESPACE, f"{tabel}-{i}")


def _angka_bulat(x: np.ndarray, digit: int = 2) -> np.ndarray:
    """Bulatkan ke ``digit`` angka signifikan -- harga lukisan 'bulat' (12 jt, 150 jt)."""
    x = np.asarray(x, dtype=float)
    mag = np.floor(np.log10(np.maximum(x, 1.0)))
    f = 10 ** (mag - digit + 1)
    return np.round(x / f) * f


def _nama(rng: np.random.Generator, n: int) -> list[str]:
    d = rng.choice(NAMA_DEPAN, n)
    b = rng.choice(NAMA_BELAKANG, n)
    return [f"{x} {y}" for x, y in zip(d, b)]


def _ts(days) -> pd.DatetimeIndex:
    # dibulatkan ke mikrodetik = presisi Postgres/datetime, supaya data generator == data di database
    return (WINDOW_START + pd.to_timedelta(np.asarray(days, dtype=float), unit="D")).floor("us")


def _kurva_tren(rng: np.random.Generator, n_seniman: int, n_bulan: int) -> np.ndarray:
    """Tren laten per seniman per bulan, bentuk (n_seniman, n_bulan+1).

    Random walk AR(1) + ~15% seniman "breakout" (naik lalu meredup) + ~10% "pudar".
    Nilai ini TIDAK ditulis ke data -- hanya mempengaruhi harga listing & pilihan
    beli. Fitur tren di dataset training dihitung dari penjualan yang TERAMATI.
    """
    z = np.zeros((n_seniman, n_bulan + 1))
    z[:, 0] = rng.normal(0, 0.5, n_seniman)
    for m in range(n_bulan):
        z[:, m + 1] = 0.8 * z[:, m] + rng.normal(0, 0.35, n_seniman)
    bulan = np.arange(n_bulan + 1)
    for a in rng.choice(n_seniman, size=max(1, int(0.15 * n_seniman)), replace=False):
        s = rng.integers(3, 18)
        z[a] += np.where(bulan >= s, 1.3 * np.exp(-(bulan - s) / 6.0), 0.0)
    for a in rng.choice(n_seniman, size=max(1, int(0.10 * n_seniman)), replace=False):
        s = rng.integers(2, 14)
        z[a] -= np.where(bulan >= s, 0.8 * np.exp(-(bulan - s) / 8.0), 0.0)
    return np.clip(z, -2.5, 3.0)


def _tren_pada(z: np.ndarray, hari: float) -> np.ndarray:
    """Interpolasi linear kurva bulanan ke hari ke-``hari`` -> vektor (n_seniman,)."""
    pos = float(np.clip(hari / 30.4375, 0, z.shape[1] - 1.0001))
    i = int(np.floor(pos))
    f = pos - i
    return z[:, i] * (1 - f) + z[:, i + 1] * f


def _nama_pelukis(slug: str) -> str:
    return " ".join(w.capitalize() for w in slug.split("-"))


def _pilih_pelukis(pool: pd.DataFrame, n: int) -> list[str]:
    """Pilih ``n`` pelukis secara deterministik: dulu wakil terkuat tiap aliran
    (supaya SEMUA aliran punya penjual), sisanya diisi pelukis dgn gambar terbanyak."""
    jumlah = pool["artist_name"].value_counts()
    terpilih: list[str] = []
    for gaya in GAYA:
        sub = pool[pool["style_name"] == gaya]["artist_name"].value_counts()
        for a in sub.index:
            if a not in terpilih:
                terpilih.append(a)
                break
    for a in jumlah.index:
        if len(terpilih) >= n:
            break
        if a not in terpilih:
            terpilih.append(a)
    return terpilih[:n]


def _alokasi_karya(rng: np.random.Generator, bobot: np.ndarray, kapasitas: np.ndarray, total: int) -> np.ndarray:
    """Bagi ``total`` karya ke seniman ~ ``bobot``, tapi tak melebihi ``kapasitas``
    (jumlah gambar yang tersedia). Kelebihan dibagi ulang ke seniman yang masih punya sisa."""
    if kapasitas.sum() < total:
        raise ValueError("gambar di pool tidak cukup utk n_karya sebanyak itu")
    hasil = np.zeros_like(kapasitas)
    sisa = total
    while sisa > 0:
        ruang = kapasitas - hasil
        p = np.where(ruang > 0, bobot, 0.0)
        tambah = rng.multinomial(sisa, p / p.sum())
        tambah = np.minimum(tambah, ruang)
        hasil += tambah
        sisa = total - int(hasil.sum())
    return hasil


def generate(n_transaksi: int = 1400, n_kolektor: int = 200, n_seniman: int = 23,
             n_karya: int = 2000, seed: int = SEED) -> dict[str, pd.DataFrame]:
    """Bangkitkan semua tabel dummy. Mengembalikan dict DataFrame:
    ``seniman, kolektor, kolektor_label_asli, karya, transaksi``.
    """
    if n_karya < n_transaksi * 1.1:
        raise ValueError("n_karya harus >= 1.1 x n_transaksi (1 karya hanya terjual sekali)")
    if n_transaksi < n_kolektor:
        raise ValueError("n_transaksi harus >= n_kolektor (tiap kolektor min. 1 pembelian)")
    rng = np.random.default_rng(seed)
    n_bulan = int(np.ceil(HARI_TOTAL / 30.4375))
    pool = pd.read_csv(POOL_PATH)

    # ------------------------------------------------------------------ seniman
    slugs = _pilih_pelukis(pool, n_seniman)
    n_seniman = len(slugs)
    jml = pool["artist_name"].value_counts()
    urut_nama = sorted(slugs, key=lambda a: (-jml[a], a))      # makin banyak gambar = makin dikenal
    rank = {a: i for i, a in enumerate(urut_nama)}
    level = np.array(["mapan" if rank[a] < 0.15 * n_seniman else
                      "menengah" if rank[a] < 0.55 * n_seniman else "pemula" for a in slugs])
    gaya_utama, gaya_sek = [], []
    for a in slugs:
        vc = pool.loc[pool["artist_name"] == a, "style_name"].value_counts()
        gaya_utama.append(vc.index[0])
        gaya_sek.append(vc.index[1] if len(vc) > 1 else None)
    harga_dasar = np.array([LEVEL_HARGA_MEDIAN[l] for l in level]) * np.exp(rng.normal(0, 0.35, n_seniman))
    popularitas = np.exp(rng.normal(0, 0.6, n_seniman)) * np.array([LEVEL_POP[l] for l in level])
    z = _kurva_tren(rng, n_seniman, n_bulan)
    seniman = pd.DataFrame({
        "id": [_uid("seniman", i) for i in range(n_seniman)],
        "display_name": [_nama_pelukis(a) for a in slugs],
        "wikiart_artist": slugs,
        "gaya_utama": gaya_utama,
        "gaya_sekunder": pd.Series(gaya_sek, dtype=object),
        "level_reputasi": level,
        "created_at": _ts(rng.uniform(-400, 30, n_seniman)),
    })

    # ----------------------------------------------------------------- kolektor
    seg_idx = rng.choice(len(SEGMEN), n_kolektor, p=[s.porsi for s in SEGMEN])
    kelompok = np.zeros((3, len(GAYA)))
    for r, daftar in enumerate((KLASIK, MODERN, KONTEMPORER)):
        for g in daftar:
            kelompok[r, G[g]] = 1.0
    pref = np.zeros((n_kolektor, len(GAYA)))
    anggaran = np.zeros(n_kolektor)
    sigma = np.zeros(n_kolektor)
    laju = np.zeros(n_kolektor)
    sens = np.zeros(n_kolektor)
    for i, si in enumerate(seg_idx):
        s = SEGMEN[si]
        base = np.array(s.afinitas) @ kelompok          # bias selera per aliran
        conc = s.alpha * len(GAYA) * base / base.sum()
        pref[i] = rng.dirichlet(np.maximum(conc, 1e-3))
        anggaran[i] = np.log(s.anggaran_median) + rng.normal(0, 0.35)
        sigma[i] = s.anggaran_sigma
        laju[i] = s.laju * np.exp(rng.normal(0, 0.45))
        sens[i] = max(0.0, s.sens_tren + rng.normal(0, 0.1))
    join_k = rng.uniform(0, 540, n_kolektor)
    kolektor = pd.DataFrame({
        "id": [_uid("kolektor", i) for i in range(n_kolektor)],
        "display_name": _nama(rng, n_kolektor),
        "kota": rng.choice(KOTA, n_kolektor),
        "created_at": _ts(join_k),
    })
    label = pd.DataFrame({
        "kolektor_id": kolektor["id"],
        "segmen_asli": [SEGMEN[i].nama for i in seg_idx],
    })

    # -------------------------------------------------------------------- karya
    # Tiap karya = 1 gambar NYATA dari pool (aliran ikut gambarnya, bukan diundi).
    kapasitas = np.array([(pool["artist_name"] == a).sum() for a in slugs])
    prod = (popularitas ** 0.5) * (kapasitas ** 0.3)
    jumlah_karya = _alokasi_karya(rng, prod, kapasitas, n_karya)
    baris_gambar = []
    seniman_karya = []
    for a_idx, (a, k) in enumerate(zip(slugs, jumlah_karya)):
        sub = pool[pool["artist_name"] == a]
        pilih = sub.iloc[rng.choice(len(sub), size=int(k), replace=False)]
        baris_gambar.append(pilih)
        seniman_karya.extend([a_idx] * int(k))
    gambar = pd.concat(baris_gambar, ignore_index=True)
    seniman_karya = np.array(seniman_karya)
    acak = rng.permutation(n_karya)                      # acak urutan supaya id tak berurut per seniman
    gambar, seniman_karya = gambar.iloc[acak].reset_index(drop=True), seniman_karya[acak]

    awal = rng.random(n_karya) < 0.35  # stok awal supaya pool pembelian tidak kosong
    hari_list = np.where(awal, rng.uniform(0, 60, n_karya), rng.uniform(0, HARI_TOTAL - 3, n_karya))
    gaya_karya = gambar["style_name"].to_numpy()
    lebar = np.clip(np.exp(rng.normal(np.log(60), 0.35, n_karya)), 20, 250)
    tinggi = np.clip(lebar * (gambar["tinggi_px"] / gambar["lebar_px"]).to_numpy(), 15, 300)  # rasio dari gambar asli
    luas = lebar * tinggi
    tren_list = np.array([_tren_pada(z, h)[a] for h, a in zip(hari_list, seniman_karya)])
    harga = (
        harga_dasar[seniman_karya]
        * np.array([GAYA_HARGA[g] for g in gaya_karya])
        * np.clip((luas / 4800.0) ** 0.6, 0.4, 4.0)
        * np.exp(0.20 * tren_list)
        * np.exp(rng.normal(0, 0.25, n_karya))
    )
    harga = np.clip(_angka_bulat(harga), 500_000, 3_000_000_000).astype(np.int64)
    karya = pd.DataFrame({
        "id": [_uid("karya", i) for i in range(n_karya)],
        "seniman_id": [seniman["id"].iloc[a] for a in seniman_karya],
        "title": [f"Tanpa Judul ({g.replace('_', ' ')})" for g in gaya_karya],
        "style_name": gaya_karya,
        "image_filename": gambar["filename"].to_numpy(),
        "lebar_cm": np.round(lebar, 1),
        "tinggi_cm": np.round(tinggi, 1),
        "price_idr": harga,
        "created_at": _ts(hari_list),
    })

    # --------------------------------------------------------------- transaksi
    # Penjadwalan: tiap kolektor dijamin >=1 pembelian; sisanya ~ laju kolektor.
    tambahan = rng.choice(n_kolektor, n_transaksi - n_kolektor, p=laju / laju.sum())
    pembeli_idx = np.concatenate([np.arange(n_kolektor), tambahan])
    sisa_hari = HARI_TOTAL - join_k[pembeli_idx] - 1.0
    hari_event = join_k[pembeli_idx] + 1.0 + sisa_hari * rng.beta(1.3, 1.0, n_transaksi)
    urut = np.argsort(hari_event)
    pembeli_idx, hari_event = pembeli_idx[urut], hari_event[urut]

    gaya_idx = np.array([G[g] for g in gaya_karya])
    log_harga = np.log(harga.astype(float))
    log_pop = np.log(popularitas)
    terjual = np.zeros(n_karya, dtype=bool)
    rows = []
    for j, (c, t) in enumerate(zip(pembeli_idx, hari_event)):
        kandidat = np.flatnonzero((hari_list <= t) & ~terjual)
        if kandidat.size == 0:
            raise RuntimeError("pool karya kosong -- naikkan n_karya atau stok awal")
        a = seniman_karya[kandidat]
        tren_t = _tren_pada(z, t)
        u = (
            1.0 * np.log(pref[c, gaya_idx[kandidat]] + 1e-3)
            - 0.7 * (log_harga[kandidat] - anggaran[c]) ** 2 / (2 * sigma[c] ** 2)
            + 0.7 * sens[c] * tren_t[a]
            + 0.3 * log_pop[a]
        )
        p = np.exp((u - u.max()) / 1.2)
        k = rng.choice(kandidat, p=p / p.sum())
        terjual[k] = True
        final = max(int(_angka_bulat(np.array([harga[k] * rng.uniform(0.88, 1.0)]), 3)[0]), 1)
        rows.append({
            "id": _uid("transaksi", j),
            "karya_id": karya["id"].iloc[k],
            "pembeli_id": kolektor["id"].iloc[c],
            "penjual_id": karya["seniman_id"].iloc[k],
            "harga_final_idr": final,
            "komisi_platform_idr": int(round(final * KOMISI_PLATFORM)),
            "status": "selesai",
            "created_at": _ts([t])[0],
        })
    transaksi = pd.DataFrame(rows)
    return {"seniman": seniman, "kolektor": kolektor, "kolektor_label_asli": label,
            "karya": karya, "transaksi": transaksi}


if __name__ == "__main__":
    t = generate()
    for nama, df in t.items():
        print(f"{nama:22s} {len(df):6d} baris")
