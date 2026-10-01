"""Model SQLAlchemy: ``lelang`` + ``lelang_bids`` -- Fase 3. Lihat
``backend/CLAUDE.md`` bagian "FASE 3 -- Lelang" untuk SQL mentah & alasan
tiap kolom.
"""

from __future__ import annotations

import enum
import uuid
from datetime import datetime

from sqlalchemy import BigInteger, CheckConstraint, DateTime, Enum, ForeignKey, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from database import Base


def _values(e):
    return [m.value for m in e]


class StatusLelang(str, enum.Enum):
    AKAN_DATANG = "akan_datang"
    BERLANGSUNG = "berlangsung"
    SELESAI = "selesai"
    DIBATALKAN = "dibatalkan"


class Lelang(Base):
    """Listing lelang per karya."""

    __tablename__ = "lelang"
    __table_args__ = (
        CheckConstraint("harga_awal_idr > 0", name="lelang_harga_awal_idr_check"),
        CheckConstraint("kelipatan_bid_idr > 0", name="lelang_kelipatan_bid_idr_check"),
        CheckConstraint("selesai_at > mulai_at", name="lelang_waktu_valid"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    karya_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("karya.id", ondelete="RESTRICT"), nullable=False
    )
    harga_awal_idr: Mapped[int] = mapped_column(BigInteger, nullable=False)
    kelipatan_bid_idr: Mapped[int] = mapped_column(BigInteger, nullable=False)
    mulai_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    selesai_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    status: Mapped[StatusLelang] = mapped_column(
        Enum(StatusLelang, name="status_lelang", values_callable=_values),
        nullable=False,
        default=StatusLelang.AKAN_DATANG,
        server_default="akan_datang",
    )
    pemenang_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class LelangBid(Base):
    """Riwayat SEMUA bid (bukan cuma tertinggi) -- transparansi & bahan dispute."""

    __tablename__ = "lelang_bids"
    __table_args__ = (CheckConstraint("jumlah_idr > 0", name="lelang_bids_jumlah_idr_check"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    lelang_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("lelang.id", ondelete="CASCADE"), nullable=False
    )
    bidder_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    jumlah_idr: Mapped[int] = mapped_column(BigInteger, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
