"""Query dashboard admin -- pendapatan platform (komisi 2,5% + langganan Pro), SQL mentah ke
schema data contoh ``dummy_admin``.

Schema dari env ``ADMIN_SCHEMA`` (divalidasi regex). Jendela waktu dihitung mundur dari
``ADMIN_WAKTU_ACUAN`` (default 2026-09-30, akhir data contoh), bukan ``now()``.
Backend hanya MEMBACA hasil forecasting (ditulis batch oleh
``dashboard-admin/forecasting/jalankan.py``); tidak ada model ML di server.
Tidak menyentuh ``public.*``, tidak memakai ORM/Alembic.

Catatan asyncpg: parameter waktu wajib ``CAST(:t AS timestamptz)``.
"""

from __future__ import annotations

import json
import os
import re
from datetime import date, datetime, timezone

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

_SCHEMA_RE = re.compile(r"^[a-z_][a-z0-9_]*$")
TARIF_KOMISI_PCT = 2.5
# Rp/bulan. Kolektor: AR + gabung Komunitas. Seniman: promosi karya, buat event, buat komunitas.
HARGA_PRO = {"kolektor": 50_000, "seniman": 150_000}
PLAN = {"kolektor": "kolektor_pro", "seniman": "seniman_pro"}
TARGET_VALID = ("total", "komisi", "langganan_kolektor", "langganan_seniman")
_KOLOM_TARGET = {"total": "total_idr", "komisi": "komisi_idr",
                 "langganan_kolektor": "langganan_kolektor_idr", "langganan_seniman": "langganan_seniman_idr"}


def _schema() -> str:
    s = os.environ.get("ADMIN_SCHEMA", "dummy_admin")
    if not _SCHEMA_RE.match(s):
        raise RuntimeError("ADMIN_SCHEMA tidak valid (harus ^[a-z_][a-z0-9_]*$)")
    return s


def waktu_acuan() -> datetime:
    raw = os.environ.get("ADMIN_WAKTU_ACUAN", "2026-09-30T23:59:59Z").strip()
    dt = datetime.fromisoformat(raw.replace("Z", "+00:00"))
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def _pct(sekarang: float, sebelum: float) -> float | None:
    if not sebelum:
        return None
    return round((sekarang - sebelum) / sebelum * 100, 1)


def daftar_bulan(n: int) -> list[date]:
    """n awal-bulan terakhir, berakhir di bulan waktu acuan (urut naik)."""
    a = waktu_acuan()
    y, m = a.year, a.month
    out = []
    for _ in range(n):
        out.append(date(y, m, 1))
        m -= 1
        if m == 0:
            y, m = y - 1, 12
    return out[::-1]


def _bulan_berikut(d: date) -> date:
    return date(d.year + (d.month == 12), 1 if d.month == 12 else d.month + 1, 1)


async def tabel_ada(db: AsyncSession, nama: str) -> bool:
    r = await db.execute(text("SELECT to_regclass(:n)"), {"n": f"{_schema()}.{nama}"})
    return r.scalar() is not None


async def ringkasan(db: AsyncSession, periode: int) -> dict:
    S, t = _schema(), waktu_acuan()

    async def jendela(a: int, b: int) -> dict:
        p = {"t": t, "a": a, "b": b}
        tx = (await db.execute(text(
            f"""SELECT COALESCE(sum(komisi_platform_idr),0)::bigint, COALESCE(sum(harga_final_idr),0)::bigint, count(*)
                FROM {S}.transaksi
                WHERE created_at >  CAST(:t AS timestamptz) - make_interval(days => :a)
                  AND created_at <= CAST(:t AS timestamptz) - make_interval(days => :b)"""), p)).one()
        lang = dict((await db.execute(text(
            f"""SELECT s.plan_type, COALESCE(sum(p.jumlah_idr),0)::bigint
                FROM {S}.pembayaran_langganan p JOIN {S}.subscriptions s ON s.id = p.subscription_id
                WHERE p.dibayar_at >  CAST(:t AS timestamptz) - make_interval(days => :a)
                  AND p.dibayar_at <= CAST(:t AS timestamptz) - make_interval(days => :b)
                GROUP BY 1"""), p)).all())
        lk, ls = int(lang.get(PLAN["kolektor"], 0)), int(lang.get(PLAN["seniman"], 0))
        return {"komisi": int(tx[0]), "gmv": int(tx[1]), "n": int(tx[2]), "lk": lk, "ls": ls,
                "total": int(tx[0]) + lk + ls}

    now, prev = await jendela(periode, 0), await jendela(2 * periode, periode)

    pro = {}
    for role, plan in PLAN.items():
        r = await db.execute(text(
            f"""SELECT (SELECT count(*) FROM {S}.users WHERE role = :role AND created_at <= CAST(:t AS timestamptz)),
                       (SELECT count(DISTINCT user_id) FROM {S}.subscriptions
                         WHERE plan_type = :plan AND mulai_at <= CAST(:t AS timestamptz)
                           AND berakhir_at > CAST(:t AS timestamptz))"""), {"role": role, "plan": plan, "t": t})
        n_user, n_pro = (int(x) for x in r.one())
        pro[role] = {"n_pro": n_pro, "n_pengguna": n_user,
                     "pro_share_pct": round(n_pro / n_user * 100, 1) if n_user else None}
    return {
        "periode_hari": periode, "tarif_komisi_pct": TARIF_KOMISI_PCT,
        "harga_pro_kolektor_idr": HARGA_PRO["kolektor"], "harga_pro_seniman_idr": HARGA_PRO["seniman"],
        "pendapatan_total_idr": now["total"], "komisi_idr": now["komisi"],
        "langganan_kolektor_idr": now["lk"], "langganan_seniman_idr": now["ls"],
        "gmv_idr": now["gmv"], "n_transaksi": now["n"],
        "perubahan_pct": {"total_idr": _pct(now["total"], prev["total"]),
                          "komisi_idr": _pct(now["komisi"], prev["komisi"]),
                          "langganan_idr": _pct(now["lk"] + now["ls"], prev["lk"] + prev["ls"])},
        "pro": pro,
    }


async def pendapatan_bulanan(db: AsyncSession, n: int) -> list[dict]:
    S = _schema()
    bulan = daftar_bulan(n)
    p = {"awal": bulan[0], "akhir": _bulan_berikut(bulan[-1])}
    tx = {r[0]: r for r in (await db.execute(text(
        f"""SELECT date_trunc('month', created_at AT TIME ZONE 'UTC')::date,
                   sum(komisi_platform_idr)::bigint, sum(harga_final_idr)::bigint, count(*)
            FROM {S}.transaksi WHERE created_at >= CAST(:awal AS date) AND created_at < CAST(:akhir AS date)
            GROUP BY 1"""), p)).all()}
    lang = {(r[0], r[1]): int(r[2]) for r in (await db.execute(text(
        f"""SELECT date_trunc('month', p.dibayar_at AT TIME ZONE 'UTC')::date, s.plan_type, sum(p.jumlah_idr)::bigint
            FROM {S}.pembayaran_langganan p JOIN {S}.subscriptions s ON s.id = p.subscription_id
            WHERE p.dibayar_at >= CAST(:awal AS date) AND p.dibayar_at < CAST(:akhir AS date)
            GROUP BY 1, 2"""), p)).all()}
    out = []
    for b in bulan:
        r = tx.get(b)
        k = int(r[1]) if r else 0
        lk, ls = lang.get((b, PLAN["kolektor"]), 0), lang.get((b, PLAN["seniman"]), 0)
        out.append({"bulan": b.isoformat(), "komisi_idr": k, "langganan_kolektor_idr": lk,
                    "langganan_seniman_idr": ls, "total_idr": k + lk + ls,
                    "gmv_idr": int(r[2]) if r else 0, "n_transaksi": int(r[3]) if r else 0})
    return out


async def forecast(db: AsyncSession, target: str, n_aktual: int) -> dict:
    S = _schema()
    dasar = {"target": target, "tersedia": False}
    if not await tabel_ada(db, "forecast_meta") or not await tabel_ada(db, "forecast_pendapatan"):
        return dasar
    meta = dict((await db.execute(text(f"SELECT kunci, nilai FROM {S}.forecast_meta"))).all())
    bt = (await db.execute(
        text(f"SELECT model, wape_pct, smape_pct, mase, cakupan_p80, n_evaluasi, terpilih, mape_pct, rmse_idr "
             f"FROM {S}.forecast_backtest WHERE target = :tg ORDER BY mape_pct NULLS LAST, wape_pct"),
        {"tg": target})).all()
    terpilih = next((r[0] for r in bt if r[6]), None)
    if not terpilih:
        return dasar

    async def titik(tg: str, model: str):
        return (await db.execute(
            text(f"SELECT bulan, p10_idr, p50_idr, p90_idr FROM {S}.forecast_pendapatan "
                 "WHERE target = :tg AND model = :m ORDER BY bulan"), {"tg": tg, "m": model})).all()

    fc = await titik(target, terpilih)
    if not fc:
        return dasar
    kolom = _KOLOM_TARGET[target]
    aktual = [{"bulan": r["bulan"], "nilai_idr": r[kolom]} for r in await pendapatan_bulanan(db, n_aktual)]
    jumlah_komponen = None
    if target == "total":  # utk catatan konsistensi: komponen diramal terpisah dgn model masing-masing
        jumlah_komponen = 0
        for tg in ("komisi", "langganan_kolektor", "langganan_seniman"):
            rows = (await db.execute(
                text(f"SELECT model FROM {S}.forecast_backtest WHERE target = :tg AND terpilih"), {"tg": tg})).all()
            if rows:
                jumlah_komponen += int(sum(x[2] for x in await titik(tg, rows[0][0])))
    return {
        "target": target, "tersedia": True, "model_terpilih": terpilih,
        "aturan_pilih": meta.get("aturan_pilih"),
        "horizon_bulan": int(meta.get("horizon_bulan", len(fc))),
        "aktual": aktual,
        "forecast": [{"bulan": b.isoformat(), "p10_idr": int(a), "p50_idr": int(c), "p90_idr": int(d)}
                     for b, a, c, d in fc],
        "total_p10_idr": int(sum(x[1] for x in fc)), "total_p50_idr": int(sum(x[2] for x in fc)),
        "total_p90_idr": int(sum(x[3] for x in fc)), "jumlah_komponen_p50_idr": jumlah_komponen,
        "backtest": [{"model": m, "wape_pct": round(w, 2), "smape_pct": round(s, 2), "mase": round(ma, 2),
                      "mape_pct": round(mp, 2) if mp is not None else None,
                      "rmse_idr": round(rm) if rm is not None else None,
                      "cakupan_p80": round(c, 2) if c is not None else None,
                      "n_evaluasi": int(ne), "terpilih": bool(tp)} for m, w, s, ma, c, ne, tp, mp, rm in bt],
        "catatan": meta.get("catatan"),
    }


async def diagnosa_deret(db: AsyncSession, target: str) -> dict:
    """Hasil cek data series (ditulis batch oleh forecasting/diagnosa.py)."""
    S = _schema()
    dasar = {"target": target, "tersedia": False}
    if not await tabel_ada(db, "diagnosa_deret"):
        return dasar
    r = (await db.execute(
        text(f"SELECT hasil, dibuat_at FROM {S}.diagnosa_deret WHERE target = :tg"), {"tg": target})).first()
    if r is None:
        return dasar
    hasil = r[0] if isinstance(r[0], dict) else json.loads(r[0])
    return {"target": target, "tersedia": True, "dibuat_at": r[1].isoformat(), "hasil": hasil}


_URUT_CLUSTER = ("Aktif", "Kurang Aktif", "Tidak Aktif")


def _peringkat(r) -> dict:
    return {"seniman_id": str(r["seniman_id"]), "nama": r["display_name"], "cluster": r["cluster"],
            "skor_keaktifan": round(float(r["skor_keaktifan"]), 1), "n_jual_90d": int(r["n_jual_90d"]),
            "omzet_12b_idr": int(r["omzet_12b"]), "n_jual_12b": int(r["n_jual_12b"]),
            "hari_sejak_jual": int(r["hari_sejak_jual"]), "pro": bool(r["pro"])}


async def keaktifan_seniman(db: AsyncSession, n_top: int = 10) -> dict:
    """Cluster keaktifan + Top 10 seniman (hasil batch seniman/aktivitas.py; backend hanya membaca)."""
    S = _schema()
    if not await tabel_ada(db, "seniman_aktivitas") or not await tabel_ada(db, "seniman_cluster_info"):
        return {"tersedia": False}
    info = {k: (v if isinstance(v, dict) else json.loads(v))
            for k, v in (await db.execute(text(f"SELECT kunci, nilai FROM {S}.seniman_cluster_info"))).all()}
    if "meta" not in info:
        return {"tersedia": False}
    kolom = "seniman_id, display_name, cluster, skor_keaktifan, n_jual_90d, omzet_12b, n_jual_12b, hari_sejak_jual, pro"
    terbaik = (await db.execute(text(
        f"SELECT {kolom} FROM {S}.seniman_aktivitas WHERE omzet_12b > 0 ORDER BY omzet_12b DESC, seniman_id LIMIT :n"),
        {"n": n_top})).mappings().all()
    aktif = (await db.execute(text(
        f"SELECT {kolom} FROM {S}.seniman_aktivitas ORDER BY skor_keaktifan DESC, n_jual_90d DESC, seniman_id LIMIT :n"),
        {"n": n_top})).mappings().all()
    return {
        "tersedia": True,
        "meta": {k: v for k, v in info["meta"].items() if k != "grid"},
        "cluster": [{"cluster": c, **info[c]} for c in _URUT_CLUSTER if c in info],
        "top_terbaik": [_peringkat(r) for r in terbaik],
        "top_aktif": [_peringkat(r) for r in aktif],
    }


async def pro_vs_nonpro(db: AsyncSession, role: str, n: int) -> list[dict]:
    """Per akhir bulan: pengguna role tsb yg Pro vs tidak upgrade. Pro = langganan yang sedang
    berlaku di akhir bulan itu (kolektor_pro / seniman_pro)."""
    S = _schema()
    bulan = daftar_bulan(n)
    r = await db.execute(
        text(
            f"""
            SELECT b.awal,
              (SELECT count(*) FROM {S}.users u WHERE u.role = :role AND u.created_at < b.akhir) AS pengguna,
              (SELECT count(DISTINCT s.user_id) FROM {S}.subscriptions s
                 WHERE s.plan_type = :plan AND s.mulai_at < b.akhir AND s.berakhir_at >= b.akhir) AS pro,
              (SELECT count(*) FROM {S}.subscriptions s
                 WHERE s.plan_type = :plan AND s.mulai_at >= b.awal AND s.mulai_at < b.akhir) AS baru
            FROM (SELECT x AS awal, (x + interval '1 month')::date AS akhir
                  FROM unnest(CAST(:bulan AS date[])) x) b
            ORDER BY b.awal
            """
        ),
        {"bulan": bulan, "role": role, "plan": PLAN[role]},
    )
    return [{"bulan": awal.isoformat(), "role": role, "n_pro": int(pro), "n_non_pro": int(u - pro),
             "pro_share_pct": round(pro / u * 100, 1) if u else None, "upgrade_baru": int(baru)}
            for awal, u, pro, baru in r.all()]
