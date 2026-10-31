"""Dashboard seniman dari data NYATA (``public.transaksi``, ``karya``, ``ulasan``) untuk seniman yang login.

Bentuk keluaran sengaja sama dengan ``dashboard_repo`` (versi data contoh) supaya layar di aplikasi tidak perlu
dua jalur. Definisi yang dipakai:

- "terjual" = pesanan berstatus ``selesai`` (karya sudah diterima pembeli), dihitung pada ``selesai_at``.
  Pesanan yang masih berjalan TIDAK dihitung sebagai pendapatan; jumlahnya dilaporkan terpisah
  (``pesanan_perlu_diproses``).
- pendapatan bersih = harga final - komisi platform yang dicatat pada tiap transaksi.
- tidak ada angka karangan: tidak ada transaksi berarti semua angka 0 atau kosong.
"""

from __future__ import annotations

import uuid
from datetime import date, datetime, timezone

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from models.user import User


def _level(n_terjual: int) -> str:
    """Label sederhana dari jumlah karya terjual (bukan skor reputasi dari model)."""
    if n_terjual >= 10:
        return "mapan"
    if n_terjual >= 3:
        return "menengah"
    return "pemula"


def _pct(sekarang: int, sebelum: int) -> float | None:
    return round(100 * (sekarang - sebelum) / sebelum, 1) if sebelum > 0 else None


async def ringkasan(db: AsyncSession, user: User, periode: int) -> dict:
    sid = user.id
    q = text(
        """
        SELECT
          count(*) FILTER (WHERE selesai_at >= now() - make_interval(days => :p)) AS n,
          coalesce(sum(harga_final_idr) FILTER (WHERE selesai_at >= now() - make_interval(days => :p)), 0) AS omzet,
          coalesce(sum(komisi_platform_idr) FILTER (WHERE selesai_at >= now() - make_interval(days => :p)), 0) AS komisi,
          count(DISTINCT pembeli_id) FILTER (WHERE selesai_at >= now() - make_interval(days => :p)) AS pembeli,
          count(*) FILTER (WHERE selesai_at >= now() - make_interval(days => 2 * :p)
                             AND selesai_at <  now() - make_interval(days => :p)) AS n_prev,
          coalesce(sum(harga_final_idr) FILTER (WHERE selesai_at >= now() - make_interval(days => 2 * :p)
                             AND selesai_at <  now() - make_interval(days => :p)), 0) AS omzet_prev,
          count(*) AS total_terjual
        FROM transaksi WHERE penjual_id = :sid AND status = 'selesai'
        """
    )
    r = (await db.execute(q, {"sid": sid, "p": periode})).mappings().one()
    tersedia = (
        await db.execute(
            text(
                """SELECT count(*) FROM karya k
                   WHERE k.seniman_id = :sid AND k.deleted_at IS NULL AND k.status_verifikasi = 'terverifikasi'
                     AND NOT EXISTS (SELECT 1 FROM transaksi t WHERE t.karya_id = k.id AND t.status <> 'dibatalkan')"""
            ),
            {"sid": sid},
        )
    ).scalar_one()
    perlu = (
        await db.execute(
            text(
                """SELECT count(*) FROM transaksi WHERE penjual_id = :sid
                   AND (status = 'dibayar' OR (status = 'dikonfirmasi' AND dikirim_at IS NULL))"""
            ),
            {"sid": sid},
        )
    ).scalar_one()
    n, omzet, komisi = int(r["n"]), int(r["omzet"]), int(r["komisi"])
    return {
        "seniman": {"id": str(sid), "display_name": user.display_name, "level_reputasi": _level(int(r["total_terjual"]))},
        "periode_hari": periode,
        "n_terjual": n,
        "omzet_idr": omzet,
        "komisi_platform_idr": komisi,
        "pendapatan_bersih_idr": omzet - komisi,
        "harga_rata2_idr": round(omzet / n) if n else 0,
        "n_pembeli_unik": int(r["pembeli"]),
        "karya_tersedia": int(tersedia),
        "karya_terjual_total": int(r["total_terjual"]),
        "pesanan_perlu_diproses": int(perlu),
        "perubahan_pct": {"n_terjual": _pct(n, int(r["n_prev"])), "omzet_idr": _pct(omzet, int(r["omzet_prev"]))},
    }


def _deret_bulan(n: int) -> list[str]:
    now = datetime.now(timezone.utc)
    y, m = now.year, now.month
    out: list[str] = []
    for _ in range(n):
        out.append(f"{y:04d}-{m:02d}-01")
        m -= 1
        if m == 0:
            y, m = y - 1, 12
    return out[::-1]


async def penjualan_bulanan(db: AsyncSession, user: User, n_bulan: int) -> list[dict]:
    deret = _deret_bulan(n_bulan)
    rows = (
        await db.execute(
            text(
                """SELECT to_char(date_trunc('month', t.selesai_at AT TIME ZONE 'UTC'), 'YYYY-MM-01') AS b,
                          k.style_name, count(*) AS n, sum(t.harga_final_idr) AS omzet, count(DISTINCT t.pembeli_id) AS pembeli
                   FROM transaksi t JOIN karya k ON k.id = t.karya_id
                   WHERE t.penjual_id = :sid AND t.status = 'selesai' AND t.selesai_at >= CAST(:awal AS date)
                   GROUP BY 1, 2"""
            ),
            {"sid": user.id, "awal": date.fromisoformat(deret[0])},
        )
    ).mappings().all()
    per_bulan: dict[str, dict] = {}
    for r in rows:
        d = per_bulan.setdefault(r["b"], {"n": 0, "omzet": 0, "gaya": {}})
        d["n"] += int(r["n"])
        d["omzet"] += int(r["omzet"])
        d["gaya"][r["style_name"]] = d["gaya"].get(r["style_name"], 0) + int(r["n"])
    pembeli = {
        r["b"]: int(r["p"])
        for r in (
            await db.execute(
                text(
                    """SELECT to_char(date_trunc('month', selesai_at AT TIME ZONE 'UTC'), 'YYYY-MM-01') AS b,
                              count(DISTINCT pembeli_id) AS p
                       FROM transaksi WHERE penjual_id = :sid AND status = 'selesai' AND selesai_at >= CAST(:awal AS date)
                       GROUP BY 1"""
                ),
                {"sid": user.id, "awal": date.fromisoformat(deret[0])},
            )
        ).mappings()
    }
    out = []
    for b in deret:
        d = per_bulan.get(b)
        out.append(
            {
                "bulan": b,
                "n_terjual": d["n"] if d else 0,
                "omzet_idr": d["omzet"] if d else 0,
                "harga_rata2_idr": round(d["omzet"] / d["n"]) if d else 0,
                "n_pembeli_unik": pembeli.get(b, 0),
                "gaya_terlaris": max(d["gaya"], key=d["gaya"].get) if d else None,
            }
        )
    return out


async def aliran(db: AsyncSession, user: User) -> list[dict]:
    """Penjualan per aliran + perbandingan dengan harga rata-rata SEMUA penjualan selesai di platform."""
    rows = (
        await db.execute(
            text(
                """WITH pasar AS (
                       SELECT k.style_name, round(avg(t.harga_final_idr))::bigint AS rata2
                       FROM transaksi t JOIN karya k ON k.id = t.karya_id WHERE t.status = 'selesai' GROUP BY 1)
                   SELECT k.style_name, count(*) AS n, sum(t.harga_final_idr) AS omzet,
                          round(avg(t.harga_final_idr))::bigint AS rata2, p.rata2 AS pasar
                   FROM transaksi t JOIN karya k ON k.id = t.karya_id JOIN pasar p ON p.style_name = k.style_name
                   WHERE t.penjual_id = :sid AND t.status = 'selesai'
                   GROUP BY k.style_name, p.rata2 ORDER BY n DESC, omzet DESC"""
            ),
            {"sid": user.id},
        )
    ).mappings().all()
    return [
        {
            "style_name": r["style_name"],
            "n_terjual": int(r["n"]),
            "omzet_idr": int(r["omzet"]),
            "harga_rata2_idr": int(r["rata2"]),
            "harga_pasar_rata2_idr": int(r["pasar"]),
            "selisih_pct": round(100 * (int(r["rata2"]) - int(r["pasar"])) / int(r["pasar"]), 1) if r["pasar"] else None,
        }
        for r in rows
    ]


async def notifikasi(db: AsyncSession, user: User, limit: int = 20) -> list[dict]:
    """Notifikasi yang diturunkan dari kejadian nyata: pesanan perlu diproses, pesanan selesai, ulasan baru."""
    rows = (
        await db.execute(
            text(
                """SELECT t.id, t.status::text AS status, t.dikirim_at, t.harga_final_idr, t.created_at, t.dibayar_at,
                          t.selesai_at, k.title, u.display_name AS pembeli
                   FROM transaksi t JOIN karya k ON k.id = t.karya_id JOIN users u ON u.id = t.pembeli_id
                   WHERE t.penjual_id = :sid AND t.status <> 'dibatalkan'
                   ORDER BY coalesce(t.selesai_at, t.dibayar_at, t.created_at) DESC LIMIT :n"""
            ),
            {"sid": user.id, "n": limit},
        )
    ).mappings().all()
    out: list[dict] = []
    for r in rows:
        harga = int(r["harga_final_idr"])
        if r["status"] == "dibayar":
            out.append({"id": f"tindakan-{r['id']}", "tipe": "tindakan", "judul": "Pesanan baru perlu dikonfirmasi",
                        "deskripsi": f'"{r["title"]}" dipesan {r["pembeli"]} dan sudah dibayar.',
                        "waktu": r["dibayar_at"].isoformat(), "nominal_idr": harga})
        elif r["status"] == "dikonfirmasi" and r["dikirim_at"] is None:
            out.append({"id": f"kirim-{r['id']}", "tipe": "tindakan", "judul": "Pesanan perlu dikirim",
                        "deskripsi": f'Kemas "{r["title"]}" untuk {r["pembeli"]}, lalu isi nomor resi.',
                        "waktu": r["dibayar_at"].isoformat() if r["dibayar_at"] else r["created_at"].isoformat(), "nominal_idr": harga})
        elif r["status"] == "selesai":
            out.append({"id": f"selesai-{r['id']}", "tipe": "pembelian", "judul": "Karya diterima pembeli",
                        "deskripsi": f'"{r["title"]}" sudah diterima {r["pembeli"]}. Pendapatan tercatat.',
                        "waktu": r["selesai_at"].isoformat(), "nominal_idr": harga})
        elif r["status"] == "menunggu_pembayaran":
            out.append({"id": f"tunggu-{r['id']}", "tipe": "pembelian", "judul": "Pesanan menunggu pembayaran",
                        "deskripsi": f'{r["pembeli"]} memesan "{r["title"]}" dan belum membayar.',
                        "waktu": r["created_at"].isoformat(), "nominal_idr": harga})
        else:  # dikonfirmasi & sudah dikirim
            out.append({"id": f"kirim-{r['id']}", "tipe": "pembelian", "judul": "Pesanan dalam pengiriman",
                        "deskripsi": f'"{r["title"]}" untuk {r["pembeli"]} sedang dikirim.',
                        "waktu": r["dikirim_at"].isoformat(), "nominal_idr": harga})
    ulasan = (
        await db.execute(
            text(
                """SELECT u.id, u.rating, u.teks, u.created_at, k.title FROM ulasan u JOIN karya k ON k.id = u.karya_id
                   WHERE u.seniman_id = :sid ORDER BY u.created_at DESC LIMIT :n"""
            ),
            {"sid": user.id, "n": limit},
        )
    ).mappings().all()
    for r in ulasan:
        out.append({"id": f"ulasan-{r['id']}", "tipe": "pembelian", "judul": f'Ulasan baru ({r["rating"]}/5)',
                    "deskripsi": f'"{r["title"]}": {r["teks"][:90]}', "waktu": r["created_at"].isoformat(), "nominal_idr": None})
    out.sort(key=lambda x: x["waktu"], reverse=True)
    return out[:limit]


URUT = ("positif", "netral", "negatif")


async def sentimen(db: AsyncSession, user: User, n_bulan: int = 6, n_contoh: int = 6) -> dict:
    sid = user.id
    p = {"sid": sid}
    agregat = (
        await db.execute(
            text("""SELECT sentimen_prediksi AS s, count(*) AS n, max(model_version) AS mv
                    FROM ulasan WHERE seniman_id = :sid AND sentimen_prediksi IS NOT NULL GROUP BY 1"""),
            p,
        )
    ).mappings().all()
    jumlah = {r["s"]: int(r["n"]) for r in agregat}
    total_dianalisis = sum(jumlah.values())
    semua = (await db.execute(text("SELECT count(*), avg(rating) FROM ulasan WHERE seniman_id = :sid"), p)).one()
    deret = _deret_bulan(n_bulan)
    per_bulan = (
        await db.execute(
            text("""SELECT to_char(date_trunc('month', created_at AT TIME ZONE 'UTC'), 'YYYY-MM-01') AS b,
                           sentimen_prediksi AS s, count(*) AS n
                    FROM ulasan WHERE seniman_id = :sid AND sentimen_prediksi IS NOT NULL GROUP BY 1, 2"""),
            p,
        )
    ).mappings().all()
    peta = {(r["b"], r["s"]): int(r["n"]) for r in per_bulan}
    contoh = (
        await db.execute(
            text("""SELECT u.teks, u.sentimen_prediksi AS sentimen, u.rating, u.created_at, k.title AS judul_karya
                    FROM ulasan u JOIN karya k ON k.id = u.karya_id
                    WHERE u.seniman_id = :sid ORDER BY u.created_at DESC LIMIT :n"""),
            {**p, "n": n_contoh},
        )
    ).mappings().all()
    return {
        "seniman_id": str(sid),
        "n_ulasan": int(semua[0]),
        "n_menunggu": int(semua[0]) - total_dianalisis,
        "model_version": next((r["mv"] for r in agregat), None),
        "hitung": [
            {"sentimen": k, "jumlah": jumlah.get(k, 0),
             "persen": round(100 * jumlah.get(k, 0) / total_dianalisis, 1) if total_dianalisis else 0.0}
            for k in URUT
        ],
        "indeks_sentimen": round(100 * (jumlah.get("positif", 0) - jumlah.get("negatif", 0)) / total_dianalisis, 1)
        if total_dianalisis else None,
        "rating_rata2": round(float(semua[1]), 2) if semua[1] is not None else None,
        "tren_bulanan": [{"bulan": b, **{k: peta.get((b, k), 0) for k in URUT}} for b in deret],
        "ulasan_terbaru": [
            {"teks": r["teks"], "sentimen": r["sentimen"] or "menunggu", "rating": int(r["rating"]),
             "tanggal": r["created_at"].isoformat().replace("+00:00", "Z"), "judul_karya": r["judul_karya"]}
            for r in contoh
        ],
    }
