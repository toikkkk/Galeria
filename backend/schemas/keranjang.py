"""Skema keranjang kolektor (lihat routers/keranjang.py)."""

from __future__ import annotations

from pydantic import BaseModel

from schemas.katalog import KaryaListItem
from schemas.pesanan import PesananOut


class KeranjangItemOut(BaseModel):
    karya: KaryaListItem
    # False bila karya sudah terjual/dipesan/dilelang/dihapus -- tetap tampil supaya pembeli tahu, tapi tidak ikut checkout.
    tersedia: bool
    alasan: str | None = None


class KeranjangOut(BaseModel):
    items: list[KeranjangItemOut]
    jumlah: int
    total_idr: int  # hanya karya yang tersedia


class KeranjangIds(BaseModel):
    ids: list[str]


class KeranjangCheckoutIn(BaseModel):
    alamat_id: str


class CheckoutGagal(BaseModel):
    karya_id: str
    judul: str
    alasan: str


class KeranjangCheckoutOut(BaseModel):
    """Satu pesanan per karya (tiap karya = transaksi bertanda tangan sendiri). Yang gagal tetap di keranjang."""

    pesanan: list[PesananOut]
    gagal: list[CheckoutGagal]
