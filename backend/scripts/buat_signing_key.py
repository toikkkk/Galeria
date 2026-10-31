"""Generate 1 keypair Ed25519 baru untuk sertifikat keaslian & transaksi (kriptografi
Digital Art Identity) -- genda.md/ml-digital-art-identity/TODO_KRIPTOGRAFI.md Tahap 2.

Kebijakan penyimpanan key: lihat ml-digital-art-identity/SPEC_PAYLOAD.md bagian 1.3.
Private key disimpan di environment variable (backend/.env, DI-GITIGNORE) -- BUKAN KMS
komersial sungguhan untuk skala prototipe akademik ini. kms_key_ref di tabel signing_keys
cuma menunjuk NAMA env var-nya, bukan key mentah.

Idempotent & AMAN secara default: kalau sudah ada signing key AKTIF di database, script
ini BERHENTI tanpa membuat apa pun (mencegah 2 key aktif bersamaan tanpa sengaja, yang akan
membingungkan -- key mana yang dipakai utk tanda tangan BARU jadi ambigu). Pakai --force
untuk tetap membuat key baru + otomatis menonaktifkan key aktif lama (lihat SPEC_PAYLOAD.md
bagian 1.4-1.5 -- key lama tetap valid untuk verifikasi sertifikat lama, cuma tidak dipakai
lagi untuk tanda tangan baru).

Jalankan (dari folder backend/, venv aktif, .env sudah diisi DATABASE_URL):
    python -m scripts.buat_signing_key
    python -m scripts.buat_signing_key --force   # kalau sengaja mau rotasi key
"""

from __future__ import annotations

import argparse
import asyncio
import base64
import re
from datetime import datetime, timezone
from pathlib import Path

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from sqlalchemy import func, select, update

from database import _session_factory, engine
from models.sertifikat import SigningKey

ENV_PATH = Path(__file__).resolve().parents[1] / ".env"


def _nama_env_var(versi: int) -> str:
    return f"SIGNING_PRIVATE_KEY_V{versi}"


def _tulis_ke_env(nama: str, nilai_base64: str) -> None:
    """Tambahkan baris baru ke backend/.env (TIDAK PERNAH menimpa baris SIGNING_PRIVATE_KEY_*
    yang sudah ada -- setiap versi key harus tetap bisa dibaca utk verifikasi key lama)."""
    teks = ENV_PATH.read_text(encoding="utf-8") if ENV_PATH.exists() else ""
    if re.search(rf"(?m)^{nama}=", teks):
        raise RuntimeError(f"{nama} sudah ada di .env -- tidak boleh ditimpa (akan menghilangkan key lama).")
    teks = teks.rstrip("\n") + f"\n{nama}={nilai_base64}\n"
    ENV_PATH.write_text(teks, encoding="utf-8")


async def buat_key(force: bool) -> None:
    if engine is None or _session_factory is None:
        raise RuntimeError(
            "DATABASE_URL belum di-set di backend/.env -- lihat .env.example sebelum menjalankan ini."
        )

    async with _session_factory() as db:
        aktif = (
            await db.scalars(select(SigningKey).where(SigningKey.is_active.is_(True)))
        ).all()

        if aktif and not force:
            print(f"[BERHENTI] Sudah ada {len(aktif)} signing key AKTIF di database:")
            for k in aktif:
                print(f"  - id={k.id}  kms_key_ref={k.kms_key_ref}  dibuat={k.created_at}")
            print("Tidak membuat key baru (cegah 2 key aktif bersamaan tanpa sengaja).")
            print("Pakai --force kalau memang sengaja mau rotasi key.")
            return

        # 1. Generate keypair Ed25519 nyata
        private_key = Ed25519PrivateKey.generate()
        public_key = private_key.public_key()

        priv_b64 = base64.b64encode(
            private_key.private_bytes(
                encoding=serialization.Encoding.Raw,
                format=serialization.PrivateFormat.Raw,
                encryption_algorithm=serialization.NoEncryption(),
            )
        ).decode("ascii")
        pub_b64 = base64.b64encode(
            public_key.public_bytes(
                encoding=serialization.Encoding.Raw,
                format=serialization.PublicFormat.Raw,
            )
        ).decode("ascii")

        # 2. Nomor versi key = jumlah signing_keys yang PERNAH ada + 1 (bukan cuma yg aktif)
        #    -- supaya nama env var tidak pernah bentrok walau key lama sudah di-revoke.
        total_pernah_ada = await db.scalar(select(func.count()).select_from(SigningKey))
        versi = (total_pernah_ada or 0) + 1
        nama_env = _nama_env_var(versi)

        # 3. Tulis private key ke .env SEBELUM insert ke DB -- kalau tulis .env gagal
        #    (mis. file terkunci), jangan sampai ada baris signing_keys tanpa private key-nya.
        _tulis_ke_env(nama_env, priv_b64)

        # 4. Nonaktifkan key lama (kalau --force dipakai dgn key aktif sebelumnya) -- lihat
        #    SPEC_PAYLOAD.md 1.5: revoked_at ditandai, TAPI baris lama TIDAK dihapus (sertifikat
        #    lama tetap bisa diverifikasi lewat signing_key_id yang tercatat di record-nya).
        if aktif:
            sekarang = datetime.now(timezone.utc)
            await db.execute(
                update(SigningKey)
                .where(SigningKey.id.in_([k.id for k in aktif]))
                .values(is_active=False, revoked_at=sekarang)
            )
            print(f"[ROTASI] {len(aktif)} key lama ditandai is_active=False, revoked_at={sekarang.isoformat()}")

        # 5. Insert key baru
        key_baru = SigningKey(
            public_key=pub_b64,
            algorithm="Ed25519",
            kms_key_ref=f"env:{nama_env}",
            is_active=True,
        )
        db.add(key_baru)
        await db.commit()
        await db.refresh(key_baru)

        print(f"\n[SELESAI] Signing key baru dibuat: id={key_baru.id}")
        print(f"  algorithm   : {key_baru.algorithm}")
        print(f"  kms_key_ref : {key_baru.kms_key_ref}")
        print(f"  public_key  : {pub_b64}")
        print(f"\nPrivate key sudah ditulis ke {ENV_PATH} sebagai {nama_env}=...")
        print("JANGAN commit file .env ini -- sudah di-gitignore, tapi pastikan tidak ter-copy manual ke tempat lain.")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--force", action="store_true", help="Tetap buat key baru walau sudah ada key aktif (rotasi)")
    args = ap.parse_args()
    asyncio.run(buat_key(force=args.force))
