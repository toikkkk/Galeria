"""Isi tabel ``dummy_rekomendasi.rekomendasi_kolektor`` dari model klasifikasi
(genda.md Tugas 3 -- kontrak output utk Vika & Aulya, lihat README.md).

Alur: baca tabel dari Neon -> utk SETIAP kolektor, skor semua karya yang
tersedia pada ``--waktu`` lewat ``src.inference.skor_kandidat()`` (fungsi yang
SAMA dipakai training & smoke-test Tugas 2 -- jadi tidak ada train/serve skew
di sini juga) -> ambil top-K -> tulis ke Neon (1 transaksi: DELETE lalu INSERT,
idempotent) + salin ke CSV.

    python scripts/hitung_rekomendasi.py                    # Neon + CSV
    python scripts/hitung_rekomendasi.py --dry-run           # CSV saja, Neon TIDAK disentuh
    python scripts/hitung_rekomendasi.py --top-k 10
    python scripts/hitung_rekomendasi.py --waktu 2026-06-01T00:00:00Z

Butuh ``DATABASE_URL`` (env var atau ``backend/.env``) kecuali ``--dry-run``
TIDAK menghapus kebutuhan baca Neon (tabel sumber tetap dibaca dari sana) --
cuma langkah tulis-nya yang dilewati.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sqlalchemy import text

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from src import db  # noqa: E402
from src.generate import WINDOW_END  # noqa: E402
from src.inference import skor_kandidat  # noqa: E402

HASIL_DIR = ROOT / "data" / "hasil"
MODEL_PATH = ROOT / "models" / "klasifikasi_rekomendasi.joblib"
KOLOM_OUT = ["kolektor_id", "karya_id", "peringkat", "skor", "alasan", "strategi", "model_version", "dihitung_pada"]


def hitung_semua(bundle: dict, tabel: dict[str, pd.DataFrame], waktu: pd.Timestamp, top_k: int) -> pd.DataFrame:
    """Loop semua kolektor -> top-K rekomendasi/kolektor. Dipisah dari I/O (DB/CSV)
    supaya mudah diuji & dipanggil ulang (mis. dari notebook) tanpa efek samping.
    """
    model_version = bundle["versi"]
    dihitung_pada = datetime.now(timezone.utc)
    kolektor_ids = tabel["kolektor"]["id"].astype(str).tolist()

    baris_per_kolektor = []
    n_cold_start = 0
    for i, kid in enumerate(kolektor_ids, start=1):
        hasil = skor_kandidat(bundle, tabel, kid, waktu)
        if hasil.empty:
            print(f"  PERINGATAN: kolektor {kid} -- 0 kandidat tersedia pada {waktu.isoformat()}, dilewati")
            continue

        # kolektor_n_beli_sebelumnya SAMA utk semua baris kolektor ini (tdk tergantung kandidat) --
        # alasan_dari_fitur menambah kode 'populer_umum' PERSIS kalau n==0 (lihat src/inference.py),
        # jadi cek ini definitionally setara dgn genda.md: "kolektor_n_beli_sebelumnya == 0 -> cold_start".
        strategi = "cold_start" if "populer_umum" in hasil["alasan"].iloc[0] else "model"
        if strategi == "cold_start":
            n_cold_start += 1

        top = hasil.sort_values("skor", ascending=False, kind="stable").head(top_k).reset_index(drop=True)
        top.insert(0, "kolektor_id", kid)
        top.insert(2, "peringkat", np.arange(1, len(top) + 1))
        top["strategi"] = strategi
        top["model_version"] = model_version
        top["dihitung_pada"] = dihitung_pada
        baris_per_kolektor.append(top)

        if i % 50 == 0 or i == len(kolektor_ids):
            print(f"  {i}/{len(kolektor_ids)} kolektor selesai")

    out = pd.concat(baris_per_kolektor, ignore_index=True)[KOLOM_OUT]
    print(f"[ringkasan] {len(out)} baris, {out['kolektor_id'].nunique()} kolektor "
          f"({n_cold_start} cold_start, {out['kolektor_id'].nunique() - n_cold_start} model)")
    kurang_top_k = out.groupby("kolektor_id").size()
    kurang_top_k = kurang_top_k[kurang_top_k < top_k]
    if len(kurang_top_k):
        print(f"  PERINGATAN: {len(kurang_top_k)} kolektor dapat < {top_k} rekomendasi "
              f"(kandidat tersedia kurang dari top_k) -- lihat log di atas")
    return out


def tulis_csv(out: pd.DataFrame, path: Path) -> None:
    csv_out = out.copy()
    csv_out["alasan"] = csv_out["alasan"].apply(json.dumps)
    csv_out["dihitung_pada"] = csv_out["dihitung_pada"].apply(lambda d: d.strftime("%Y-%m-%dT%H:%M:%SZ"))
    path.parent.mkdir(parents=True, exist_ok=True)
    csv_out.to_csv(path, index=False, encoding="utf-8", lineterminator="\n")
    print(f"[csv] {path.relative_to(ROOT)}  ({len(csv_out)} baris)")


async def tulis_neon(out: pd.DataFrame) -> None:
    """DELETE lalu INSERT dalam SATU transaksi (idempotent: dijalankan ulang -> hasil
    sama). Hanya menyentuh dummy_rekomendasi.rekomendasi_kolektor (genda.md: "Hanya
    sentuh tabel itu" -- TIDAK TRUNCATE tabel sumber spt kolektor/karya/transaksi).
    """
    baris = []
    for r in out.to_dict("records"):
        baris.append({
            "kolektor_id": r["kolektor_id"],
            "karya_id": r["karya_id"],
            "peringkat": int(r["peringkat"]),
            "skor": float(r["skor"]),
            "alasan": json.dumps(r["alasan"]),  # list Python -> string JSON, di-CAST ::jsonb di SQL
            "strategi": r["strategi"],
            "model_version": r["model_version"],
            "dihitung_pada": r["dihitung_pada"],
        })

    sql_insert = text(f"""
        INSERT INTO {db.SCHEMA}.rekomendasi_kolektor
            (kolektor_id, karya_id, peringkat, skor, alasan, strategi, model_version, dihitung_pada)
        VALUES
            (:kolektor_id, :karya_id, :peringkat, :skor, CAST(:alasan AS JSONB), :strategi, :model_version, :dihitung_pada)
    """)

    eng = db.buat_engine()
    try:
        async with eng.begin() as conn:   # begin() = 1 transaksi, auto-commit di akhir / rollback kalau exception
            await db.pastikan_schema(conn)  # jaga-jaga kalau tabel belum ada (aman, IF NOT EXISTS)
            await conn.execute(text(f"DELETE FROM {db.SCHEMA}.rekomendasi_kolektor"))
            ukuran_batch = 500
            for i in range(0, len(baris), ukuran_batch):
                await conn.execute(sql_insert, baris[i:i + ukuran_batch])
        print(f"[neon] {len(baris)} baris ditulis ke {db.SCHEMA}.rekomendasi_kolektor (1 transaksi: DELETE+INSERT)")
    finally:
        await eng.dispose()


async def jalankan(args) -> int:
    print(f"[1/4] memuat model dari {MODEL_PATH.relative_to(ROOT)} ...")
    bundle = joblib.load(MODEL_PATH)
    print(f"      versi={bundle['versi']}  dilatih_pada={bundle['dilatih_pada']}")

    print(f"[2/4] membaca tabel dari Neon ({db.SCHEMA}) ...")
    eng = db.buat_engine()
    try:
        async with eng.connect() as conn:
            tabel = await db.baca_semua(conn)
    finally:
        await eng.dispose()
    print("      " + ", ".join(f"{k}={len(v)}" for k, v in tabel.items()))

    waktu = pd.Timestamp(args.waktu) if args.waktu else WINDOW_END
    if waktu.tzinfo is None:
        waktu = waktu.tz_localize("UTC")

    print(f"[3/4] menghitung rekomendasi (waktu={waktu.isoformat()}, top_k={args.top_k}) ...")
    out = hitung_semua(bundle, tabel, waktu, args.top_k)

    tulis_csv(out, HASIL_DIR / "rekomendasi_kolektor.csv")

    if args.dry_run:
        print("[4/4] --dry-run: Neon TIDAK ditulis.")
        return 0

    print("[4/4] menulis ke Neon ...")
    await tulis_neon(out)
    return 0


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--waktu", default=None, help="ISO-8601 UTC, default = WINDOW_END (2026-09-30T23:59:59Z)")
    ap.add_argument("--top-k", type=int, default=20, dest="top_k")
    ap.add_argument("--dry-run", action="store_true", help="CSV saja, Neon tidak ditulis")
    sys.exit(asyncio.run(jalankan(ap.parse_args())))
