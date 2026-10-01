"""fase 5 (terakhir): koleksi_favorit + notifikasi + subscriptions

Revision ID: 0007_fase5_engagement
Revises: 0006_fase4_event
Create Date: 2026-10-01
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

revision: str = "0007_fase5_engagement"
down_revision: Union[str, None] = "0006_fase4_event"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TIPE_NOTIFIKASI = sa.Enum(
    "transaksi", "lelang", "event", "verifikasi_karya", "sistem", name="tipe_notifikasi"
)
PLAN_SUBSCRIPTION = sa.Enum("ar_akses", "komunitas_pro", name="plan_subscription")
STATUS_SUBSCRIPTION = sa.Enum("aktif", "kedaluwarsa", "dibatalkan", name="status_subscription")

# CATATAN enum: ketiga enum di atas cuma dipakai di kolom op.create_table()
# tabel BARU ("notifikasi", "subscriptions") -- TIDAK perlu di-create()
# eksplisit (create_table otomatis menerbitkan CREATE TYPE). Lihat 0002/0003
# utk bug yang pernah kejadian kalau aturan ini dilanggar.


def upgrade() -> None:
    op.create_table(
        "koleksi_favorit",
        sa.Column(
            "user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
        ),
        sa.Column(
            "karya_id", UUID(as_uuid=True), sa.ForeignKey("karya.id", ondelete="CASCADE"), primary_key=True
        ),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    op.create_table(
        "notifikasi",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("tipe", TIPE_NOTIFIKASI, nullable=False),
        sa.Column("judul", sa.Text(), nullable=False),
        sa.Column("isi", sa.Text(), nullable=True),
        sa.Column("is_read", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    # op.execute() langsung (bukan op.create_index) -- DESC campur kolom
    # biasa tidak selalu didukung bersih oleh signature op.create_index
    # (lihat catatan yang sama di 0005_fase3_lelang.py).
    op.execute(
        "CREATE INDEX notifikasi_user_id_created_at_idx "
        "ON notifikasi (user_id, created_at DESC)"
    )

    op.create_table(
        "subscriptions",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("plan_type", PLAN_SUBSCRIPTION, nullable=False),
        sa.Column("status", STATUS_SUBSCRIPTION, nullable=False, server_default="aktif"),
        sa.Column("mulai_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("berakhir_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.CheckConstraint("berakhir_at > mulai_at", name="subscriptions_waktu_valid"),
    )
    op.create_index("subscriptions_user_id_idx", "subscriptions", ["user_id"])


def downgrade() -> None:
    op.drop_index("subscriptions_user_id_idx", table_name="subscriptions")
    op.drop_table("subscriptions")

    op.drop_index("notifikasi_user_id_created_at_idx", table_name="notifikasi")
    op.drop_table("notifikasi")

    op.drop_table("koleksi_favorit")

    bind = op.get_bind()
    STATUS_SUBSCRIPTION.drop(bind, checkfirst=True)
    PLAN_SUBSCRIPTION.drop(bind, checkfirst=True)
    TIPE_NOTIFIKASI.drop(bind, checkfirst=True)
