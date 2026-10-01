"""Model SQLAlchemy: ``users`` + ``auth_sessions`` -- Fase 1 Identity & Auth.

Lihat ``backend/CLAUDE.md`` bagian "FASE 1 -- Identity & Auth" untuk SQL
mentah & alasan tiap kolom. File ini HANYA skema data -- belum ada logic
hashing password / issue JWT (itu lapisan terpisah yang dibangun DI ATAS
tabel ini, belum dikerjakan).
"""

from __future__ import annotations

import enum
import uuid
from datetime import datetime

from sqlalchemy import Boolean, CheckConstraint, DateTime, Enum, ForeignKey, Text, func
from sqlalchemy.dialects.postgresql import CITEXT, INET, UUID
from sqlalchemy.orm import Mapped, mapped_column

from database import Base


class UserRole(str, enum.Enum):
    SENIMAN = "seniman"
    KOLEKTOR = "kolektor"
    KOMUNITAS = "komunitas"
    ADMIN = "admin"


class User(Base):
    """Akun multi-role. ``password_hash``/``google_sub`` dua-duanya nullable
    (Pola A coexistence email+Google, lihat root CLAUDE.md "Autentikasi") --
    TAPI minimal satu wajib terisi, ditegakkan lewat CHECK constraint di DB,
    bukan cuma validasi aplikasi.
    """

    __tablename__ = "users"
    __table_args__ = (
        CheckConstraint(
            "password_hash IS NOT NULL OR google_sub IS NOT NULL",
            name="users_punya_kredensial_login",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    # CITEXT -- email case-insensitive ("A@x.com" == "a@x.com") di level DB,
    # bukan cuma di-lowercase manual saat insert (lihat CREATE EXTENSION citext).
    email: Mapped[str] = mapped_column(CITEXT, unique=True, nullable=False)
    password_hash: Mapped[str | None] = mapped_column(Text, nullable=True)
    google_sub: Mapped[str | None] = mapped_column(Text, unique=True, nullable=True)
    display_name: Mapped[str] = mapped_column(Text, nullable=False)
    avatar_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    role: Mapped[UserRole] = mapped_column(
        Enum(UserRole, name="user_role", values_callable=lambda e: [m.value for m in e]),
        nullable=False,
    )
    email_verified: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class AuthSession(Base):
    """Refresh token (TER-HASH, bukan mentah) + device info -- memungkinkan
    revoke (logout paksa/ban) walau JWT access token sendiri stateless.
    """

    __tablename__ = "auth_sessions"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    refresh_token_hash: Mapped[str] = mapped_column(Text, nullable=False)
    device_info: Mapped[str | None] = mapped_column(Text, nullable=True)
    ip_address: Mapped[str | None] = mapped_column(INET, nullable=True)
    issued_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
