"""komunitas seniman: komunitas, anggota, postingan, suka, komentar, dan event milik komunitas

Revision ID: 0013_komunitas
Revises: 0012_event_tiket_nyata
Create Date: 2026-10-31

- ``komunitas``: dibuat oleh seorang pemilik; ``terbuka`` = siapa pun boleh bergabung, selain itu perlu disetujui.
- ``komunitas_anggota``: status ``aktif`` atau ``menunggu`` (permintaan bergabung ke komunitas tertutup).
- ``komunitas_post`` (+ foto di R2 ``komunitas/<uuid>.jpg``), ``komunitas_like``, ``komunitas_komentar``.
- ``events.komunitas_ref_id``: event yang diselenggarakan atas nama sebuah komunitas.
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0013_komunitas"
down_revision: Union[str, None] = "0012_event_tiket_nyata"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

UUID = postgresql.UUID(as_uuid=True)


def upgrade() -> None:
    op.create_table(
        "komunitas",
        sa.Column("id", UUID, primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("pemilik_id", UUID, sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("nama", sa.Text(), nullable=False),
        sa.Column("deskripsi", sa.Text(), nullable=True),
        sa.Column("aliran", postgresql.ARRAY(sa.Text()), nullable=False, server_default=sa.text("'{}'")),
        sa.Column("terbuka", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("aturan", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("uq_komunitas_nama", "komunitas", [sa.text("lower(nama)")], unique=True)
    op.create_index("ix_komunitas_pemilik", "komunitas", ["pemilik_id"])

    op.create_table(
        "komunitas_anggota",
        sa.Column("komunitas_id", UUID, sa.ForeignKey("komunitas.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("user_id", UUID, sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("peran", sa.Text(), nullable=False, server_default="anggota"),
        sa.Column("status", sa.Text(), nullable=False, server_default="aktif"),
        sa.Column("bergabung_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("peran IN ('pemilik','anggota')", name="komunitas_anggota_peran_check"),
        sa.CheckConstraint("status IN ('aktif','menunggu')", name="komunitas_anggota_status_check"),
    )
    op.create_index("ix_komunitas_anggota_user", "komunitas_anggota", ["user_id"])

    op.create_table(
        "komunitas_post",
        sa.Column("id", UUID, primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("komunitas_id", UUID, sa.ForeignKey("komunitas.id", ondelete="CASCADE"), nullable=False),
        sa.Column("penulis_id", UUID, sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("teks", sa.Text(), nullable=False),
        sa.Column("image_key", sa.Text(), nullable=True),
        sa.Column("disematkan", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint("char_length(teks) BETWEEN 1 AND 1000", name="komunitas_post_teks_check"),
    )
    op.create_index("ix_komunitas_post_feed", "komunitas_post", ["komunitas_id", "created_at"])
    op.create_index("uq_komunitas_post_sematan", "komunitas_post", ["komunitas_id"], unique=True,
                    postgresql_where=sa.text("disematkan AND deleted_at IS NULL"))

    op.create_table(
        "komunitas_like",
        sa.Column("post_id", UUID, sa.ForeignKey("komunitas_post.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("user_id", UUID, sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    op.create_table(
        "komunitas_komentar",
        sa.Column("id", UUID, primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("post_id", UUID, sa.ForeignKey("komunitas_post.id", ondelete="CASCADE"), nullable=False),
        sa.Column("penulis_id", UUID, sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("teks", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint("char_length(teks) BETWEEN 1 AND 500", name="komunitas_komentar_teks_check"),
    )
    op.create_index("ix_komunitas_komentar_post", "komunitas_komentar", ["post_id", "created_at"])

    op.add_column("events", sa.Column("komunitas_ref_id", UUID, sa.ForeignKey("komunitas.id", ondelete="SET NULL"), nullable=True))
    op.create_index("ix_events_komunitas_ref", "events", ["komunitas_ref_id"])


def downgrade() -> None:
    op.drop_index("ix_events_komunitas_ref", table_name="events")
    op.drop_column("events", "komunitas_ref_id")
    op.drop_index("ix_komunitas_komentar_post", table_name="komunitas_komentar")
    op.drop_table("komunitas_komentar")
    op.drop_table("komunitas_like")
    op.drop_index("uq_komunitas_post_sematan", table_name="komunitas_post")
    op.drop_index("ix_komunitas_post_feed", table_name="komunitas_post")
    op.drop_table("komunitas_post")
    op.drop_index("ix_komunitas_anggota_user", table_name="komunitas_anggota")
    op.drop_table("komunitas_anggota")
    op.drop_index("ix_komunitas_pemilik", table_name="komunitas")
    op.drop_index("uq_komunitas_nama", table_name="komunitas")
    op.drop_table("komunitas")
