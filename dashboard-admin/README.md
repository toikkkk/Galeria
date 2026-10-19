# dashboard-admin — Dashboard Admin GALERIA (website)

Website admin: **pendapatan platform** dan **forecasting-nya**, plus **bar chart pengguna Pro vs tidak upgrade**.
Terpisah dari `ml-recommender/` (dashboard seniman).

## Sumber pendapatan platform
| Sumber | Aturan |
|---|---|
| **Komisi penjualan karya** | **2,5%** dari harga final karya yang dijual seniman |
| **Langganan Pro kolektor** | **Rp50.000/bulan** — membuka fitur AR dan gabung Komunitas |
| **Langganan Pro seniman** | **Rp150.000/bulan** — satu paket: promosi karya (tampil di beranda kolektor), buat event, buat komunitas |

Biaya langganan masuk **penuh** ke platform (2,5% hanya untuk penjualan karya). Tidak ada biaya promosi terpisah.
> Catatan: UI mobile saat ini menampilkan Seniman PRO **Rp149.000** (`adakan_event_sheet.dart`); dashboard memakai Rp150.000 sesuai keputusan produk — samakan salah satunya.

```
dashboard-admin/
├── data/generate.py       generator data sintetis (simulasi per-pengguna; semua parameter di atas file)
├── data/muat_neon.py      DROP + buat ulang schema dummy_admin di Neon + isi data   (--hapus: hanya DROP)
├── data/validasi.py       uji integritas/reproduksi/pemulihan efek/ketahanan antar-seed → data/LAPORAN_DATA.md
├── sql/dummy_admin.sql    DDL (users, subscriptions, pembayaran_langganan, transaksi, forecast_*)
├── forecasting/           dataset.py (SQL→deret bulanan) · modelku.py (model) · jalankan.py (backtest+forecast)
└── web/                   React + Vite + Recharts
backend/ (file baru)       routers/admin_dashboard.py · services/admin_repo.py · schemas/admin.py → /api/admin/*
```

## Menjalankan
```powershell
cd dashboard-admin
python -m venv .venv --system-site-packages ; .venv\Scripts\activate ; pip install -r requirements.txt
python data\muat_neon.py            # isi data contoh ke Neon (schema dummy_admin, bukan public.*) — membangun ulang schema
python forecasting\jalankan.py      # backtest 9 model x 4 target + tulis forecast ke Neon (unduh Chronos-2 saat pertama)
# backend (dari backend/):  uvicorn main:app --reload      (butuh DATABASE_URL di backend/.env)
cd web ; copy .env.example .env ; npm install ; npm run dev    # http://localhost:5173
```
`muat_neon.py` menghapus tabel forecast juga → jalankan ulang `jalankan.py` setelahnya.
`jalankan.py --pilih <model>` memaksa model yang tampil untuk semua target (default: WAPE terkecil **per target**);
`--hanya <model...>` / `--target <t...>` menguji sebagian tanpa menulis DB.

## Endpoint (`/api/admin/*`)
`/ringkasan?periode=30|90|365` · `/pendapatan-bulanan?bulan=36` · `/forecast?target=total|komisi|langganan_kolektor|langganan_seniman&bulan_aktual=18` · `/pro-vs-nonpro?role=kolektor|seniman&bulan=12`

## Data sintetis — variabel simulasi
Simulasi per-pengguna: pertumbuhan pengguna (+4%/bln, promo), peluang upgrade Pro per role (naik bertahap + lonjakan
promo), lama langganan (geometrik; kolektor ±10 bln, seniman ±8 bln), pembayaran per siklus 30 hari. Efek ke penjualan:
kolektor Pro belanja **1,9×** lebih sering; laju beli platform naik **30% × pangsa seniman Pro** (karya dipromosikan di
beranda), seniman Pro **2×** lebih sering terpilih sebagai penjual; musim (Ramadan, Desember), kedewasaan platform, inflasi
harga karya. Pro = langganan sedang berlaku di akhir bulan. Role `komunitas` tidak dimodelkan (tidak punya paket sendiri).

## Pertanggungjawaban data
`python data\validasi.py` (atau `--cepat`) menulis **[data/LAPORAN_DATA.md](data/LAPORAN_DATA.md)**: tabel parameter beserta dasarnya
(keputusan produk / fakta kalender / asumsi), 15 uji integritas internal, reproduksibilitas (seed sama → identik; Neon = hitungan langsung),
uji **pemulihan efek** (efek yang ditanam diestimasi balik dari data), dan uji **ketahanan antar-seed** (4 seed × seluruh model).
Temuan penting: efek Pro kolektor, penjual Pro, dan laju dasar terpulihkan; **efek promosi seniman Pro tidak terpulihkan** karena besarnya
(±2% laju beli) tenggelam di noise bulanan (±9%) — jangan ditafsirkan sebagai pendorong penjualan di data ini. Pemenang model Theta/ensemble
berganti-ganti antar-seed; kovariat Pro secara konsisten memperbaiki Chronos-2. Laporan itu juga memuat keterbatasan untuk presentasi.

## Forecasting
Target: **total**, **komisi**, **langganan kolektor**, **langganan seniman** — masing-masing punya backtest dan pemenang sendiri.
Backtest bergulir (titik potong 24–30 bulan, horizon 6): seasonal-naive+tren, ETS, Theta, LightGBM, **Chronos-2**
(4 varian: kalender / kovariat Pro, skala asli / log) dan ensemble Chronos-2+Theta. Metrik: WAPE, sMAPE, MASE, cakupan P10–P90.
Model titik mendapat interval dari galat backtest. Backend hanya membaca tabel `dummy_admin.forecast_*` (tanpa torch di server).

Hasil run terakhir (WAPE backtest, makin kecil makin baik): total — Chronos-2 (log)+kalender 15,7% · komisi — Chronos-2+kovariat Pro
16,3% · langganan kolektor — Theta 10,2% · langganan seniman — Theta 14,9%. Total diramal langsung, sehingga jumlah ramalan
komponen bisa sedikit berbeda (dashboard menampilkan keduanya).

**Kejujuran:** data sintetis dengan struktur yang kita tentukan sendiri → skor mencerminkan desain simulasi, bukan performa
produksi. Hanya 36 titik data bulanan; selisih kecil antar-model bisa noise. Forecast = proyeksi statistik, bukan jaminan pendapatan.

## Login & keamanan
Satu akun admin dari `backend/.env` (bukan tabel `users`): `ADMIN_EMAIL`, `ADMIN_PASSWORD_HASH` (bcrypt), `ADMIN_JWT_SECRET`.
Buat nilainya dengan `python scripts/buat_hash_admin.py` (dari `backend/`), tempel ke `.env`, lalu **restart penuh** uvicorn
(`--reload` tidak memantau `.env`). Web memanggil `POST /api/admin/login` → JWT (60 menit; "Ingat saya" 7 hari) → header
`Authorization: Bearer` ke semua `/api/admin/*`. Salah 5× → IP dikunci 5 menit (disimpan di memori server).
`X-Admin-Key` (`ADMIN_API_KEY`) lama masih diterima untuk skrip.
Belum ada: banyak admin, 2FA, rate-limit terdistribusi; CORS backend masih `*`. Ganti dengan Auth asli sebelum rilis.
