"""Penerbitan sertifikat keaslian (TODO_KRIPTOGRAFI.md Tahap 4.1).

Dipanggil SEKALI oleh ``routers/verification.py`` setelah Art-to-Art + Art-to-AI
merekomendasikan ``"terverifikasi"`` -- BUKAN dipanggil ulang tiap kali karya dicek lagi
(re-verifikasi = baris ``sertifikat_keaslian`` baru + ``karya.sertifikat_aktif_id`` di-update,
TIDAK PERNAH meng-``UPDATE`` baris lama -- lihat docstring ``SertifikatKeaslian``).

Payload yang ditandatangani WAJIB mengikuti ``ml-digital-art-identity/SPEC_PAYLOAD.md``
bagian 1.2.a persis -- jangan ubah field di sini tanpa mengubah dokumen itu juga.
"""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from models.karya import Karya
from models.sertifikat import (
    AiDetectionHasilSertifikat,
    ArtToArtHasilSertifikat,
    SertifikatKeaslian,
    SigningKey,
    StatusAkhirSertifikat,
)
from services.kripto import format_waktu_kanonik, hitung_payload_hash, muat_private_key, tanda_tangani

# VerificationResult (schemas/verification.py) pakai "lolos"/"duplikat_terdeteksi" dan
# "lolos"/"ai_generated_terdeteksi" -- BEDA penamaan dari enum SertifikatKeaslian
# ("bersih"/"asli"). Pemetaan eksplisit di sini, bukan menyamakan nama enum, supaya kedua
# tabel (karya_verifikasi_log vs sertifikat_keaslian) boleh berevolusi independen.
_PETA_ART_TO_ART = {
    "lolos": ArtToArtHasilSertifikat.BERSIH,
    "duplikat_terdeteksi": ArtToArtHasilSertifikat.DUPLIKAT_TERDETEKSI,
}
_PETA_AI_DETECTION = {
    "lolos": AiDetectionHasilSertifikat.ASLI,
    "ai_generated_terdeteksi": AiDetectionHasilSertifikat.AI_GENERATED_TERDETEKSI,
}


async def _artwork_id_berikutnya(db: AsyncSession) -> str:
    """Format GAL-ART-{tahun}-{NNNNNN} (kriptografi.md 5.1). Nomor urut dihitung dari
    jumlah karya yang SUDAH punya artwork_id tahun ini + 1.

    KETERBATASAN JUJUR (bukan disembunyikan): ini BUKAN atomic sequence -- pada skala
    prototipe akademik (upload karya tidak terjadi ribuan/detik), risiko 2 request
    bersamaan mendapat nomor yang sama diterima sebagai keterbatasan MVP. Migrasi ke
    `sa.Sequence` Postgres (atomic) adalah perbaikan wajar untuk skala produksi nyata.
    """
    tahun = datetime.now(timezone.utc).year
    prefix = f"GAL-ART-{tahun}-"
    total = await db.scalar(
        select(func.count()).select_from(Karya).where(Karya.artwork_id.like(f"{prefix}%"))
    )
    return f"{prefix}{(total or 0) + 1:06d}"


async def terbitkan_sertifikat(
    db: AsyncSession,
    karya: Karya,
    art_to_art_result: str,
    ai_detection_result: str,
) -> SertifikatKeaslian:
    """Bangun payload kanonik -> hash -> tanda tangani -> simpan ``sertifikat_keaslian`` ->
    update ``karya.sertifikat_aktif_id`` (+ ``karya.artwork_id`` kalau karya ini belum
    pernah punya). TIDAK melakukan ``db.commit()`` -- caller (router) yang menentukan
    kapan transaksi DB ditutup, konsisten dengan konvensi ``digital_art_identity_service.py``.
    """
    if not karya.file_hash:
        raise ValueError(f"karya {karya.id} belum punya file_hash -- tidak bisa diterbitkan sertifikat")
    if not karya.seniman_id:
        raise ValueError(f"karya {karya.id} belum punya seniman_id (creator) -- tidak bisa diterbitkan sertifikat")

    signing_key = await db.scalar(select(SigningKey).where(SigningKey.is_active.is_(True)))
    if signing_key is None:
        raise RuntimeError("Tidak ada signing key aktif -- jalankan `python -m scripts.buat_signing_key` dulu.")

    if not karya.artwork_id:
        karya.artwork_id = await _artwork_id_berikutnya(db)

    verified_at = datetime.now(timezone.utc)
    payload = {
        "schema": "sertifikat_keaslian.v1",
        "karya_id": str(karya.id),
        "creator_id": str(karya.seniman_id),
        "file_hash": karya.file_hash,
        "art_to_art_result": _PETA_ART_TO_ART[art_to_art_result].value,
        "ai_detection_result": _PETA_AI_DETECTION[ai_detection_result].value,
        "status_akhir": StatusAkhirSertifikat.TERVERIFIKASI.value,
        "verified_at": format_waktu_kanonik(verified_at),
    }
    payload_hash = hitung_payload_hash(payload)
    private_key = muat_private_key(signing_key.kms_key_ref)
    digital_signature = tanda_tangani(payload_hash, private_key)

    sertifikat = SertifikatKeaslian(
        karya_id=karya.id,
        file_hash=karya.file_hash,
        art_to_art_result=_PETA_ART_TO_ART[art_to_art_result],
        ai_detection_result=_PETA_AI_DETECTION[ai_detection_result],
        status_akhir=StatusAkhirSertifikat.TERVERIFIKASI,
        verified_at=verified_at,
        payload_hash=payload_hash,
        digital_signature=digital_signature,
        signing_key_id=signing_key.id,
    )
    db.add(sertifikat)
    await db.flush()  # supaya sertifikat.id terisi sebelum dipakai di bawah

    karya.sertifikat_aktif_id = sertifikat.id
    return sertifikat
