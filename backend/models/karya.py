"""Model SQLAlchemy: ``karya`` (katalog marketplace) + ``karya_embeddings``
(vector Visual Search, pgvector).

Field ``karya`` sengaja mirror persis ``mobile/lib/models/karya.dart`` (class
``Karya`` + ``sampleKarya``) supaya response API tinggal dipetakan 1:1 ke
model Flutter, tanpa perlu terjemahan field di kedua sisi.

``karya_embeddings`` dipisah dari ``karya`` (bukan kolom langsung) --
future-proof untuk kasus 1 karya punya multi-embedding (mis. beberapa foto
sudut berbeda per karya).
"""

from __future__ import annotations

import enum
import uuid
from datetime import datetime

from pgvector.sqlalchemy import Vector
from sqlalchemy import DateTime, Enum, ForeignKey, Numeric, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from database import Base

# Harus sama persis dgn dimensi output ml-visual-search/export/model.onnx
# (convnext_small penultimate layer). LIHAT CATATAN plan: config.yaml bilang
# 2048 tapi itu basi (sisa baseline ResNet50) -- yang benar 768.
EMBEDDING_DIM = 768


class StatusVerifikasiKarya(str, enum.Enum):
    MENUNGGU = "menunggu"
    TERVERIFIKASI = "terverifikasi"
    DITOLAK = "ditolak"
    PERLU_DITINJAU = "perlu_ditinjau"


class Karya(Base):
    __tablename__ = "karya"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    title: Mapped[str] = mapped_column(nullable=False)
    artist_name: Mapped[str] = mapped_column(nullable=False)
    style_name: Mapped[str] = mapped_column(nullable=False)
    # Nama galeri/sanggar penjual -- dipakai jg utk pencarian (lihat
    # Karya.matchesQuery di sisi Flutter).
    gallery_name: Mapped[str] = mapped_column(nullable=False)
    # Placeholder/contoh, BUKAN harga transaksi nyata (belum ada data
    # transaksi aktual di platform) -- sama seperti komentar di karya.dart.
    price_idr: Mapped[int] = mapped_column(nullable=False)
    is_promoted: Mapped[bool] = mapped_column(default=False, nullable=False)
    # Nama file gambar, dicocokkan ke aset lokal yang sudah dibundling di
    # mobile/assets/images/catalog/ -- BELUM ada hosting gambar (R2) di fase
    # ini, lihat CLAUDE.md "Di Luar Scope".
    image_filename: Mapped[str] = mapped_column(nullable=False)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())

    # --- Kolom Fase 1 (lihat backend/CLAUDE.md "FASE 1 -- [ALTER] karya") ---
    # Nullable di DB meski konsepnya "wajib" -- 8 baris seed lama tidak
    # punya nilai ini. Validasi "wajib diisi utk karya BARU" ada di level
    # endpoint upload (Pydantic), bukan NOT NULL DB, supaya data lama tidak
    # perlu di-backfill paksa sebelum migration jalan.
    seniman_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), nullable=True
    )
    status_verifikasi: Mapped[StatusVerifikasiKarya] = mapped_column(
        Enum(
            StatusVerifikasiKarya,
            name="status_verifikasi_karya",
            values_callable=lambda e: [m.value for m in e],
        ),
        nullable=False,
        default=StatusVerifikasiKarya.MENUNGGU,
        server_default="menunggu",
    )
    # Ukuran fisik (cm) -- wajib utk fitur AR Simulation (skala nyata).
    lebar_cm: Mapped[float | None] = mapped_column(Numeric(6, 2, asdecimal=False), nullable=True)
    tinggi_cm: Mapped[float | None] = mapped_column(Numeric(6, 2, asdecimal=False), nullable=True)
    # Object key R2 -- lihat root CLAUDE.md "Cara Kerja Cloudflare R2". NULL =
    # masih pakai asset lokal via image_filename (belum migrasi ke R2).
    image_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    # SHA-256 exact-integrity hash file gambar saat ini -- BEDA dari phash
    # (fuzzy) di karya_fingerprints, lihat backend/CLAUDE.md domain kriptografi.
    file_hash: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Soft-delete -- karya yang pernah terjual/disertifikasi tidak boleh
    # hilang fisik dari tabel (histori pembeli/sertifikat jadi yatim piatu).
    # Naive DateTime (BUKAN timezone=True) -- menyamakan konvensi created_at
    # di tabel ini yang sudah ada (naive sejak migration 0001).
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(), nullable=True)
    # --- Kolom Fase 2 (lihat backend/CLAUDE.md "[ALTER] karya -- pointer
    # sertifikat aktif") -- ditambah SETELAH tabel sertifikat_keaslian ada,
    # resolusi circular FK (karya <-> sertifikat_keaslian saling rujuk).
    sertifikat_aktif_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("sertifikat_keaslian.id", ondelete="SET NULL"), nullable=True
    )

    embedding: Mapped["KaryaEmbedding"] = relationship(
        back_populates="karya", uselist=False, cascade="all, delete-orphan"
    )


class KaryaEmbedding(Base):
    __tablename__ = "karya_embeddings"

    karya_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("karya.id", ondelete="CASCADE"), primary_key=True
    )
    embedding: Mapped[list[float]] = mapped_column(Vector(EMBEDDING_DIM), nullable=False)

    karya: Mapped[Karya] = relationship(back_populates="embedding")
