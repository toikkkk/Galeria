"""Skema lelang: membuat lelang, memasang bid, dan membaca daftar/detail."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field


class LelangBuat(BaseModel):
    karya_id: str
    harga_awal_idr: int = Field(gt=0, le=100_000_000_000)
    kelipatan_bid_idr: int = Field(gt=0, le=10_000_000_000)
    mulai_at: datetime
    selesai_at: datetime


class BidIn(BaseModel):
    jumlah_idr: int = Field(gt=0, le=100_000_000_000)


class KaryaLelang(BaseModel):
    id: str
    title: str
    artist_name: str
    style_name: str
    image_url: str | None = None
    image_filename: str | None = None
    lebar_cm: float | None = None
    tinggi_cm: float | None = None


class BidOut(BaseModel):
    nama: str
    jumlah_idr: int
    waktu: datetime
    saya: bool = False


class LelangOut(BaseModel):
    id: str
    status: str  # akan_datang | berlangsung | selesai | dibatalkan (dihitung dari waktu server)
    karya: KaryaLelang
    seniman_nama: str
    harga_awal_idr: int
    kelipatan_bid_idr: int
    harga_saat_ini_idr: int  # bid tertinggi, atau harga awal bila belum ada bid
    jumlah_bid: int
    bid_minimum_berikutnya_idr: int
    mulai_at: datetime
    selesai_at: datetime
    server_now: datetime  # untuk hitung mundur yang tidak bergantung jam HP
    saya_tertinggi: bool = False
    saya_pemenang: bool = False
    pemenang_nama: str | None = None
    pesanan_id: str | None = None  # pesanan pemenang (terlihat oleh pemenang dan penjual)
    bisa_dibatalkan: bool = False  # penjual, belum ada bid


class LelangDetail(LelangOut):
    bids: list[BidOut]


class LelangList(BaseModel):
    items: list[LelangOut]
    total: int
