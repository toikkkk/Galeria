"""Endpoint Visual Search — HP "scan lukisan" -> style + kecocokan katalog.

Tanggung jawab file ini: HANYA routing HTTP (validasi request, panggil
service, bentuk response). Logic model ada di ``services/visual_search_service.py``
-- jangan taruh preprocessing/inferensi di sini.
"""

from __future__ import annotations

import io

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile
from PIL import Image, ImageOps
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from schemas.visual_search import VisualSearchResponse

router = APIRouter(prefix="/api", tags=["visual-search"])


@router.post("/visual-search", response_model=VisualSearchResponse)
async def visual_search(
    request: Request,
    file: UploadFile = File(...),
    top_k: int = 5,
    hint_left: float | None = None,
    hint_top: float | None = None,
    hint_width: float | None = None,
    hint_height: float | None = None,
    db: AsyncSession = Depends(get_db),
):
    """Terima 1 foto -> prediksi style + top-k kecocokan katalog GALERIA.

    Sesuai desain ml-visual-search: JANGAN klaim "pasti sama" kalau
    ``verdict != "confirmed"`` -- tampilkan `verdict_message` apa adanya ke
    user, jangan ditimpa jadi kalimat yang lebih pasti dari itu.

    ``hint_*`` (opsional, fraksi 0..1): posisi bingkai panduan di kamera
    mobile terhadap gambar (lihat ``visual_search_camera_screen.dart``).
    Kalau ada, HANYA isi bingkai itu yang diproses model (lihat
    ``VisualSearchService.search``); kalau tidak ada (mis. gambar dari
    galeri), backend mencoba beberapa crop otomatis.
    """
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(400, "File harus berupa gambar")

    raw = await file.read()
    try:
        image = Image.open(io.BytesIO(raw))
        # PENTING: foto dari kamera HP (terutama portrait) sering disimpan
        # dengan piksel mentah landscape + tag EXIF "Orientation" yang minta
        # rotasi saat ditampilkan. PIL TIDAK menerapkan itu otomatis -- tanpa
        # baris ini, model bisa menerima lukisan yang kesamping 90 derajat,
        # menghancurkan similarity walau foto sudah pas secara visual di HP.
        image = ImageOps.exif_transpose(image).convert("RGB")
    except Exception:
        raise HTTPException(400, "Gagal membaca gambar (file korup/format tidak didukung)")

    hint_rect = None
    if None not in (hint_left, hint_top, hint_width, hint_height):
        hint_rect = (hint_left, hint_top, hint_width, hint_height)

    service = request.app.state.visual_search_service
    result = await service.search(image, db=db, top_k=top_k, hint_rect=hint_rect)
    return VisualSearchResponse(**result)
