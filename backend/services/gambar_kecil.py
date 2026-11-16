"""Gambar versi kecil (thumbnail) untuk daftar katalog.

Gambar asli karya bisa ~1 MB. Di daftar/kartu cukup ~40-90 KB, jadi muat jauh lebih cepat lewat tunnel/seluler.
Lebar yang diizinkan dibatasi ke beberapa nilai tetap (``LEBAR_OK``) supaya cache disk tidak membengkak dan
endpoint tidak bisa dipakai membuat ribuan varian ukuran.

Hasil disimpan di cache disk (folder temp OS, bukan di repo), jadi tiap gambar hanya diperkecil sekali.
"""

from __future__ import annotations

import asyncio
import io
import re
import tempfile
from collections.abc import Awaitable, Callable
from pathlib import Path

from PIL import Image

LEBAR_OK = (240, 360, 480, 720, 1080)
_CACHE = Path(tempfile.gettempdir()) / "galeria_thumb_cache"
_AMAN = re.compile(r"[^A-Za-z0-9_.-]")


def lebar_valid(w: int | None) -> int | None:
    """Pembulatan ke atas ke lebar yang diizinkan; ``None`` = tampilkan gambar asli."""
    if w is None:
        return None
    for x in LEBAR_OK:
        if w <= x:
            return x
    return LEBAR_OK[-1]


def _perkecil(data: bytes, lebar: int) -> bytes:
    im = Image.open(io.BytesIO(data)).convert("RGB")
    if im.width > lebar:
        im = im.resize((lebar, max(1, round(im.height * lebar / im.width))), Image.Resampling.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=80, optimize=True, progressive=True)
    return buf.getvalue()


def _jalur(kunci: str, lebar: int) -> Path:
    return _CACHE / str(lebar) / (_AMAN.sub("_", kunci) + ".jpg")


def dari_cache(kunci: str, lebar: int) -> bytes | None:
    f = _jalur(kunci, lebar)
    return f.read_bytes() if f.is_file() else None


async def thumbnail(kunci: str, lebar: int, asli: Callable[[], Awaitable[bytes | None]]) -> bytes | None:
    """Thumbnail JPEG lebar ``lebar`` untuk ``kunci``. ``asli`` hanya dipanggil bila belum ada di cache."""
    hit = dari_cache(kunci, lebar)
    if hit is not None:
        return hit
    data = await asli()
    if data is None:
        return None
    hasil = await asyncio.to_thread(_perkecil, data, lebar)
    f = _jalur(kunci, lebar)
    f.parent.mkdir(parents=True, exist_ok=True)
    tmp = f.with_suffix(".part")
    tmp.write_bytes(hasil)
    tmp.replace(f)
    return hasil
