"""Ambil deret bulanan (target + kovariat) dari schema dummy_admin di Neon."""

from __future__ import annotations

import asyncio
import os
import re
import sys
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine

RAIZ = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RAIZ / "data"))
from generate import N_BULAN, awal_bulan, kalender_bulanan  # noqa: E402

load_dotenv(RAIZ.parent / "backend" / ".env")

SCHEMA = os.environ.get("ADMIN_SCHEMA", "dummy_admin")
if not re.fullmatch(r"[a-z_][a-z0-9_]*", SCHEMA):
    raise SystemExit("ADMIN_SCHEMA tidak valid")

# Satu baris per bulan. "Pro" = langganan yg sedang berlaku di akhir bulan, dipisah per role:
# kolektor_pro (AR + gabung Komunitas) dan seniman_pro (promosi karya + buat event/komunitas).
SQL_BULANAN = f"""
WITH bulan AS (
  SELECT d::date AS awal, (d + interval '1 month')::date AS akhir
  FROM generate_series(CAST(:awal AS date), CAST(:akhir AS date), interval '1 month') d
)
SELECT b.awal AS bulan,
  COALESCE((SELECT sum(komisi_platform_idr) FROM {SCHEMA}.transaksi t
            WHERE t.created_at >= b.awal AND t.created_at < b.akhir), 0)::bigint AS komisi_idr,
  COALESCE((SELECT sum(harga_final_idr) FROM {SCHEMA}.transaksi t
            WHERE t.created_at >= b.awal AND t.created_at < b.akhir), 0)::bigint AS gmv_idr,
  (SELECT count(*) FROM {SCHEMA}.transaksi t
    WHERE t.created_at >= b.awal AND t.created_at < b.akhir) AS n_transaksi,
  COALESCE((SELECT sum(p.jumlah_idr) FROM {SCHEMA}.pembayaran_langganan p
            JOIN {SCHEMA}.subscriptions s ON s.id = p.subscription_id
            WHERE s.plan_type = 'kolektor_pro' AND p.dibayar_at >= b.awal AND p.dibayar_at < b.akhir), 0)::bigint
            AS langganan_kolektor_idr,
  COALESCE((SELECT sum(p.jumlah_idr) FROM {SCHEMA}.pembayaran_langganan p
            JOIN {SCHEMA}.subscriptions s ON s.id = p.subscription_id
            WHERE s.plan_type = 'seniman_pro' AND p.dibayar_at >= b.awal AND p.dibayar_at < b.akhir), 0)::bigint
            AS langganan_seniman_idr,
  (SELECT count(*) FROM {SCHEMA}.users u
    WHERE u.created_at >= b.awal AND u.created_at < b.akhir) AS pengguna_baru,
  (SELECT count(*) FROM {SCHEMA}.users u
    WHERE u.created_at < b.akhir AND u.role = 'kolektor') AS n_kolektor,
  (SELECT count(*) FROM {SCHEMA}.users u
    WHERE u.created_at < b.akhir AND u.role = 'seniman') AS n_seniman,
  (SELECT count(DISTINCT s.user_id) FROM {SCHEMA}.subscriptions s
    WHERE s.plan_type = 'kolektor_pro' AND s.mulai_at < b.akhir AND s.berakhir_at >= b.akhir) AS n_pro_kolektor,
  (SELECT count(DISTINCT s.user_id) FROM {SCHEMA}.subscriptions s
    WHERE s.plan_type = 'seniman_pro' AND s.mulai_at < b.akhir AND s.berakhir_at >= b.akhir) AS n_pro_seniman
FROM bulan b ORDER BY b.awal
"""

# target forecast -> kolom di deret bulanan
TARGET = {
    "total": "total_idr",
    "komisi": "komisi_idr",
    "langganan_kolektor": "langganan_kolektor_idr",
    "langganan_seniman": "langganan_seniman_idr",
}


async def _ambil() -> pd.DataFrame:
    url = os.environ.get("DATABASE_URL")
    if not url:
        raise SystemExit("DATABASE_URL belum di-set (backend/.env)")
    engine = create_async_engine(url)
    try:
        async with engine.connect() as conn:
            rows = (await conn.execute(text(SQL_BULANAN), {
                "awal": awal_bulan(0).date(),
                "akhir": awal_bulan(N_BULAN - 1).date()})).mappings().all()
    finally:
        await engine.dispose()
    return _lengkapi(pd.DataFrame(rows))


def _lengkapi(df: pd.DataFrame) -> pd.DataFrame:
    """Kolom turunan + kovariat kalender (dipakai oleh jalur SQL maupun jalur pandas)."""
    df = df.copy()
    df["bulan"] = pd.to_datetime(df["bulan"])
    df["total_idr"] = df["komisi_idr"] + df["langganan_kolektor_idr"] + df["langganan_seniman_idr"]
    df["pro_share_kolektor"] = df["n_pro_kolektor"] / df["n_kolektor"].clip(lower=1)
    df["pro_share_seniman"] = df["n_pro_seniman"] / df["n_seniman"].clip(lower=1)
    kal = kalender_bulanan([b.tz_localize("UTC") for b in df["bulan"]])
    kal["bulan"] = kal["bulan"].dt.tz_localize(None)
    return df.merge(kal, on="bulan")


def bulanan_dari_data(d) -> pd.DataFrame:
    """Deret bulanan yang SAMA dengan SQL_BULANAN, dihitung langsung dari DataDummy (tanpa database).
    Dipakai utk silang-cek terhadap hasil SQL di Neon dan utk uji ketahanan antar-seed."""
    bulan = [awal_bulan(i) for i in range(N_BULAN)]
    tx, pb = d.transaksi, d.pembayaran.merge(d.subscriptions[["id", "plan_type"]],
                                             left_on="subscription_id", right_on="id")
    rows = []
    for b in bulan:
        a = b + pd.offsets.MonthBegin(1)
        t = tx[(tx["created_at"] >= b) & (tx["created_at"] < a)]
        p = pb[(pb["dibayar_at"] >= b) & (pb["dibayar_at"] < a)]
        u = d.users
        s = d.subscriptions
        aktif = s[(s["mulai_at"] < a) & (s["berakhir_at"] >= a)]
        rows.append({
            "bulan": b.tz_localize(None), "komisi_idr": int(t["komisi_platform_idr"].sum()),
            "gmv_idr": int(t["harga_final_idr"].sum()), "n_transaksi": len(t),
            "langganan_kolektor_idr": int(p.loc[p["plan_type"] == "kolektor_pro", "jumlah_idr"].sum()),
            "langganan_seniman_idr": int(p.loc[p["plan_type"] == "seniman_pro", "jumlah_idr"].sum()),
            "pengguna_baru": int(((u["created_at"] >= b) & (u["created_at"] < a)).sum()),
            "n_kolektor": int(((u["created_at"] < a) & (u["role"] == "kolektor")).sum()),
            "n_seniman": int(((u["created_at"] < a) & (u["role"] == "seniman")).sum()),
            "n_pro_kolektor": int(aktif.loc[aktif["plan_type"] == "kolektor_pro", "user_id"].nunique()),
            "n_pro_seniman": int(aktif.loc[aktif["plan_type"] == "seniman_pro", "user_id"].nunique()),
        })
    return _lengkapi(pd.DataFrame(rows))


def muat_bulanan() -> pd.DataFrame:
    return asyncio.run(_ambil())


def kalender_masa_depan(bulan_terakhir: pd.Timestamp, h: int) -> pd.DataFrame:
    """Kovariat kalender utk h bulan setelah bulan_terakhir (diketahui di muka)."""
    bln = [(bulan_terakhir + pd.DateOffset(months=i)).tz_localize("UTC") for i in range(1, h + 1)]
    kal = kalender_bulanan(bln)
    kal["bulan"] = kal["bulan"].dt.tz_localize(None)
    return kal
