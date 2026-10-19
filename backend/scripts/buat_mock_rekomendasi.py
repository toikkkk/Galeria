"""Bangun ulang ``fixtures/rekomendasi_mock.json`` dari keluaran model Genda (CSV) + data Neon.

CSV dimasukkan ke ``rekomendasi_kolektor`` di DALAM satu transaksi yang selalu di-ROLLBACK -- Neon
tidak berubah. Query yang dipakai sama persis dgn endpoint asli (``services.rekomendasi_repo``), jadi
mock memuat bentuk, teks alasan, gambar, dan filter (karya terjual / disembunyikan) yang sama.
Kolektor yang dipilih = yang punya item layak tampil terbanyak.

    python scripts/buat_mock_rekomendasi.py [--csv PATH] [--top-k 10]
"""
import argparse
import asyncio
import csv
import datetime
import json
import os
import sys
import uuid
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND))

from dotenv import load_dotenv  # noqa: E402
from sqlalchemy import text  # noqa: E402
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine  # noqa: E402

from services import rekomendasi_repo as repo  # noqa: E402

load_dotenv(BACKEND / ".env")

ap = argparse.ArgumentParser()
ap.add_argument("--csv", default=str(BACKEND.parent / "ml-recommender" / "data" / "hasil" / "rekomendasi_kolektor.csv"))
ap.add_argument("--top-k", type=int, default=10)
args = ap.parse_args()


def baris_csv(path: str) -> list[dict]:
    hasil = []
    for r in csv.DictReader(open(path, encoding="utf-8")):
        hasil.append({
            **r,
            "peringkat": int(r["peringkat"]),
            "skor": float(r["skor"]),
            "dihitung_pada": datetime.datetime.fromisoformat(r["dihitung_pada"].replace("Z", "+00:00")),
        })
    return hasil


async def main() -> None:
    S = repo._schema()
    rows = baris_csv(args.csv)
    engine = create_async_engine(os.environ["DATABASE_URL"])
    async with AsyncSession(engine) as db:
        async with db.begin():
            await db.execute(
                text(
                    f"""INSERT INTO {S}.rekomendasi_kolektor
                    (kolektor_id, karya_id, peringkat, skor, alasan, strategi, model_version, dihitung_pada)
                    VALUES (CAST(:kolektor_id AS uuid), CAST(:karya_id AS uuid), :peringkat, :skor,
                            CAST(:alasan AS jsonb), :strategi, :model_version, :dihitung_pada)"""
                ),
                rows,
            )
            terbaik = None
            for kid in sorted({r["kolektor_id"] for r in rows}):
                hasil = await repo.rekomendasi(db, uuid.UUID(kid), args.top_k)
                if hasil and (terbaik is None or len(hasil["items"]) > len(terbaik["items"])):
                    terbaik = hasil
            if terbaik is None:
                raise SystemExit("Tidak ada kolektor dengan rekomendasi layak tampil.")
            demo = next(d for d in await repo.kolektor_demo(db, n=200) if d["id"] == terbaik["kolektor_id"]) \
                if any(d["id"] == terbaik["kolektor_id"] for d in await repo.kolektor_demo(db, n=200)) else None
            if demo is None:
                info = (await db.execute(
                    text(f"""SELECT c.id, c.display_name, ks.segmen_nama AS segmen,
                             (SELECT count(*) FROM {S}.transaksi t WHERE t.pembeli_id = c.id) AS n
                             FROM {S}.kolektor c LEFT JOIN {S}.kolektor_segmen ks ON ks.kolektor_id = c.id
                             WHERE c.id = :id"""),
                    {"id": uuid.UUID(terbaik["kolektor_id"])},
                )).mappings().one()
                demo = {"id": str(info["id"]), "display_name": info["display_name"],
                        "segmen": info["segmen"], "n_pembelian": int(info["n"])}
            await db.rollback()  # tidak ada yang tersimpan
    await engine.dispose()

    out = BACKEND / "fixtures" / "rekomendasi_mock.json"
    out.write_text(json.dumps({"kolektor": demo, "rekomendasi": terbaik}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{out.name}: {demo['display_name']} ({demo['segmen']}), {len(terbaik['items'])} item, "
          f"{terbaik['model_version']}, strategi={terbaik['strategi']}")


asyncio.run(main())
