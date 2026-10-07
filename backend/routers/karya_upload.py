"""Endpoint pembuatan karya baru (`POST /api/karya`).

KONTEKS PENTING -- baca sebelum mengubah file ini: Auth (JWT, Google
Sign-In) BELUM dibangun (lihat root CLAUDE.md "Belum dikerjakan"), jadi
endpoint ini TIDAK bisa tahu siapa seniman yang sedang login -- `seniman_id`
sengaja dibiarkan NULL (kolom sudah nullable di skema, lihat models/karya.py)
dan `artist_name`/`gallery_name` dikirim sebagai field form bebas, BUKAN
dari identitas user terautentikasi.

Ini keputusan SADAR supaya alur upload->verifikasi->katalog bisa benar-benar
didemokan sekarang, bukan menunggu Auth selesai. Begitu Auth ada, endpoint
ini WAJIB diperbarui: ambil `seniman_id`/`artist_name`/`gallery_name` dari
JWT token (`Depends(current_user)`), BUKAN dari form input lagi -- supaya
orang tidak bisa upload karya mengatasnamakan seniman lain.

Gambar disimpan LOKAL di server (`uploads/karya/`), BUKAN Cloudflare R2 --
R2 belum diimplementasi (lihat root CLAUDE.md "Cara Kerja Cloudflare R2:
rencana, BELUM diimplementasi", perlu bucket+API token dari dashboard
Cloudflare yang belum ada). Pola kolom `image_key` yang dipakai di sini
SAMA PERSIS dengan desain R2 yang sudah direncanakan (lihat models/karya.py)
-- migrasi ke R2 nanti tinggal ganti cara `image_key` di-resolve jadi URL,
TANPA perlu migrasi skema/kolom baru.
"""

from __future__ import annotations

import hashlib
import io
import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile
from PIL import Image as PILImage, ImageOps
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models.karya import Karya, StatusVerifikasiKarya
from schemas.karya_upload import KaryaCreated

router = APIRouter(prefix="/api", tags=["karya"])

UPLOADS_DIR = Path(__file__).resolve().parent.parent / "uploads" / "karya"


@router.post("/karya", response_model=KaryaCreated)
async def create_karya(
    title: str = Query(..., min_length=1, max_length=200),
    artist_name: str = Query(..., min_length=1, max_length=200),
    gallery_name: str = Query(..., min_length=1, max_length=200),
    style_name: str = Query(..., min_length=1, max_length=100),
    price_idr: int = Query(..., gt=0),
    lebar_cm: float = Query(..., gt=0),
    tinggi_cm: float = Query(..., gt=0),
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
):
    """Buat baris `karya` baru, status awal `menunggu` -- BELUM tampil di
    `GET /api/katalog` (lihat routers/katalog.py, sudah difilter hanya
    `status_verifikasi=terverifikasi`) sampai lolos
    `POST /api/karya/{id}/verify`.

    Metadata dikirim sbg QUERY PARAM (bukan form field body) -- SENGAJA
    menyamakan pola `routers/visual_search.py` (`top_k`, `hint_*`), supaya
    `ApiClient.postMultipart()` di mobile (lihat services/api_client.dart)
    bisa dipakai apa adanya tanpa perlu menambah jalur baru utk form-field
    body di client yang sudah dipakai di banyak tempat.
    """
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(400, "File harus berupa gambar")
    raw = await file.read()
    if not raw:
        raise HTTPException(400, "File gambar kosong")

    try:
        image = PILImage.open(io.BytesIO(raw))
        image = ImageOps.exif_transpose(image).convert("RGB")
    except Exception:
        raise HTTPException(400, "Gagal membaca gambar (file korup/format tidak didukung)")

    karya_id = uuid.uuid4()
    UPLOADS_DIR.mkdir(parents=True, exist_ok=True)
    filename = f"{karya_id}.jpg"
    dest = UPLOADS_DIR / filename
    image.save(dest, format="JPEG", quality=92)

    file_hash = hashlib.sha256(raw).hexdigest()

    karya = Karya(
        id=karya_id,
        title=title.strip(),
        artist_name=artist_name.strip(),
        gallery_name=gallery_name.strip(),
        style_name=style_name.strip(),
        price_idr=price_idr,
        # image_filename TETAP diisi (kolom NOT NULL, lihat models/karya.py)
        # walau mobile sekarang baca gambar dari `image_url` (lihat
        # schemas/katalog.py) -- konsisten dgn 8 karya seed lama yg masih
        # pakai asset lokal.
        image_filename=filename,
        # Pointer ke file ter-upload -- resolve jadi URL publik di
        # routers/katalog.py::_to_list_item. Lihat docstring modul ini.
        image_key=f"uploads/karya/{filename}",
        file_hash=file_hash,
        lebar_cm=lebar_cm,
        tinggi_cm=tinggi_cm,
        status_verifikasi=StatusVerifikasiKarya.MENUNGGU,
    )
    db.add(karya)
    await db.commit()

    return KaryaCreated(id=str(karya_id), status_verifikasi=karya.status_verifikasi.value)
