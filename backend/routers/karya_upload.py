"""Endpoint karya milik seniman: unggah, daftar "karya saya", dan hapus.

Semua endpoint di sini WAJIB login sebagai ``seniman``. Pemilik karya (``seniman_id``) dan nama
yang tampil (``artist_name``) diambil dari akun yang login, BUKAN dari input form, jadi tidak ada
yang bisa mengunggah karya atas nama seniman lain.

Gambar disimpan di Cloudflare R2 (key ``karya/<uuid>.jpg``, lihat ``services/storage.py``).
Bila R2 belum dikonfigurasi di ``.env`` (mis. mesin pengembang baru), gambar jatuh ke disk lokal
``uploads/karya/`` supaya alur tetap bisa dicoba. ``karya.image_key`` membedakan keduanya.
"""

from __future__ import annotations

import hashlib
import io
import logging
import uuid
from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile
from PIL import Image as PILImage, ImageOps
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models.karya import Karya, StatusVerifikasiKarya
from models.transaksi import Transaksi
from models.user import User
from models.verification import KaryaFingerprint
from routers.katalog import to_list_item
from schemas.katalog import KaryaListItem
from schemas.karya_upload import KaryaCreated, KaryaSayaPage
from services import storage
from services.auth_deps import butuh_role

logger = logging.getLogger("galeria.karya")

router = APIRouter(prefix="/api", tags=["karya"])

UPLOADS_DIR = Path(__file__).resolve().parent.parent / "uploads" / "karya"
MAKS_BYTE = 15 * 1024 * 1024  # 15 MB


@router.post("/karya", response_model=KaryaCreated)
async def create_karya(
    title: str = Query(..., min_length=1, max_length=200),
    style_name: str = Query(..., min_length=1, max_length=100),
    price_idr: int = Query(..., gt=0, le=100_000_000_000),
    lebar_cm: float = Query(..., gt=0, le=1000),
    tinggi_cm: float = Query(..., gt=0, le=1000),
    gallery_name: str | None = Query(None, max_length=200, description="Kosong = nama seniman"),
    file: UploadFile = File(...),
    user: User = Depends(butuh_role("seniman")),
    db: AsyncSession = Depends(get_db),
):
    """Buat karya baru milik seniman yang login, status awal ``menunggu``.

    Karya BELUM tampil di ``GET /api/katalog`` sampai lolos ``POST /api/karya/{id}/verify``.
    Metadata dikirim sebagai query param agar ``ApiClient.postMultipart()`` di mobile bisa dipakai
    apa adanya (pola sama ``routers/visual_search.py``).
    """
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(400, "File harus berupa gambar")
    raw = await file.read()
    if not raw:
        raise HTTPException(400, "File gambar kosong")
    if len(raw) > MAKS_BYTE:
        raise HTTPException(413, "Gambar terlalu besar (maksimal 15 MB)")

    try:
        image = PILImage.open(io.BytesIO(raw))
        image = ImageOps.exif_transpose(image).convert("RGB")
    except Exception:
        raise HTTPException(400, "Gagal membaca gambar (file korup/format tidak didukung)")

    buf = io.BytesIO()
    image.save(buf, format="JPEG", quality=92)
    jpeg = buf.getvalue()

    karya_id = uuid.uuid4()
    filename = f"{karya_id}.jpg"
    if storage.terkonfigurasi():
        image_key = f"karya/{filename}"
        try:
            await storage.unggah(image_key, jpeg, "image/jpeg")
        except Exception:
            logger.exception("Unggah ke R2 gagal")
            raise HTTPException(502, "Gagal menyimpan gambar ke penyimpanan. Coba lagi sebentar.")
    else:
        UPLOADS_DIR.mkdir(parents=True, exist_ok=True)
        (UPLOADS_DIR / filename).write_bytes(jpeg)
        image_key = f"uploads/karya/{filename}"

    nama = user.display_name
    karya = Karya(
        id=karya_id,
        seniman_id=user.id,
        title=title.strip(),
        artist_name=nama,
        gallery_name=(gallery_name or "").strip() or nama,
        style_name=style_name.strip(),
        price_idr=price_idr,
        image_filename=filename,
        image_key=image_key,
        file_hash=hashlib.sha256(raw).hexdigest(),
        lebar_cm=lebar_cm,
        tinggi_cm=tinggi_cm,
        status_verifikasi=StatusVerifikasiKarya.MENUNGGU,
    )
    db.add(karya)
    try:
        await db.commit()
    except Exception:
        await db.rollback()
        if image_key.startswith("karya/"):  # jangan tinggalkan objek yatim di bucket
            try:
                await storage.hapus(image_key)
            except Exception:
                logger.warning("Gagal membersihkan objek R2 %s setelah commit gagal", image_key)
        raise
    return KaryaCreated(id=str(karya_id), status_verifikasi=karya.status_verifikasi.value)


@router.get("/karya-saya", response_model=KaryaSayaPage)
async def karya_saya(
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=100),
    user: User = Depends(butuh_role("seniman")),
    db: AsyncSession = Depends(get_db),
):
    """SEMUA karya milik seniman yang login (termasuk menunggu / ditolak / perlu ditinjau)."""
    filt = (Karya.seniman_id == user.id) & Karya.deleted_at.is_(None)
    total = (await db.execute(select(func.count()).select_from(Karya).where(filt))).scalar_one()
    rows = (
        await db.execute(
            select(Karya, KaryaFingerprint)
            .outerjoin(KaryaFingerprint, KaryaFingerprint.karya_id == Karya.id)
            .where(filt)
            .order_by(Karya.created_at.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
    ).all()
    return KaryaSayaPage(items=[to_list_item(k, fp) for k, fp in rows], page=page, page_size=page_size, total=total)


@router.delete("/karya/{karya_id}", status_code=204)
async def hapus_karya(
    karya_id: str,
    user: User = Depends(butuh_role("seniman")),
    db: AsyncSession = Depends(get_db),
):
    """Hapus (soft-delete) karya milikmu. Karya yang pernah punya transaksi tidak boleh dihapus."""
    try:
        kid = uuid.UUID(karya_id)
    except ValueError:
        raise HTTPException(404, "Karya tidak ditemukan")
    karya = await db.get(Karya, kid)
    if karya is None or karya.deleted_at is not None or karya.seniman_id != user.id:
        raise HTTPException(404, "Karya tidak ditemukan")  # bukan 403: jangan bocorkan keberadaan karya orang lain
    ada = (await db.execute(select(func.count()).select_from(Transaksi).where(Transaksi.karya_id == kid))).scalar_one()
    if ada:
        raise HTTPException(409, "Karya ini sudah punya transaksi, jadi tidak bisa dihapus.")
    karya.deleted_at = datetime.utcnow()
    await db.commit()
