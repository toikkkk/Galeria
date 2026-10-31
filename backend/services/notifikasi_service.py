"""Penerbitan notifikasi in-app.

``kirim`` hanya menambahkan baris ke sesi yang sedang berjalan TANPA commit, jadi notifikasi lahir atomik bersama
kejadian yang memicunya (pesanan berubah status, bid masuk, dst.): kalau kejadiannya gagal, notifikasinya ikut batal.
Gagal membuat notifikasi tidak boleh menggagalkan kejadian utamanya, maka error di sini ditelan dan dicatat.
"""

from __future__ import annotations

import logging
import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from models.engagement import Notifikasi, TipeNotifikasi

logger = logging.getLogger("galeria.notifikasi")


def kirim(
    db: AsyncSession,
    user_id: uuid.UUID | None,
    tipe: TipeNotifikasi,
    judul: str,
    isi: str | None = None,
    tautan: str | None = None,
) -> None:
    if user_id is None:
        return
    try:
        db.add(Notifikasi(id=uuid.uuid4(), user_id=user_id, tipe=tipe, judul=judul[:120], isi=(isi[:300] if isi else None), tautan=tautan))
    except Exception:  # pragma: no cover - penambahan ke sesi hampir tak pernah gagal
        logger.exception("Gagal menyiapkan notifikasi untuk %s", user_id)
