"""Tetapkan segmen tiap kolektor dengan model clustering, lalu isi tabel ``kolektor_segmen`` di Neon.

Model dimuat dari ``models/clustering_kolektor.joblib`` (hasil ``scripts/latih_clustering.py``).
Fitur dibangun dari data yang dibaca ulang dari Neon (``features.bangun_clustering``, snapshot akhir
periode data), jadi hasilnya selalu mengikuti isi database. Tabel yang ditulis HANYA
``dummy_rekomendasi.kolektor_segmen`` (DELETE lalu INSERT dalam satu transaksi -> idempotent).

    python scripts/hitung_segmen.py --dry-run        # hitung + CSV, TANPA menulis database (tetap membaca Neon)
    python scripts/hitung_segmen.py                  # tulis ke Neon
    python scripts/hitung_segmen.py --dari-csv       # tanpa database sama sekali: pakai data/training/clustering_kolektor.csv
"""

from __future__ import annotations

import argparse
import asyncio
import json
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path

import joblib
import pandas as pd
from sqlalchemy import text

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
from src import clustering as C  # noqa: E402
from src import db  # noqa: E402
from src.features import bangun_clustering  # noqa: E402

ARTEFAK = ROOT / "models" / "clustering_kolektor.joblib"
CSV_HASIL = ROOT / "data" / "hasil" / "segmen_kolektor.csv"
CSV_KAMUS = ROOT / "data" / "hasil" / "segmen_kamus.csv"
CSV_FITUR = ROOT / "data" / "training" / "clustering_kolektor.csv"


async def _baca_fitur() -> pd.DataFrame:
    eng = db.buat_engine()
    async with eng.connect() as conn:
        t = await db.baca_semua(conn)
    await eng.dispose()
    return bangun_clustering(t["seniman"], t["kolektor"], t["karya"], t["transaksi"])


def _kamus(bundle: dict) -> pd.DataFrame:
    return pd.DataFrame([{"segmen_id": sid, "segmen_nama": s["nama"], "deskripsi": s["deskripsi"], "ukuran": s["ukuran"],
                          "aliran_favorit": s["aliran_favorit"], "profil": json.dumps(s["profil"], ensure_ascii=False, sort_keys=True),
                          "model_version": bundle["versi"]} for sid, s in sorted(bundle["segmen"].items())])


async def _tulis(hasil: pd.DataFrame, kamus: pd.DataFrame, versi: str) -> int:
    waktu = datetime.now(timezone.utc)
    eng = db.buat_engine()
    async with eng.begin() as conn:                       # satu transaksi: gagal = tidak ada yang berubah
        await db.pastikan_schema(conn)
        public_sebelum = await db.hitung_public(conn)
        await conn.execute(text(f"DELETE FROM {db.SCHEMA}.kolektor_segmen"))
        await conn.execute(text(f"DELETE FROM {db.SCHEMA}.segmen_kamus"))
        await conn.execute(
            text(f"INSERT INTO {db.SCHEMA}.segmen_kamus (segmen_id, segmen_nama, deskripsi, ukuran, aliran_favorit, profil, model_version, dihitung_pada) "
                 "VALUES (:i, :n, :d, :u, :a, CAST(:p AS jsonb), :v, :t)"),
            [{"i": int(r.segmen_id), "n": r.segmen_nama, "d": r.deskripsi, "u": int(r.ukuran), "a": r.aliran_favorit, "p": r.profil, "v": versi, "t": waktu}
             for r in kamus.itertuples()],
        )
        await conn.execute(
            text(f"INSERT INTO {db.SCHEMA}.kolektor_segmen (kolektor_id, segmen_id, segmen_nama, model_version, dihitung_pada) "
                 "VALUES (:k, :i, :n, :v, :t)"),
            [{"k": uuid.UUID(r.kolektor_id), "i": int(r.segmen_id), "n": r.segmen_nama, "v": versi, "t": waktu}
             for r in hasil.itertuples()],
        )
        n = (await conn.execute(text(f"SELECT count(*) FROM {db.SCHEMA}.kolektor_segmen"))).scalar_one()
        assert public_sebelum == await db.hitung_public(conn), "tabel public berubah!"
    await eng.dispose()
    return n


def main(dry_run: bool, dari_csv: bool) -> None:
    if not ARTEFAK.exists():
        raise SystemExit(f"{ARTEFAK.relative_to(ROOT)} belum ada -- jalankan dulu: python scripts/latih_clustering.py")
    bundle = joblib.load(ARTEFAK)
    fitur = pd.read_csv(CSV_FITUR) if dari_csv else asyncio.run(_baca_fitur())
    print(f"{len(fitur)} kolektor ({'CSV' if dari_csv else 'dibaca dari Neon'}) | model {bundle['versi']} (K={bundle['k']})")

    hasil = C.tetapkan(bundle, fitur)
    CSV_HASIL.parent.mkdir(parents=True, exist_ok=True)
    hasil.assign(model_version=bundle["versi"]).sort_values("kolektor_id").to_csv(CSV_HASIL, index=False, encoding="utf-8", lineterminator="\n")
    print(f"CSV -> {CSV_HASIL.relative_to(ROOT)}")
    kamus = _kamus(bundle)
    kamus.to_csv(CSV_KAMUS, index=False, encoding="utf-8", lineterminator="\n")
    print(f"CSV -> {CSV_KAMUS.relative_to(ROOT)}")
    print(hasil.groupby(["segmen_id", "segmen_nama"]).size().rename("n_kolektor").to_string())

    if dry_run or dari_csv:
        print("(tidak menulis database)")
        return
    n = asyncio.run(_tulis(hasil, kamus, bundle["versi"]))
    print(f"Neon: {db.SCHEMA}.kolektor_segmen terisi {n} baris + segmen_kamus {len(kamus)} baris; tabel public tidak berubah.")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dry-run", action="store_true", help="tanpa menulis database")
    ap.add_argument("--dari-csv", action="store_true", help="pakai CSV training, tanpa database")
    a = ap.parse_args()
    main(a.dry_run, a.dari_csv)
