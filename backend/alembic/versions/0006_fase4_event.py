"""fase 4: events + event_tiket + event_tiket_pembelian

Revision ID: 0006_fase4_event
Revises: 0005_fase3_lelang
Create Date: 2026-10-01
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

revision: str = "0006_fase4_event"
down_revision: Union[str, None] = "0005_fase3_lelang"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

STATUS_EVENT = sa.Enum("draft", "dipublikasikan", "selesai", "dibatalkan", name="status_event")
STATUS_TIKET_PEMBELIAN = sa.Enum("aktif", "terpakai", "dibatalkan", name="status_tiket_pembelian")

# CATATAN enum: kedua enum di atas cuma dipakai di kolom op.create_table()
# tabel BARU ("events", "event_tiket_pembelian") -- TIDAK perlu di-create()
# eksplisit (create_table otomatis menerbitkan CREATE TYPE). Lihat 0002/0003
# utk bug yang pernah kejadian kalau aturan ini dilanggar.


def upgrade() -> None:
    op.create_table(
        "events",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "komunitas_id",
            UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("judul", sa.Text(), nullable=False),
        sa.Column("deskripsi", sa.Text(), nullable=True),
        sa.Column("lokasi", sa.Text(), nullable=True),
        sa.Column("mulai_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("selesai_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("status", STATUS_EVENT, nullable=False, server_default="draft"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.CheckConstraint("selesai_at > mulai_at", name="events_waktu_valid"),
    )
    op.create_index("events_komunitas_id_idx", "events", ["komunitas_id"])

    op.create_table(
        "event_tiket",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "event_id", UUID(as_uuid=True), sa.ForeignKey("events.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("nama_tiket", sa.Text(), nullable=False),
        sa.Column("harga_idr", sa.BigInteger(), nullable=False),
        sa.Column("kuota", sa.Integer(), nullable=False),
        sa.CheckConstraint("harga_idr >= 0", name="event_tiket_harga_idr_check"),
        sa.CheckConstraint("kuota >= 0", name="event_tiket_kuota_check"),
    )

    op.create_table(
        "event_tiket_pembelian",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "event_tiket_id",
            UUID(as_uuid=True),
            sa.ForeignKey("event_tiket.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column(
            "pembeli_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
        ),
        sa.Column("kode_tiket", sa.Text(), nullable=False, unique=True),
        sa.Column("status", STATUS_TIKET_PEMBELIAN, nullable=False, server_default="aktif"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("event_tiket_pembelian_pembeli_id_idx", "event_tiket_pembelian", ["pembeli_id"])


def downgrade() -> None:
    op.drop_index("event_tiket_pembelian_pembeli_id_idx", table_name="event_tiket_pembelian")
    op.drop_table("event_tiket_pembelian")
    op.drop_table("event_tiket")
    op.drop_index("events_komunitas_id_idx", table_name="events")
    op.drop_table("events")

    bind = op.get_bind()
    STATUS_TIKET_PEMBELIAN.drop(bind, checkfirst=True)
    STATUS_EVENT.drop(bind, checkfirst=True)
