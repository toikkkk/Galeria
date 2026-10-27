"""Endpoint verification engine -- Art-to-Art (deteksi duplikat) + Art-to-AI
(deteksi AI-generated). Tanggung jawab file ini: HANYA routing HTTP. Logic
model & orkestrasi ada di ``services/digital_art_identity_service.py``.

Dua endpoint, dua skenario pakai:
- ``POST /api/verification/check`` -- pratinjau TANPA simpan ke DB (mis. UI
  upload karya mau kasih peringatan dini "sepertinya AI-generated" SEBELUM
  seniman menekan submit form). Tidak butuh karya_id karena karya belum tentu
  ada di database.
- ``POST /api/karya/{karya_id}/verify`` -- verifikasi RESMI atas karya yang
  SUDAH ada baris-nya di tabel ``karya``, hasilnya disimpan (upsert
  ``karya_fingerprints`` + insert ``karya_verifikasi_log``) dan transaksi
  di-commit di sini. Kalau rekomendasi = "terverifikasi", sertifikat
  kriptografis JUGA diterbitkan di sini (``services/sertifikat_service.py``,
  TODO_KRIPTOGRAFI.md Tahap 4.1) -- satu titik tunggal yang mengikat hasil
  verification engine ke lapisan kriptografi, sesuai alur di
  ``ml-digital-art-identity/kriptografi.md`` bagian 4.
"""

from __future__ import annotations

import io
import logging
import uuid

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile
from PIL import Image, ImageOps
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models.karya import Karya, StatusVerifikasiKarya
from schemas.verification import VerificationResult
from services.sertifikat_service import terbitkan_sertifikat

logger = logging.getLogger("galeria.verification")
router = APIRouter(prefix="/api", tags=["verification"])


async def _read_image(file: UploadFile) -> Image.Image:
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(400, "File harus berupa gambar")
    raw = await file.read()
    try:
        image = Image.open(io.BytesIO(raw))
        # Sama seperti visual_search.py -- terapkan orientasi EXIF (foto HP
        # portrait sering disimpan landscape + tag rotasi).
        return ImageOps.exif_transpose(image).convert("RGB")
    except Exception:
        raise HTTPException(400, "Gagal membaca gambar (file korup/format tidak didukung)")


@router.post("/verification/check", response_model=VerificationResult)
async def check_verification(
    request: Request,
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
):
    """Pratinjau Art-to-Art + Art-to-AI, TANPA menyimpan apa pun ke database."""
    image = await _read_image(file)
    service = request.app.state.digital_art_identity_service
    result = await service.verify(image, db=db, karya_id=None, persist=False)
    return VerificationResult(**result, persisted=False)


@router.post("/karya/{karya_id}/verify", response_model=VerificationResult)
async def verify_karya(
    karya_id: str,
    request: Request,
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
):
    """Verifikasi RESMI karya yang sudah ada di tabel ``karya`` -- hasil
    disimpan (``karya_fingerprints`` + ``karya_verifikasi_log``) DAN
    ``karya.status_verifikasi`` diperbarui mengikuti ``rekomendasi_status``
    (lihat DigitalArtIdentityService._decide_status) sebelum di-commit.

    CATATAN JUJUR: ini auto-apply rekomendasi, BUKAN proses review manusia
    sungguhan utk kasus "perlu_ditinjau" -- admin dashboard utk override
    manual belum dibangun (di luar scope saat ini). Karya "perlu_ditinjau"
    tetap TIDAK tampil di GET /api/katalog (lihat routers/katalog.py,
    hanya "terverifikasi" yang tampil) sampai status-nya diubah manual.
    """
    try:
        karya_uuid = uuid.UUID(karya_id)
    except ValueError:
        raise HTTPException(404, "Karya tidak ditemukan")

    karya = await db.get(Karya, karya_uuid)
    if karya is None:
        raise HTTPException(404, "Karya tidak ditemukan")

    image = await _read_image(file)
    service = request.app.state.digital_art_identity_service
    result = await service.verify(image, db=db, karya_id=karya_uuid, persist=True)

    karya.status_verifikasi = StatusVerifikasiKarya(result["rekomendasi_status"])

    # Sertifikat kriptografis HANYA diterbitkan kalau rekomendasi = "terverifikasi"
    # (kriptografi.md: PASS -> certificate; REVIEW/REJECT tidak pernah dapat sertifikat).
    # Dipanggil SEKALI di sini -- re-verifikasi karya yang SUDAH tersertifikasi akan
    # menerbitkan baris sertifikat BARU (bukan update), lihat docstring terbitkan_sertifikat().
    #
    # try/except DISENGAJA (bukan dibiarkan propagate jadi HTTP 500): endpoint upload
    # (routers/karya_upload.py) membiarkan `karya.seniman_id` NULL karena Auth belum
    # dibangun (lihat root CLAUDE.md "Belum dikerjakan") -- terbitkan_sertifikat() secara
    # SENGAJA menolak karya tanpa seniman_id (lihat docstring-nya). Itu validasi yang
    # BENAR, tapi kegagalannya TIDAK BOLEH membatalkan hasil verifikasi AI yang sudah
    # genuinely berhasil -- pengguna (seniman) tetap berhak tahu karyanya lolos Art-to-Art/
    # Art-to-AI, walau sertifikat kriptografisnya belum bisa diterbitkan sampai Auth ada.
    if result["rekomendasi_status"] == "terverifikasi":
        try:
            await terbitkan_sertifikat(
                db,
                karya,
                art_to_art_result=result["art_to_art_result"],
                ai_detection_result=result["ai_detection_result"],
            )
        except (ValueError, RuntimeError) as exc:
            logger.warning("Sertifikat TIDAK diterbitkan utk karya %s: %s", karya.id, exc)

    await db.commit()
    return VerificationResult(**result, persisted=True)
