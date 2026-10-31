"""Endpoint sentimen ulasan untuk dashboard seniman (hasil klasifikasi IndoBERT, data dummy).

Hanya membaca tabel hasil -- model dijalankan batch di ``ml-sentiment/`` (tanpa torch di server).
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.exc import ProgrammingError
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from schemas.sentimen import SentimenSeniman
from services import dashboard_repo, sentimen_repo as repo
from services.db_errors import tabel_belum_ada

router = APIRouter(prefix="/api/dashboard", tags=["dashboard-seniman", "sentimen"])


@router.get("/seniman/{seniman_id}/sentimen", response_model=SentimenSeniman)
async def sentimen_seniman(seniman_id: str, db: AsyncSession = Depends(get_db)):
    """Ringkasan sentimen ulasan kolektor untuk satu seniman (positif/netral/negatif, tren, contoh ulasan)."""
    sid = dashboard_repo.parse_uuid(seniman_id)
    if sid is None or await dashboard_repo.get_seniman(db, sid) is None:
        raise HTTPException(404, "Seniman tidak ditemukan")
    try:
        return await repo.sentimen_seniman(db, sid)
    except ProgrammingError as exc:
        # tabel hasil belum dimuat ke Neon (ml-sentiment/scripts/muat_neon.py belum dijalankan)
        await db.rollback()
        if not tabel_belum_ada(exc):
            raise
        raise HTTPException(503, "Analisis sentimen belum dihitung")
