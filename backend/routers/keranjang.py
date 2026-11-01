"""Keranjang kolektor (tabel ``keranjang_item``).

Karya seni itu unik (stok 1), jadi keranjang hanya berisi karya, tanpa jumlah. Checkout membuat SATU pesanan per
karya lewat ``pesanan_service.buat_pesanan`` -- semua aturan pesanan tunggal (harga dari server, tanda tangan,
satu transaksi aktif per karya, bukan karya sendiri, tidak sedang dilelang) berlaku apa adanya. Pembayaran tetap
per pesanan (sandbox). Karya yang gagal dipesan tetap di keranjang beserta alasannya.
"""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models.engagement import KeranjangItem
from models.karya import Karya, StatusVerifikasiKarya
from models.lelang import Lelang, StatusLelang
from models.transaksi import StatusTransaksi as S
from models.transaksi import Transaksi
from models.user import User
from routers.katalog import to_list_item
from schemas.keranjang import (
    CheckoutGagal,
    KeranjangCheckoutIn,
    KeranjangCheckoutOut,
    KeranjangIds,
    KeranjangItemOut,
    KeranjangOut,
)
from services import pesanan_service as svc
from services.auth_deps import butuh_role

router = APIRouter(prefix="/api/keranjang", tags=["keranjang"])

MAKS_ITEM = 50
_kolektor = butuh_role("kolektor", "komunitas")


def _kid(v: str) -> uuid.UUID:
    try:
        return uuid.UUID(v)
    except ValueError:
        raise HTTPException(404, "Karya tidak ditemukan")


async def _alasan_tidak_tersedia(db: AsyncSession, karya: Karya, user: User) -> str | None:
    """None = bisa dibeli sekarang."""
    if karya.deleted_at is not None or karya.status_verifikasi != StatusVerifikasiKarya.TERVERIFIKASI:
        return "Karya sudah tidak tersedia."
    if karya.seniman_id == user.id:
        return "Ini karyamu sendiri."
    if await db.scalar(select(Transaksi.id).where(Transaksi.karya_id == karya.id, Transaksi.status != S.DIBATALKAN).limit(1)) is not None:
        return "Sudah terjual atau sedang dipesan orang lain."
    if await db.scalar(select(Lelang.id).where(Lelang.karya_id == karya.id, Lelang.status.in_([StatusLelang.AKAN_DATANG, StatusLelang.BERLANGSUNG])).limit(1)) is not None:
        return "Sedang dilelang."
    return None


async def _muat(db: AsyncSession, user: User) -> KeranjangOut:
    await svc.kedaluwarsakan(db)  # pesanan kedaluwarsa dibatalkan -> karya kembali tersedia
    rows = (await db.execute(
        select(Karya).join(KeranjangItem, KeranjangItem.karya_id == Karya.id)
        .where(KeranjangItem.user_id == user.id).order_by(KeranjangItem.created_at.desc())
    )).scalars().all()
    items, total = [], 0
    for k in rows:
        alasan = await _alasan_tidak_tersedia(db, k, user)
        it = to_list_item(k)
        it.terjual = alasan is not None and "terjual" in alasan
        items.append(KeranjangItemOut(karya=it, tersedia=alasan is None, alasan=alasan))
        if alasan is None:
            total += k.price_idr
    return KeranjangOut(items=items, jumlah=len(items), total_idr=total)


@router.get("", response_model=KeranjangOut)
async def lihat(user: User = Depends(_kolektor), db: AsyncSession = Depends(get_db)):
    return await _muat(db, user)


@router.get("/ids", response_model=KeranjangIds)
async def ids(user: User = Depends(_kolektor), db: AsyncSession = Depends(get_db)):
    rows = (await db.execute(select(KeranjangItem.karya_id).where(KeranjangItem.user_id == user.id))).scalars().all()
    return KeranjangIds(ids=[str(r) for r in rows])


# Didaftarkan SEBELUM POST /{karya_id} supaya 'checkout' tidak tertangkap sebagai id karya.
@router.post("/checkout", response_model=KeranjangCheckoutOut)
async def checkout(body: KeranjangCheckoutIn, user: User = Depends(_kolektor), db: AsyncSession = Depends(get_db)):
    """Pesan semua karya yang masih tersedia di keranjang ke satu alamat. Tiap karya jadi pesanannya sendiri."""
    rows = (await db.execute(
        select(Karya).join(KeranjangItem, KeranjangItem.karya_id == Karya.id)
        .where(KeranjangItem.user_id == user.id).order_by(KeranjangItem.created_at)
    )).scalars().all()
    if not rows:
        raise HTTPException(409, "Keranjang kosong.")
    daftar = [(k.id, k.title) for k in rows]  # simpan sekarang: buat_pesanan meng-commit & me-refresh sesi
    pesanan, gagal = [], []
    for kid, judul in daftar:
        try:
            t = await svc.buat_pesanan(db, user, str(kid), body.alamat_id)
        except HTTPException as exc:
            await db.rollback()
            if exc.status_code == 404 and "Alamat" in str(exc.detail):
                raise  # alamat salah berlaku untuk semuanya, bukan salah satu karya
            gagal.append(CheckoutGagal(karya_id=str(kid), judul=judul, alasan=str(exc.detail)))
            continue
        item = await db.get(KeranjangItem, (user.id, kid))
        if item is not None:
            await db.delete(item)
            await db.commit()
        pesanan.append(await svc.muat_out(db, t, user.id))
    return KeranjangCheckoutOut(pesanan=pesanan, gagal=gagal)


@router.post("/{karya_id}", response_model=KeranjangIds, status_code=201)
async def tambah(karya_id: str, user: User = Depends(_kolektor), db: AsyncSession = Depends(get_db)):
    """Masukkan karya ke keranjang (idempoten)."""
    kid = _kid(karya_id)
    karya = await db.get(Karya, kid)
    if karya is None or karya.deleted_at is not None or karya.status_verifikasi != StatusVerifikasiKarya.TERVERIFIKASI:
        raise HTTPException(404, "Karya tidak ditemukan")
    alasan = await _alasan_tidak_tersedia(db, karya, user)
    if alasan is not None:
        raise HTTPException(409, alasan)
    jumlah = (await db.execute(select(func.count()).select_from(KeranjangItem).where(KeranjangItem.user_id == user.id))).scalar_one()
    if jumlah >= MAKS_ITEM:
        raise HTTPException(409, f"Keranjang penuh (maksimal {MAKS_ITEM} karya).")
    await db.execute(pg_insert(KeranjangItem).values(user_id=user.id, karya_id=kid).on_conflict_do_nothing())
    await db.commit()
    return await ids(user, db)


@router.delete("/{karya_id}", response_model=KeranjangIds)
async def hapus(karya_id: str, user: User = Depends(_kolektor), db: AsyncSession = Depends(get_db)):
    item = await db.get(KeranjangItem, (user.id, _kid(karya_id)))
    if item is not None:
        await db.delete(item)
        await db.commit()
    return await ids(user, db)


@router.delete("", response_model=KeranjangIds)
async def kosongkan(user: User = Depends(_kolektor), db: AsyncSession = Depends(get_db)):
    for it in (await db.execute(select(KeranjangItem).where(KeranjangItem.user_id == user.id))).scalars().all():
        await db.delete(it)
    await db.commit()
    return KeranjangIds(ids=[])
