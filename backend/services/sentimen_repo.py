"""Query sentimen ulasan per seniman -- SQL mentah ke schema ``SENTIMEN_SCHEMA`` (default ``dummy_sentimen``).

Yang dibaca adalah ``sentimen_prediksi`` (keluaran model), BUKAN ``sentimen_label`` (label buatan
generator yang hanya dipakai utk evaluasi). Nama schema divalidasi regex; semua nilai user lewat
parameter ter-bind. Tidak menyentuh ``public.*``.
"""

from __future__ import annotations

import os
import re
import uuid

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from services.dashboard_repo import _bulan_terakhir, _schema as _schema_rekom, waktu_acuan

_SCHEMA_RE = re.compile(r"^[a-z_][a-z0-9_]*$")
URUT = ("positif", "netral", "negatif")


def _schema() -> str:
    s = os.environ.get("SENTIMEN_SCHEMA", "dummy_sentimen")
    if not _SCHEMA_RE.match(s):
        raise RuntimeError("SENTIMEN_SCHEMA tidak valid (harus ^[a-z_][a-z0-9_]*$)")
    return s


async def sentimen_seniman(db: AsyncSession, sid: uuid.UUID, n_bulan: int = 6, n_contoh: int = 6) -> dict:
    S, SR = _schema(), _schema_rekom()
    p = {"sid": sid}
    agregat = (
        await db.execute(
            text(f"""SELECT sentimen_prediksi AS s, count(*) AS n, avg(rating) AS r, max(model_version) AS mv
                     FROM {S}.ulasan WHERE seniman_id = :sid AND sentimen_prediksi IS NOT NULL GROUP BY 1"""),
            p,
        )
    ).mappings().all()
    jumlah = {r["s"]: int(r["n"]) for r in agregat}
    total = sum(jumlah.values())
    rating_total = sum(float(r["r"]) * int(r["n"]) for r in agregat)
    hitung = [
        {"sentimen": k, "jumlah": jumlah.get(k, 0), "persen": round(100 * jumlah.get(k, 0) / total, 1) if total else 0.0}
        for k in URUT
    ]

    bulan = _bulan_terakhir(waktu_acuan(), n_bulan)
    per_bulan = (
        await db.execute(
            text(f"""SELECT to_char(date_trunc('month', created_at AT TIME ZONE 'UTC'), 'YYYY-MM-01') AS b,
                            sentimen_prediksi AS s, count(*) AS n
                     FROM {S}.ulasan WHERE seniman_id = :sid AND sentimen_prediksi IS NOT NULL GROUP BY 1, 2"""),
            p,
        )
    ).mappings().all()
    peta = {(r["b"], r["s"]): int(r["n"]) for r in per_bulan}
    tren = [{"bulan": b, **{k: peta.get((b, k), 0) for k in URUT}} for b in bulan]

    contoh = (
        await db.execute(
            text(f"""SELECT u.teks, u.sentimen_prediksi AS sentimen, u.rating, u.created_at, k.title AS judul_karya
                     FROM {S}.ulasan u LEFT JOIN {SR}.karya k ON k.id = u.karya_id
                     WHERE u.seniman_id = :sid AND u.sentimen_prediksi IS NOT NULL ORDER BY u.created_at DESC LIMIT :n"""),
            {**p, "n": n_contoh},
        )
    ).mappings().all()

    menunggu = (
        await db.execute(
            text(f"SELECT count(*) FROM {S}.ulasan WHERE seniman_id = :sid AND sentimen_prediksi IS NULL"), p
        )
    ).scalar_one()
    mv = next((r["mv"] for r in agregat), None)
    return {
        "seniman_id": str(sid),
        "n_ulasan": total,
        "n_menunggu": int(menunggu),
        "model_version": mv,
        "hitung": hitung,
        "indeks_sentimen": round(100 * (jumlah.get("positif", 0) - jumlah.get("negatif", 0)) / total, 1) if total else None,
        "rating_rata2": round(rating_total / total, 2) if total else None,
        "tren_bulanan": tren,
        "ulasan_terbaru": [
            {"teks": r["teks"], "sentimen": r["sentimen"], "rating": int(r["rating"]),
             "tanggal": r["created_at"].isoformat().replace("+00:00", "Z"), "judul_karya": r["judul_karya"]}
            for r in contoh
        ],
    }
