"""kode email sekali pakai (lupa password + verifikasi email)

Revision ID: 0016_kode_email
Revises: 0015_edit_karya_keranjang
Create Date: 2026-11-11

- ``kode_email``: kode 6 digit yang dikirim lewat email. Disimpan sebagai HMAC (bukan kode mentah), kedaluwarsa 15 menit,
  dibatasi jumlah percobaannya, dan sekali pakai (``dipakai_at``). Dihapus otomatis bila akunnya dihapus (CASCADE).
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0016_kode_email"
down_revision: Union[str, None] = "0015_edit_karya_keranjang"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

UUID = postgresql.UUID(as_uuid=True)


def upgrade() -> None:
    op.create_table(
        "kode_email",
        sa.Column("id", UUID, primary_key=True),
        sa.Column("user_id", UUID, sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("tujuan", sa.Text(), nullable=False),
        sa.Column("kode_hash", sa.Text(), nullable=False),
        sa.Column("kedaluwarsa_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("percobaan", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("dipakai_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.CheckConstraint("tujuan IN ('reset_password','verifikasi_email')", name="kode_email_tujuan_valid"),
    )
    op.create_index("ix_kode_email_user_tujuan", "kode_email", ["user_id", "tujuan", "created_at"])


def downgrade() -> None:
    op.drop_index("ix_kode_email_user_tujuan", table_name="kode_email")
    op.drop_table("kode_email")
