"""Generator ulasan dummy berbahasa Indonesia untuk analisis sentimen (500 baris).

Setiap ulasan menempel pada SATU transaksi nyata di data dummy rekomendasi
(``ml-recommender/data/export/transaksi.csv``): pembeli = penulis ulasan, penjual = seniman yang
diulas. Teks disusun dari klausa per aspek (kualitas lukisan, pengiriman, kemasan, dst.) dengan
variasi gaya tulis (formal/santai, singkatan, huruf kecil semua, typo ringan).

KEJUJURAN: label dibuat OLEH generator ini, bukan dinilai manusia. Skor model pada data ini
mencerminkan desain generator, bukan performa pada ulasan pengguna sungguhan. Yang sengaja dibuat
tidak sepele: negasi ("tidak mengecewakan" = positif), kalimat kontras ("bagus tapi ..." — kalimat
setelah "tapi" menentukan), dan kalimat netral/faktual — supaya model berbasis kata kunci tidak
otomatis menang.

    python src/generate.py            # tulis data/ulasan_dummy.csv (deterministik, seed tetap)
"""
from __future__ import annotations

import csv
import random
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TRANSAKSI = ROOT.parent / "ml-recommender" / "data" / "export" / "transaksi.csv"
KARYA = ROOT.parent / "ml-recommender" / "data" / "export" / "karya.csv"
OUT = ROOT / "data" / "ulasan_dummy.csv"

N = 500
SEED = 20261020
TARGET = {"positif": 200, "netral": 140, "negatif": 160}   # total 500
WINDOW_END = datetime(2026, 9, 30, 23, 59, 59, tzinfo=timezone.utc)
NS = uuid.UUID("b1c2d3e4-0000-4000-8000-5e17140e0001")     # namespace uuid5 tetap

# ------------------------------------------------------------------ klausa --
# {aspek: {polaritas: [klausa, ...]}}. Klausa berdiri sendiri (tanpa huruf kapital/titik).
K = {
    "kualitas": {
        "pos": ["lukisannya bagus banget", "goresan kuasnya halus dan detail", "kualitas lukisannya luar biasa",
                "karyanya indah, lebih bagus dari yang saya bayangkan", "hasil lukisannya rapi dan berkelas",
                "detailnya terasa hidup", "karya aslinya memukau"],
        "neg": ["lukisannya biasa banget, tidak sebagus yang dijanjikan", "goresan kuasnya kasar dan kurang rapi",
                "kualitas lukisannya mengecewakan", "ada bagian cat yang terkelupas", "detailnya kurang, terlihat buru-buru",
                "hasilnya jauh dari ekspektasi"],
        "net": ["lukisannya ya begitu saja", "kualitasnya standar", "karyanya lumayan, tidak istimewa",
                "hasil lukisannya cukup"],
    },
    "warna": {
        "pos": ["warnanya hidup dan tidak pucat", "perpaduan warnanya cantik", "warna aslinya persis seperti di foto",
                "warnanya pas dengan ruang tamu saya"],
        "neg": ["warnanya pucat, beda dengan foto di aplikasi", "warnanya kusam tidak seperti di katalog",
                "warna aslinya jauh lebih gelap dari fotonya"],
        "net": ["warnanya sesuai gambar, tidak lebih tidak kurang", "warnanya biasa saja"],
    },
    "pengiriman": {
        "pos": ["pengirimannya cepat", "sampai lebih cepat dari estimasi", "pengiriman aman dan tepat waktu",
                "kurirnya hati-hati, barang sampai dengan selamat"],
        "neg": ["pengirimannya lama sekali", "telat sampai hampir dua minggu", "kurirnya ceroboh, barang sampai penyok",
                "tidak ada kabar pengiriman sama sekali"],
        "net": ["barang sampai dalam waktu sesuai estimasi", "pengiriman memakan waktu tiga hari",
                "paket diterima hari ini"],
    },
    "kemasan": {
        "pos": ["kemasannya rapi dan tebal", "dibungkus bubble wrap dan kayu, aman sekali", "packing-nya profesional"],
        "neg": ["kemasannya asal-asalan", "bungkusnya tipis, pojok bingkai retak", "packing-nya kurang aman untuk barang pecah belah"],
        "net": ["kemasannya standar", "dibungkus kardus biasa"],
    },
    "kesesuaian": {
        "pos": ["sesuai deskripsi", "persis seperti yang ada di foto", "ukurannya pas seperti yang tertulis"],
        "neg": ["tidak sesuai deskripsi", "ukurannya lebih kecil dari yang tertulis", "beda jauh dengan foto produk"],
        "net": ["ukurannya sesuai yang tertulis", "sesuai deskripsi, tidak ada kejutan"],
    },
    "harga": {
        "pos": ["harganya sebanding dengan kualitasnya", "worth it untuk harga segini", "harganya masuk akal untuk karya sebagus ini"],
        "neg": ["harganya terlalu mahal untuk kualitas begini", "tidak sepadan dengan harganya", "overprice menurut saya"],
        "net": ["harganya sesuai yang tertera", "harga standar pasar"],
    },
    "komunikasi": {
        "pos": ["senimannya ramah dan fast response", "komunikasi dengan seniman lancar", "penjualnya sangat membantu menjawab pertanyaan"],
        "neg": ["senimannya lambat membalas pesan", "chat saya diabaikan berhari-hari", "penjualnya kurang ramah"],
        "net": ["senimannya membalas pesan seperlunya", "komunikasinya biasa saja"],
    },
}

# klausa netral murni (faktual, tanpa penilaian)
FAKTUAL = ["lukisannya sudah saya terima", "sudah saya pasang di ruang kerja", "ini pembelian pertama saya di GALERIA",
           "saya beli untuk hadiah", "barang diterima hari ini", "belum saya bingkai, baru dibuka",
           "saya beli lewat lelang", "dipesan minggu lalu dan sudah sampai"]

OPENER = {
    "positif": ["", "", "", "jujur ", "menurut saya ", "alhamdulillah ", "wah ", "sejauh ini ", "overall "],
    "negatif": ["", "", "", "jujur ", "menurut saya ", "sejauh ini ", "overall "],
    "netral": ["", "", "", "jujur ", "menurut saya ", "sejauh ini ", "overall "],
}
# ekor kalimat campuran -- sengaja bervariasi (termasuk kosong) agar label tidak bisa ditebak dari satu frasa
EKOR = {
    "positif": ["", "", " jadi tetap puas", " dan overall oke", " dan itu cukup menebus", ", saya maafkan", " jadi ya tidak masalah"],
    "negatif": ["", "", " dan bikin kecewa", " dan itu sangat mengganggu", ", sayangnya itu yang paling terasa", " jadi saya menyesal", " dan tidak bisa saya terima"],
    "netral": ["", " jadi ya impas", " jadi ya biasa saja", " jadi ya cukup", " jadi saya bingung menilainya"],
}
CLOSER = {
    "positif": ["", "", "", "recommended!", "pasti beli lagi.", "puas banget.", "terima kasih ya kak.", "mantap 👍", "top!"],
    "negatif": ["", "", "", "kecewa.", "tidak akan beli lagi.", "semoga diperbaiki.", "sayang sekali.", "tidak recommended."],
    "netral": ["", "", "", "ya begitulah.", "cukuplah.", "tidak lebih tidak kurang.", "semoga bermanfaat untuk yang lain."],
}
NEGASI_POS = ["tidak mengecewakan sama sekali", "tidak ada kekurangan berarti", "nggak nyesel belinya", "tidak sia-sia belanja di sini",
              "tidak ada cacat sedikit pun"]
NEGASI_NEG = ["tidak sesuai harapan sama sekali", "tidak bisa dibilang bagus", "nggak worth it", "tidak layak untuk harga segitu"]


def pilih_aspek(rng: random.Random, n: int) -> list[str]:
    return rng.sample(list(K), n)


def susun(rng: random.Random, label: str) -> str:
    """Susun satu ulasan dengan label tujuan."""
    jenis = rng.random()
    if label == "positif":
        if jenis < 0.12:        # negasi bermakna positif
            a = pilih_aspek(rng, 1)[0]
            klausa = [rng.choice(NEGASI_POS), rng.choice(K[a]["pos"])]
            rng.shuffle(klausa)
            teks = " dan ".join(klausa)
        elif jenis < 0.35:      # campuran: negatif ringan di depan, positif menentukan di belakang
            a, b = pilih_aspek(rng, 2)
            teks = f"{rng.choice(K[a]['neg'])}, tapi {rng.choice(K[b]['pos'])}{rng.choice(EKOR['positif'])}"
        else:
            a, b = pilih_aspek(rng, 2)
            sambung = rng.choice([" dan ", ", ", " serta ", ". "])
            teks = f"{rng.choice(K[a]['pos'])}{sambung}{rng.choice(K[b]['pos'])}"
    elif label == "negatif":
        if jenis < 0.12:
            a = pilih_aspek(rng, 1)[0]
            teks = f"{rng.choice(NEGASI_NEG)}, {rng.choice(K[a]['neg'])}"
        elif jenis < 0.40:      # campuran: positif di depan, negatif menentukan di belakang
            a, b = pilih_aspek(rng, 2)
            teks = f"{rng.choice(K[a]['pos'])}, tapi {rng.choice(K[b]['neg'])}{rng.choice(EKOR['negatif'])}"
        else:
            a, b = pilih_aspek(rng, 2)
            sambung = rng.choice([" dan ", ", ", " serta ", ". "])
            teks = f"{rng.choice(K[a]['neg'])}{sambung}{rng.choice(K[b]['neg'])}"
    else:  # netral
        if jenis < 0.30:        # faktual murni
            f1, f2 = rng.sample(FAKTUAL, 2)
            teks = f"{f1}, {f2}"
        elif jenis < 0.55:      # pos + neg seimbang
            a, b = pilih_aspek(rng, 2)
            teks = f"{rng.choice(K[a]['pos'])} tapi {rng.choice(K[b]['neg'])}{rng.choice(EKOR['netral'])}"
        else:
            a, b = pilih_aspek(rng, 2)
            teks = f"{rng.choice(K[a]['net'])}, {rng.choice(K[b]['net'])}"
    teks = rng.choice(OPENER[label]) + teks
    campuran = " tapi " in teks
    penutup = "" if campuran and label != "positif" else rng.choice(CLOSER[label])
    if penutup:
        teks = f"{teks}. {penutup}"
    return teks


def gaya_tulis(rng: random.Random, teks: str) -> str:
    """Variasi gaya tulis: huruf kapital, singkatan, huruf berulang, typo ringan."""
    teks = teks.strip().replace("..", ".")
    r = rng.random()
    if r < 0.30:                         # semua huruf kecil, tanpa titik di akhir
        teks = teks.lower().rstrip(".")
    elif r < 0.80:                       # kalimat berkapital
        teks = teks[0].upper() + teks[1:]
        if not teks.endswith((".", "!", "👍")):
            teks += "."
    if rng.random() < 0.35:
        for a, b in [("banget", "bgt"), ("yang ", "yg "), ("tidak ", "gak "), ("sudah ", "udah "), ("dengan ", "dgn "), ("tapi", "tp")]:
            if rng.random() < 0.5:
                teks = teks.replace(a, b)
    if rng.random() < 0.12:
        teks = teks.replace("bagus", "bagusss").replace("mantap", "mantaap")
    if rng.random() < 0.08 and "pengiriman" in teks:
        teks = teks.replace("pengiriman", "pengirman", 1)
    return teks


RATING = {"positif": ([5, 4], [0.75, 0.25]), "netral": ([3, 4, 2], [0.7, 0.15, 0.15]), "negatif": ([1, 2], [0.45, 0.55])}


def main() -> None:
    rng = random.Random(SEED)
    trx = list(csv.DictReader(open(TRANSAKSI, encoding="utf-8")))
    trx = [t for t in trx if t["status"] == "selesai"]
    rng.shuffle(trx)
    pilihan = trx[:N]
    labels = [l for l, n in TARGET.items() for _ in range(n)]
    rng.shuffle(labels)
    assert len(labels) == N and len(pilihan) == N

    dipakai: set[str] = set()
    baris = []
    for t, label in zip(pilihan, labels):
        teks = ""
        for _ in range(50):              # cegah teks kembar persis
            teks = gaya_tulis(rng, susun(rng, label))
            if teks not in dipakai:
                break
        dipakai.add(teks)
        pilih, bobot = RATING[label]
        waktu_beli = datetime.fromisoformat(t["created_at"].replace("Z", "+00:00"))
        waktu = min(waktu_beli + timedelta(days=rng.randint(3, 40), hours=rng.randint(0, 23)), WINDOW_END)
        baris.append({
            "ulasan_id": str(uuid.uuid5(NS, t["id"])),
            "transaksi_id": t["id"], "karya_id": t["karya_id"], "kolektor_id": t["pembeli_id"],
            "seniman_id": t["penjual_id"], "teks": teks,
            "rating": rng.choices(pilih, bobot)[0], "sentimen": label,
            "created_at": waktu.strftime("%Y-%m-%dT%H:%M:%SZ"),
        })

    # split stratified 70/15/15 (acak, bukan waktu: ulasan antar-waktu tidak saling membocorkan)
    per_label: dict[str, list[dict]] = {}
    for b in baris:
        per_label.setdefault(b["sentimen"], []).append(b)
    for items in per_label.values():
        n = len(items)
        a, b_ = round(n * 0.70), round(n * 0.85)
        for i, row in enumerate(items):
            row["split"] = "train" if i < a else "val" if i < b_ else "test"

    baris.sort(key=lambda r: r["created_at"])
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(baris[0]))
        w.writeheader()
        w.writerows(baris)
    uniq = len({b["teks"] for b in baris})
    dist = {l: sum(b["sentimen"] == l for b in baris) for l in TARGET}
    spl = {s: sum(b["split"] == s for b in baris) for s in ("train", "val", "test")}
    print(f"{OUT.relative_to(ROOT.parent)}: {len(baris)} baris | unik {uniq} | {dist} | {spl}")


if __name__ == "__main__":
    main()
