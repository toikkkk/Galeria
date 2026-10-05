"""Query dashboard seniman -- SQL mentah ke schema data dummy rekomendasi.

Schema dibaca dari env ``REKOMENDASI_SCHEMA`` (divalidasi regex sebelum
disisipkan ke SQL; nama schema tidak bisa di-bind sebagai parameter). Semua
jendela waktu dihitung mundur dari ``REKOMENDASI_WAKTU_ACUAN`` (akhir data
dummy), BUKAN ``now()``. Tidak menyentuh ``public.*`` dan tidak memakai model
ORM/Alembic.

Catatan asyncpg: parameter waktu wajib ``CAST(:t AS timestamptz)``.
"""

from __future__ import annotations

import os
import re
import uuid
from datetime import datetime, timezone

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

_SCHEMA_RE = re.compile(r"^[a-z_][a-z0-9_]*$")
_DEFAULT_ACUAN = "2026-09-30T23:59:59Z"


def _schema() -> str:
    s = os.environ.get("REKOMENDASI_SCHEMA", "dummy_rekomendasi")
    if not _SCHEMA_RE.match(s):
        raise RuntimeError("REKOMENDASI_SCHEMA tidak valid (harus ^[a-z_][a-z0-9_]*$)")
    return s


def waktu_acuan() -> datetime:
    raw = os.environ.get("REKOMENDASI_WAKTU_ACUAN", _DEFAULT_ACUAN).strip()
    dt = datetime.fromisoformat(raw.replace("Z", "+00:00"))
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def parse_uuid(value: str) -> uuid.UUID | None:
    try:
        return uuid.UUID(value)
    except ValueError:
        return None


def _pct(sekarang: float, sebelum: float) -> float | None:
    if not sebelum:
        return None
    return round((sekarang - sebelum) / sebelum * 100, 1)


async def daftar_seniman_demo(db: AsyncSession) -> list[dict]:
    S = _schema()
    rows = await db.execute(
        text(
            f"""
            SELECT s.id, s.display_name, s.level_reputasi, count(tr.id) AS n_terjual
            FROM {S}.seniman s
            LEFT JOIN {S}.transaksi tr
              ON tr.penjual_id = s.id AND tr.created_at <= CAST(:t AS timestamptz)
            GROUP BY s.id, s.display_name, s.level_reputasi
            ORDER BY n_terjual DESC, s.display_name
            """
        ),
        {"t": waktu_acuan()},
    )
    return [
        {
            "id": str(r.id),
            "display_name": r.display_name,
            "level_reputasi": r.level_reputasi,
            "n_terjual": int(r.n_terjual),
        }
        for r in rows
    ]


async def get_seniman(db: AsyncSession, sid: uuid.UUID) -> dict | None:
    S = _schema()
    r = (
        await db.execute(
            text(f"SELECT id, display_name, level_reputasi FROM {S}.seniman WHERE id = :sid"),
            {"sid": sid},
        )
    ).first()
    if r is None:
        return None
    return {"id": str(r.id), "display_name": r.display_name, "level_reputasi": r.level_reputasi}


async def _agregat_periode(db: AsyncSession, sid: uuid.UUID, t: datetime, p: int, offset: int):
    """Agregat transaksi di jendela (t - offset - p hari, t - offset hari]."""
    S = _schema()
    return (
        await db.execute(
            text(
                f"""
                SELECT count(*) AS n,
                       COALESCE(sum(harga_final_idr),0)::bigint AS omzet,
                       COALESCE(sum(komisi_platform_idr),0)::bigint AS komisi,
                       COALESCE(round(avg(harga_final_idr)),0)::bigint AS rata2,
                       count(DISTINCT pembeli_id) AS pembeli
                FROM {S}.transaksi
                WHERE penjual_id = :sid
                  AND created_at >  CAST(:t AS timestamptz) - make_interval(days => :lo)
                  AND created_at <= CAST(:t AS timestamptz) - make_interval(days => :hi)
                """
            ),
            {"sid": sid, "t": t, "lo": offset + p, "hi": offset},
        )
    ).one()


async def ringkasan(db: AsyncSession, seniman: dict, sid: uuid.UUID, periode: int) -> dict:
    S = _schema()
    t = waktu_acuan()
    cur = await _agregat_periode(db, sid, t, periode, 0)
    prev = await _agregat_periode(db, sid, t, periode, periode)
    stok = (
        await db.execute(
            text(
                f"""
                SELECT count(*) FILTER (WHERE tr.id IS NULL) AS tersedia,
                       count(*) FILTER (WHERE tr.id IS NOT NULL) AS terjual
                FROM {S}.karya k LEFT JOIN {S}.transaksi tr ON tr.karya_id = k.id
                WHERE k.seniman_id = :sid AND k.created_at <= CAST(:t AS timestamptz)
                """
            ),
            {"sid": sid, "t": t},
        )
    ).one()
    return {
        "seniman": seniman,
        "periode_hari": periode,
        "n_terjual": int(cur.n),
        "omzet_idr": int(cur.omzet),
        "komisi_platform_idr": int(cur.komisi),
        "pendapatan_bersih_idr": int(cur.omzet - cur.komisi),
        "harga_rata2_idr": int(cur.rata2),
        "n_pembeli_unik": int(cur.pembeli),
        "karya_tersedia": int(stok.tersedia),
        "karya_terjual_total": int(stok.terjual),
        "perubahan_pct": {
            "n_terjual": _pct(cur.n, prev.n),
            "omzet_idr": _pct(cur.omzet, prev.omzet),
        },
    }


def _bulan_terakhir(t: datetime, n: int) -> list[str]:
    """N awal-bulan (YYYY-MM-01) berakhir di bulan ``t``, urut lama -> baru (UTC)."""
    t = t.astimezone(timezone.utc)
    y, m = t.year, t.month
    out: list[str] = []
    for _ in range(n):
        out.append(f"{y:04d}-{m:02d}-01")
        m -= 1
        if m == 0:
            y, m = y - 1, 12
    return out[::-1]


async def penjualan_bulanan(db: AsyncSession, sid: uuid.UUID, n_bulan: int) -> list[dict]:
    S = _schema()
    deret = _bulan_terakhir(waktu_acuan(), n_bulan)
    rows = await db.execute(
        text(
            f"""
            SELECT bulan, n_terjual, omzet_idr, harga_rata2_idr, n_pembeli_unik, gaya_terlaris
            FROM {S}.v_seniman_metrik_bulanan
            WHERE seniman_id = :sid AND bulan >= :awal AND bulan <= :akhir
            """
        ),
        {"sid": sid, "awal": deret[0], "akhir": deret[-1]},
    )
    ada = {r.bulan: r for r in rows}
    hasil = []
    for b in deret:
        r = ada.get(b)
        hasil.append(
            {
                "bulan": b,
                "n_terjual": int(r.n_terjual) if r else 0,
                "omzet_idr": int(r.omzet_idr) if r else 0,
                "harga_rata2_idr": int(r.harga_rata2_idr) if r else 0,
                "n_pembeli_unik": int(r.n_pembeli_unik) if r else 0,
                "gaya_terlaris": r.gaya_terlaris if r else None,
            }
        )
    return hasil


async def aliran(db: AsyncSession, sid: uuid.UUID) -> list[dict]:
    S = _schema()
    rows = await db.execute(
        text(
            f"""
            WITH pasar AS (
                SELECT k.style_name, round(avg(tr.harga_final_idr))::bigint AS rata2
                FROM {S}.transaksi tr JOIN {S}.karya k ON k.id = tr.karya_id
                WHERE tr.created_at <= CAST(:t AS timestamptz)
                GROUP BY k.style_name
            )
            SELECT k.style_name,
                   count(*) AS n,
                   sum(tr.harga_final_idr)::bigint AS omzet,
                   round(avg(tr.harga_final_idr))::bigint AS rata2,
                   p.rata2 AS pasar
            FROM {S}.transaksi tr
            JOIN {S}.karya k ON k.id = tr.karya_id
            JOIN pasar p ON p.style_name = k.style_name
            WHERE tr.penjual_id = :sid AND tr.created_at <= CAST(:t AS timestamptz)
            GROUP BY k.style_name, p.rata2
            ORDER BY n DESC, omzet DESC
            """
        ),
        {"sid": sid, "t": waktu_acuan()},
    )
    return [
        {
            "style_name": r.style_name,
            "n_terjual": int(r.n),
            "omzet_idr": int(r.omzet),
            "harga_rata2_idr": int(r.rata2),
            "harga_pasar_rata2_idr": int(r.pasar),
            "selisih_pct": _pct(r.rata2, r.pasar),
        }
        for r in rows
    ]


async def segmen_pembeli(db: AsyncSession, sid: uuid.UUID) -> dict:
    S = _schema()
    total_tabel = (await db.execute(text(f"SELECT count(*) FROM {S}.kolektor_segmen"))).scalar_one()
    if total_tabel == 0:
        return {"tersedia": False, "items": []}
    rows = (
        await db.execute(
            text(
                f"""
                SELECT ks.segmen_id, ks.segmen_nama, sk.deskripsi,
                       count(DISTINCT tr.pembeli_id) AS n_pembeli
                FROM {S}.transaksi tr
                JOIN {S}.kolektor_segmen ks ON ks.kolektor_id = tr.pembeli_id
                LEFT JOIN {S}.segmen_kamus sk ON sk.segmen_id = ks.segmen_id
                WHERE tr.penjual_id = :sid AND tr.created_at <= CAST(:t AS timestamptz)
                GROUP BY ks.segmen_id, ks.segmen_nama, sk.deskripsi
                ORDER BY n_pembeli DESC, ks.segmen_id
                """
            ),
            {"sid": sid, "t": waktu_acuan()},
        )
    ).all()
    jumlah = sum(r.n_pembeli for r in rows)
    items = [
        {
            "segmen_id": int(r.segmen_id),
            "segmen_nama": r.segmen_nama,
            "n_pembeli": int(r.n_pembeli),
            "porsi_pct": round(r.n_pembeli / jumlah * 100, 1) if jumlah else None,
            "deskripsi": r.deskripsi,
        }
        for r in rows
    ]
    return {"tersedia": True, "items": items}


async def tren_pasar(db: AsyncSession) -> dict:
    S = _schema()
    t = waktu_acuan()
    seniman_rows = await db.execute(
        text(
            f"""
            SELECT s.id, s.display_name,
                   count(*) FILTER (WHERE tr.created_at > CAST(:t AS timestamptz) - make_interval(days => 30)) AS n30,
                   count(*) AS n90,
                   COALESCE(round(avg(tr.harga_final_idr) FILTER (
                       WHERE tr.created_at > CAST(:t AS timestamptz) - make_interval(days => 30))), 0)::bigint AS rata2_30
            FROM {S}.transaksi tr JOIN {S}.seniman s ON s.id = tr.penjual_id
            WHERE tr.created_at >  CAST(:t AS timestamptz) - make_interval(days => 90)
              AND tr.created_at <= CAST(:t AS timestamptz)
            GROUP BY s.id, s.display_name
            """
        ),
        {"t": t},
    )
    seniman = []
    for r in seniman_rows:
        if r.n30 == 0:
            continue
        # rumus yang sama dengan fitur model: (n30+1) / ((n90-n30)/2 + 1)
        lonjakan = (r.n30 + 1) / ((r.n90 - r.n30) / 2 + 1)
        seniman.append(
            {
                "seniman_id": str(r.id),
                "display_name": r.display_name,
                "n_terjual_30hari": int(r.n30),
                "lonjakan": round(lonjakan, 2),
                "harga_rata2_30hari_idr": int(r.rata2_30),
            }
        )
    seniman.sort(key=lambda x: (-x["n_terjual_30hari"], -x["lonjakan"]))

    aliran_rows = (
        await db.execute(
            text(
                f"""
                SELECT k.style_name, count(*) AS n30,
                       round(avg(tr.harga_final_idr))::bigint AS rata2
                FROM {S}.transaksi tr JOIN {S}.karya k ON k.id = tr.karya_id
                WHERE tr.created_at >  CAST(:t AS timestamptz) - make_interval(days => 30)
                  AND tr.created_at <= CAST(:t AS timestamptz)
                GROUP BY k.style_name
                ORDER BY n30 DESC, k.style_name
                """
            ),
            {"t": t},
        )
    ).all()
    total = sum(r.n30 for r in aliran_rows)
    aliran_ramai = [
        {
            "style_name": r.style_name,
            "n_terjual_30hari": int(r.n30),
            "porsi_penjualan_pct": round(r.n30 / total * 100, 1) if total else None,
            "harga_rata2_30hari_idr": int(r.rata2),
        }
        for r in aliran_rows
    ]
    return {"seniman_ramai": seniman[:10], "aliran_ramai": aliran_ramai}
