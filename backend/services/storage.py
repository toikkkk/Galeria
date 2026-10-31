"""Penyimpanan gambar di Cloudflare R2 (S3-compatible).

Pola sama dengan ``database.py``: config dibaca dari env, tidak ada config = app tetap
bisa start, error jelas baru muncul saat upload/ambil benar-benar dipanggil.

Dua endpoint R2 yang BEDA (jangan tertukar):
- ``R2_ENDPOINT``        -> API S3 (upload/hapus/ambil), butuh access key.
- ``R2_PUBLIC_URL_BASE`` -> URL publik r2.dev / domain sendiri (hanya untuk MENAMPILKAN).

Gambar dilayani lewat ``GET /api/media/{key}`` (backend mengambil dari R2 lewat API S3) karena
``r2.dev`` terblokir DNS di sebagian provider Indonesia. Untuk produksi set ``MEDIA_MODE=public``
agar ``image_url`` langsung menunjuk ``R2_PUBLIC_URL_BASE`` (bebas biaya egress, tanpa lewat server).

boto3 itu sinkron, jadi semua panggilan dijalankan di thread agar event loop tidak terblokir.
"""

from __future__ import annotations

import asyncio
import os
from functools import lru_cache

KUNCI_DIDUKUNG = ("karya/",)  # prefix key yang boleh dilayani /api/media


class StorageBelumDiatur(RuntimeError):
    pass


def _env(nama: str) -> str:
    return os.environ.get(nama, "").strip()


def terkonfigurasi() -> bool:
    return all(_env(n) for n in ("R2_ENDPOINT", "R2_ACCESS_KEY_ID", "R2_SECRET_ACCESS_KEY", "R2_BUCKET"))


@lru_cache(maxsize=1)
def _klien():
    if not terkonfigurasi():
        raise StorageBelumDiatur(
            "Penyimpanan R2 belum dikonfigurasi (isi R2_ENDPOINT, R2_ACCESS_KEY_ID, "
            "R2_SECRET_ACCESS_KEY, R2_BUCKET di backend/.env)."
        )
    import boto3
    from botocore.config import Config

    return boto3.client(
        "s3",
        endpoint_url=_env("R2_ENDPOINT"),
        aws_access_key_id=_env("R2_ACCESS_KEY_ID"),
        aws_secret_access_key=_env("R2_SECRET_ACCESS_KEY"),
        region_name="auto",
        config=Config(signature_version="s3v4", retries={"max_attempts": 3, "mode": "standard"}),
    )


async def unggah(key: str, data: bytes, content_type: str = "image/jpeg") -> None:
    def _kerja() -> None:
        _klien().put_object(Bucket=_env("R2_BUCKET"), Key=key, Body=data, ContentType=content_type)

    await asyncio.to_thread(_kerja)


async def ambil(key: str) -> tuple[bytes, str] | None:
    """(isi, content_type) atau None bila objek tidak ada."""

    def _kerja():
        try:
            r = _klien().get_object(Bucket=_env("R2_BUCKET"), Key=key)
        except _klien().exceptions.NoSuchKey:
            return None
        return r["Body"].read(), r.get("ContentType", "application/octet-stream")

    return await asyncio.to_thread(_kerja)


async def hapus(key: str) -> None:
    def _kerja() -> None:
        _klien().delete_object(Bucket=_env("R2_BUCKET"), Key=key)

    await asyncio.to_thread(_kerja)


def url_gambar(image_key: str | None) -> str | None:
    """URL yang dikirim ke aplikasi untuk sebuah ``karya.image_key`` (None = pakai asset lokal app).

    - ``uploads/...``   : file lama di disk server (karya yang diunggah sebelum R2 dipakai).
    - ``katalog-dummy/``: gambar dataset dummy (dilayani ``routers/gambar.py``).
    - lainnya (``karya/...``): objek R2 milik karya nyata.
    """
    if not image_key:
        return None
    if image_key.startswith("uploads/"):
        return f"/{image_key}"
    if image_key.startswith("katalog-dummy/"):
        base = _env("GAMBAR_PROXY_BASE") or _env("R2_PUBLIC_URL_BASE")
        return f"{base.rstrip('/')}/{image_key}" if base else None
    if _env("MEDIA_MODE") == "public" and _env("R2_PUBLIC_URL_BASE"):
        return f"{_env('R2_PUBLIC_URL_BASE').rstrip('/')}/{image_key}"
    return f"/api/media/{image_key}"
