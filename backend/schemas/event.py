"""Skema event, tiket, pesanan tiket, dan check-in."""

from __future__ import annotations

import re
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field, field_validator, model_validator

from schemas.pesanan import InstruksiBayar, MetodeBayar


class TiketIn(BaseModel):
    nama: str = Field(min_length=2, max_length=60)
    harga_idr: int = Field(ge=0, le=100_000_000)
    kuota: int = Field(ge=1, le=10_000)
    keterangan: str | None = Field(None, max_length=200)

    @field_validator("nama", "keterangan")
    @classmethod
    def _spasi(cls, v: str | None) -> str | None:
        return " ".join(v.split()) if v else v


class EventBuat(BaseModel):
    judul: str = Field(min_length=3, max_length=120)
    deskripsi: str | None = Field(None, max_length=2000)
    tema: str | None = Field(None, max_length=80)
    format: Literal["offline", "online"] = "offline"
    nama_lokasi: str | None = Field(None, max_length=120)
    alamat: str | None = Field(None, max_length=300)
    kota: str | None = Field(None, max_length=80)
    link_online: str | None = Field(None, max_length=300)
    mulai_at: datetime
    selesai_at: datetime
    tiket: list[TiketIn] = Field(min_length=1, max_length=6)
    karya_ids: list[str] = Field(default_factory=list, max_length=20)

    @field_validator("judul", "tema", "nama_lokasi", "kota")
    @classmethod
    def _spasi(cls, v: str | None) -> str | None:
        return " ".join(v.split()) if v else v

    @model_validator(mode="after")
    def _konsisten(self):
        if self.format == "offline" and not (self.nama_lokasi and self.kota):
            raise ValueError("event offline wajib mengisi nama lokasi dan kota")
        if self.format == "online":
            if not self.link_online or not re.match(r"^https://\S+$", self.link_online):
                raise ValueError("event online wajib mengisi tautan https://")
        return self


class TiketOut(BaseModel):
    id: str
    nama: str
    harga_idr: int
    kuota: int
    sisa: int
    keterangan: str | None = None


class KaryaEvent(BaseModel):
    id: str
    title: str
    artist_name: str
    style_name: str
    price_idr: int
    image_url: str | None = None
    image_filename: str | None = None


class EventOut(BaseModel):
    id: str
    judul: str
    deskripsi: str | None
    tema: str | None
    format: str
    nama_lokasi: str | None
    alamat: str | None
    kota: str | None
    link_online: str | None  # hanya terisi untuk penyelenggara dan pemegang tiket
    mulai_at: datetime
    selesai_at: datetime
    status: str  # akan_datang | berlangsung | selesai | dibatalkan
    penyelenggara_nama: str
    gratis: bool
    harga_mulai_idr: int
    total_kuota: int
    total_sisa: int
    tiket: list[TiketOut]
    karya: list[KaryaEvent]
    server_now: datetime
    saya_punya_tiket: bool = False
    saya_penyelenggara: bool = False
    # statistik, hanya untuk penyelenggara
    tiket_terjual: int | None = None
    pendapatan_idr: int | None = None
    sudah_checkin: int | None = None
    bisa_dibatalkan: bool = False


class EventList(BaseModel):
    items: list[EventOut]
    total: int


class PesanTiketIn(BaseModel):
    tiket_id: str
    jumlah: int = Field(ge=1, le=5)
    nama_pemegang: str = Field(min_length=2, max_length=80)

    @field_validator("nama_pemegang")
    @classmethod
    def _spasi(cls, v: str) -> str:
        return " ".join(v.split())


class BayarTiketIn(BaseModel):
    metode: MetodeBayar


class ETiket(BaseModel):
    id: str
    kode: str
    nama_pemegang: str | None
    status: str  # aktif | terpakai | dibatalkan
    checkin_at: datetime | None = None


class EventRingkas(BaseModel):
    id: str
    judul: str
    format: str
    kota: str | None
    nama_lokasi: str | None
    mulai_at: datetime
    selesai_at: datetime
    status: str


class PesananTiketOut(BaseModel):
    id: str
    event: EventRingkas
    tiket_nama: str
    jumlah: int
    harga_satuan_idr: int
    total_idr: int
    status: str
    status_label: str
    nama_pemegang: str
    instruksi_bayar: InstruksiBayar | None = None
    batas_bayar_at: datetime | None = None
    dibayar_at: datetime | None = None
    created_at: datetime
    etiket: list[ETiket]
    aksi: list[str] = []


class TiketSayaItem(BaseModel):
    etiket: ETiket
    tiket_nama: str
    event: EventRingkas
    link_online: str | None = None


class TiketSayaList(BaseModel):
    items: list[TiketSayaItem]


class CheckinIn(BaseModel):
    kode: str = Field(min_length=6, max_length=40)

    @field_validator("kode")
    @classmethod
    def _norm(cls, v: str) -> str:
        return v.strip().upper()


class CheckinOut(BaseModel):
    berhasil: bool
    pesan: str
    nama_pemegang: str | None = None
    tiket_nama: str | None = None
    event_judul: str | None = None


class PesertaItem(BaseModel):
    kode: str
    nama_pemegang: str | None
    tiket_nama: str
    status: str
    checkin_at: datetime | None = None
    akun_pembeli: str


class PesertaList(BaseModel):
    items: list[PesertaItem]
    total: int
