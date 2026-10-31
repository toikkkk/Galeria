"""Model SQLAlchemy: ``ulasan`` (ulasan pembeli atas pesanan yang sudah diterima)."""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, Float, ForeignKey, SmallInteger, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from database import Base


class Ulasan(Base):
    __tablename__ = "ulasan"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    transaksi_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("transaksi.id", ondelete="RESTRICT"), nullable=False, unique=True
    )
    karya_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("karya.id", ondelete="RESTRICT"), nullable=False)
    pembeli_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False)
    seniman_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False)
    rating: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    teks: Mapped[str] = mapped_column(Text, nullable=False)
    sentimen_prediksi: Mapped[str | None] = mapped_column(Text, nullable=True)
    prob_negatif: Mapped[float | None] = mapped_column(Float, nullable=True)
    prob_netral: Mapped[float | None] = mapped_column(Float, nullable=True)
    prob_positif: Mapped[float | None] = mapped_column(Float, nullable=True)
    model_version: Mapped[str | None] = mapped_column(Text, nullable=True)
    dihitung_pada: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
