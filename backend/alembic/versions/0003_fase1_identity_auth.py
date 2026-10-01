"""fase 1 identity & auth: tabel users + auth_sessions, update karya

Revision ID: 0003_fase1_identity_auth
Revises: 0002_verification_engine
Create Date: 2026-10-01
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import CITEXT, INET, UUID

revision: str = "0003_fase1_identity_auth"
down_revision: Union[str, None] = "0002_verification_engine"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

USER_ROLE = sa.Enum("seniman", "kolektor", "komunitas", "admin", name="user_role")
STATUS_VERIFIKASI_KARYA = sa.Enum(
    "menunggu", "terverifikasi", "ditolak", "perlu_ditinjau", name="status_verifikasi_karya"
)


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS citext")
    # CATATAN PENTING (dua perilaku Alembic yang beda, jangan disamaratakan):
    # - op.create_table() OTOMATIS menerbitkan CREATE TYPE utk kolom ber-tipe
    #   Enum -- USER_ROLE di bawah (dipakai tabel `users` yang baru dibuat)
    #   JANGAN di-create() eksplisit, nanti "type already exists" (lihat bug
    #   yang sama pernah kejadian di 0002_verification_engine.py).
    # - op.add_column() ke tabel yang SUDAH ADA TIDAK otomatis menerbitkan
    #   CREATE TYPE -- STATUS_VERIFIKASI_KARYA (dipakai ALTER TABLE karya di
    #   bawah) JUSTRU WAJIB di-create() eksplisit duluan, kalau tidak "type
    #   does not exist".

    op.create_table(
        "users",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("email", CITEXT(), nullable=False, unique=True),
        sa.Column("password_hash", sa.Text(), nullable=True),
        sa.Column("google_sub", sa.Text(), nullable=True, unique=True),
        sa.Column("display_name", sa.Text(), nullable=False),
        sa.Column("avatar_url", sa.Text(), nullable=True),
        sa.Column("role", USER_ROLE, nullable=False),
        sa.Column("email_verified", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), onupdate=sa.func.now()
        ),
    )
    op.create_check_constraint(
        "users_punya_kredensial_login",
        "users",
        "password_hash IS NOT NULL OR google_sub IS NOT NULL",
    )

    op.create_table(
        "auth_sessions",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("refresh_token_hash", sa.Text(), nullable=False),
        sa.Column("device_info", sa.Text(), nullable=True),
        sa.Column("ip_address", INET(), nullable=True),
        sa.Column("issued_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("auth_sessions_user_id_idx", "auth_sessions", ["user_id"])

    # --- update karya (lihat backend/CLAUDE.md "FASE 1 -- [ALTER] karya") ---
    # Semua kolom baru NULLABLE di level DB -- 8 baris seed lama tidak punya
    # nilai ini. Validasi "wajib diisi utk karya BARU" ada di endpoint upload
    # (aplikasi), bukan di sini, supaya tidak perlu backfill paksa data lama.
    op.add_column(
        "karya", sa.Column("seniman_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="RESTRICT"))
    )
    # BEDA dari USER_ROLE di atas: op.add_column() (ALTER TABLE ke tabel yang
    # SUDAH ADA) TIDAK seperti op.create_table() -- dia TIDAK otomatis
    # menerbitkan CREATE TYPE untuk kolom ber-tipe Enum, jadi tipe-nya WAJIB
    # dibuat eksplisit duluan di sini (kebalikan dari catatan di awal upgrade()).
    STATUS_VERIFIKASI_KARYA.create(op.get_bind(), checkfirst=True)
    op.add_column(
        "karya",
        sa.Column(
            "status_verifikasi", STATUS_VERIFIKASI_KARYA, nullable=False, server_default="menunggu"
        ),
    )
    op.add_column("karya", sa.Column("lebar_cm", sa.Numeric(6, 2), nullable=True))
    op.add_column("karya", sa.Column("tinggi_cm", sa.Numeric(6, 2), nullable=True))
    op.add_column("karya", sa.Column("image_key", sa.Text(), nullable=True))
    op.add_column("karya", sa.Column("file_hash", sa.Text(), nullable=True))
    # Naive DateTime (BUKAN timezone=True) -- menyamakan konvensi created_at
    # tabel ini yang sudah ada (naive sejak migration 0001).
    op.add_column("karya", sa.Column("deleted_at", sa.DateTime(), nullable=True))

    # --- tutup TODO karya_verifikasi_log.reviewer_id (ditinggalkan sengaja
    # tanpa FK di 0002_verification_engine krn users belum ada saat itu) ---
    op.create_foreign_key(
        "karya_verifikasi_log_reviewer_id_fkey",
        "karya_verifikasi_log",
        "users",
        ["reviewer_id"],
        ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    op.drop_constraint(
        "karya_verifikasi_log_reviewer_id_fkey", "karya_verifikasi_log", type_="foreignkey"
    )

    op.drop_column("karya", "deleted_at")
    op.drop_column("karya", "file_hash")
    op.drop_column("karya", "image_key")
    op.drop_column("karya", "tinggi_cm")
    op.drop_column("karya", "lebar_cm")
    op.drop_column("karya", "status_verifikasi")
    op.drop_column("karya", "seniman_id")

    op.drop_index("auth_sessions_user_id_idx", table_name="auth_sessions")
    op.drop_table("auth_sessions")
    op.drop_constraint("users_punya_kredensial_login", "users", type_="check")
    op.drop_table("users")

    bind = op.get_bind()
    STATUS_VERIFIKASI_KARYA.drop(bind, checkfirst=True)
    USER_ROLE.drop(bind, checkfirst=True)
    op.execute("DROP EXTENSION IF EXISTS citext")
