"""Koneksi database async (Neon Postgres) + dependency FastAPI.

Tanggung jawab file ini:
- Baca ``DATABASE_URL`` dari ``.env`` (lihat ``.env.example`` untuk format).
- Bikin async engine + session factory SEKALI (dipakai ulang tiap request,
  bukan bikin koneksi baru tiap kali).
- ``Base`` -- kelas dasar untuk semua model SQLAlchemy (lihat ``models/``).
- ``get_db()`` -- FastAPI dependency, dipakai via ``Depends(get_db)`` di
  router yang butuh akses database.
"""

from __future__ import annotations

import os
from collections.abc import AsyncGenerator

from dotenv import load_dotenv
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

load_dotenv()

DATABASE_URL = os.environ.get("DATABASE_URL", "")


class Base(DeclarativeBase):
    """Kelas dasar untuk semua model SQLAlchemy di ``models/``."""


def _make_engine():
    if not DATABASE_URL:
        # Belum di-setup -- biarkan app tetap bisa start (mis. utk baca /docs),
        # tapi query ke DB akan gagal jelas saat dipakai, bukan diam-diam salah.
        return None
    return create_async_engine(DATABASE_URL, pool_pre_ping=True)


engine = _make_engine()
_session_factory = (
    async_sessionmaker(engine, expire_on_commit=False) if engine is not None else None
)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """FastAPI dependency: ``db: AsyncSession = Depends(get_db)``."""
    if _session_factory is None:
        raise RuntimeError(
            "DATABASE_URL belum di-set di backend/.env -- lihat .env.example."
        )
    async with _session_factory() as session:
        yield session
