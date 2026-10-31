"""Model SQLAlchemy: ``tagihan`` (langganan & promosi) dan ``karya_promosi`` -- migrasi 0014."""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import BigInteger, Boolean, DateTime, ForeignKey, Integer, Text, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from database import Base


class Tagihan(Base):
    __tablename__ = "tagihan"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False)
    jenis: Mapped[str] = mapped_column(Text, nullable=False)  # langganan | promosi
    judul: Mapped[str] = mapped_column(Text, nullable=False)
    jumlah_idr: Mapped[int] = mapped_column(BigInteger, nullable=False)
    payload: Mapped[dict] = mapped_column(JSONB, nullable=False, default=dict)
    status: Mapped[str] = mapped_column(Text, nullable=False, default="menunggu_pembayaran", server_default="menunggu_pembayaran")
    metode_pembayaran: Mapped[str | None] = mapped_column(Text, nullable=True)
    referensi_pembayaran: Mapped[str | None] = mapped_column(Text, nullable=True)
    batas_bayar_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    dibayar_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class KaryaPromosi(Base):
    __tablename__ = "karya_promosi"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    karya_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("karya.id", ondelete="RESTRICT"), nullable=False)
    seniman_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False)
    tagihan_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("tagihan.id", ondelete="RESTRICT"), nullable=False, unique=True)
    durasi_hari: Mapped[int] = mapped_column(Integer, nullable=False)
    harga_idr: Mapped[int] = mapped_column(BigInteger, nullable=False)
    di_beranda: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    di_lelang: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    mulai_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    berakhir_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
