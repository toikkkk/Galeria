"""Unit test ``services/kripto.py`` -- TODO_KRIPTOGRAFI.md Tahap 3.4.

Jalankan (dari folder backend/, venv aktif):
    python -m pytest tests/test_kripto.py -v
"""

from __future__ import annotations

import base64

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat

from services.kripto import (
    hitung_payload_hash,
    muat_public_key,
    tanda_tangani,
    verifikasi_signature,
)


def _payload_contoh() -> dict:
    return {
        "schema": "sertifikat_keaslian.v1",
        "karya_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        "creator_id": "7c9e6a4d-6f3b-4ae1-9f0a-1b2c3d4e5f6a",
        "file_hash": "8f7a91d8c4a2b6e1f0d3c5a7b9e2f4d6c8a0b2e4f6d8c0a2b4e6f8d0c2a4b6e8",
        "art_to_art_result": "bersih",
        "ai_detection_result": "asli",
        "status_akhir": "terverifikasi",
        "verified_at": "2026-10-26T09:15:00Z",
    }


# --------------------------------------------------------- hitung_payload_hash
def test_hash_deterministic_untuk_payload_sama():
    """Payload identik -> hash identik, berkali-kali (prasyarat mutlak sebelum bisa menandatangani apa pun)."""
    p = _payload_contoh()
    assert hitung_payload_hash(p) == hitung_payload_hash(p)
    assert hitung_payload_hash(p) == hitung_payload_hash(dict(p))  # dict baru, isi sama


def test_hash_tidak_peduli_urutan_key_dict():
    """Urutan key saat membangun dict TIDAK BOLEH mempengaruhi hash (json.dumps sort_keys=True)."""
    p1 = _payload_contoh()
    p2 = {k: p1[k] for k in reversed(list(p1.keys()))}  # urutan key dibalik
    assert hitung_payload_hash(p1) == hitung_payload_hash(p2)


def test_hash_berubah_total_kalau_1_field_berubah():
    """Avalanche effect -- bukti SHA-256 bekerja sebagai pendeteksi perubahan."""
    p1 = _payload_contoh()
    p2 = dict(p1, status_akhir="ditolak")
    h1, h2 = hitung_payload_hash(p1), hitung_payload_hash(p2)
    assert h1 != h2
    # tidak cuma "beda", harus beda SIGNIFIKAN (avalanche) -- heuristik longgar: >25% karakter beda
    beda = sum(1 for a, b in zip(h1, h2) if a != b)
    assert beda > len(h1) * 0.25


def test_hash_cocok_dgn_nilai_di_spec_payload_md():
    """Regression test terhadap contoh TERDOKUMENTASI di SPEC_PAYLOAD.md -- kalau ini gagal,
    berarti cara serialisasi di kripto.py MENYIMPANG dari spesifikasi yang sudah ditulis &
    direview, bukan cuma bug kecil."""
    p = _payload_contoh()
    assert hitung_payload_hash(p) == "d5cceedf8659f52c022e78b662aef8fc1cb8ab6f68cfbbde107c9ed1434d9b4a"


# ------------------------------------------------------- tanda_tangani / verifikasi_signature
def _public_key_b64(private_key: Ed25519PrivateKey) -> str:
    raw = private_key.public_key().public_bytes(encoding=Encoding.Raw, format=PublicFormat.Raw)
    return base64.b64encode(raw).decode("ascii")


def test_signature_valid_untuk_payload_asli():
    private_key = Ed25519PrivateKey.generate()
    public_key_b64 = _public_key_b64(private_key)

    payload_hash = hitung_payload_hash(_payload_contoh())
    signature_b64 = tanda_tangani(payload_hash, private_key)

    assert verifikasi_signature(payload_hash, signature_b64, public_key_b64) is True


def test_signature_invalid_kalau_payload_diubah_setelah_tanda_tangan():
    """INI TES PALING PENTING (TODO 3.4, 5.2) -- membuktikan sistem benar-benar mendeteksi
    tamper, bukan cuma asumsi di atas kertas."""
    private_key = Ed25519PrivateKey.generate()
    public_key_b64 = _public_key_b64(private_key)

    payload_asli = _payload_contoh()
    hash_asli = hitung_payload_hash(payload_asli)
    signature_b64 = tanda_tangani(hash_asli, private_key)
    assert verifikasi_signature(hash_asli, signature_b64, public_key_b64) is True

    # simulasi tamper: 1 field diubah, hash dihitung ULANG dari data yang sudah diubah
    # (persis skenario endpoint verifikasi publik: ambil data TERKINI dari DB, hash ulang)
    payload_tamper = dict(payload_asli, status_akhir="ditolak")
    hash_tamper = hitung_payload_hash(payload_tamper)

    assert verifikasi_signature(hash_tamper, signature_b64, public_key_b64) is False


def test_signature_invalid_kalau_pakai_public_key_yang_salah():
    """Signature dari key A tidak boleh valid terhadap public key B -- kalau ini gagal,
    sistem bisa dibobol dgn signature dari sumber manapun."""
    key_a = Ed25519PrivateKey.generate()
    key_b = Ed25519PrivateKey.generate()
    public_key_b_b64 = _public_key_b64(key_b)

    payload_hash = hitung_payload_hash(_payload_contoh())
    signature_dari_a = tanda_tangani(payload_hash, key_a)

    assert verifikasi_signature(payload_hash, signature_dari_a, public_key_b_b64) is False


def test_muat_public_key_menghasilkan_objek_yang_benar():
    private_key = Ed25519PrivateKey.generate()
    raw = private_key.public_key().public_bytes(encoding=Encoding.Raw, format=PublicFormat.Raw)
    public_key_b64 = _public_key_b64(private_key)

    loaded = muat_public_key(public_key_b64)
    assert loaded.public_bytes(encoding=Encoding.Raw, format=PublicFormat.Raw) == raw
