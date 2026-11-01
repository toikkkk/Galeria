"""Isi sentimen ulasan yang masih menunggu (``sentimen_prediksi IS NULL``) memakai model ringan server.

Ulasan baru sudah otomatis dianalisis saat dikirim; skrip ini untuk ulasan LAMA yang terkirim sebelum fitur itu ada.
Hanya menyentuh baris NULL di ``public.ulasan`` (idempotent, aman dijalankan berulang).

    python -m scripts.analisis_ulasan_tertunda [--dry-run]
"""

from __future__ import annotations

import argparse
import asyncio

from sqlalchemy import select

from database import _session_factory, engine
from models.ulasan import Ulasan
from services import sentimen_ringan


async def main(dry: bool) -> None:
    if sentimen_ringan.prediksi("tes") is None:
        raise SystemExit(f"Bobot model tidak ada: {sentimen_ringan.BERKAS} -- jalankan ml-sentiment/scripts/latih_ringan.py dulu.")
    from datetime import datetime, timezone

    async with _session_factory() as db:
        rows = (await db.execute(select(Ulasan).where(Ulasan.sentimen_prediksi.is_(None)))).scalars().all()
        for u in rows:
            h = sentimen_ringan.prediksi(u.teks)
            print(f"{h['label']:8s} {max(h['prob'].values()):.2f}  {u.teks[:80]}")
            if not dry:
                u.sentimen_prediksi, u.model_version, u.dihitung_pada = h["label"], h["model_version"], datetime.now(timezone.utc)
                u.prob_negatif, u.prob_netral, u.prob_positif = (h["prob"][k] for k in ("negatif", "netral", "positif"))
        if not dry:
            await db.commit()
    await engine.dispose()
    print(f"{len(rows)} ulasan {'(dry-run, tidak disimpan)' if dry else 'diisi'}.")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    asyncio.run(main(ap.parse_args().dry_run))
