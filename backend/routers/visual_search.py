"""Endpoint Visual Search — HP "scan lukisan" -> style + kecocokan katalog.

Tanggung jawab file ini: HANYA routing HTTP (validasi request, panggil
service, bentuk response). Logic model ada di ``services/visual_search_service.py``
-- jangan taruh preprocessing/inferensi di sini.
"""

from __future__ import annotations

import io

from fastapi import APIRouter, File, HTTPException, UploadFile
from PIL import Image

from ..schemas.visual_search import VisualSearchResponse

router = APIRouter(prefix="/api", tags=["visual-search"])


@router.post("/visual-search", response_model=VisualSearchResponse)
async def visual_search(file: UploadFile = File(...), top_k: int = 5):
    """Terima 1 foto -> prediksi style + top-k kecocokan katalog GALERIA.

    Sesuai desain ml-visual-search: JANGAN klaim "pasti sama" kalau
    ``verdict != "confirmed"`` -- tampilkan `verdict_message` apa adanya ke
    user, jangan ditimpa jadi kalimat yang lebih pasti dari itu.
    """
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(400, "File harus berupa gambar")

    raw = await file.read()
    try:
        image = Image.open(io.BytesIO(raw)).convert("RGB")
    except Exception:
        raise HTTPException(400, "Gagal membaca gambar (file korup/format tidak didukung)")

    # TODO: ambil service dari app state (di-load sekali saat startup, lihat main.py)
    #   result = request.app.state.visual_search_service.search(image, top_k=top_k)
    #   return VisualSearchResponse(**result)
    raise NotImplementedError("Wire ke VisualSearchService setelah services/ diisi.")
