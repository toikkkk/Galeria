"""checkout & pesanan: alamat pengiriman, nomor HP, siklus hidup transaksi

Revision ID: 0009_checkout_pesanan
Revises: 0008_artwork_id
Create Date: 2026-10-31

- ``users.nomor_hp`` (nullable): dipakai penjual/kurir menghubungi pembeli.
- ``alamat_pengiriman``: buku alamat per pengguna (satu bisa ditandai utama).
- ``transaksi``: kolom siklus hidup (alamat snapshot, metode & referensi bayar, batas bayar, cap waktu tiap
  tahap, kurir/resi). Alamat disimpan sebagai SNAPSHOT supaya mengubah/menghapus alamat di buku alamat
  tidak mengubah pesanan lama.
- Indeks unik parsial: satu karya hanya boleh punya SATU transaksi yang belum dibatalkan, jadi dua kolektor
  yang menekan "beli" bersamaan tidak mungkin sama-sama berhasil (dijamin database, bukan hanya aplikasi).
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0009_checkout_pesanan"
down_revision: Union[str, None] = "0008_artwork_id"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("users", sa.Column("nomor_hp", sa.Text(), nullable=True))

    op.create_table(
        "alamat_pengiriman",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("label", sa.Text(), nullable=False),
        sa.Column("nama_penerima", sa.Text(), nullable=False),
        sa.Column("telepon", sa.Text(), nullable=False),
        sa.Column("alamat_lengkap", sa.Text(), nullable=False),
        sa.Column("kota", sa.Text(), nullable=False),
        sa.Column("kode_pos", sa.Text(), nullable=False),
        sa.Column("is_utama", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_alamat_pengiriman_user", "alamat_pengiriman", ["user_id"])
    op.create_index(
        "uq_alamat_utama_per_user", "alamat_pengiriman", ["user_id"], unique=True, postgresql_where=sa.text("is_utama")
    )

    op.add_column("transaksi", sa.Column("alamat_snapshot", postgresql.JSONB(), nullable=True))
    op.add_column("transaksi", sa.Column("metode_pembayaran", sa.Text(), nullable=True))
    op.add_column("transaksi", sa.Column("referensi_pembayaran", sa.Text(), nullable=True))
    op.add_column("transaksi", sa.Column("batas_bayar_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("transaksi", sa.Column("dibayar_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("transaksi", sa.Column("dikonfirmasi_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("transaksi", sa.Column("dikirim_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("transaksi", sa.Column("selesai_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("transaksi", sa.Column("dibatalkan_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("transaksi", sa.Column("kurir", sa.Text(), nullable=True))
    op.add_column("transaksi", sa.Column("no_resi", sa.Text(), nullable=True))
    op.create_index(
        "uq_transaksi_karya_aktif",
        "transaksi",
        ["karya_id"],
        unique=True,
        postgresql_where=sa.text("status <> 'dibatalkan'"),
    )
    op.create_index("ix_transaksi_pembeli", "transaksi", ["pembeli_id", "created_at"])
    op.create_index("ix_transaksi_penjual", "transaksi", ["penjual_id", "created_at"])


def downgrade() -> None:
    op.drop_index("ix_transaksi_penjual", table_name="transaksi")
    op.drop_index("ix_transaksi_pembeli", table_name="transaksi")
    op.drop_index("uq_transaksi_karya_aktif", table_name="transaksi")
    for kolom in (
        "no_resi", "kurir", "dibatalkan_at", "selesai_at", "dikirim_at", "dikonfirmasi_at",
        "dibayar_at", "batas_bayar_at", "referensi_pembayaran", "metode_pembayaran", "alamat_snapshot",
    ):
        op.drop_column("transaksi", kolom)
    op.drop_index("uq_alamat_utama_per_user", table_name="alamat_pengiriman")
    op.drop_index("ix_alamat_pengiriman_user", table_name="alamat_pengiriman")
    op.drop_table("alamat_pengiriman")
    op.drop_column("users", "nomor_hp")
