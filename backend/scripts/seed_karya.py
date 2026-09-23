"""Seed 8 karya contoh ke database + hitung embedding-nya.

Data di-copy PERSIS dari ``mobile/lib/models/karya.dart`` (``sampleKarya``)
supaya konsisten dengan yang sudah tampil di UI mobile (title, artist, style,
gallery, harga placeholder — lihat komentar di file Dart itu untuk konteks
lengkap kenapa data ini "contoh", bukan data transaksi nyata).

Embedding dihitung lewat ``VisualSearchService.embed()`` yang SAMA persis
dipakai untuk query live (bukan reuse dari ``catalog_embeddings.npz`` --
nama file gambar di ``mobile/assets/images/catalog/`` beda dari index WikiArt
asli, jadi dihitung ulang di sini).

Idempotent: skip baris yang title+artist_name-nya sudah ada di database.

Jalankan (dari folder backend/, venv aktif, .env sudah diisi DATABASE_URL):
    python -m scripts.seed_karya
"""

from __future__ import annotations

import asyncio
import os
from pathlib import Path

from PIL import Image
from sqlalchemy import select

from database import _session_factory, engine
from models.karya import Karya, KaryaEmbedding
from services.visual_search_service import VisualSearchService

BASE_DIR = Path(__file__).parent.parent
ML_DIR = BASE_DIR.parent / "ml-visual-search"
CATALOG_DIR = BASE_DIR.parent / "mobile" / "assets" / "images" / "catalog"

# Copy persis dari mobile/lib/models/karya.dart -> sampleKarya.
SAMPLE_KARYA = [
    {
        "image_filename": "impressionism_01.jpg",
        "title": "Tanpa Judul (Impresionisme)",
        "artist_name": "Pierre-Auguste Renoir",
        "style_name": "Impressionism",
        "gallery_name": "Galeri Hadiprana, Jakarta",
        "price_idr": 185_000_000,
        "is_promoted": False,
    },
    {
        "image_filename": "post_impressionism_01.jpg",
        "title": "Tanpa Judul (Pasca-Impresionisme)",
        "artist_name": "Vincent van Gogh",
        "style_name": "Post Impressionism",
        "gallery_name": "D'Gallerie Jakarta",
        "price_idr": 420_000_000,
        "is_promoted": True,
    },
    {
        "image_filename": "romanticism_01.jpg",
        "title": "Tanpa Judul (Romantisisme)",
        "artist_name": "Ivan Aivazovsky",
        "style_name": "Romanticism",
        "gallery_name": "Artemis Art Gallery",
        "price_idr": 95_000_000,
        "is_promoted": False,
    },
    {
        "image_filename": "baroque_01.jpg",
        "title": "Tanpa Judul (Barok)",
        "artist_name": "Rembrandt",
        "style_name": "Baroque",
        "gallery_name": "Sanggar Rupa Nusantara",
        "price_idr": 610_000_000,
        "is_promoted": True,
    },
    {
        "image_filename": "cubism_01.jpg",
        "title": "Tanpa Judul (Kubisme)",
        "artist_name": "Pablo Picasso",
        "style_name": "Cubism",
        "gallery_name": "Studio Bentang Alam",
        "price_idr": 980_000_000,
        "is_promoted": True,
    },
    {
        "image_filename": "art_nouveau_01.jpg",
        "title": "Tanpa Judul (Art Nouveau)",
        "artist_name": "Boris Kustodiev",
        "style_name": "Art Nouveau",
        "gallery_name": "Selasar Sunaryo Art Space",
        "price_idr": 72_000_000,
        "is_promoted": False,
    },
    {
        "image_filename": "expressionism_01.jpg",
        "title": "Tanpa Judul (Ekspresionisme)",
        "artist_name": "Pyotr Konchalovsky",
        "style_name": "Expressionism",
        "gallery_name": "Studio Bimo Setiawan",
        "price_idr": 138_000_000,
        "is_promoted": False,
    },
    {
        "image_filename": "symbolism_01.jpg",
        "title": "Tanpa Judul (Simbolisme)",
        "artist_name": "Martiros Saryan",
        "style_name": "Symbolism",
        "gallery_name": "Komunitas Alam Tropis",
        "price_idr": 64_000_000,
        "is_promoted": False,
    },
]


async def seed() -> None:
    if engine is None or _session_factory is None:
        raise RuntimeError(
            "DATABASE_URL belum di-set di backend/.env -- lihat .env.example "
            "(copy connection string dari Neon dashboard) sebelum menjalankan seed."
        )

    service = VisualSearchService(
        model_path=os.environ.get("VS_MODEL_PATH", ML_DIR / "export" / "model.onnx"),
        label_map_path=os.environ.get(
            "VS_LABEL_MAP_PATH", ML_DIR / "data" / "cache" / "label_to_idx__style_name.json"
        ),
    )
    service.load()

    inserted = 0
    skipped = 0

    async with _session_factory() as db:
        for item in SAMPLE_KARYA:
            existing = await db.scalar(
                select(Karya).where(
                    Karya.title == item["title"], Karya.artist_name == item["artist_name"]
                )
            )
            if existing is not None:
                print(f"  SKIP (sudah ada): {item['title']} -- {item['artist_name']}")
                skipped += 1
                continue

            image_path = CATALOG_DIR / item["image_filename"]
            if not image_path.exists():
                print(f"  GAGAL (gambar tidak ditemukan): {image_path}")
                continue

            image = Image.open(image_path).convert("RGB")
            embedding = service.embed(image)

            karya = Karya(
                title=item["title"],
                artist_name=item["artist_name"],
                style_name=item["style_name"],
                gallery_name=item["gallery_name"],
                price_idr=item["price_idr"],
                is_promoted=item["is_promoted"],
                image_filename=item["image_filename"],
            )
            db.add(karya)
            await db.flush()  # supaya karya.id terisi sebelum dipakai di bawah

            db.add(KaryaEmbedding(karya_id=karya.id, embedding=embedding))
            print(f"  INSERT: {item['title']} -- {item['artist_name']}")
            inserted += 1

        await db.commit()

    print(f"\nSelesai. {inserted} baris baru, {skipped} dilewati (sudah ada).")


if __name__ == "__main__":
    asyncio.run(seed())
