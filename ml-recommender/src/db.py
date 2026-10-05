"""Akses database Neon utk data dummy sistem rekomendasi.

SEMUA objek dibuat di schema TERPISAH ``dummy_rekomendasi`` -- tabel di schema
``public`` (karya, karya_embeddings, dst) TIDAK pernah disentuh. Alasan memakai
schema terpisah (bukan tabel produksi ``users``/``transaksi``/``karya``):

* ``transaksi`` produksi mewajibkan ``payload_hash`` + ``digital_signature`` +
  ``signing_key_id`` (bukti order diproses backend). Mengisi data dummy ke sana
  = memalsukan tanda tangan, dan merusak arti "bukan injeksi DB langsung".
* ``public.karya`` tampil di katalog aplikasi mobile -- 2.000 karya dummy akan
  ikut tampil ke pengguna.
* Dibuang bersih dgn 1 perintah: ``DROP SCHEMA dummy_rekomendasi CASCADE``.

Nama & tipe kolom SENGAJA meniru tabel produksi (``pembeli_id``, ``penjual_id``,
``harga_final_idr``, ``komisi_platform_idr``, ``price_idr``, ``created_at`` ...)
supaya pipeline fitur nanti tinggal diarahkan ke tabel produksi.

DDL ada di sini (bukan migrasi Alembic) dgn sengaja: schema ini bukan bagian
skema produk, dan migrasi baru akan bentrok dgn rantai 0003-0007 milik tim
(multiple heads). Aman diulang (IF NOT EXISTS).
"""

from __future__ import annotations

import os
from decimal import Decimal
from pathlib import Path

import numpy as np
import pandas as pd
from dotenv import dotenv_values
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncConnection, create_async_engine

SCHEMA = "dummy_rekomendasi"
ROOT = Path(__file__).resolve().parent.parent
URUTAN = ["seniman", "kolektor", "kolektor_label_asli", "karya", "transaksi"]  # urutan FK

DDL = [
    f"CREATE SCHEMA IF NOT EXISTS {SCHEMA}",
    f"COMMENT ON SCHEMA {SCHEMA} IS 'DATA SINTETIS utk melatih sistem rekomendasi. Bukan data nyata. Aman di-DROP.'",
    f"""CREATE TABLE IF NOT EXISTS {SCHEMA}.seniman (
        id              UUID PRIMARY KEY,
        display_name    TEXT NOT NULL,
        wikiart_artist  TEXT NOT NULL UNIQUE,
        gaya_utama      TEXT NOT NULL,
        gaya_sekunder   TEXT NULL,
        level_reputasi  TEXT NOT NULL CHECK (level_reputasi IN ('pemula','menengah','mapan')),
        created_at      TIMESTAMPTZ NOT NULL
    )""",
    f"""CREATE TABLE IF NOT EXISTS {SCHEMA}.kolektor (
        id            UUID PRIMARY KEY,
        display_name  TEXT NOT NULL,
        kota          TEXT NOT NULL,
        created_at    TIMESTAMPTZ NOT NULL
    )""",
    f"""CREATE TABLE IF NOT EXISTS {SCHEMA}.kolektor_label_asli (
        kolektor_id  UUID PRIMARY KEY REFERENCES {SCHEMA}.kolektor(id) ON DELETE CASCADE,
        segmen_asli  TEXT NOT NULL
    )""",
    f"""CREATE TABLE IF NOT EXISTS {SCHEMA}.karya (
        id              UUID PRIMARY KEY,
        seniman_id      UUID NOT NULL REFERENCES {SCHEMA}.seniman(id) ON DELETE RESTRICT,
        title           TEXT NOT NULL,
        style_name      TEXT NOT NULL,
        image_filename  TEXT NOT NULL UNIQUE,
        image_key       TEXT NULL,   -- kunci objek di R2; NULL = belum diunggah (diisi scripts/upload_gambar_r2.py)
        lebar_cm        NUMERIC(6,2) NOT NULL,
        tinggi_cm       NUMERIC(6,2) NOT NULL,
        price_idr       BIGINT NOT NULL CHECK (price_idr > 0),
        created_at      TIMESTAMPTZ NOT NULL
    )""",
    f"""CREATE TABLE IF NOT EXISTS {SCHEMA}.transaksi (
        id                   UUID PRIMARY KEY,
        karya_id             UUID NOT NULL UNIQUE REFERENCES {SCHEMA}.karya(id) ON DELETE RESTRICT,
        pembeli_id           UUID NOT NULL REFERENCES {SCHEMA}.kolektor(id) ON DELETE RESTRICT,
        penjual_id           UUID NOT NULL REFERENCES {SCHEMA}.seniman(id) ON DELETE RESTRICT,
        harga_final_idr      BIGINT NOT NULL CHECK (harga_final_idr > 0),
        komisi_platform_idr  BIGINT NOT NULL CHECK (komisi_platform_idr >= 0),
        status               TEXT NOT NULL DEFAULT 'selesai' CHECK (status IN ('selesai')),
        created_at           TIMESTAMPTZ NOT NULL
    )""",
    f"CREATE INDEX IF NOT EXISTS karya_seniman_id_idx ON {SCHEMA}.karya (seniman_id)",
    f"CREATE INDEX IF NOT EXISTS karya_style_name_idx ON {SCHEMA}.karya (style_name)",
    f"CREATE INDEX IF NOT EXISTS transaksi_pembeli_idx ON {SCHEMA}.transaksi (pembeli_id, created_at)",
    f"CREATE INDEX IF NOT EXISTS transaksi_penjual_idx ON {SCHEMA}.transaksi (penjual_id, created_at)",
    # Dashboard seniman: metrik penjualan per bulan (dipakai juga utk CSV & dicocokkan dgn pandas).
    f"""CREATE OR REPLACE VIEW {SCHEMA}.v_seniman_metrik_bulanan AS
        SELECT t.penjual_id                                              AS seniman_id,
               to_char(date_trunc('month', t.created_at AT TIME ZONE 'UTC'), 'YYYY-MM-DD') AS bulan,
               count(*)                                                  AS n_terjual,
               sum(t.harga_final_idr)::bigint                            AS omzet_idr,
               sum(t.komisi_platform_idr)::bigint                        AS komisi_platform_idr,
               sum(t.harga_final_idr - t.komisi_platform_idr)::bigint    AS pendapatan_bersih_idr,
               round(avg(t.harga_final_idr))::bigint                     AS harga_rata2_idr,
               max(t.harga_final_idr)                                    AS harga_maks_idr,
               count(DISTINCT t.pembeli_id)                              AS n_pembeli_unik,
               mode() WITHIN GROUP (ORDER BY k.style_name)               AS gaya_terlaris
        FROM {SCHEMA}.transaksi t
        JOIN {SCHEMA}.karya k ON k.id = t.karya_id
        WHERE t.status = 'selesai'
        GROUP BY 1, 2""",
]

KOLOM = {
    "seniman": ["id", "display_name", "wikiart_artist", "gaya_utama", "gaya_sekunder", "level_reputasi", "created_at"],
    "kolektor": ["id", "display_name", "kota", "created_at"],
    "kolektor_label_asli": ["kolektor_id", "segmen_asli"],
    "karya": ["id", "seniman_id", "title", "style_name", "image_filename", "lebar_cm", "tinggi_cm", "price_idr", "created_at"],
    "transaksi": ["id", "karya_id", "pembeli_id", "penjual_id", "harga_final_idr", "komisi_platform_idr", "status", "created_at"],
}
DESIMAL = {"lebar_cm", "tinggi_cm"}


def database_url() -> str:
    url = os.environ.get("DATABASE_URL") or dotenv_values(ROOT.parent / "backend" / ".env").get("DATABASE_URL", "")
    if not url:
        raise RuntimeError("DATABASE_URL tidak ditemukan (env var atau backend/.env) -- lihat backend/.env.example")
    return url


def buat_engine():
    return create_async_engine(database_url(), pool_pre_ping=True)


def _py(v, kolom: str):
    """numpy/pandas -> tipe Python murni yang diterima asyncpg."""
    if v is None or (not isinstance(v, (str, bytes)) and pd.isna(v)):
        return None
    if isinstance(v, pd.Timestamp):
        return v.to_pydatetime()
    if isinstance(v, np.generic):
        v = v.item()
    if kolom in DESIMAL:
        return Decimal(f"{float(v):.2f}")
    return v


async def pastikan_schema(conn: AsyncConnection) -> None:
    for stmt in DDL:
        await conn.execute(text(stmt))


async def hitung(conn: AsyncConnection) -> dict[str, int]:
    return {t: (await conn.execute(text(f"SELECT count(*) FROM {SCHEMA}.{t}"))).scalar_one() for t in URUTAN}


async def hitung_public(conn: AsyncConnection) -> dict[str, int]:
    """Jumlah baris semua tabel di schema public -- dipakai membuktikan tak ada yang berubah."""
    tabel = (await conn.execute(text(
        "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE' ORDER BY 1"
    ))).scalars().all()
    return {t: (await conn.execute(text(f'SELECT count(*) FROM public."{t}"'))).scalar_one() for t in tabel}


async def kosongkan(conn: AsyncConnection) -> None:
    await conn.execute(text(f"TRUNCATE {', '.join(f'{SCHEMA}.{t}' for t in URUTAN)} RESTART IDENTITY CASCADE"))


async def isi(conn: AsyncConnection, data: dict[str, pd.DataFrame], ukuran_batch: int = 500) -> None:
    for t in URUTAN:
        df, kol = data[t], KOLOM[t]
        sql = text(f"INSERT INTO {SCHEMA}.{t} ({', '.join(kol)}) VALUES ({', '.join(':' + c for c in kol)})")
        baris = [{c: _py(r[c], c) for c in kol} for r in df[kol].to_dict("records")]
        for i in range(0, len(baris), ukuran_batch):
            await conn.execute(sql, baris[i:i + ukuran_batch])


async def baca(conn: AsyncConnection, nama: str) -> pd.DataFrame:
    hasil = await conn.execute(text(f"SELECT * FROM {SCHEMA}.{nama}"))
    return pd.DataFrame(hasil.mappings().all())


async def baca_semua(conn: AsyncConnection) -> dict[str, pd.DataFrame]:
    return {t: await baca(conn, t) for t in URUTAN}
