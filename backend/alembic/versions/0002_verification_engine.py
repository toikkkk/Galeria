"""verification engine: tabel karya_fingerprints + karya_verifikasi_log

Revision ID: 0002_verification_engine
Revises: 0001_initial
Create Date: 2026-09-28
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from pgvector.sqlalchemy import Vector
from sqlalchemy.dialects.postgresql import UUID

revision: str = "0002_verification_engine"
down_revision: Union[str, None] = "0001_initial"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

ART_TO_ART_EMBEDDING_DIM = 512

TIPE_CEK = sa.Enum("art_to_art", "art_to_ai", "manual_review", name="tipe_cek")
HASIL_CEK = sa.Enum(
    "lolos",
    "duplikat_terdeteksi",
    "ai_generated_terdeteksi",
    "ditolak_manual",
    "disetujui_manual",
    name="hasil_cek",
)


def upgrade() -> None:
    # TIDAK create() eksplisit di sini -- op.create_table() di bawah SUDAH
    # otomatis menerbitkan CREATE TYPE untuk kolom ber-tipe Enum (default
    # SQLAlchemy `create_type=True`). Memanggil .create() eksplisit DI SINI
    # JUGA menyebabkan "type already exists" krn enum dibuat dua kali --
    # sekali di sini, sekali lagi otomatis saat create_table memproses kolom
    # `tipe_cek`/`hasil` di bawah.
    op.create_table(
        "karya_fingerprints",
        sa.Column(
            "karya_id",
            UUID(as_uuid=True),
            sa.ForeignKey("karya.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column("phash", sa.Text(), nullable=False),
        sa.Column("embedding_arttoart", Vector(ART_TO_ART_EMBEDDING_DIM), nullable=False),
        sa.Column("ai_generated_probability", sa.Float(), nullable=False),
        sa.Column("ai_generated_flag", sa.Boolean(), nullable=False),
        sa.Column("model_version_arttoart", sa.Text(), nullable=False),
        sa.Column("model_version_arttoai", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(), server_default=sa.func.now()),
    )

    # HNSW L2 (Euclidean) -- BUKAN vector_cosine_ops seperti index
    # karya_embeddings. Art-to-Art dikalibrasi & dievaluasi pakai jarak
    # Euclidean (F.pairwise_distance di notebook), threshold 0.10 hanya
    # valid dalam ruang metrik itu -- pakai cosine di sini akan diam-diam
    # membuat threshold jadi tidak berarti.
    op.execute(
        "CREATE INDEX karya_fingerprints_embedding_arttoart_hnsw_idx "
        "ON karya_fingerprints USING hnsw (embedding_arttoart vector_l2_ops)"
    )

    op.create_table(
        "karya_verifikasi_log",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "karya_id",
            UUID(as_uuid=True),
            sa.ForeignKey("karya.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("tipe_cek", TIPE_CEK, nullable=False),
        sa.Column("hasil", HASIL_CEK, nullable=False),
        sa.Column("skor", sa.Float(), nullable=True),
        sa.Column(
            "referensi_karya_id",
            UUID(as_uuid=True),
            sa.ForeignKey("karya.id", ondelete="SET NULL"),
            nullable=True,
        ),
        # FK ke users.id ditambahkan via migration terpisah begitu tabel
        # users ada (Fase 1 Auth) -- lihat models/verification.py.
        sa.Column("reviewer_id", UUID(as_uuid=True), nullable=True),
        sa.Column("catatan", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now()),
    )
    # Query paling umum: "semua log 1 karya, urut waktu" (tampilan seniman
    # "kenapa karya saya ditolak?") -- index komposit sesuai pola akses itu.
    op.create_index(
        "karya_verifikasi_log_karya_id_created_at_idx",
        "karya_verifikasi_log",
        ["karya_id", "created_at"],
    )


def downgrade() -> None:
    op.drop_index("karya_verifikasi_log_karya_id_created_at_idx", table_name="karya_verifikasi_log")
    op.drop_table("karya_verifikasi_log")
    op.execute("DROP INDEX IF EXISTS karya_fingerprints_embedding_arttoart_hnsw_idx")
    op.drop_table("karya_fingerprints")
    HASIL_CEK.drop(op.get_bind(), checkfirst=True)
    TIPE_CEK.drop(op.get_bind(), checkfirst=True)
