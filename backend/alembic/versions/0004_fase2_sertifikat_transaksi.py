"""fase 2 lanjutan: signing_keys + sertifikat_keaslian + transaksi + kepemilikan_karya

Revision ID: 0004_fase2_sertifikat_transaksi
Revises: 0003_fase1_identity_auth
Create Date: 2026-10-01
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

revision: str = "0004_fase2_sertifikat_transaksi"
down_revision: Union[str, None] = "0003_fase1_identity_auth"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

ART_TO_ART_HASIL_SERTIFIKAT = sa.Enum(
    "bersih", "duplikat_terdeteksi", name="art_to_art_hasil_sertifikat"
)
AI_DETECTION_HASIL_SERTIFIKAT = sa.Enum(
    "asli", "ai_generated_terdeteksi", name="ai_detection_hasil_sertifikat"
)
STATUS_AKHIR_SERTIFIKAT = sa.Enum("terverifikasi", "ditolak", name="status_akhir_sertifikat")
STATUS_TRANSAKSI = sa.Enum(
    "menunggu_pembayaran", "dibayar", "dikonfirmasi", "selesai", "dibatalkan", name="status_transaksi"
)
SUMBER_KEPEMILIKAN = sa.Enum(
    "upload_asli", "pembelian", "lelang", "transfer_manual", name="sumber_kepemilikan"
)

# CATATAN enum (lihat 0002/0003 utk bug yang pernah kejadian): SEMUA enum di
# migration ini HANYA dipakai di kolom op.create_table() tabel BARU -- jadi
# TIDAK ADA yang perlu di-create() eksplisit (create_table otomatis
# menerbitkan CREATE TYPE). Beda kasusnya kalau nanti ada enum dipakai lewat
# op.add_column() ke tabel yang SUDAH ADA (spt status_verifikasi_karya di 0003).


def upgrade() -> None:
    op.create_table(
        "signing_keys",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("public_key", sa.Text(), nullable=False),
        sa.Column("algorithm", sa.Text(), nullable=False),
        sa.Column("kms_key_ref", sa.Text(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
    )

    op.create_table(
        "sertifikat_keaslian",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "karya_id", UUID(as_uuid=True), sa.ForeignKey("karya.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("file_hash", sa.Text(), nullable=False),
        sa.Column("art_to_art_result", ART_TO_ART_HASIL_SERTIFIKAT, nullable=False),
        sa.Column("ai_detection_result", AI_DETECTION_HASIL_SERTIFIKAT, nullable=False),
        sa.Column("status_akhir", STATUS_AKHIR_SERTIFIKAT, nullable=False),
        sa.Column("verified_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("payload_hash", sa.Text(), nullable=False),
        sa.Column("digital_signature", sa.Text(), nullable=False),
        sa.Column(
            "signing_key_id",
            UUID(as_uuid=True),
            sa.ForeignKey("signing_keys.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        # TIDAK ADA updated_at -- APPEND-ONLY, lihat models/sertifikat.py.
    )
    op.create_index("sertifikat_keaslian_karya_id_idx", "sertifikat_keaslian", ["karya_id"])

    # Resolusi circular FK karya <-> sertifikat_keaslian (lihat backend/CLAUDE.md
    # "Urutan eksekusi") -- dilakukan di sini, SETELAH sertifikat_keaslian ada.
    op.add_column(
        "karya",
        sa.Column(
            "sertifikat_aktif_id",
            UUID(as_uuid=True),
            sa.ForeignKey("sertifikat_keaslian.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )

    op.create_table(
        "transaksi",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "karya_id", UUID(as_uuid=True), sa.ForeignKey("karya.id", ondelete="RESTRICT"), nullable=False
        ),
        sa.Column(
            "pembeli_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
        ),
        sa.Column(
            "penjual_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
        ),
        sa.Column("harga_final_idr", sa.BigInteger(), nullable=False),
        sa.Column("komisi_platform_idr", sa.BigInteger(), nullable=False),
        sa.Column(
            "status", STATUS_TRANSAKSI, nullable=False, server_default="menunggu_pembayaran"
        ),
        sa.Column("payload_hash", sa.Text(), nullable=False),
        sa.Column("digital_signature", sa.Text(), nullable=False),
        sa.Column(
            "signing_key_id",
            UUID(as_uuid=True),
            sa.ForeignKey("signing_keys.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), onupdate=sa.func.now()
        ),
        sa.CheckConstraint("harga_final_idr > 0", name="transaksi_harga_final_idr_check"),
        sa.CheckConstraint("komisi_platform_idr >= 0", name="transaksi_komisi_platform_idr_check"),
    )
    op.create_index("transaksi_karya_id_idx", "transaksi", ["karya_id"])
    op.create_index("transaksi_pembeli_id_idx", "transaksi", ["pembeli_id"])
    op.create_index("transaksi_penjual_id_idx", "transaksi", ["penjual_id"])

    op.create_table(
        "kepemilikan_karya",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "karya_id", UUID(as_uuid=True), sa.ForeignKey("karya.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column(
            "pemilik_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
        ),
        sa.Column("sumber", SUMBER_KEPEMILIKAN, nullable=False),
        sa.Column(
            "transaksi_id",
            UUID(as_uuid=True),
            sa.ForeignKey("transaksi.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("diperoleh_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("dilepas_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    # Partial unique index -- menjamin DI LEVEL DATABASE tidak mungkin ada 2
    # "pemilik aktif" (dilepas_at IS NULL) utk 1 karya bersamaan.
    op.create_index(
        "kepemilikan_karya_satu_pemilik_aktif_idx",
        "kepemilikan_karya",
        ["karya_id"],
        unique=True,
        postgresql_where=sa.text("dilepas_at IS NULL"),
    )
    op.create_index("kepemilikan_karya_pemilik_id_idx", "kepemilikan_karya", ["pemilik_id"])


def downgrade() -> None:
    op.drop_index("kepemilikan_karya_pemilik_id_idx", table_name="kepemilikan_karya")
    op.drop_index("kepemilikan_karya_satu_pemilik_aktif_idx", table_name="kepemilikan_karya")
    op.drop_table("kepemilikan_karya")

    op.drop_index("transaksi_penjual_id_idx", table_name="transaksi")
    op.drop_index("transaksi_pembeli_id_idx", table_name="transaksi")
    op.drop_index("transaksi_karya_id_idx", table_name="transaksi")
    op.drop_table("transaksi")

    op.drop_column("karya", "sertifikat_aktif_id")

    op.drop_index("sertifikat_keaslian_karya_id_idx", table_name="sertifikat_keaslian")
    op.drop_table("sertifikat_keaslian")

    op.drop_table("signing_keys")

    bind = op.get_bind()
    SUMBER_KEPEMILIKAN.drop(bind, checkfirst=True)
    STATUS_TRANSAKSI.drop(bind, checkfirst=True)
    STATUS_AKHIR_SERTIFIKAT.drop(bind, checkfirst=True)
    AI_DETECTION_HASIL_SERTIFIKAT.drop(bind, checkfirst=True)
    ART_TO_ART_HASIL_SERTIFIKAT.drop(bind, checkfirst=True)
