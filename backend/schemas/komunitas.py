"""Skema komunitas: komunitas, anggota, postingan, dan komentar."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field, field_validator


class KomunitasBuat(BaseModel):
    nama: str = Field(min_length=3, max_length=60)
    deskripsi: str | None = Field(None, max_length=500)
    aliran: list[str] = Field(default_factory=list, max_length=8)
    terbuka: bool = True
    aturan: str | None = Field(None, max_length=1000)

    @field_validator("nama")
    @classmethod
    def _nama(cls, v: str) -> str:
        return " ".join(v.split())

    @field_validator("aliran")
    @classmethod
    def _aliran(cls, v: list[str]) -> list[str]:
        bersih = [" ".join(a.split()) for a in v if a and a.strip()]
        if any(len(a) > 40 for a in bersih):
            raise ValueError("nama aliran maksimal 40 karakter")
        return list(dict.fromkeys(bersih))


class KomunitasUbah(BaseModel):
    deskripsi: str | None = Field(None, max_length=500)
    terbuka: bool | None = None
    aturan: str | None = Field(None, max_length=1000)


class KomunitasOut(BaseModel):
    id: str
    nama: str
    deskripsi: str | None
    aliran: list[str]
    terbuka: bool
    aturan: str | None
    pemilik_nama: str
    jumlah_anggota: int
    dibuat_at: datetime
    # hubungan pengguna yang melihat: pemilik | anggota | menunggu | None (belum bergabung)
    saya: str | None = None
    jumlah_permintaan: int | None = None  # hanya untuk pemilik


class KomunitasList(BaseModel):
    items: list[KomunitasOut]
    total: int


class AnggotaOut(BaseModel):
    user_id: str
    nama: str
    peran: str
    bergabung_at: datetime


class AnggotaList(BaseModel):
    anggota: list[AnggotaOut]
    permintaan: list[AnggotaOut] = []  # hanya terisi untuk pemilik


class PostBuat(BaseModel):
    teks: str = Field(min_length=1, max_length=1000)

    @field_validator("teks")
    @classmethod
    def _teks(cls, v: str) -> str:
        v = "\n".join(" ".join(baris.split()) for baris in v.strip().splitlines())
        if not v:
            raise ValueError("teks tidak boleh kosong")
        return v


class KomentarBuat(BaseModel):
    teks: str = Field(min_length=1, max_length=500)

    @field_validator("teks")
    @classmethod
    def _teks(cls, v: str) -> str:
        v = " ".join(v.split())
        if not v:
            raise ValueError("komentar tidak boleh kosong")
        return v


class PostOut(BaseModel):
    id: str
    komunitas_id: str
    penulis_id: str
    penulis_nama: str
    penulis_pemilik: bool
    teks: str
    image_url: str | None = None
    disematkan: bool
    jumlah_like: int
    jumlah_komentar: int
    saya_like: bool
    waktu: datetime
    bisa_hapus: bool
    bisa_sematkan: bool


class PostList(BaseModel):
    items: list[PostOut]
    ada_lagi: bool


class LikeOut(BaseModel):
    saya_like: bool
    jumlah_like: int


class KomentarOut(BaseModel):
    id: str
    penulis_id: str
    penulis_nama: str
    teks: str
    waktu: datetime
    bisa_hapus: bool


class KomentarList(BaseModel):
    items: list[KomentarOut]
