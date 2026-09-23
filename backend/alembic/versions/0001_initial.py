"""initial: extension vector + tabel karya + karya_embeddings

Revision ID: 0001_initial
Revises:
Create Date: 2026-09-23
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from pgvector.sqlalchemy import Vector
from sqlalchemy.dialects.postgresql import UUID

revision: str = "0001_initial"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

EMBEDDING_DIM = 768


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS vector")

    op.create_table(
        "karya",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("title", sa.String(), nullable=False),
        sa.Column("artist_name", sa.String(), nullable=False),
        sa.Column("style_name", sa.String(), nullable=False),
        sa.Column("gallery_name", sa.String(), nullable=False),
        sa.Column("price_idr", sa.Integer(), nullable=False),
        sa.Column("is_promoted", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("image_filename", sa.String(), nullable=False),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now()),
    )

    op.create_table(
        "karya_embeddings",
        sa.Column(
            "karya_id",
            UUID(as_uuid=True),
            sa.ForeignKey("karya.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column("embedding", Vector(EMBEDDING_DIM), nullable=False),
    )

    # Index HNSW cosine -- nearest-neighbor search Visual Search.
    # Belum kritis di skala 8 baris (seed awal), tapi disiapkan dari sekarang
    # supaya tidak perlu migration terpisah nanti pas katalog membesar.
    op.execute(
        "CREATE INDEX karya_embeddings_embedding_hnsw_idx "
        "ON karya_embeddings USING hnsw (embedding vector_cosine_ops)"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS karya_embeddings_embedding_hnsw_idx")
    op.drop_table("karya_embeddings")
    op.drop_table("karya")
