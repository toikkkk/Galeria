"""Gambar lukisan BERAGAM untuk akun demo, diambil dari subset WikiArt lokal (``ml-visual-search/data/raw``).

Sebelumnya akun demo memakai hanya 8 gambar dasar (satu per aliran) yang dipotong acak, sehingga banyak karya
tampak kembar. Di sini tiap karya mendapat lukisan berbeda dari aliran yang sama.

Catatan lisensi: WikiArt = riset non-komersial. Aman untuk demo akademik/pameran, JANGAN dibawa ke rilis komersial.
"""

from __future__ import annotations

import csv
import io
import random
from pathlib import Path

from PIL import Image

RAW = Path(__file__).resolve().parents[2] / "ml-visual-search" / "data" / "raw"

# label aliran di aplikasi -> nama kelas di metadata WikiArt
_KELAS = {
    "Impressionism": "Impressionism",
    "Romanticism": "Romanticism",
    "Cubism": "Cubism",
    "Expressionism": "Expressionism",
    "Post Impressionism": "Post_Impressionism",
    "Baroque": "Baroque",
    "Art Nouveau": "Art_Nouveau",
    "Symbolism": "Symbolism",
}

_per_gaya: dict[str, list[str]] | None = None
_dipakai: set[str] = set()


def _muat() -> dict[str, list[str]]:
    global _per_gaya
    if _per_gaya is None:
        meta = RAW / "metadata.csv"
        if not meta.exists():
            raise SystemExit(f"Dataset WikiArt lokal tidak ditemukan: {meta}")
        peta: dict[str, list[str]] = {}
        with meta.open(encoding="utf-8") as f:
            for r in csv.DictReader(f):
                peta.setdefault(r["style_name"], []).append(r["filename"])
        _per_gaya = peta
    return _per_gaya


def ambil(rnd: random.Random, gaya: str) -> bytes:
    """Satu lukisan (JPEG, sisi terpanjang <= 1400 px) dari aliran ``gaya``, belum dipakai karya demo lain."""
    kelas = _KELAS[gaya]
    kandidat = list(_muat().get(kelas, []))
    rnd.shuffle(kandidat)
    for nama in kandidat[:400]:
        if nama in _dipakai:
            continue
        berkas = RAW / nama
        if not berkas.exists():
            continue
        try:
            im = Image.open(berkas).convert("RGB")
        except Exception:  # noqa: BLE001 - gambar rusak dilewati
            continue
        w, h = im.size
        # hindari bentuk ekstrem (panorama/strip) dan gambar terlalu kecil: kurang pantas dipajang di kartu & AR
        if min(w, h) < 600 or not (0.62 <= w / h <= 1.7):
            continue
        _dipakai.add(nama)
        im.thumbnail((1400, 1400))
        buf = io.BytesIO()
        im.save(buf, "JPEG", quality=88)
        return buf.getvalue()
    raise SystemExit(f"Tidak menemukan gambar yang cocok untuk aliran {gaya}.")
