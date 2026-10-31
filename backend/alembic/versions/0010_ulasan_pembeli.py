"""ulasan pembeli: rating + teks per pesanan selesai, dengan kolom hasil analisis sentimen

Revision ID: 0010_ulasan_pembeli
Revises: 0009_checkout_pesanan
Create Date: 2026-10-31

Satu ulasan per transaksi (``transaksi_id`` UNIK): hanya pembeli yang sudah MENERIMA karya (status selesai)
yang boleh menulis, dan hanya sekali. Kolom ``sentimen_prediksi`` dan ``prob_*`` diisi batch oleh
``ml-sentiment/scripts/analisis_ulasan_baru.py`` (IndoBERT tidak dijalankan di server); NULL = menunggu analisis.
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0010_ulasan_pembeli"
down_revision: Union[str, None] = "0009_checkout_pesanan"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "ulasan",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("transaksi_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("transaksi.id", ondelete="RESTRICT"), nullable=False, unique=True),
        sa.Column("karya_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("karya.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("pembeli_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("seniman_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("rating", sa.SmallInteger(), nullable=False),
        sa.Column("teks", sa.Text(), nullable=False),
        sa.Column("sentimen_prediksi", sa.Text(), nullable=True),
        sa.Column("prob_negatif", sa.Float(), nullable=True),
        sa.Column("prob_netral", sa.Float(), nullable=True),
        sa.Column("prob_positif", sa.Float(), nullable=True),
        sa.Column("model_version", sa.Text(), nullable=True),
        sa.Column("dihitung_pada", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("rating BETWEEN 1 AND 5", name="ulasan_rating_check"),
        sa.CheckConstraint("char_length(teks) BETWEEN 10 AND 500", name="ulasan_teks_check"),
        sa.CheckConstraint(
            "sentimen_prediksi IS NULL OR sentimen_prediksi IN ('negatif','netral','positif')", name="ulasan_sentimen_check"
        ),
    )
    op.create_index("ix_ulasan_karya", "ulasan", ["karya_id", "created_at"])
    op.create_index("ix_ulasan_seniman", "ulasan", ["seniman_id", "created_at"])


def downgrade() -> None:
    op.drop_index("ix_ulasan_seniman", table_name="ulasan")
    op.drop_index("ix_ulasan_karya", table_name="ulasan")
    op.drop_table("ulasan")
