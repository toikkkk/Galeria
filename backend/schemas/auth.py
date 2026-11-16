"""Skema request/response Auth pengguna (email+password dan Google Sign-In)."""

from __future__ import annotations

import re
from typing import Literal

from pydantic import BaseModel, Field, field_validator

# Admin TIDAK bisa dibuat lewat registrasi publik -- akun admin dikelola terpisah.
RolePublik = Literal["seniman", "kolektor", "komunitas"]

_EMAIL = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
PASSWORD_MIN = 8
PASSWORD_MAKS_BYTE = 72  # batas bcrypt; lebih dari ini DITOLAK (bukan dipotong diam-diam)


def _email(v: str) -> str:
    v = v.strip().lower()
    if len(v) > 254 or not _EMAIL.match(v):
        raise ValueError("format email tidak valid")
    return v


class RegisterReq(BaseModel):
    email: str
    password: str
    display_name: str
    role: RolePublik
    nomor_hp: str | None = None

    @field_validator("email")
    @classmethod
    def _v_email(cls, v: str) -> str:
        return _email(v)

    @field_validator("display_name")
    @classmethod
    def _v_nama(cls, v: str) -> str:
        v = " ".join(v.split())
        if not (2 <= len(v) <= 60):
            raise ValueError("nama tampilan harus 2-60 karakter")
        return v

    @field_validator("nomor_hp")
    @classmethod
    def _v_hp(cls, v: str | None) -> str | None:
        if v is None or not v.strip():
            return None
        digit = "".join(c for c in v if c.isdigit())
        if digit.startswith("62"):
            digit = digit[2:]
        digit = digit.lstrip("0")
        if not (8 <= len(digit) <= 13):
            raise ValueError("nomor HP tidak valid")
        return "+62" + digit

    @field_validator("password")
    @classmethod
    def _v_pw(cls, v: str) -> str:
        if len(v) < PASSWORD_MIN:
            raise ValueError(f"password minimal {PASSWORD_MIN} karakter")
        if len(v.encode()) > PASSWORD_MAKS_BYTE:
            raise ValueError(f"password terlalu panjang (maks {PASSWORD_MAKS_BYTE} byte)")
        if not (re.search(r"[A-Za-z]", v) and re.search(r"\d", v)):
            raise ValueError("password harus mengandung huruf dan angka")
        return v


def cek_password_kuat(v: str) -> str:
    """Aturan password yang sama dengan pendaftaran (dipakai juga saat reset password)."""
    if len(v) < PASSWORD_MIN:
        raise ValueError(f"password minimal {PASSWORD_MIN} karakter")
    if len(v.encode()) > PASSWORD_MAKS_BYTE:
        raise ValueError(f"password terlalu panjang (maks {PASSWORD_MAKS_BYTE} byte)")
    if not (re.search(r"[A-Za-z]", v) and re.search(r"\d", v)):
        raise ValueError("password harus mengandung huruf dan angka")
    return v


def _kode6(v: str) -> str:
    v = v.strip()
    if not re.fullmatch(r"\d{6}", v):
        raise ValueError("kode harus 6 digit angka")
    return v


class LupaPasswordReq(BaseModel):
    email: str

    @field_validator("email")
    @classmethod
    def _v_email(cls, v: str) -> str:
        return _email(v)


class ResetPasswordReq(BaseModel):
    email: str
    kode: str
    password_baru: str

    @field_validator("email")
    @classmethod
    def _v_email(cls, v: str) -> str:
        return v.strip().lower()

    @field_validator("kode")
    @classmethod
    def _v_kode(cls, v: str) -> str:
        return _kode6(v)

    @field_validator("password_baru")
    @classmethod
    def _v_pw(cls, v: str) -> str:
        return cek_password_kuat(v)


class VerifikasiEmailReq(BaseModel):
    kode: str

    @field_validator("kode")
    @classmethod
    def _v_kode(cls, v: str) -> str:
        return _kode6(v)


class LoginReq(BaseModel):
    email: str
    password: str = Field(max_length=200)
    device: str | None = Field(default=None, max_length=120)

    @field_validator("email")
    @classmethod
    def _v_email(cls, v: str) -> str:
        return v.strip().lower()


class RefreshReq(BaseModel):
    refresh_token: str = Field(max_length=300)


class GoogleReq(BaseModel):
    id_token: str = Field(max_length=4096)
    # wajib bila akun baru (pengguna belum pernah mendaftar); diabaikan bila akun sudah ada
    role: RolePublik | None = None
    device: str | None = Field(default=None, max_length=120)


class UserOut(BaseModel):
    id: str
    email: str
    display_name: str
    role: str
    avatar_url: str | None = None
    nomor_hp: str | None = None
    email_verified: bool


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int  # detik masa berlaku access token
    user: UserOut
