"""kriptografi: tambah karya.artwork_id (human-readable, mis. GAL-ART-2026-000001)

Revision ID: 0008_artwork_id
Revises: 0007_fase5_engagement
Create Date: 2026-10-26

Lihat ml-digital-art-identity/kriptografi.md bagian 5.1 -- Artwork ID adalah
identitas APLIKASI (untuk QR code, halaman verifikasi publik, dll), BEDA dari
``karya.id`` (UUID, kunci primer internal). Nullable + UNIQUE (bukan NOT NULL):
diisi SAAT karya pertama kali lolos verifikasi (lihat services/sertifikat_service.py),
karya yang belum/tidak pernah lolos verifikasi tidak pernah punya artwork_id.
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0008_artwork_id"
down_revision: Union[str, None] = "0007_fase5_engagement"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("karya", sa.Column("artwork_id", sa.Text(), nullable=True))
    op.create_unique_constraint("uq_karya_artwork_id", "karya", ["artwork_id"])


def downgrade() -> None:
    op.drop_constraint("uq_karya_artwork_id", "karya", type_="unique")
    op.drop_column("karya", "artwork_id")
