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

import uuid
from datetime import datetime

from pgvector.sqlalchemy import Vector
from sqlalchemy import ForeignKey, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from database import Base

# Harus sama persis dgn dimensi output ml-visual-search/export/model.onnx
# (convnext_small penultimate layer). LIHAT CATATAN plan: config.yaml bilang
# 2048 tapi itu basi (sisa baseline ResNet50) -- yang benar 768.
EMBEDDING_DIM = 768


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
