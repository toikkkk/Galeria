"""Urutan baris KANONIK utk tabel dummy -- supaya pipeline tidak bergantung pada urutan fisik Postgres.

Masalah yang diperbaiki: ``SELECT *`` tanpa ``ORDER BY`` tidak menjamin urutan baris. Setelah ``UPDATE``
(mis. mengisi ``image_key`` dari ``scripts/upload_gambar_r2.py``) Postgres menyimpan ulang baris dalam urutan
lain. Pemilihan karya negatif di ``features.bangun_klasifikasi`` memakai posisi baris, sehingga seluruh negatif
berubah padahal datanya sama (ditemukan 2026-10-05: 1.400 dari 1.400 grup berubah).

Urutan kanonik = urutan pembuatan oleh generator. Id dibuat ``uuid5(NAMESPACE, f"{tabel}-{i}")`` (lihat
``generate._uid``), jadi indeks ``i`` bisa dipulihkan dari id. Dengan itu dataset yang SUDAH dibagikan ke tim
tetap bisa direproduksi persis. Id yang bukan hasil generator (mis. data nyata) diletakkan sesudahnya,
terurut menurut id -- tetap deterministik.
"""

from __future__ import annotations

import uuid

import pandas as pd

from .generate import NAMESPACE


def urutkan(df: pd.DataFrame, kolom_id: str, prefix: str) -> pd.DataFrame:
    ids = df[kolom_id].astype(str)
    peta = {str(uuid.uuid5(NAMESPACE, f"{prefix}-{i}")): i for i in range(len(df))}
    kunci = ids.map(peta).fillna(len(df) + 1).to_numpy()
    return (df.assign(_kunci=kunci, _id=ids.to_numpy())
              .sort_values(["_kunci", "_id"], kind="mergesort")
              .drop(columns=["_kunci", "_id"])
              .reset_index(drop=True))


# tabel -> (kolom id, prefix id generator)
KUNCI_TABEL = {
    "seniman": ("id", "seniman"),
    "kolektor": ("id", "kolektor"),
    "kolektor_label_asli": ("kolektor_id", "kolektor"),
    "karya": ("id", "karya"),
    "transaksi": ("id", "transaksi"),
}
