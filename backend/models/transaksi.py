"""Model SQLAlchemy: ``transaksi`` + ``kepemilikan_karya`` -- Fase 2 lanjutan
(Kepemilikan & Transaksi). Lihat ``backend/CLAUDE.md`` untuk SQL mentah &
alasan tiap kolom.
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


class StatusTransaksi(str, enum.Enum):
    MENUNGGU_PEMBAYARAN = "menunggu_pembayaran"
    DIBAYAR = "dibayar"
    DIKONFIRMASI = "dikonfirmasi"
    SELESAI = "selesai"
    DIBATALKAN = "dibatalkan"


class SumberKepemilikan(str, enum.Enum):
    UPLOAD_ASLI = "upload_asli"
    PEMBELIAN = "pembelian"
    LELANG = "lelang"
    TRANSFER_MANUAL = "transfer_manual"


class Transaksi(Base):
    """Order jual-beli. ``komisi_platform_idr`` dicatat EKSPLISIT per baris
    (bukan dihitung ulang dari persen saat laporan dibuat) -- kalau tarif
    komisi berubah di masa depan, laporan lama tetap benar. Ditandatangani
    (``digital_signature``) sbg bukti order diproses backend Galeria asli.

    ``harga_final_idr``/``komisi_platform_idr`` sengaja BIGINT (bukan INTEGER
    spt ``karya.price_idr``) -- lihat backend/CLAUDE.md "Catatan konsistensi".
    """

    __tablename__ = "transaksi"
    __table_args__ = (
        CheckConstraint("harga_final_idr > 0", name="transaksi_harga_final_idr_check"),
        CheckConstraint("komisi_platform_idr >= 0", name="transaksi_komisi_platform_idr_check"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    karya_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("karya.id", ondelete="RESTRICT"), nullable=False
    )
    pembeli_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    penjual_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    harga_final_idr: Mapped[int] = mapped_column(BigInteger, nullable=False)
    komisi_platform_idr: Mapped[int] = mapped_column(BigInteger, nullable=False)
    status: Mapped[StatusTransaksi] = mapped_column(
        Enum(StatusTransaksi, name="status_transaksi", values_callable=_values),
        nullable=False,
        default=StatusTransaksi.MENUNGGU_PEMBAYARAN,
        server_default="menunggu_pembayaran",
    )
    payload_hash: Mapped[str] = mapped_column(nullable=False)
    digital_signature: Mapped[str] = mapped_column(nullable=False)
    signing_key_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("signing_keys.id", ondelete="RESTRICT"), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class KepemilikanKarya(Base):
    """Riwayat pemilik -- BEDA dari ``karya.seniman_id`` (kreator, permanen).
    Partial unique index (lihat migration) menjamin di level DB tidak mungkin
    ada 2 "pemilik aktif" (``dilepas_at IS NULL``) untuk 1 karya bersamaan.
    """

    __tablename__ = "kepemilikan_karya"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    karya_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("karya.id", ondelete="CASCADE"), nullable=False
    )
    pemilik_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    sumber: Mapped[SumberKepemilikan] = mapped_column(
        Enum(SumberKepemilikan, name="sumber_kepemilikan", values_callable=_values), nullable=False
    )
    transaksi_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("transaksi.id", ondelete="SET NULL"), nullable=True
    )
    diperoleh_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    dilepas_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
