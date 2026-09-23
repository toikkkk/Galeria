"""Konfigurasi runtime Alembic -- async, baca DATABASE_URL dari .env.

Beda dari template default ``alembic init`` (yang expect config sync): kita
pakai ``run_async_migrations`` karena engine di ``database.py`` async
(asyncpg). Pola ini standar utk SQLAlchemy 2.0 async + Alembic, lihat docs
Alembic "Using Asyncio with Alembic".
"""

from __future__ import annotations

import asyncio
import os
import sys
from logging.config import fileConfig
from pathlib import Path

from alembic import context
from dotenv import load_dotenv
from sqlalchemy import pool
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import async_engine_from_config

# Supaya "from database import Base" dan "from models.karya import Karya"
# bisa di-import walau alembic dijalankan dari mana pun.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

load_dotenv()

from database import Base  # noqa: E402
from models.karya import Karya, KaryaEmbedding  # noqa: E402,F401  -- registrasi model ke Base.metadata

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Override sqlalchemy.url (kosong di alembic.ini) dari .env
database_url = os.environ.get("DATABASE_URL", "")
if database_url:
    config.set_main_option("sqlalchemy.url", database_url)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection: Connection) -> None:
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations() -> None:
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)
    await connectable.dispose()


def run_migrations_online() -> None:
    if not config.get_main_option("sqlalchemy.url"):
        raise RuntimeError(
            "DATABASE_URL belum di-set di backend/.env -- lihat .env.example "
            "(copy connection string dari Neon dashboard)."
        )
    asyncio.run(run_async_migrations())


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
