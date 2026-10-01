"""Model SQLAlchemy: ``signing_keys`` + ``sertifikat_keaslian`` -- kriptografi
sertifikat digital keaslian (asymmetric-key digital signature).

Lihat ``backend/CLAUDE.md`` bagian "FASE 2 -- ... + Kriptografi Sertifikat"
untuk SQL mentah & alasan tiap kolom.
"""

from __future__ import annotations

import enum
import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from database import Base


class ArtToArtHasilSertifikat(str, enum.Enum):
    BERSIH = "bersih"
    DUPLIKAT_TERDETEKSI = "duplikat_terdeteksi"


class AiDetectionHasilSertifikat(str, enum.Enum):
    ASLI = "asli"
    AI_GENERATED_TERDETEKSI = "ai_generated_terdeteksi"


class StatusAkhirSertifikat(str, enum.Enum):
    TERVERIFIKASI = "terverifikasi"
    DITOLAK = "ditolak"


def _values(e):
    return [m.value for m in e]


class SigningKey(Base):
    """Registry public key + referensi KMS. PRIVATE KEY TIDAK PERNAH jadi
    kolom di sini -- lihat backend/CLAUDE.md kenapa.
    """

    __tablename__ = "signing_keys"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    public_key: Mapped[str] = mapped_column(Text, nullable=False)
    algorithm: Mapped[str] = mapped_column(Text, nullable=False)  # mis. "Ed25519"
    kms_key_ref: Mapped[str] = mapped_column(Text, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class SertifikatKeaslian(Base):
    """Snapshot hasil verifikasi final + digital signature.

    APPEND-ONLY -- TIDAK ADA updated_at, tidak boleh di-UPDATE sama sekali
    setelah ditandatangani (ubah 1 karakter = signature invalid). Re-verifikasi
    = INSERT baris baru + update karya.sertifikat_aktif_id.
    """

    __tablename__ = "sertifikat_keaslian"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    karya_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("karya.id", ondelete="CASCADE"), nullable=False
    )
    file_hash: Mapped[str] = mapped_column(Text, nullable=False)  # snapshot, immutable
    art_to_art_result: Mapped[ArtToArtHasilSertifikat] = mapped_column(
        Enum(
            ArtToArtHasilSertifikat,
            name="art_to_art_hasil_sertifikat",
            values_callable=_values,
        ),
        nullable=False,
    )
    ai_detection_result: Mapped[AiDetectionHasilSertifikat] = mapped_column(
        Enum(
            AiDetectionHasilSertifikat,
            name="ai_detection_hasil_sertifikat",
            values_callable=_values,
        ),
        nullable=False,
    )
    status_akhir: Mapped[StatusAkhirSertifikat] = mapped_column(
        Enum(StatusAkhirSertifikat, name="status_akhir_sertifikat", values_callable=_values),
        nullable=False,
    )
    verified_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    payload_hash: Mapped[str] = mapped_column(Text, nullable=False)
    digital_signature: Mapped[str] = mapped_column(Text, nullable=False)
    signing_key_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("signing_keys.id", ondelete="RESTRICT"), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
