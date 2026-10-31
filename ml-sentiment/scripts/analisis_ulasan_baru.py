"""Analisis sentimen ulasan BARU yang ditulis kolektor di aplikasi (``sentimen_prediksi IS NULL``).

Membaca ulasan yang menunggu dari Neon, memprediksi dengan IndoBERT hasil ``src/train.py``
(``models/indobert_sentimen/``), lalu mengisi ``sentimen_prediksi`` / ``prob_*`` / ``model_version``.
Hanya menyentuh baris yang masih NULL di DUA tabel: ``dummy_sentimen.ulasan`` (ulasan contoh) dan ``public.ulasan``
(ulasan pembeli nyata dari pesanan yang sudah diterima). Butuh ``DATABASE_URL`` (``backend/.env``).

    python scripts/analisis_ulasan_baru.py [--dry-run]
"""
import argparse
import asyncio
import os
from pathlib import Path

import torch
from dotenv import load_dotenv
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine
from transformers import AutoModelForSequenceClassification, AutoTokenizer

ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT.parent / "backend" / ".env")
MODEL_DIR = ROOT / "models" / "indobert_sentimen"
# (tabel, kolom id) -- kedua tabel punya kolom sentimen_prediksi/prob_*/model_version/dihitung_pada yang sama
TABEL = [("dummy_sentimen.ulasan", "ulasan_id"), ("public.ulasan", "id")]
LABELS = ["negatif", "netral", "positif"]   # urutan SAMA dgn src/train.py
MODEL_VERSION = "indobert-v1"
MAX_LEN = 64                                  # SAMA dgn pelatihan

ap = argparse.ArgumentParser()
ap.add_argument("--dry-run", action="store_true", help="hanya tampilkan prediksi, Neon tidak diubah")
args = ap.parse_args()


async def main() -> None:
    if not MODEL_DIR.is_dir():
        raise SystemExit(f"Model belum ada di {MODEL_DIR} -- jalankan src/train.py dulu.")
    url = os.environ.get("DATABASE_URL")
    if not url:
        raise SystemExit("DATABASE_URL belum di-set (backend/.env)")
    engine = create_async_engine(url)
    async with engine.begin() as conn:
        rows = []  # (tabel, kolom_id, id, teks)
        for tabel, kid in TABEL:
            for r in (await conn.execute(text(
                f"SELECT {kid} AS id, teks FROM {tabel} WHERE sentimen_prediksi IS NULL ORDER BY created_at"
            ))).mappings().all():
                rows.append((tabel, kid, r["id"], r["teks"]))
        if not rows:
            print("Tidak ada ulasan yang menunggu analisis.")
            await engine.dispose()
            return
        tok = AutoTokenizer.from_pretrained(MODEL_DIR)
        model = AutoModelForSequenceClassification.from_pretrained(MODEL_DIR).eval()
        enc = tok([r[3] for r in rows], padding="max_length", truncation=True, max_length=MAX_LEN, return_tensors="pt")
        with torch.no_grad():
            proba = torch.softmax(model(**enc).logits, dim=-1).numpy()
        for (tabel, kid, rid, teks), p in zip(rows, proba):
            label = LABELS[int(p.argmax())]
            print(f"{label:8s} {p.max():.2f}  [{tabel}] {teks[:80]}")
            if not args.dry_run:
                await conn.execute(text(f"""UPDATE {tabel}
                    SET sentimen_prediksi = :s, prob_negatif = :n, prob_netral = :e, prob_positif = :p,
                        model_version = :mv, dihitung_pada = now()
                    WHERE {kid} = :id AND sentimen_prediksi IS NULL"""),
                    {"s": label, "n": float(p[0]), "e": float(p[1]), "p": float(p[2]), "mv": MODEL_VERSION, "id": rid})
    await engine.dispose()
    print(f"{len(rows)} ulasan {'dianalisis (dry-run, tidak disimpan)' if args.dry_run else 'dianalisis dan disimpan'}.")


asyncio.run(main())
