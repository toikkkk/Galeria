"""Model SQLAlchemy: ``events`` + ``event_tiket`` + ``event_tiket_pembelian``
-- Fase 4. Lihat ``backend/CLAUDE.md`` bagian "FASE 4 -- Event Komunitas"
untuk SQL mentah & alasan tiap kolom.
"""

from __future__ import annotations

import enum
import uuid
from datetime import datetime

from sqlalchemy import BigInteger, CheckConstraint, DateTime, Enum, ForeignKey, Integer, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from database import Base


def _values(e):
    return [m.value for m in e]


class StatusEvent(str, enum.Enum):
    DRAFT = "draft"
    DIPUBLIKASIKAN = "dipublikasikan"
    SELESAI = "selesai"
    DIBATALKAN = "dibatalkan"


class StatusTiketPembelian(str, enum.Enum):
    AKTIF = "aktif"
    TERPAKAI = "terpakai"
    DIBATALKAN = "dibatalkan"


class Event(Base):
    """Event milik komunitas (role='komunitas')."""

    __tablename__ = "events"
    __table_args__ = (CheckConstraint("selesai_at > mulai_at", name="events_waktu_valid"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    komunitas_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    judul: Mapped[str] = mapped_column(Text, nullable=False)
    deskripsi: Mapped[str | None] = mapped_column(Text, nullable=True)
    lokasi: Mapped[str | None] = mapped_column(Text, nullable=True)
    # --- migrasi 0012 ---
    tema: Mapped[str | None] = mapped_column(Text, nullable=True)
    format: Mapped[str] = mapped_column(Text, nullable=False, default="offline", server_default="offline")
    nama_lokasi: Mapped[str | None] = mapped_column(Text, nullable=True)
    alamat: Mapped[str | None] = mapped_column(Text, nullable=True)
    kota: Mapped[str | None] = mapped_column(Text, nullable=True)
    link_online: Mapped[str | None] = mapped_column(Text, nullable=True)
    mulai_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    selesai_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    status: Mapped[StatusEvent] = mapped_column(
        Enum(StatusEvent, name="status_event", values_callable=_values),
        nullable=False,
        default=StatusEvent.DRAFT,
        server_default="draft",
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class EventTiket(Base):
    """Jenis tiket per event (mis. reguler/VIP)."""

    __tablename__ = "event_tiket"
    __table_args__ = (
        CheckConstraint("harga_idr >= 0", name="event_tiket_harga_idr_check"),
        CheckConstraint("kuota >= 0", name="event_tiket_kuota_check"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    event_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("events.id", ondelete="CASCADE"), nullable=False
    )
    nama_tiket: Mapped[str] = mapped_column(Text, nullable=False)
    harga_idr: Mapped[int] = mapped_column(BigInteger, nullable=False)
    kuota: Mapped[int] = mapped_column(Integer, nullable=False)
    keterangan: Mapped[str | None] = mapped_column(Text, nullable=True)


class EventKarya(Base):
    """Karya yang dipamerkan pada sebuah event."""

    __tablename__ = "event_karya"

    event_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("events.id", ondelete="CASCADE"), primary_key=True)
    karya_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("karya.id", ondelete="RESTRICT"), primary_key=True)


class EventPesanan(Base):
    """Satu pembelian tiket (jenis + jumlah). Menahan kuota selama menunggu pembayaran / sudah dibayar."""

    __tablename__ = "event_pesanan"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    event_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("events.id", ondelete="RESTRICT"), nullable=False)
    event_tiket_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("event_tiket.id", ondelete="RESTRICT"), nullable=False)
    pembeli_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False)
    jumlah: Mapped[int] = mapped_column(Integer, nullable=False)
    harga_satuan_idr: Mapped[int] = mapped_column(BigInteger, nullable=False)
    total_idr: Mapped[int] = mapped_column(BigInteger, nullable=False)
    nama_pemegang: Mapped[str] = mapped_column(Text, nullable=False)
    status: Mapped[str] = mapped_column(Text, nullable=False, default="menunggu_pembayaran", server_default="menunggu_pembayaran")
    metode_pembayaran: Mapped[str | None] = mapped_column(Text, nullable=True)
    referensi_pembayaran: Mapped[str | None] = mapped_column(Text, nullable=True)
    batas_bayar_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    dibayar_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class EventTiketPembelian(Base):
    """E-tiket milik 1 pembeli. ``kode_tiket`` unik -- dipakai QR/check-in."""

    __tablename__ = "event_tiket_pembelian"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    event_tiket_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("event_tiket.id", ondelete="RESTRICT"), nullable=False
    )
    pembeli_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    kode_tiket: Mapped[str] = mapped_column(Text, nullable=False, unique=True)
    status: Mapped[StatusTiketPembelian] = mapped_column(
        Enum(StatusTiketPembelian, name="status_tiket_pembelian", values_callable=_values),
        nullable=False,
        default=StatusTiketPembelian.AKTIF,
        server_default="aktif",
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    # --- migrasi 0012 ---
    pesanan_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("event_pesanan.id", ondelete="RESTRICT"), nullable=True)
    nama_pemegang: Mapped[str | None] = mapped_column(Text, nullable=True)
    checkin_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
