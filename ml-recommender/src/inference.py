"""Inferensi live: skor kandidat karya utk 1 kolektor pada 1 waktu tertentu.

Dipakai ``scripts/hitung_rekomendasi.py`` (genda.md Tugas 3) utk mengisi tabel
Neon ``dummy_rekomendasi.rekomendasi_kolektor``. SELURUH rumus fitur di sini
memanggil ``features.fitur_pasangan()`` -- FUNGSI YANG SAMA PERSIS dipakai
``bangun_klasifikasi()`` saat membangun CSV training -- supaya tidak ada
*train/serve skew* (genda.md Tugas 2, poin 1).
"""

from __future__ import annotations

import numpy as np
import pandas as pd

from .features import FITUR, FITUR_KATEGORIKAL, N_GAYA, _Konteks, fitur_pasangan
from .generate import WINDOW_START

# ------------------------------------------------------------------- waktu --
def _ke_hari(waktu) -> float:
    """ISO-8601 string / pd.Timestamp -> float hari sejak WINDOW_START (format
    internal 't' yang dipakai seluruh features.py/_Konteks). Padanan skalar dari
    ``features._hari()`` (yang menerima pd.Series).
    """
    ts = pd.Timestamp(waktu)
    ts = ts.tz_localize("UTC") if ts.tzinfo is None else ts.tz_convert("UTC")
    return (ts - WINDOW_START).total_seconds() / 86400.0


# -------------------------------------------------------- kode alasan (kontrak) --
# Kosakata & ambang batas PERSIS tabel "Kode alasan" di README.md "Kontrak
# antar-bagian" -- JANGAN ubah kode/nama di sini sepihak, itu dipakai Vika &
# backend. Ambang batas numerik ditentukan Genda (didokumentasikan di
# models/LAPORAN_MODEL.md), teks Indonesia utk UI dibuat di BACKEND, bukan di sini.
AMBANG_GAYA_FAVORIT = 0.25          # match_porsi_gaya_ini >= ini
AMBANG_RASIO_HARGA_MIN = 0.6        # match_rasio_harga_vs_rata2 dlm [min, maks]
AMBANG_RASIO_HARGA_MAKS = 1.6
AMBANG_SENIMAN_NAIK_DAUN = 1.5      # seniman_lonjakan_30hari >= ini
AMBANG_KARYA_BARU_HARI = 14         # karya_umur_listing_hari <= ini
# "jauh di atas rata-rata" (README) didefinisikan sbg >= 2x porsi "adil" kalau
# penjualan 30 hari merata ke semua N_GAYA aliran (1/N_GAYA per aliran kalau rata).
AMBANG_GAYA_RAMAI = 2.0 / N_GAYA


def alasan_dari_fitur(baris_fitur: dict) -> list[str]:
    """Kode alasan (BUKAN teks -- lihat README) dari 1 baris fitur hasil
    ``fitur_pasangan()``. Kolektor tanpa riwayat (`kolektor_n_beli_sebelumnya`
    == 0) SELALU dapat kode ``populer_umum`` (cold-start, lihat genda.md Tugas 3
    & README kolom `strategi`) -- kode item-level lain (tren/harga karya) tetap
    bisa menyertai karena tidak bergantung riwayat kolektor.
    """
    kode: list[str] = []
    if baris_fitur["kolektor_n_beli_sebelumnya"] == 0:
        kode.append("populer_umum")

    porsi_gaya = baris_fitur.get("match_porsi_gaya_ini")
    if pd.notna(porsi_gaya) and porsi_gaya >= AMBANG_GAYA_FAVORIT:
        kode.append("gaya_favorit")

    rasio = baris_fitur.get("match_rasio_harga_vs_rata2")
    if (baris_fitur.get("match_harga_dalam_rentang") == 1
            and pd.notna(rasio) and AMBANG_RASIO_HARGA_MIN <= rasio <= AMBANG_RASIO_HARGA_MAKS):
        kode.append("harga_sesuai")

    if baris_fitur["seniman_lonjakan_30hari"] >= AMBANG_SENIMAN_NAIK_DAUN:
        kode.append("seniman_naik_daun")

    gaya_porsi = baris_fitur.get("gaya_porsi_penjualan_30hari")
    if pd.notna(gaya_porsi) and gaya_porsi >= AMBANG_GAYA_RAMAI:
        kode.append("gaya_ramai")

    if baris_fitur["match_n_beli_seniman_ini"] >= 1:
        kode.append("pernah_beli_seniman")

    if baris_fitur["karya_umur_listing_hari"] <= AMBANG_KARYA_BARU_HARI:
        kode.append("karya_baru")

    return kode


# --------------------------------------------------------------- skor_kandidat --
def skor_kandidat(
    bundle: dict,
    tabel: dict[str, pd.DataFrame],
    kolektor_id: str,
    t,
    karya_ids: list[str] | None = None,
) -> pd.DataFrame:
    """Skor semua (atau sebagian) kandidat karya utk 1 kolektor pada waktu ``t``.

    Parameters
    ----------
    bundle : dict
        Isi ``models/klasifikasi_rekomendasi.joblib`` (``model``, ``fitur``,
        ``kategorikal``, dst -- lihat notebooks/01_klasifikasi.ipynb bagian 23).
    tabel : dict[str, DataFrame]
        ``{"seniman":.., "kolektor":.., "karya":.., "transaksi":..}`` -- bentuk
        sama dgn ``db.baca_semua()`` / argumen ``bangun_klasifikasi()``.
    kolektor_id : str
        Kolektor yang mau diberi rekomendasi.
    t : str | pd.Timestamp | float
        Waktu acuan. String/Timestamp dikonversi via ``_ke_hari()``; float
        diasumsikan SUDAH dalam format internal (hari sejak WINDOW_START).
    karya_ids : list[str] | None
        Subset karya yang mau diskor. ``None`` (default) = semua karya yang
        TERSEDIA pada ``t`` (``created_at <= t`` DAN belum ada di `transaksi`,
        lihat genda.md Tugas 3 poin "Alur") -- caller (``hitung_rekomendasi.py``)
        yang bertanggung jawab MENGECUALIKAN karya yang sudah dimiliki kolektor
        itu sendiri kalau perlu (tidak relevan di sini krn karya = barang unik,
        1 karya cuma bisa terjual sekali -- begitu laku, otomatis hilang dari
        `karya_tersedia()`).

    Returns
    -------
    DataFrame[karya_id, skor, alasan] -- BELUM diurutkan/dipotong top-K, itu
    tanggung jawab caller. ``alasan`` = ``list[str]`` kode (lihat
    ``alasan_dari_fitur``), bukan teks siap-tampil.
    """
    cx = _Konteks(tabel["seniman"], tabel["kolektor"], tabel["karya"], tabel["transaksi"])
    kolektor_id = str(kolektor_id)
    if kolektor_id not in cx.kol_join:
        raise KeyError(f"kolektor_id {kolektor_id!r} tidak ditemukan di tabel kolektor")

    t_hari = float(t) if isinstance(t, (int, float)) else _ke_hari(t)

    if karya_ids is None:
        idx_list = cx.karya_tersedia(t_hari)
    else:
        hilang = [kid for kid in karya_ids if str(kid) not in cx.idx_karya]
        if hilang:
            raise KeyError(f"karya_id tidak ditemukan: {hilang}")
        idx_list = np.array([cx.idx_karya[str(kid)] for kid in karya_ids], dtype=int)

    if len(idx_list) == 0:
        return pd.DataFrame({"karya_id": pd.Series(dtype=str), "skor": pd.Series(dtype=float), "alasan": pd.Series(dtype=object)})

    n30_semua = cx.n30_semua(t_hari)
    # SATU-SATUNYA tempat rumus fitur dipanggil -- fungsi yg sama dgn training
    # (bangun_klasifikasi), lihat docstring modul & genda.md Tugas 2.
    fitur_tiap_baris = [fitur_pasangan(cx, kolektor_id, int(i), t_hari, n30_semua) for i in idx_list]

    X = pd.DataFrame(fitur_tiap_baris, columns=bundle["fitur"])
    for c in bundle["kategorikal"]:
        X[c] = X[c].astype("category")

    skor = bundle["model"].predict_proba(X)[:, 1]
    alasan = [alasan_dari_fitur(f) for f in fitur_tiap_baris]

    return pd.DataFrame({
        "karya_id": cx.kr_ids[idx_list],
        "skor": skor,
        "alasan": alasan,
    })
