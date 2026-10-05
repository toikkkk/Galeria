"""Query katalog dummy + rekomendasi -- SQL mentah ke schema data dummy.

Schema dibaca dari env ``REKOMENDASI_SCHEMA`` (divalidasi regex sebelum
disisipkan ke SQL; nama schema tidak bisa di-bind sebagai parameter). Semua
nilai dari user selalu lewat parameter ter-bind. Tidak menyentuh ``public.*``
dan tidak memakai model ORM/Alembic (schema ini di luar rantai migrasi tim).
"""

from __future__ import annotations

import os
import re
import uuid

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

_SCHEMA_RE = re.compile(r"^[a-z_][a-z0-9_]*$")

# Kode alasan (kosakata tetap, lihat ml-recommender/README.md) -> teks Indonesia.
_ALASAN_TEKS = {
    "gaya_favorit": "Sesuai aliran favoritmu: {aliran}",
    "harga_sesuai": "Harga sesuai kebiasaan belanjamu",
    "seniman_naik_daun": "Penjualan seniman ini sedang naik",
    "gaya_ramai": "Aliran ini sedang ramai",
    "pernah_beli_seniman": "Kamu pernah membeli dari seniman ini",
    "karya_baru": "Baru terpasang",
    "populer_umum": "Sedang diminati kolektor lain",
}

_URUTAN = {
    "terbaru": "k.created_at DESC, k.id",
    "harga_asc": "k.price_idr ASC, k.id",
    "harga_desc": "k.price_idr DESC, k.id",
}

# Kolom karya yang dikirim ke app (bentuk = ``Karya.fromJson`` + field tambahan).
_KOLOM_KARYA = """
    k.id, k.title, s.display_name AS artist_name, k.style_name,
    'Studio ' || s.display_name AS gallery_name, k.price_idr,
    k.image_filename, k.image_key, k.seniman_id, k.lebar_cm, k.tinggi_cm
"""

_BELUM_TERJUAL = """
    LEFT JOIN {S}.transaksi tr ON tr.karya_id = k.id
"""


def _schema() -> str:
    s = os.environ.get("REKOMENDASI_SCHEMA", "dummy_rekomendasi")
    if not _SCHEMA_RE.match(s):
        raise RuntimeError("REKOMENDASI_SCHEMA tidak valid (harus ^[a-z_][a-z0-9_]*$)")
    return s


def parse_uuid(value: str) -> uuid.UUID | None:
    try:
        return uuid.UUID(value)
    except ValueError:
        return None


def image_url(image_key: str | None) -> str | None:
    base = os.environ.get("R2_PUBLIC_URL_BASE", "").strip()
    if not image_key or not base:
        return None
    return f"{base.rstrip('/')}/{image_key}"


def _karya_dict(r) -> dict:
    return {
        "id": str(r["id"]),
        "title": r["title"],
        "artist_name": r["artist_name"],
        "style_name": r["style_name"],
        "gallery_name": r["gallery_name"],
        "price_idr": int(r["price_idr"]),
        "is_promoted": False,
        "image_filename": r["image_filename"],
        "image_url": image_url(r["image_key"]),
        "seniman_id": str(r["seniman_id"]),
        "lebar_cm": float(r["lebar_cm"]) if r["lebar_cm"] is not None else None,
        "tinggi_cm": float(r["tinggi_cm"]) if r["tinggi_cm"] is not None else None,
    }


def teks_alasan(alasan: list, style_name: str) -> list[dict]:
    """Ubah daftar kode alasan (list kode, atau list objek berisi ``kode``) jadi teks."""
    hasil = []
    for a in alasan or []:
        kode = a.get("kode") if isinstance(a, dict) else a
        if kode not in _ALASAN_TEKS:
            continue
        hasil.append({"kode": kode, "teks": _ALASAN_TEKS[kode].format(aliran=style_name)})
    return hasil


async def katalog(
    db: AsyncSession,
    *,
    page: int,
    page_size: int,
    gaya: str | None,
    harga_min: int | None,
    harga_maks: int | None,
    q: str | None,
    urut: str,
    hanya_tersedia: bool,
) -> tuple[list[dict], int]:
    S = _schema()
    where = ["TRUE"]
    params: dict = {"limit": page_size, "offset": (page - 1) * page_size}
    if gaya:
        where.append("k.style_name = :gaya")
        params["gaya"] = gaya
    if harga_min is not None:
        where.append("k.price_idr >= :hmin")
        params["hmin"] = harga_min
    if harga_maks is not None:
        where.append("k.price_idr <= :hmaks")
        params["hmaks"] = harga_maks
    if q:
        escaped = q.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
        where.append("(k.title ILIKE :q OR s.display_name ILIKE :q)")
        params["q"] = f"%{escaped}%"
    if hanya_tersedia:
        where.append("tr.id IS NULL")
    kondisi = " AND ".join(where)
    dasar = f"""
        FROM {S}.karya k
        JOIN {S}.seniman s ON s.id = k.seniman_id
        {_BELUM_TERJUAL.format(S=S)}
        WHERE {kondisi}
    """
    total = (await db.execute(text(f"SELECT count(*) {dasar}"), params)).scalar_one()
    rows = (
        await db.execute(
            text(f"SELECT {_KOLOM_KARYA} {dasar} ORDER BY {_URUTAN[urut]} LIMIT :limit OFFSET :offset"),
            params,
        )
    ).mappings()
    return [_karya_dict(r) for r in rows], total


async def kolektor_demo(db: AsyncSession, n: int = 5) -> list[dict]:
    """Kolektor contoh yang punya baris rekomendasi, divariasikan per segmen."""
    S = _schema()
    rows = (
        await db.execute(
            text(
                f"""
                SELECT DISTINCT ON (coalesce(ks.segmen_id, -1))
                    c.id, c.display_name, ks.segmen_nama AS segmen,
                    (SELECT count(*) FROM {S}.transaksi t WHERE t.pembeli_id = c.id) AS n_pembelian
                FROM {S}.kolektor c
                JOIN {S}.rekomendasi_kolektor r ON r.kolektor_id = c.id
                LEFT JOIN {S}.kolektor_segmen ks ON ks.kolektor_id = c.id
                ORDER BY coalesce(ks.segmen_id, -1), c.id
                """
            )
        )
    ).mappings().all()
    return [
        {
            "id": str(r["id"]),
            "display_name": r["display_name"],
            "segmen": r["segmen"],
            "n_pembelian": int(r["n_pembelian"]),
        }
        for r in rows[:n]
    ]


async def kolektor_ada(db: AsyncSession, kolektor_id: uuid.UUID) -> bool:
    S = _schema()
    r = await db.execute(text(f"SELECT 1 FROM {S}.kolektor WHERE id = :id"), {"id": kolektor_id})
    return r.first() is not None


async def segmen_kolektor(db: AsyncSession, kolektor_id: uuid.UUID) -> dict | None:
    S = _schema()
    r = (
        await db.execute(
            text(f"SELECT segmen_id, segmen_nama FROM {S}.kolektor_segmen WHERE kolektor_id = :id"),
            {"id": kolektor_id},
        )
    ).mappings().first()
    return {"id": r["segmen_id"], "nama": r["segmen_nama"]} if r else None


async def rekomendasi(db: AsyncSession, kolektor_id: uuid.UUID, top_k: int) -> dict | None:
    """Baca ``rekomendasi_kolektor``; ``None`` bila kolektor belum punya hasil."""
    S = _schema()
    rows = (
        await db.execute(
            text(
                f"""
                SELECT r.peringkat, r.skor, r.alasan, r.strategi, r.model_version, r.dihitung_pada,
                       {_KOLOM_KARYA}
                FROM {S}.rekomendasi_kolektor r
                JOIN {S}.karya k ON k.id = r.karya_id
                JOIN {S}.seniman s ON s.id = k.seniman_id
                {_BELUM_TERJUAL.format(S=S)}
                WHERE r.kolektor_id = :id AND tr.id IS NULL
                ORDER BY r.peringkat
                LIMIT :k
                """
            ),
            {"id": kolektor_id, "k": top_k},
        )
    ).mappings().all()
    if not rows:
        return None
    items = [
        {
            "peringkat": r["peringkat"],
            "skor": round(float(r["skor"]), 4),
            "alasan": teks_alasan(r["alasan"], r["style_name"]),
            "karya": _karya_dict(r),
        }
        for r in rows
    ]
    return {
        "kolektor_id": str(kolektor_id),
        "strategi": rows[0]["strategi"],
        "model_version": rows[0]["model_version"],
        "dihitung_pada": rows[0]["dihitung_pada"].isoformat().replace("+00:00", "Z"),
        "segmen": await segmen_kolektor(db, kolektor_id),
        "items": items,
    }
