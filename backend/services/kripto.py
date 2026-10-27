"""Primitif kriptografi untuk sertifikat keaslian & transaksi (Digital Art Identity).

Modul ini SENGAJA generik -- cuma 3 operasi dasar (hash payload, tanda tangani, verifikasi).
Logika BISNIS (payload apa saja yang masuk sertifikat vs transaksi) ada di tempat lain
(Tahap 4, `terbitkan_sertifikat()`/`catat_transfer_kepemilikan()`) -- modul ini tidak tahu
apa itu "karya" atau "transaksi", cuma tahu cara meng-hash dict dan menandatangani string.

Format payload kanonik & kebijakan key WAJIB mengikuti
``ml-digital-art-identity/SPEC_PAYLOAD.md`` -- jangan ubah cara serialisasi di sini tanpa
mengubah dokumen itu juga (dan menjalankan ulang seluruh contoh hash di dalamnya).
"""

from __future__ import annotations

import base64
import hashlib
import json
import os
from datetime import datetime, timezone

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives.asymmetric.ed25519 import (
    Ed25519PrivateKey,
    Ed25519PublicKey,
)


def format_waktu_kanonik(dt: datetime) -> str:
    """ISO-8601 UTC presisi DETIK + 'Z' (SPEC_PAYLOAD.md 1.1 poin 2) -- dipakai tiap kali
    timestamp masuk ke payload yang di-hash. WAJIB dipanggil sama persis saat membangun
    payload untuk menandatangani (``services/sertifikat_service.py``) maupun saat membangun
    ulang payload untuk verifikasi (``routers/verifikasi_publik.py``) -- kalau salah satu sisi
    memakai presisi berbeda (mis. mikrodetik), hash yang dihasilkan tidak akan pernah cocok.
    """
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def hitung_payload_hash(payload: dict) -> str:
    """SHA-256 dari payload, diserialisasi SECARA KANONIK (SPEC_PAYLOAD.md 1.1):
    key terurut alfabetis, tanpa spasi, UTF-8. Dipanggil PERSIS sama saat menandatangani
    (Tahap 4) maupun saat verifikasi ulang (endpoint publik) -- kalau 2 sisi memakai cara
    serialisasi berbeda, hash yang dihasilkan beda walau isi payload-nya sama persis.
    """
    kanonik = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
    return hashlib.sha256(kanonik.encode("utf-8")).hexdigest()


def muat_private_key(kms_key_ref: str) -> Ed25519PrivateKey:
    """Ambil private key dari environment variable sesuai ``kms_key_ref`` (format ``"env:NAMA"``,
    lihat SPEC_PAYLOAD.md 1.3 -- bukan KMS komersial sungguhan pada skala prototipe ini).
    """
    if not kms_key_ref.startswith("env:"):
        raise ValueError(f"kms_key_ref tidak dikenali: {kms_key_ref!r} (harus diawali 'env:')")
    nama_env = kms_key_ref.removeprefix("env:")
    nilai = os.environ.get(nama_env)
    if not nilai:
        raise RuntimeError(
            f"Env var {nama_env} belum di-set -- jalankan `python -m scripts.buat_signing_key` dulu, "
            f"atau cek backend/.env kalau sudah pernah dibuat sebelumnya."
        )
    return Ed25519PrivateKey.from_private_bytes(base64.b64decode(nilai))


def muat_public_key(public_key_b64: str) -> Ed25519PublicKey:
    """Ambil public key dari string base64 (kolom ``signing_keys.public_key``)."""
    return Ed25519PublicKey.from_public_bytes(base64.b64decode(public_key_b64))


def tanda_tangani(payload_hash: str, private_key: Ed25519PrivateKey) -> str:
    """Tanda tangani ``payload_hash`` (string hex 64 karakter dari ``hitung_payload_hash``),
    kembalikan signature base64 (64 byte mentah -> ~88 karakter base64).

    KONVENSI WAJIB (SPEC_PAYLOAD.md 1.1 poin 7): yang ditandatangani adalah bytes UTF-8 dari
    STRING HEX payload_hash, BUKAN 32 byte mentah digest-nya. ``verifikasi_signature()`` di bawah
    HARUS memakai konvensi yang sama persis, kalau tidak semua verifikasi akan gagal.
    """
    signature = private_key.sign(payload_hash.encode("utf-8"))
    return base64.b64encode(signature).decode("ascii")


def verifikasi_signature(payload_hash: str, signature_b64: str, public_key_b64: str) -> bool:
    """Verifikasi ``signature_b64`` terhadap ``payload_hash``, pakai ``public_key_b64`` yang
    SESUAI dengan ``signing_key_id`` yang tercatat di record (SPEC_PAYLOAD.md 1.4 -- BUKAN selalu
    key yang sedang aktif sekarang, supaya rotasi key tidak meng-invalid-kan sertifikat lama).

    Mengembalikan ``bool`` murni (tidak raise exception untuk signature tidak valid) -- supaya
    endpoint verifikasi publik (Tahap 4.3) bisa langsung memakai hasilnya tanpa try/except
    tambahan. Error selain "signature tidak valid" (mis. public_key_b64 rusak formatnya) TETAP
    di-raise -- itu bug/data korup, beda dari "signature memang tidak cocok".
    """
    public_key = muat_public_key(public_key_b64)
    try:
        public_key.verify(base64.b64decode(signature_b64), payload_hash.encode("utf-8"))
        return True
    except InvalidSignature:
        return False
