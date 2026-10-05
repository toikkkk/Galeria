"""Unggah gambar katalog dummy ke Cloudflare R2, lalu catat ``image_key``-nya di Neon.

Kenapa R2, bukan Neon: 2.000 gambar = ~1,6 GB (rata2 800 KB), melebihi free tier Neon
(0,5 GB). Sesuai arsitektur proyek (CLAUDE.md "Cara Kerja Cloudflare R2"): gambar di
R2, database hanya menyimpan KUNCI objek (``karya.image_key``).

Sumber gambar: ``ml-visual-search/data/raw/<image_filename>`` (dataset v1, file ASLI
tanpa re-encode). Key di bucket: ``katalog-dummy/<image_filename>`` -- prefix itu
memisahkan gambar dummy dari unggahan karya sungguhan nanti.

Idempotent & aman diulang: objek yg sudah ada (ukuran sama) dilewati. Setelah
``jalankan_pipeline.py --reset`` (yg mengosongkan ``image_key``), jalankan ulang
skrip ini -- tidak mengunggah ulang, hanya mengisi kembali ``image_key``.

Konfigurasi (env var atau ``backend/.env``) -- BELUM ada di repo, harus dibuat di
dashboard Cloudflare dulu (checklist di CLAUDE.md root, bagian R2):
    R2_ENDPOINT, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET
    R2_PUBLIC_URL_BASE   (opsional di skrip ini; hanya utk mencetak contoh URL)
Nilai rahasia tidak pernah dicetak.

    python scripts/upload_gambar_r2.py --dry-run     # tanpa jaringan: hitung berkas & ukuran
    python scripts/upload_gambar_r2.py               # unggah + isi image_key di Neon
"""

from __future__ import annotations

import argparse
import asyncio
import os
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import pandas as pd
from dotenv import dotenv_values
from sqlalchemy import text

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
from src import db  # noqa: E402

RAW_DIR = ROOT.parent / "ml-visual-search" / "data" / "raw"
PREFIX = "katalog-dummy/"
WAJIB = ["R2_ENDPOINT", "R2_ACCESS_KEY_ID", "R2_SECRET_ACCESS_KEY", "R2_BUCKET"]


def baca_config() -> dict[str, str]:
    env = dotenv_values(ROOT.parent / "backend" / ".env")
    return {k: (os.environ.get(k) or env.get(k) or "") for k in WAJIB + ["R2_PUBLIC_URL_BASE"]}


def key_untuk(filename: str) -> str:
    return f"{PREFIX}{filename}"


def rencana(filenames: list[str], raw_dir: Path = RAW_DIR) -> pd.DataFrame:
    """Daftar unggahan: filename, key, path lokal, ukuran. Error jelas kalau berkas lokal hilang."""
    baris = []
    for fn in filenames:
        p = raw_dir / fn
        if not p.exists():
            raise FileNotFoundError(f"gambar lokal tidak ada: {p}")
        baris.append({"filename": fn, "key": key_untuk(fn), "path": p, "ukuran": p.stat().st_size})
    return pd.DataFrame(baris)


def sinkron(client, bucket: str, plan: pd.DataFrame, kerja: int = 8) -> dict[str, list[str]]:
    """Unggah yang belum ada. Mengembalikan {'diunggah': [...], 'dilewati': [...], 'gagal': [...]} (key)."""
    hasil: dict[str, list[str]] = {"diunggah": [], "dilewati": [], "gagal": []}

    def satu(r) -> tuple[str, str]:
        try:
            try:
                head = client.head_object(Bucket=bucket, Key=r.key)
                if head["ContentLength"] == r.ukuran:
                    return "dilewati", r.key
            except Exception as e:  # noqa: BLE001 -- 404 = belum ada; selain itu coba unggah
                kode = getattr(e, "response", {}).get("Error", {}).get("Code", "")
                if kode not in ("404", "NoSuchKey", "NotFound"):
                    raise
            client.upload_file(
                str(r.path), bucket, r.key,
                ExtraArgs={"ContentType": "image/jpeg", "CacheControl": "public, max-age=31536000, immutable"},
            )
            return "diunggah", r.key
        except Exception:  # noqa: BLE001
            return "gagal", r.key

    with ThreadPoolExecutor(max_workers=kerja) as ex:
        for status, key in ex.map(satu, list(plan.itertuples(index=False))):
            hasil[status].append(key)
    return hasil


async def ambil_filenames() -> list[str]:
    eng = db.buat_engine()
    async with eng.connect() as conn:
        rows = (await conn.execute(text(f"SELECT image_filename FROM {db.SCHEMA}.karya ORDER BY image_filename"))).scalars().all()
    await eng.dispose()
    return list(rows)


async def catat_key(keys_ok: set[str]) -> int:
    eng = db.buat_engine()
    async with eng.begin() as conn:
        # image_key diisi HANYA utk objek yang terbukti ada di R2 -> database tidak pernah menunjuk ke objek hantu
        for key in keys_ok:
            await conn.execute(
                text(f"UPDATE {db.SCHEMA}.karya SET image_key = :k WHERE image_filename = :f"),
                {"k": key, "f": key[len(PREFIX):]},
            )
        terisi = (await conn.execute(text(f"SELECT count(*) FROM {db.SCHEMA}.karya WHERE image_key IS NOT NULL"))).scalar_one()
    await eng.dispose()
    return terisi


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dry-run", action="store_true", help="tanpa jaringan/R2: hanya hitung berkas & ukuran")
    ap.add_argument("--kerja", type=int, default=8, help="jumlah unggahan paralel")
    args = ap.parse_args()

    if args.dry_run:   # tanpa database juga: pakai CSV hasil pipeline
        filenames = sorted(pd.read_csv(ROOT / "data" / "export" / "karya.csv")["image_filename"])
    else:
        filenames = asyncio.run(ambil_filenames())
    plan = rencana(filenames)
    print(f"{len(plan)} gambar, total {plan['ukuran'].sum() / 1e6:.0f} MB; contoh key: {plan['key'].iloc[0]}")
    if args.dry_run:
        print("--dry-run: tidak ada yang diunggah.")
        return 0

    cfg = baca_config()
    kurang = [k for k in WAJIB if not cfg[k]]
    if kurang:
        print("R2 BELUM dikonfigurasi. Variabel kosong:", ", ".join(kurang))
        print("Buat bucket + API token (Object Read & Write) di dashboard Cloudflare, isi di backend/.env")
        print("(langkah lengkap: CLAUDE.md root, 'Checklist setup bucket sungguhan'). Tidak ada yang diubah.")
        return 2

    import boto3
    from botocore.config import Config

    client = boto3.client(
        "s3", endpoint_url=cfg["R2_ENDPOINT"], aws_access_key_id=cfg["R2_ACCESS_KEY_ID"],
        aws_secret_access_key=cfg["R2_SECRET_ACCESS_KEY"], region_name="auto",
        config=Config(retries={"max_attempts": 5, "mode": "standard"}, max_pool_connections=max(10, args.kerja)),
    )
    hasil = sinkron(client, cfg["R2_BUCKET"], plan, kerja=args.kerja)
    print({k: len(v) for k, v in hasil.items()})
    if hasil["gagal"]:
        print("gagal (contoh):", hasil["gagal"][:5])
    ok = set(hasil["diunggah"]) | set(hasil["dilewati"])
    terisi = asyncio.run(catat_key(ok))
    print(f"Neon: image_key terisi utk {terisi} karya.")
    if cfg["R2_PUBLIC_URL_BASE"]:
        print("contoh URL publik:", f"{cfg['R2_PUBLIC_URL_BASE'].rstrip('/')}/{plan['key'].iloc[0]}")
    return 1 if hasil["gagal"] else 0


if __name__ == "__main__":
    sys.exit(main())
