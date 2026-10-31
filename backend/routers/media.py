"""Penyaji gambar karya yang tersimpan di Cloudflare R2 (``GET /api/media/karya/<uuid>.jpg``).

Backend mengambil objek lewat API S3 R2 (bukan ``r2.dev``, yang terblokir DNS di sebagian provider
Indonesia) lalu menyajikannya ke aplikasi. Hanya key ``karya/<uuid>.jpg`` yang dilayani, jadi
endpoint ini tidak bisa dipakai membaca objek lain di bucket. Nama file tidak bisa ditebak (UUID)
dan gambar karya memang tampil publik di katalog, jadi tidak perlu login.
"""

from __future__ import annotations

import re

from fastapi import APIRouter, HTTPException
from fastapi.responses import Response

from services import storage

router = APIRouter(prefix="/api", tags=["media"])

_KEY_OK = re.compile(r"^karya/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jpg$")


@router.get("/media/{key:path}")
async def media(key: str) -> Response:
    if not _KEY_OK.match(key):
        raise HTTPException(404, "Gambar tidak ditemukan")
    try:
        hasil = await storage.ambil(key)
    except storage.StorageBelumDiatur as exc:
        raise HTTPException(503, str(exc))
    if hasil is None:
        raise HTTPException(404, "Gambar tidak ditemukan")
    isi, tipe = hasil
    # Isi sebuah key tidak pernah berubah (key = UUID karya), jadi aman di-cache lama.
    return Response(isi, media_type=tipe, headers={"Cache-Control": "public, max-age=31536000, immutable"})
