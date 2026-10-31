"""Model SQLAlchemy: komunitas seniman, anggota, postingan, suka, dan komentar (migrasi 0013)."""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Text, func
from sqlalchemy.dialects.postgresql import ARRAY, UUID
from sqlalchemy.orm import Mapped, mapped_column

from database import Base


class Komunitas(Base):
    __tablename__ = "komunitas"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    pemilik_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False)
    nama: Mapped[str] = mapped_column(Text, nullable=False)
    deskripsi: Mapped[str | None] = mapped_column(Text, nullable=True)
    aliran: Mapped[list[str]] = mapped_column(ARRAY(Text), nullable=False, default=list)
    terbuka: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    aturan: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class KomunitasAnggota(Base):
    __tablename__ = "komunitas_anggota"

    komunitas_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("komunitas.id", ondelete="CASCADE"), primary_key=True)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    peran: Mapped[str] = mapped_column(Text, nullable=False, default="anggota")
    status: Mapped[str] = mapped_column(Text, nullable=False, default="aktif")
    bergabung_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class KomunitasPost(Base):
    __tablename__ = "komunitas_post"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    komunitas_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("komunitas.id", ondelete="CASCADE"), nullable=False)
    penulis_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False)
    teks: Mapped[str] = mapped_column(Text, nullable=False)
    image_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    disematkan: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class KomunitasLike(Base):
    __tablename__ = "komunitas_like"

    post_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("komunitas_post.id", ondelete="CASCADE"), primary_key=True)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class KomunitasKomentar(Base):
    __tablename__ = "komunitas_komentar"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    post_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("komunitas_post.id", ondelete="CASCADE"), nullable=False)
    penulis_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False)
    teks: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
