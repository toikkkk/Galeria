"""Simpan ulasan yang ditulis kolektor di aplikasi -- SQL mentah ke schema ``SENTIMEN_SCHEMA``.

Sentimen sengaja dikosongkan (NULL = menunggu analisis); lihat ``schemas/ulasan.py``. Tidak menyentuh
``public.*``. Nilai dari user selalu lewat parameter ter-bind.
"""

from __future__ import annotations

import uuid

from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from services.dashboard_repo import _schema as _schema_rekom
from services.sentimen_repo import _schema as _schema_sentimen


class SudahMengulas(Exception):
    """Kolektor ini sudah pernah menulis ulasan untuk karya yang sama."""


async def kolektor_demo(db: AsyncSession) -> dict | None:
    """Kolektor contoh (pengganti login sampai Auth selesai) -- tidak bergantung pada tabel rekomendasi."""
    SR = _schema_rekom()
    r = (await db.execute(text(f"SELECT id, display_name FROM {SR}.kolektor ORDER BY id LIMIT 1"))).mappings().first()
    return {"id": str(r["id"]), "display_name": r["display_name"]} if r else None


async def kolektor_ada(db: AsyncSession, kid: uuid.UUID) -> bool:
    SR = _schema_rekom()
    return (await db.execute(text(f"SELECT 1 FROM {SR}.kolektor WHERE id = :id"), {"id": kid})).first() is not None


async def seniman_dari_karya(db: AsyncSession, karya_id: uuid.UUID) -> uuid.UUID | None:
    SR = _schema_rekom()
    r = (await db.execute(text(f"SELECT seniman_id FROM {SR}.karya WHERE id = :id"), {"id": karya_id})).first()
    return r[0] if r else None


async def simpan(db: AsyncSession, *, karya_id: uuid.UUID, kolektor_id: uuid.UUID, seniman_id: uuid.UUID,
                 rating: int, teks: str) -> str:
    S = _schema_sentimen()
    ulasan_id = uuid.uuid4()
    try:
        await db.execute(
            text(f"""INSERT INTO {S}.ulasan (ulasan_id, karya_id, kolektor_id, seniman_id, teks, rating, created_at, sumber)
                     VALUES (:uid, :kar, :kol, :sen, :teks, :rating, now(), 'app')"""),
            {"uid": ulasan_id, "kar": karya_id, "kol": kolektor_id, "sen": seniman_id, "teks": teks, "rating": rating},
        )
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise SudahMengulas()
    return str(ulasan_id)
