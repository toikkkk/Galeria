"""Model SQLAlchemy: ``koleksi_favorit`` + ``notifikasi`` + ``subscriptions``
-- Fase 5 (terakhir). Lihat ``backend/CLAUDE.md`` bagian "FASE 5 --
Engagement & Monetisasi" untuk SQL mentah & alasan tiap kolom.
"""

from __future__ import annotations

import enum
import uuid
from datetime import datetime

from sqlalchemy import Boolean, CheckConstraint, DateTime, Enum, ForeignKey, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from database import Base


def _values(e):
    return [m.value for m in e]


class TipeNotifikasi(str, enum.Enum):
    TRANSAKSI = "transaksi"
    LELANG = "lelang"
    EVENT = "event"
    VERIFIKASI_KARYA = "verifikasi_karya"
    SISTEM = "sistem"


class PlanSubscription(str, enum.Enum):
    AR_AKSES = "ar_akses"
    KOMUNITAS_PRO = "komunitas_pro"


class StatusSubscription(str, enum.Enum):
    AKTIF = "aktif"
    KEDALUWARSA = "kedaluwarsa"
    DIBATALKAN = "dibatalkan"


class KoleksiFavorit(Base):
    """Wishlist -- composite PK, natural utk relasi many-to-many user<->karya."""

    __tablename__ = "koleksi_favorit"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    karya_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("karya.id", ondelete="CASCADE"), primary_key=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Notifikasi(Base):
    __tablename__ = "notifikasi"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    tipe: Mapped[TipeNotifikasi] = mapped_column(
        Enum(TipeNotifikasi, name="tipe_notifikasi", values_callable=_values), nullable=False
    )
    judul: Mapped[str] = mapped_column(Text, nullable=False)
    isi: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_read: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Subscription(Base):
    """Satu tabel utk 2 revenue model sekaligus (``plan_type``) -- strukturnya
    identik, memisah jadi 2 tabel cuma duplikasi skema tanpa manfaat.
    """

    __tablename__ = "subscriptions"
    __table_args__ = (CheckConstraint("berakhir_at > mulai_at", name="subscriptions_waktu_valid"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    plan_type: Mapped[PlanSubscription] = mapped_column(
        Enum(PlanSubscription, name="plan_subscription", values_callable=_values), nullable=False
    )
    status: Mapped[StatusSubscription] = mapped_column(
        Enum(StatusSubscription, name="status_subscription", values_callable=_values),
        nullable=False,
        default=StatusSubscription.AKTIF,
        server_default="aktif",
    )
    mulai_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    berakhir_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
