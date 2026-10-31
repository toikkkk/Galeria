"""Koleksi karya yang KAMU MILIKI (kepemilikan aktif, hasil pembelian atau lelang yang sudah diterima)."""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models.karya import Karya
from models.transaksi import KepemilikanKarya, Transaksi
from models.user import User
from routers.katalog import tandai_terjual, to_list_item
from schemas.katalog import KaryaListItem
from services.auth_deps import get_current_user

router = APIRouter(prefix="/api/koleksi", tags=["koleksi"])


class KoleksiItem(BaseModel):
    karya: KaryaListItem
    diperoleh_at: datetime
    sumber: str  # pembelian | lelang | ...
    harga_idr: int | None = None  # harga yang kamu bayar (bila dari transaksi)


@router.get("", response_model=list[KoleksiItem])
async def koleksi_saya(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Karya yang saat ini kamu miliki, yang terbaru diperoleh dulu. ID sertifikat (``artwork_id``) ada di tiap karya."""
    rows = (await db.execute(
        select(KepemilikanKarya, Karya, Transaksi.harga_final_idr)
        .join(Karya, Karya.id == KepemilikanKarya.karya_id)
        .outerjoin(Transaksi, Transaksi.id == KepemilikanKarya.transaksi_id)
        .where(KepemilikanKarya.pemilik_id == user.id, KepemilikanKarya.dilepas_at.is_(None), Karya.deleted_at.is_(None))
        .order_by(KepemilikanKarya.diperoleh_at.desc())
    )).all()
    items = [to_list_item(k) for _, k, _ in rows]
    await tandai_terjual(db, items)
    return [
        KoleksiItem(karya=item, diperoleh_at=kp.diperoleh_at, sumber=kp.sumber.value, harga_idr=int(harga) if harga is not None else None)
        for item, (kp, _, harga) in zip(items, rows)
    ]
