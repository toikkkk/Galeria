"""Model SQLAlchemy: ``karya_fingerprints`` + ``karya_verifikasi_log`` --
tabel inti "verification engine" Digital Art Identity (Art-to-Art +
Art-to-AI). Lihat CLAUDE.md bagian "Skema Data Utama" (domain 2: Karya &
Verifikasi) untuk desain lengkap & alasannya.

Dua tabel ini SENGAJA punya peran berbeda:
- ``karya_fingerprints``: snapshot TERBARU (1:1 per karya) -- dipakai untuk
  pencarian nearest-neighbor cepat (kolom vector, HNSW index).
- ``karya_verifikasi_log``: append-only, banyak baris per karya (1 per kali
  cek dijalankan) -- jejak audit "kenapa keputusan ini diambil".

CATATAN scope: kolom kriptografi (``signing_keys``/``sertifikat_keaslian``,
lihat CLAUDE.md domain 3) BELUM diimplementasikan di sini -- itu lapisan
terpisah yang dibangun DI ATAS hasil verification engine ini, bukan bagian
dari tabel ini.
"""

from __future__ import annotations

import enum
import uuid
from datetime import datetime

from pgvector.sqlalchemy import Vector
from sqlalchemy import Boolean, DateTime, Enum, Float, ForeignKey, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from database import Base

# Harus sama persis dgn output ForwardOnceWrapper di
# ml-digital-art-identity/src/export.py (SiameseConvNeXt, embedding_dim=512).
# BEDA dari EMBEDDING_DIM di models/karya.py (768, Visual Search) -- dua
# model terpisah, dua ruang vektor terpisah, JANGAN disamakan.
ART_TO_ART_EMBEDDING_DIM = 512


class TipeCek(str, enum.Enum):
    ART_TO_ART = "art_to_art"
    ART_TO_AI = "art_to_ai"
    MANUAL_REVIEW = "manual_review"


class HasilCek(str, enum.Enum):
    LOLOS = "lolos"
    DUPLIKAT_TERDETEKSI = "duplikat_terdeteksi"
    AI_GENERATED_TERDETEKSI = "ai_generated_terdeteksi"
    DITOLAK_MANUAL = "ditolak_manual"
    DISETUJUI_MANUAL = "disetujui_manual"


class KaryaFingerprint(Base):
    """Snapshot fingerprint TERBARU 1 karya (di-upsert tiap kali ``verify()``
    dijalankan ulang -- lihat ``services/digital_art_identity_service.py``).
    """

    __tablename__ = "karya_fingerprints"

    karya_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("karya.id", ondelete="CASCADE"), primary_key=True
    )
    # imagehash.phash() default (hash_size=8 -> 64-bit), disimpan sbg hex
    # string PERSIS str(imagehash.phash(img)) -- BUKAN BIGINT: hash 64-bit
    # unsigned bisa melebihi batas positif BIGINT signed Postgres (2^63-1),
    # TEXT lebih aman & tetap murah (16 karakter tetap).
    phash: Mapped[str] = mapped_column(Text, nullable=False)
    # Ruang vektor Art-to-Art (Siamese, Euclidean/L2) -- TERPISAH dari
    # karya_embeddings.embedding (Visual Search, 768-d, cosine). Lihat
    # models/karya.py utk kolom itu.
    embedding_arttoart: Mapped[list[float]] = mapped_column(
        Vector(ART_TO_ART_EMBEDDING_DIM), nullable=False
    )
    ai_generated_probability: Mapped[float] = mapped_column(Float, nullable=False)
    ai_generated_flag: Mapped[bool] = mapped_column(Boolean, nullable=False)
    # Checkpoint/versi model yang menghasilkan baris ini -- wajib dicatat
    # supaya bisa dilacak "karya lama ini dicek pakai model versi berapa"
    # kalau model di-retrain di masa depan (lihat CLAUDE.md Riwayat Keputusan #10).
    model_version_arttoart: Mapped[str] = mapped_column(Text, nullable=False)
    model_version_arttoai: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, server_default=func.now(), onupdate=func.now()
    )


class KaryaVerifikasiLog(Base):
    """Append-only: SATU baris baru tiap kali 1 jenis cek dijalankan (lihat
    ``TipeCek``). JANGAN di-``UPDATE`` -- ini jejak audit historis, re-run
    verifikasi harus menambah baris baru, bukan menimpa yang lama.
    """

    __tablename__ = "karya_verifikasi_log"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    karya_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("karya.id", ondelete="CASCADE"), nullable=False
    )
    # values_callable WAJIB ada -- default SQLAlchemy menyimpan `.name` member
    # enum ("ART_TO_ART"), bukan `.value` ("art_to_art"). Tanpa ini, insert
    # akan gagal "invalid input value for enum" krn mismatch dgn label ENUM
    # Postgres di migration (huruf kecil, lihat alembic/versions/0002_*.py).
    tipe_cek: Mapped[TipeCek] = mapped_column(
        Enum(TipeCek, name="tipe_cek", native_enum=True, values_callable=lambda e: [m.value for m in e]),
        nullable=False,
    )
    hasil: Mapped[HasilCek] = mapped_column(
        Enum(HasilCek, name="hasil_cek", native_enum=True, values_callable=lambda e: [m.value for m in e]),
        nullable=False,
    )
    # Jarak Euclidean (art_to_art) ATAU probabilitas AI-generated (art_to_ai) --
    # makna kolom ini BERGANTUNG pada tipe_cek, lihat kolom terkait sebelum baca.
    skor: Mapped[float | None] = mapped_column(Float, nullable=True)
    # Terisi kalau hasil=DUPLIKAT_TERDETEKSI -- karya lama yang jadi match.
    referensi_karya_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("karya.id", ondelete="SET NULL"), nullable=True
    )
    # FK ke users.id BELUM bisa dibuat -- tabel users belum ada (lihat CLAUDE.md
    # Fase 1 Auth). Kolom ini nullable, diisi hanya kalau tipe_cek=MANUAL_REVIEW.
    # TODO(fase auth): tambah FK via migration terpisah begitu users ada.
    reviewer_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    catatan: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
