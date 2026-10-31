"""event & tiket nyata: detail event, karya yang dipamerkan, pesanan tiket, check-in

Revision ID: 0012_event_tiket_nyata
Revises: 0011_lelang_transaksi
Create Date: 2026-10-31

- ``events``: tema, format (offline/online), lokasi terperinci, link online (hanya dibuka untuk pemegang tiket).
- ``event_karya``: karya yang dipamerkan pada sebuah event.
- ``event_pesanan``: satu pembelian tiket (jenis + jumlah), menahan kuota selama menunggu pembayaran.
- ``event_tiket_pembelian``: tiap baris = SATU e-tiket (kode unik); ``checkin_at`` terisi saat dipindai penyelenggara.
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0012_event_tiket_nyata"
down_revision: Union[str, None] = "0011_lelang_transaksi"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("events", sa.Column("tema", sa.Text(), nullable=True))
    op.add_column("events", sa.Column("format", sa.Text(), nullable=False, server_default="offline"))
    op.add_column("events", sa.Column("nama_lokasi", sa.Text(), nullable=True))
    op.add_column("events", sa.Column("alamat", sa.Text(), nullable=True))
    op.add_column("events", sa.Column("kota", sa.Text(), nullable=True))
    op.add_column("events", sa.Column("link_online", sa.Text(), nullable=True))
    op.create_check_constraint("events_format_check", "events", "format IN ('offline','online')")
    op.create_index("ix_events_status_mulai", "events", ["status", "mulai_at"])
    op.create_index("ix_events_penyelenggara", "events", ["komunitas_id", "created_at"])

    op.add_column("event_tiket", sa.Column("keterangan", sa.Text(), nullable=True))

    op.create_table(
        "event_karya",
        sa.Column("event_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("events.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("karya_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("karya.id", ondelete="RESTRICT"), primary_key=True),
    )

    op.create_table(
        "event_pesanan",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("event_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("events.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("event_tiket_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("event_tiket.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("pembeli_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("jumlah", sa.Integer(), nullable=False),
        sa.Column("harga_satuan_idr", sa.BigInteger(), nullable=False),
        sa.Column("total_idr", sa.BigInteger(), nullable=False),
        sa.Column("nama_pemegang", sa.Text(), nullable=False),
        sa.Column("status", sa.Text(), nullable=False, server_default="menunggu_pembayaran"),
        sa.Column("metode_pembayaran", sa.Text(), nullable=True),
        sa.Column("referensi_pembayaran", sa.Text(), nullable=True),
        sa.Column("batas_bayar_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("dibayar_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("jumlah BETWEEN 1 AND 5", name="event_pesanan_jumlah_check"),
        sa.CheckConstraint("status IN ('menunggu_pembayaran','dibayar','dibatalkan')", name="event_pesanan_status_check"),
    )
    op.create_index("ix_event_pesanan_pembeli", "event_pesanan", ["pembeli_id", "created_at"])
    op.create_index("ix_event_pesanan_tiket", "event_pesanan", ["event_tiket_id", "status"])

    op.add_column(
        "event_tiket_pembelian",
        sa.Column("pesanan_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("event_pesanan.id", ondelete="RESTRICT"), nullable=True),
    )
    op.add_column("event_tiket_pembelian", sa.Column("nama_pemegang", sa.Text(), nullable=True))
    op.add_column("event_tiket_pembelian", sa.Column("checkin_at", sa.DateTime(timezone=True), nullable=True))
    op.create_index("ix_tiket_pembelian_pembeli", "event_tiket_pembelian", ["pembeli_id", "created_at"])


def downgrade() -> None:
    op.drop_index("ix_tiket_pembelian_pembeli", table_name="event_tiket_pembelian")
    op.drop_column("event_tiket_pembelian", "checkin_at")
    op.drop_column("event_tiket_pembelian", "nama_pemegang")
    op.drop_column("event_tiket_pembelian", "pesanan_id")
    op.drop_index("ix_event_pesanan_tiket", table_name="event_pesanan")
    op.drop_index("ix_event_pesanan_pembeli", table_name="event_pesanan")
    op.drop_table("event_pesanan")
    op.drop_table("event_karya")
    op.drop_column("event_tiket", "keterangan")
    op.drop_index("ix_events_penyelenggara", table_name="events")
    op.drop_index("ix_events_status_mulai", table_name="events")
    op.drop_constraint("events_format_check", "events", type_="check")
    for k in ("link_online", "kota", "alamat", "nama_lokasi", "format", "tema"):
        op.drop_column("events", k)
