"""fase 3: lelang + lelang_bids

Revision ID: 0005_fase3_lelang
Revises: 0004_fase2_sertifikat_transaksi
Create Date: 2026-10-01
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

revision: str = "0005_fase3_lelang"
down_revision: Union[str, None] = "0004_fase2_sertifikat_transaksi"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

STATUS_LELANG = sa.Enum("akan_datang", "berlangsung", "selesai", "dibatalkan", name="status_lelang")

# CATATAN enum: STATUS_LELANG cuma dipakai di kolom op.create_table() tabel
# BARU ("lelang") -- TIDAK perlu di-create() eksplisit (create_table otomatis
# menerbitkan CREATE TYPE). Lihat 0002/0003 utk bug yang pernah kejadian
# kalau aturan ini dilanggar.


def upgrade() -> None:
    op.create_table(
        "lelang",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "karya_id", UUID(as_uuid=True), sa.ForeignKey("karya.id", ondelete="RESTRICT"), nullable=False
        ),
        sa.Column("harga_awal_idr", sa.BigInteger(), nullable=False),
        sa.Column("kelipatan_bid_idr", sa.BigInteger(), nullable=False),
        sa.Column("mulai_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("selesai_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("status", STATUS_LELANG, nullable=False, server_default="akan_datang"),
        sa.Column(
            "pemenang_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True
        ),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.CheckConstraint("harga_awal_idr > 0", name="lelang_harga_awal_idr_check"),
        sa.CheckConstraint("kelipatan_bid_idr > 0", name="lelang_kelipatan_bid_idr_check"),
        sa.CheckConstraint("selesai_at > mulai_at", name="lelang_waktu_valid"),
    )
    op.create_index("lelang_karya_id_idx", "lelang", ["karya_id"])
    op.create_index("lelang_status_idx", "lelang", ["status"])

    op.create_table(
        "lelang_bids",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "lelang_id", UUID(as_uuid=True), sa.ForeignKey("lelang.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column(
            "bidder_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
        ),
        sa.Column("jumlah_idr", sa.BigInteger(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.CheckConstraint("jumlah_idr > 0", name="lelang_bids_jumlah_idr_check"),
    )
    # Riwayat SEMUA bid (bukan cuma tertinggi) -- transparansi & bahan dispute.
    # op.execute() langsung (bukan op.create_index) -- DESC campur kolom biasa
    # tidak selalu didukung bersih oleh signature op.create_index.
    op.execute(
        "CREATE INDEX lelang_bids_lelang_id_created_at_idx "
        "ON lelang_bids (lelang_id, created_at DESC)"
    )


def downgrade() -> None:
    op.drop_index("lelang_bids_lelang_id_created_at_idx", table_name="lelang_bids")
    op.drop_table("lelang_bids")

    op.drop_index("lelang_status_idx", table_name="lelang")
    op.drop_index("lelang_karya_id_idx", table_name="lelang")
    op.drop_table("lelang")

    STATUS_LELANG.drop(op.get_bind(), checkfirst=True)
