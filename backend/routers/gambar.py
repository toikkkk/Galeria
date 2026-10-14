"""Penyaji gambar katalog dummy lewat backend (opsional, utk jaringan yang memblokir ``r2.dev``).

Sebagian provider seluler Indonesia membelokkan DNS ``*.r2.dev`` sehingga HP tidak bisa mengunduh
gambar langsung dari R2, padahal laptop/backend bisa. Bila env ``GAMBAR_PROXY_BASE`` diisi,
``image_url`` di response API menunjuk ke endpoint ini; backend mengambil gambar dari R2
(``R2_PUBLIC_URL_BASE``) lalu menyajikannya ke HP lewat jalur yang memang sudah terbukti (mis. USB
``adb reverse``). Gambar tetap berasal dari R2 -- tidak disimpan di database.

Hanya key ``katalog-dummy/<nama>.jpg|jpeg|png|webp`` yang dilayani (mencegah SSRF / path traversal).
Cache disk di folder temp OS, bukan di repo.
"""

from __future__ import annotations

import asyncio
import os
import re
import tempfile
import urllib.error
import urllib.request
from pathlib import Path

from fastapi import APIRouter, HTTPException
from fastapi.responses import Response

router = APIRouter(prefix="/api", tags=["gambar"])

_KEY_OK = re.compile(r"^katalog-dummy/[A-Za-z0-9_.-]+\.(jpe?g|png|webp)$", re.IGNORECASE)
_TIPE = {"jpg": "image/jpeg", "jpeg": "image/jpeg", "png": "image/png", "webp": "image/webp"}
_CACHE = Path(tempfile.gettempdir()) / "galeria_gambar_cache"


def _ambil(url: str, tujuan: Path) -> None:
    req = urllib.request.Request(url, headers={"User-Agent": "galeria-backend"})
    with urllib.request.urlopen(req, timeout=20) as resp:  # noqa: S310 -- url dibangun dari base env + key tervalidasi
        data = resp.read()
    tujuan.parent.mkdir(parents=True, exist_ok=True)
    tmp = tujuan.with_suffix(tujuan.suffix + ".part")
    tmp.write_bytes(data)
    tmp.replace(tujuan)


def _folder_lokal() -> Path | None:
    """Folder gambar dataset di mesin ini (opsional). Isi ``GAMBAR_LOCAL_DIR`` di .env, atau
    biarkan kosong: otomatis memakai ``ml-visual-search/data/raw`` bila ada. Dipakai lebih dulu
    daripada R2 -- berguna bila ``r2.dev`` terblokir (DNS/SNI) di jaringan tempat demo."""
    env = os.environ.get("GAMBAR_LOCAL_DIR", "").strip()
    d = Path(env) if env else Path(__file__).resolve().parent.parent.parent / "ml-visual-search" / "data" / "raw"
    return d if d.is_dir() else None


@router.get("/gambar/{key:path}")
async def gambar(key: str) -> Response:
    if not _KEY_OK.match(key):
        raise HTTPException(404, "Gambar tidak ditemukan")

    lokal_dir = _folder_lokal()
    if lokal_dir is not None:
        lokal = lokal_dir / key.rsplit("/", 1)[-1]   # key tervalidasi _KEY_OK: tanpa "..", hanya nama file
        if lokal.is_file():
            return Response(
                lokal.read_bytes(),
                media_type=_TIPE[key.rsplit(".", 1)[-1].lower()],
                headers={"Cache-Control": "public, max-age=86400"},
            )

    base = os.environ.get("R2_PUBLIC_URL_BASE", "").strip().rstrip("/")
    if not base:
        raise HTTPException(503, "R2_PUBLIC_URL_BASE belum di-set")

    file = _CACHE / key
    if not file.exists():
        try:
            await asyncio.to_thread(_ambil, f"{base}/{key}", file)
        except urllib.error.HTTPError as e:
            raise HTTPException(404 if e.code == 404 else 502, "Gambar tidak bisa diambil dari R2") from e
        except (urllib.error.URLError, TimeoutError, OSError) as e:
            raise HTTPException(502, "R2 tidak terjangkau dari backend") from e

    ext = key.rsplit(".", 1)[-1].lower()
    return Response(
        file.read_bytes(),
        media_type=_TIPE[ext],
        headers={"Cache-Control": "public, max-age=86400"},
    )
