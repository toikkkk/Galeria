"""Isi schema dummy_admin di Neon dengan data contoh (idempotent: kosongkan lalu isi ulang).

    cd dashboard-admin
    .venv\\Scripts\\python data\\muat_neon.py          # buat tabel + isi
    .venv\\Scripts\\python data\\muat_neon.py --hapus  # DROP SCHEMA dummy_admin CASCADE

Membaca DATABASE_URL dari backend/.env. TIDAK menyentuh public.*.
"""

from __future__ import annotations

import argparse
import asyncio
import os
import sys
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine

RAIZ = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RAIZ / "data"))
from generate import buat_data  # noqa: E402

load_dotenv(RAIZ.parent / "backend" / ".env")


async def _insert(conn, tabel: str, df: pd.DataFrame, kolom: list[str]):
    cols = ", ".join(kolom)
    params = ", ".join(f":{c}" for c in kolom)
    stmt = text(f"INSERT INTO dummy_admin.{tabel} ({cols}) VALUES ({params})")
    rows = [{c: (v.to_pydatetime() if isinstance(v, pd.Timestamp) else v) for c, v in r.items()}
            for r in df[kolom].to_dict("records")]
    for i in range(0, len(rows), 1000):
        await conn.execute(stmt, rows[i:i + 1000])


async def main(hapus: bool):
    url = os.environ.get("DATABASE_URL")
    if not url:
        raise SystemExit("DATABASE_URL belum di-set (backend/.env)")
    engine = create_async_engine(url)
    async with engine.begin() as conn:
        if hapus:
            await conn.execute(text("DROP SCHEMA IF EXISTS dummy_admin CASCADE"))
            print("schema dummy_admin dihapus")
            return
        # Bangun ulang bersih: schema ini milik dashboard admin saja (data contoh + hasil forecast).
        await conn.execute(text("DROP SCHEMA IF EXISTS dummy_admin CASCADE"))
        ddl = (RAIZ / "sql" / "dummy_admin.sql").read_text(encoding="utf-8")
        # buang komentar baris, lalu pecah per statement
        ddl = "\n".join(l for l in ddl.splitlines() if not l.strip().startswith("--"))
        for stmt in [s.strip() for s in ddl.split(";") if s.strip()]:
            await conn.execute(text(stmt))
        d = buat_data()
        await _insert(conn, "users", d.users, ["id", "role", "display_name", "created_at"])
        await _insert(conn, "subscriptions", d.subscriptions,
                      ["id", "user_id", "plan_type", "status", "harga_bulanan_idr", "mulai_at", "berakhir_at"])
        await _insert(conn, "pembayaran_langganan", d.pembayaran,
                      ["id", "subscription_id", "dibayar_at", "jumlah_idr"])
        await _insert(conn, "transaksi", d.transaksi,
                      ["id", "karya_id", "pembeli_id", "penjual_id", "harga_final_idr",
                       "komisi_platform_idr", "created_at"])
        for t in ("users", "subscriptions", "pembayaran_langganan", "transaksi"):
            n = (await conn.execute(text(f"SELECT count(*) FROM dummy_admin.{t}"))).scalar()
            print(f"dummy_admin.{t}: {n} baris")
    await engine.dispose()


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--hapus", action="store_true")
    asyncio.run(main(ap.parse_args().hapus))
