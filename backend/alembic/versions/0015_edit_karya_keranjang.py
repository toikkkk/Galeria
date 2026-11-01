"""deskripsi karya (edit karya oleh seniman) dan keranjang kolektor

Revision ID: 0015_edit_karya_keranjang
Revises: 0014_langganan_promosi
Create Date: 2026-11-01

- ``karya.deskripsi``: teks bebas dari seniman (nullable; karya lama kosong).
- ``keranjang_item``: karya yang ditaruh kolektor di keranjang. Karya seni itu unik (stok 1), jadi tidak ada
  kolom jumlah; composite PK (user_id, karya_id) membuat menambah dua kali tidak menggandakan.
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0015_edit_karya_keranjang"
down_revision: Union[str, None] = "0014_langganan_promosi"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

UUID = postgresql.UUID(as_uuid=True)


def upgrade() -> None:
    op.add_column("karya", sa.Column("deskripsi", sa.Text(), nullable=True))
    op.create_table(
        "keranjang_item",
        sa.Column("user_id", UUID, sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("karya_id", UUID, sa.ForeignKey("karya.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_keranjang_user", "keranjang_item", ["user_id", "created_at"])


def downgrade() -> None:
    op.drop_index("ix_keranjang_user", table_name="keranjang_item")
    op.drop_table("keranjang_item")
    op.drop_column("karya", "deskripsi")
