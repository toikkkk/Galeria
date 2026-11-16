"""Model SQLAlchemy: ``kode_email`` -- kode sekali pakai 6 digit yang dikirim lewat email (migrasi 0016).

Dua tujuan: ``reset_password`` (lupa password) dan ``verifikasi_email`` (membuktikan email milik pengguna).
Kode TIDAK disimpan mentah: hanya HMAC-SHA256-nya (kunci = JWT_SECRET), jadi bocornya tabel ini tidak membocorkan kode.
"""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Integer, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from database import Base


class KodeEmail(Base):
    __tablename__ = "kode_email"
    __table_args__ = (
        CheckConstraint("tujuan IN ('reset_password','verifikasi_email')", name="kode_email_tujuan_valid"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    tujuan: Mapped[str] = mapped_column(Text, nullable=False)
    kode_hash: Mapped[str] = mapped_column(Text, nullable=False)
    kedaluwarsa_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    percobaan: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default="0")
    dipakai_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
