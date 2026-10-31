"""Buku alamat pengiriman milik pengguna yang login (untuk checkout)."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models.user import AlamatPengiriman, User
from schemas.pesanan import AlamatIn, AlamatOut
from services.auth_deps import get_current_user

router = APIRouter(prefix="/api/alamat", tags=["alamat"])

MAKS_ALAMAT = 10


def _out(a: AlamatPengiriman) -> AlamatOut:
    return AlamatOut(
        id=str(a.id), label=a.label, nama_penerima=a.nama_penerima, telepon=a.telepon,
        alamat_lengkap=a.alamat_lengkap, kota=a.kota, kode_pos=a.kode_pos, is_utama=a.is_utama,
    )


async def _milik(db: AsyncSession, user: User, alamat_id: str) -> AlamatPengiriman:
    try:
        aid = uuid.UUID(alamat_id)
    except ValueError:
        raise HTTPException(404, "Alamat tidak ditemukan")
    a = await db.get(AlamatPengiriman, aid)
    if a is None or a.user_id != user.id:
        raise HTTPException(404, "Alamat tidak ditemukan")
    return a


@router.get("", response_model=list[AlamatOut])
async def daftar(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    rows = (
        await db.execute(
            select(AlamatPengiriman)
            .where(AlamatPengiriman.user_id == user.id)
            .order_by(AlamatPengiriman.is_utama.desc(), AlamatPengiriman.created_at)
        )
    ).scalars().all()
    return [_out(a) for a in rows]


@router.post("", response_model=AlamatOut, status_code=201)
async def tambah(body: AlamatIn, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    jumlah = (
        await db.execute(select(func.count()).select_from(AlamatPengiriman).where(AlamatPengiriman.user_id == user.id))
    ).scalar_one()
    if jumlah >= MAKS_ALAMAT:
        raise HTTPException(409, f"Maksimal {MAKS_ALAMAT} alamat. Hapus yang tidak dipakai dulu.")
    a = AlamatPengiriman(id=uuid.uuid4(), user_id=user.id, is_utama=(jumlah == 0), **body.model_dump())
    db.add(a)
    await db.commit()
    return _out(a)


@router.post("/{alamat_id}/utama", response_model=AlamatOut)
async def jadikan_utama(alamat_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    a = await _milik(db, user, alamat_id)
    await db.execute(update(AlamatPengiriman).where(AlamatPengiriman.user_id == user.id).values(is_utama=False))
    a.is_utama = True
    await db.commit()
    return _out(a)


@router.delete("/{alamat_id}", status_code=204)
async def hapus(alamat_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    a = await _milik(db, user, alamat_id)
    dulu_utama = a.is_utama
    await db.delete(a)
    await db.flush()
    if dulu_utama:  # selama masih punya alamat, selalu ada satu yang utama
        pengganti = (
            await db.execute(
                select(AlamatPengiriman)
                .where(AlamatPengiriman.user_id == user.id)
                .order_by(AlamatPengiriman.created_at)
                .limit(1)
            )
        ).scalar_one_or_none()
        if pengganti is not None:
            pengganti.is_utama = True
    await db.commit()
