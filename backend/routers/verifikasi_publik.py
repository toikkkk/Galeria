"""Endpoint verifikasi publik sertifikat keaslian (TODO_KRIPTOGRAFI.md Tahap 4.3).

``GET /api/verifikasi/{artwork_id}`` -- TANPA LOGIN, tujuan QR code di sertifikat
(kriptografi.md bagian 21). INI SATU-SATUNYA TEMPAT YANG BOLEH MENJAWAB "sertifikat ini
valid atau tidak" -- dan jawabannya SELALU dihitung ulang dari data live + verifikasi
signature matematis, TIDAK PERNAH membaca kolom "status" yang di-cache begitu saja. Kalau
suatu saat ada endpoint lain yang cuma baca boolean dari DB tanpa panggil fungsi ini,
itu PELANGGARAN desain -- lihat alasan di review keamanan Tahap 1.

Dua pengecekan independen dilakukan (bukan 1 boolean tunggal):
1. ``hash_cocok`` -- payload DIBANGUN ULANG dari data karya+sertifikat SAAT INI, lalu
   dibandingkan dengan ``sertifikat.payload_hash`` yang TERSIMPAN (append-only, tidak
   pernah diubah sejak ditandatangani). Beda berarti data terkait sudah berubah sejak
   sertifikat diterbitkan (karya_id, creator_id, file_hash, hasil verifikasi, dst).
2. ``signature_valid`` -- signature yang TERSIMPAN diverifikasi matematis terhadap
   ``payload_hash`` yang TERSIMPAN, pakai public key sesuai ``signing_key_id`` yang
   tercatat di sertifikat ITU (BUKAN key yang aktif sekarang -- SPEC_PAYLOAD.md 1.4).

``status_keseluruhan`` = "VALID" hanya kalau KEDUANYA benar.
"""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import APIRouter, Depends, HTTPException

from database import get_db
from models.karya import Karya
from models.sertifikat import SertifikatKeaslian, SigningKey
from models.transaksi import KepemilikanKarya
from schemas.verifikasi_publik import HasilVerifikasiPublik, RiwayatKepemilikan
from services.kripto import format_waktu_kanonik, hitung_payload_hash, verifikasi_signature

router = APIRouter(prefix="/api", tags=["verifikasi-publik"])


@router.get("/verifikasi/{artwork_id}", response_model=HasilVerifikasiPublik)
async def verifikasi_publik(artwork_id: str, db: AsyncSession = Depends(get_db)):
    karya = await db.scalar(select(Karya).where(Karya.artwork_id == artwork_id))
    if karya is None:
        raise HTTPException(404, "Artwork ID tidak ditemukan")

    sertifikat = (
        await db.scalar(select(SertifikatKeaslian).where(SertifikatKeaslian.id == karya.sertifikat_aktif_id))
        if karya.sertifikat_aktif_id
        else None
    )
    if sertifikat is None:
        raise HTTPException(404, "Karya ini belum punya sertifikat aktif")

    signing_key = await db.scalar(select(SigningKey).where(SigningKey.id == sertifikat.signing_key_id))
    if signing_key is None:
        # Seharusnya tidak pernah terjadi (FK RESTRICT) -- kalau terjadi, itu data korup, bukan "invalid" biasa.
        raise HTTPException(500, "signing_key untuk sertifikat ini tidak ditemukan -- data tidak konsisten")

    # --- Bangun ulang payload dari data SAAT INI (karya.seniman_id dibaca LIVE -- lihat
    # docstring modul ini & SPEC_PAYLOAD.md: kalau creator berubah setelah sertifikasi,
    # payload yang dibangun ulang akan BEDA dari payload_hash tersimpan -> hash_cocok=False) ---
    payload_sekarang = {
        "schema": "sertifikat_keaslian.v1",
        "karya_id": str(sertifikat.karya_id),
        "creator_id": str(karya.seniman_id) if karya.seniman_id else None,
        "file_hash": sertifikat.file_hash,
        "art_to_art_result": sertifikat.art_to_art_result.value,
        "ai_detection_result": sertifikat.ai_detection_result.value,
        "status_akhir": sertifikat.status_akhir.value,
        "verified_at": format_waktu_kanonik(sertifikat.verified_at),
    }
    hash_hitung_ulang = hitung_payload_hash(payload_sekarang)
    hash_cocok = hash_hitung_ulang == sertifikat.payload_hash

    signature_valid = verifikasi_signature(
        sertifikat.payload_hash, sertifikat.digital_signature, signing_key.public_key
    )

    status_keseluruhan = "VALID" if (hash_cocok and signature_valid) else "INVALID"

    # --- Riwayat kepemilikan ---
    baris_kepemilikan = (
        await db.scalars(
            select(KepemilikanKarya)
            .where(KepemilikanKarya.karya_id == karya.id)
            .order_by(KepemilikanKarya.diperoleh_at)
        )
    ).all()
    pemilik_aktif = next((k for k in baris_kepemilikan if k.dilepas_at is None), None)

    return HasilVerifikasiPublik(
        artwork_id=karya.artwork_id,
        karya_id=str(karya.id),
        title=karya.title,
        creator_name=karya.artist_name,
        status_akhir=sertifikat.status_akhir.value,
        file_hash=sertifikat.file_hash,
        verified_at=sertifikat.verified_at,
        hash_cocok=hash_cocok,
        signature_valid=signature_valid,
        status_keseluruhan=status_keseluruhan,
        peringatan_key_dicabut=signing_key.revoked_at is not None,
        current_owner_id=str(pemilik_aktif.pemilik_id) if pemilik_aktif else None,
        riwayat_kepemilikan=[
            RiwayatKepemilikan(
                pemilik_id=str(k.pemilik_id),
                sumber=k.sumber.value,
                diperoleh_at=k.diperoleh_at,
                dilepas_at=k.dilepas_at,
            )
            for k in baris_kepemilikan
        ],
    )
