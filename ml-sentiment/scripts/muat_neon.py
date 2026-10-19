"""Muat ``data/hasil/sentimen_ulasan.csv`` (keluaran ``src/train.py``) ke Neon, schema ``dummy_sentimen``.

Idempotent: buat schema/tabel bila belum ada, lalu DELETE + INSERT dalam SATU transaksi.
Hanya menyentuh ``dummy_sentimen.*``. Butuh ``DATABASE_URL`` (env atau ``backend/.env``).

    python scripts/muat_neon.py [--dry-run]
"""
import argparse
import asyncio
import csv
import os
from datetime import datetime, timezone
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine

ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT.parent / "backend" / ".env")
CSV = ROOT / "data" / "hasil" / "sentimen_ulasan.csv"
# buang komentar "--" (termasuk di akhir baris) sebelum dipecah per ";"
DDL = "\n".join(l.split("--")[0] for l in (ROOT / "sql" / "dummy_sentimen.sql").read_text(encoding="utf-8").splitlines())

ap = argparse.ArgumentParser()
ap.add_argument("--dry-run", action="store_true", help="hanya baca CSV & validasi, Neon tidak disentuh")
args = ap.parse_args()


def baris() -> list[dict]:
    hasil = []
    for r in csv.DictReader(open(CSV, encoding="utf-8")):
        hasil.append({
            "ulasan_id": r["ulasan_id"], "transaksi_id": r["transaksi_id"], "karya_id": r["karya_id"],
            "kolektor_id": r["kolektor_id"], "seniman_id": r["seniman_id"], "teks": r["teks"],
            "rating": int(r["rating"]), "sentimen_label": r["sentimen"], "split": r["split"],
            "sentimen_prediksi": r["sentimen_prediksi"], "prob_negatif": float(r["prob_negatif"]),
            "prob_netral": float(r["prob_netral"]), "prob_positif": float(r["prob_positif"]),
            "model_version": r["model_version"],
            "created_at": datetime.fromisoformat(r["created_at"].replace("Z", "+00:00")),
        })
    return hasil


async def main() -> None:
    rows = baris()
    print(f"{len(rows)} baris dibaca dari {CSV.name}")
    if args.dry_run:
        return
    url = os.environ.get("DATABASE_URL")
    if not url:
        raise SystemExit("DATABASE_URL belum di-set (backend/.env)")
    engine = create_async_engine(url)
    async with engine.begin() as conn:
        for stmt in [s.strip() for s in DDL.split(";") if s.strip()]:
            await conn.execute(text(stmt))
        await conn.execute(text("DELETE FROM dummy_sentimen.ulasan WHERE sumber = 'dummy'"))  # ulasan 'app' (ditulis kolektor) TIDAK dihapus
        await conn.execute(
            text("""INSERT INTO dummy_sentimen.ulasan
                (ulasan_id, transaksi_id, karya_id, kolektor_id, seniman_id, teks, rating, sentimen_label, split,
                 sentimen_prediksi, prob_negatif, prob_netral, prob_positif, model_version, created_at, dihitung_pada, sumber)
                VALUES (CAST(:ulasan_id AS uuid), CAST(:transaksi_id AS uuid), CAST(:karya_id AS uuid),
                        CAST(:kolektor_id AS uuid), CAST(:seniman_id AS uuid), :teks, :rating, :sentimen_label, :split,
                        :sentimen_prediksi, :prob_negatif, :prob_netral, :prob_positif, :model_version, :created_at, now(), 'dummy')"""),
            rows,
        )
        n = (await conn.execute(text("SELECT count(*) FROM dummy_sentimen.ulasan WHERE sumber = 'dummy'"))).scalar()
    await engine.dispose()
    print(f"dummy_sentimen.ulasan terisi: {n} baris")


asyncio.run(main())
