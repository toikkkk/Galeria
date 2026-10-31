"""lelang nyata: transaksi pemenang terhubung ke lelang, satu lelang aktif per karya

Revision ID: 0011_lelang_transaksi
Revises: 0010_ulasan_pembeli
Create Date: 2026-10-31

- ``transaksi.lelang_id`` (nullable, unik): pesanan yang lahir dari pemenang lelang. Pesanan ini dibuat tanpa
  alamat; pemenang memilih alamat sebelum membayar.
- Indeks unik parsial: satu karya hanya boleh punya SATU lelang yang masih aktif (akan_datang / berlangsung).
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0011_lelang_transaksi"
down_revision: Union[str, None] = "0010_ulasan_pembeli"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "transaksi",
        sa.Column("lelang_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("lelang.id", ondelete="RESTRICT"), nullable=True),
    )
    op.create_unique_constraint("uq_transaksi_lelang", "transaksi", ["lelang_id"])
    op.create_index(
        "uq_lelang_aktif_per_karya",
        "lelang",
        ["karya_id"],
        unique=True,
        postgresql_where=sa.text("status IN ('akan_datang','berlangsung')"),
    )
    op.create_index("ix_lelang_bids_lelang", "lelang_bids", ["lelang_id", "jumlah_idr"])


def downgrade() -> None:
    op.drop_index("ix_lelang_bids_lelang", table_name="lelang_bids")
    op.drop_index("uq_lelang_aktif_per_karya", table_name="lelang")
    op.drop_constraint("uq_transaksi_lelang", "transaksi", type_="unique")
    op.drop_column("transaksi", "lelang_id")
