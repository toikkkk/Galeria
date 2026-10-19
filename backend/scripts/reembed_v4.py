"""Hitung ulang embedding katalog di Neon memakai model yang aktif di backend/.env (v4).

Kenapa perlu: embedding lama dihitung model v2; ruang vektor v4 berbeda, jadi
pencarian karya mirip salah sampai embedding dihitung ulang.

Yang dilakukan:
  1. Cadangkan embedding lama ke backend/scripts/embedding_backup_<waktu>.npz
  2. UPDATE kolom `embedding` baris yang sudah ada di `karya_embeddings`
     (tidak menghapus baris, tidak menyentuh tabel `karya`).

Jalankan dari folder backend:
    .venv\\Scripts\\python -m scripts.reembed_v4
"""

from __future__ import annotations

import asyncio
import json
import os
import time
from pathlib import Path

import numpy as np
from dotenv import load_dotenv
from PIL import Image
from sqlalchemy import text

BACKEND = Path(__file__).resolve().parent.parent
load_dotenv(BACKEND / ".env")

from database import engine  # noqa: E402
from services.visual_search_service import VisualSearchService  # noqa: E402

CATALOG_DIR = BACKEND.parent / "mobile" / "assets" / "images" / "catalog"


def _path(env: str) -> Path:
    p = Path(os.environ[env])
    return p if p.is_absolute() else (BACKEND / p).resolve()


async def main() -> None:
    if engine is None:
        raise RuntimeError("DATABASE_URL belum di-set di backend/.env")
    svc = VisualSearchService(_path("VS_MODEL_PATH"), _path("VS_LABEL_MAP_PATH"))
    svc.load()
    print("model:", _path("VS_MODEL_PATH"))

    async with engine.begin() as conn:
        rows = (
            await conn.execute(
                text(
                    "select e.karya_id, k.image_filename, e.embedding::text "
                    "from karya_embeddings e join karya k on k.id = e.karya_id"
                )
            )
        ).all()
        backup = BACKEND / "scripts" / f"embedding_backup_{time.strftime('%Y%m%d_%H%M%S')}.npz"
        np.savez(
            backup,
            ids=[str(r[0]) for r in rows],
            emb=np.array([json.loads(r[2]) for r in rows]),
        )
        print("cadangan:", backup)

        for karya_id, filename, _ in rows:
            path = CATALOG_DIR / filename
            if not path.exists():
                print("  LEWAT (gambar tidak ada):", filename)
                continue
            vec = svc.embed(Image.open(path).convert("RGB"))
            await conn.execute(
                text("update karya_embeddings set embedding = cast(:v as vector) where karya_id = :i"),
                {"v": json.dumps([float(x) for x in vec]), "i": karya_id},
            )
            print("  update", filename, len(vec))
    print("selesai")


if __name__ == "__main__":
    asyncio.run(main())
