"""langganan, promosi karya, tagihan generik, dan tautan notifikasi

Revision ID: 0014_langganan_promosi
Revises: 0013_komunitas
Create Date: 2026-10-31

- ``tagihan``: tagihan yang dibayar lewat pembayaran sandbox untuk produk non-karya (langganan & promosi).
  Saat dibayar, server menerbitkan ``subscriptions`` (atau memperpanjangnya) / ``karya_promosi``.
- ``karya_promosi``: promosi karya berbayar yang aktif sampai ``berakhir_at`` (hanya lahir setelah tagihan dibayar).
- ``notifikasi.tautan``: tujuan saat notifikasi diketuk (mis. ``pesanan:<uuid>``, ``lelang:<uuid>``).
- nilai enum ``tipe_notifikasi`` baru: ``komunitas``.
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0014_langganan_promosi"
down_revision: Union[str, None] = "0013_komunitas"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

UUID = postgresql.UUID(as_uuid=True)


def upgrade() -> None:
    with op.get_context().autocommit_block():
        op.execute("ALTER TYPE tipe_notifikasi ADD VALUE IF NOT EXISTS 'komunitas'")

    op.add_column("notifikasi", sa.Column("tautan", sa.Text(), nullable=True))
    op.create_index("ix_notifikasi_user", "notifikasi", ["user_id", "created_at"])
    op.create_index("ix_notifikasi_belum", "notifikasi", ["user_id"], postgresql_where=sa.text("NOT is_read"))

    op.create_table(
        "tagihan",
        sa.Column("id", UUID, primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", UUID, sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("jenis", sa.Text(), nullable=False),
        sa.Column("judul", sa.Text(), nullable=False),
        sa.Column("jumlah_idr", sa.BigInteger(), nullable=False),
        sa.Column("payload", postgresql.JSONB(), nullable=False, server_default=sa.text("'{}'::jsonb")),
        sa.Column("status", sa.Text(), nullable=False, server_default="menunggu_pembayaran"),
        sa.Column("metode_pembayaran", sa.Text(), nullable=True),
        sa.Column("referensi_pembayaran", sa.Text(), nullable=True),
        sa.Column("batas_bayar_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("dibayar_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("jenis IN ('langganan','promosi')", name="tagihan_jenis_check"),
        sa.CheckConstraint("status IN ('menunggu_pembayaran','dibayar','dibatalkan')", name="tagihan_status_check"),
        sa.CheckConstraint("jumlah_idr > 0", name="tagihan_jumlah_check"),
    )
    op.create_index("ix_tagihan_user", "tagihan", ["user_id", "created_at"])

    op.create_table(
        "karya_promosi",
        sa.Column("id", UUID, primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("karya_id", UUID, sa.ForeignKey("karya.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("seniman_id", UUID, sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("tagihan_id", UUID, sa.ForeignKey("tagihan.id", ondelete="RESTRICT"), nullable=False, unique=True),
        sa.Column("durasi_hari", sa.Integer(), nullable=False),
        sa.Column("harga_idr", sa.BigInteger(), nullable=False),
        sa.Column("di_beranda", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("di_lelang", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("mulai_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("berakhir_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("berakhir_at > mulai_at", name="karya_promosi_waktu_check"),
    )
    op.create_index("ix_karya_promosi_karya", "karya_promosi", ["karya_id", "berakhir_at"])
    op.create_index("ix_karya_promosi_seniman", "karya_promosi", ["seniman_id", "berakhir_at"])

    op.create_index("ix_subscriptions_user_plan", "subscriptions", ["user_id", "plan_type", "berakhir_at"])


def downgrade() -> None:
    op.drop_index("ix_subscriptions_user_plan", table_name="subscriptions")
    op.drop_index("ix_karya_promosi_seniman", table_name="karya_promosi")
    op.drop_index("ix_karya_promosi_karya", table_name="karya_promosi")
    op.drop_table("karya_promosi")
    op.drop_index("ix_tagihan_user", table_name="tagihan")
    op.drop_table("tagihan")
    op.drop_index("ix_notifikasi_belum", table_name="notifikasi")
    op.drop_index("ix_notifikasi_user", table_name="notifikasi")
    op.drop_column("notifikasi", "tautan")
    # nilai enum 'komunitas' tidak dihapus (PostgreSQL tidak mendukung DROP VALUE dengan aman)
