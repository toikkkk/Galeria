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

## Cara tercepat (setelah `git pull`)
```powershell
powershell -ExecutionPolicy Bypass -File dashboard-admin\mulai.ps1
```
Skrip ini memasang dependensi (backend + web), membuat akun admin di `backend\.env` bila belum ada (email `admin@galeria.id`,
password acak yang dicetak di layar; atau `-Password "..."`), lalu membuka backend (:8000) dan web (:5173).
**Satu-satunya yang harus disiapkan manual:** `DATABASE_URL` di `backend\.env` (connection string Neon dari tim; `.env` tidak masuk git).
Data contoh sudah ada di Neon bersama, jadi tidak perlu `muat_neon.py` lagi.

## Menjalankan manual
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
`/ringkasan?periode=30|90|365` · `/pendapatan-bulanan?bulan=36` · `/forecast?target=total|komisi|langganan_kolektor|langganan_seniman&bulan_aktual=18` · `/diagnosa?target=...` · `/keaktifan-seniman` · `/pro-vs-nonpro?role=kolektor|seniman&bulan=12`

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

## Forecasting (ARIMA vs Fuzzy Time Series)
Urutan kerja (sesuai arahan dosen): **cek data series dulu, baru pilih metode**.

**Langkah 1 — diagnosa** (`forecasting/diagnosa.py` → tabel `diagnosa_deret` → `GET /api/admin/diagnosa?target=`; tampil di kartu Forecast):
kelengkapan (bulan hilang/ganda/nol/negatif), outlier (robust z-score MAD pada sisa tren Theil–Sen), tren (Mann–Kendall + laju Theil–Sen),
musiman (kekuatan STL + ACF lag 12), stasioneritas (ADF dan KPSS pada level dan selisih → orde `d`).
Temuan pada data ini: 36 bulan lengkap; tren naik kuat (±9–13% per bulan); musiman sedang–kuat tetapi hanya 3 siklus (berdaya rendah);
level tidak stasioner → d = 1; bulan peluncuran (nilai < 5% median) dibuang sebelum pemodelan.

**Langkah 2 — semua metode dibandingkan** (`forecasting/arima_fts.py`, `modelku.py`, `jalankan.py`), target: total, komisi, langganan kolektor, langganan seniman.
Dua metode yang DIMINTA dosen selalu masuk perbandingan, ditandai ★ di web, dan sembilan model pembanding dari eksplorasi sebelumnya ikut diuji supaya yang ditampilkan benar-benar yang terbaik:
* ★ **ARIMA (univariat)** pada log1p(y); d dari ADF+KPSS (0/1), (p, q) 0–1 dipilih dari AICc.
* ★ **Fuzzy Time Series multivariat** (2 faktor: pendapatan + satu faktor pengaruh yang dipilih otomatis dari korelasi pada data latih: jumlah transaksi / pengguna Pro / pengguna baru), orde-1,
  pada selisih log (FTS tidak bisa mengekstrapolasi di luar rentang universe).
* Pembanding: seasonal-naive+tren, ETS, Theta, LightGBM, Chronos-2 (4 varian), ensemble Chronos-2+Theta.
* Evaluasi: backtest bergulir (titik potong T = 24…30 bulan, horizon 6) → **MAPE** (kriteria utama) dan **RMSE** (pembanding). Pemenang per target ditampilkan di web dengan **dua garis** (aktual dan forecast); tanpa stacked bar, tanpa pita interval.

```powershell
cd dashboard-admin
python -m venv .venv --system-site-packages ; .venv\Scripts\activate ; pip install asyncpg
pip install torch --index-url https://download.pytorch.org/whl/cpu ; pip install chronos-forecasting lightgbm   # hanya utk model pembanding
python forecasting\diagnosa.py        # cek data series -> Neon
python forecasting\jalankan.py        # backtest 11 model + forecast -> Neon (±20-30 menit krn Chronos-2 di CPU)
python forecasting\uji_model.py       # 14 uji cepat ARIMA dan FTS (tanpa database)
```

Hasil run terakhir (MAPE backtest, makin kecil makin baik):

| Sumber | **Terbaik (ditampilkan)** | ★ ARIMA | ★ FTS |
|---|---|---|---|
| Total | Chronos-2 + kovariat Pro **15,6%** | 28,8% | 48,6% |
| Komisi | Chronos-2 + kovariat Pro **15,9%** | 30,5% | 51,7% |
| Langganan kolektor | Theta **9,7%** | 38,7% | 10,6% |
| Langganan seniman | Theta **15,3%** | 27,9% | 20,7% |

Antara dua metode yang diminta: ARIMA unggul di total dan komisi, FTS unggul di dua langganan. Namun **model pembanding lebih akurat daripada keduanya di semua sumber** (di langganan kolektor FTS hampir setara Theta).
Angka model pembanding mereproduksi hasil sebelumnya (Aulya) pada metrik WAPE yang sama.

**Kejujuran:**
* Data sintetis dengan struktur yang kita tentukan sendiri → skor mencerminkan desain simulasi, bukan performa produksi. Hanya 36 bulan; 7 titik uji × 6 bulan, sehingga selisih kecil antar-metode bisa kebetulan.
* **Keputusan desain diambil setelah melihat hasil awal**, jadi skor di atas bukan evaluasi yang sepenuhnya "buta": pada ARIMA/FTS, percobaan pertama meledak (ARIMA komisi MAPE >1.600%) karena (1) bulan peluncuran bernilai Rp0,2 juta lalu Rp15 juta
  membuat satu selisih log raksasa → diperbaiki dengan membuang bulan awal < 5% median; (2) d=2 dan orde ARMA besar overfit pada ±30 titik → d maks 1, (p, q) ≤ 1 dengan AICc; (3) FTS pada selisih mentah terkunci
  di keadaan "naik besar" → dipindah ke selisih log. Perubahan ini beralasan metodologis, tetapi pembaca harus tahu urutannya.
* Forecast meneruskan tren historis; bila pertumbuhan melambat keduanya cenderung melebihkan.

## Keaktifan seniman: cluster dan Top 10
`seniman/aktivitas.py` (batch → tabel `seniman_aktivitas`, `seniman_cluster_info` → `GET /api/admin/keaktifan-seniman` → kartu "Keaktifan seniman"):
* **Skor keaktifan** (0–100) = 50% peringkat-persentil penjualan 90 hari + 30% omzet 90 hari + 20% kebaruan penjualan terakhir. Satu definisi ini dipakai Top 10, cluster, dan (nanti) notifikasi/reward/rekomendasi.
  Data admin tidak mencatat unggahan karya, jadi keaktifan = keaktifan **menjual**.
* **Cluster Aktif / Kurang Aktif / Tidak Aktif**: UMAP + HDBSCAN (bukan K-Means, arahan dosen). Pada data ini HDBSCAN menemukan **18 kelompok kecil**
  (perilaku bersifat kontinu), bukan 3, dan jumlahnya tak bisa dipaksa; kelompok-kelompok itu digabung hierarkis (Ward, 1-D pada rata-rata skor) menjadi 3 tingkat.
* **Top 10 seniman terbaik** (omzet 12 bulan terakhir) dan **Top 10 paling aktif** (skor keaktifan): bar chart horizontal biasa.
* Hasil: Aktif 355 (20,4%) · Kurang Aktif 969 (55,7%) · Tidak Aktif 416 (23,9%) dari 1.740 seniman.

```powershell
cd dashboard-admin ; .venv\Scripts\activate ; pip install umap-learn hdbscan
python seniman\aktivitas.py          # hitung + tulis ke Neon (±1–2 menit)
python seniman\uji_aktivitas.py      # 8 uji fungsi murni (tanpa database)
```
**Kejujuran:** silhouette (ruang fitur asli) kelompok HDBSCAN = 0,42 dan stabil (ARI 0,81 ± 0,03), tetapi setelah digabung menjadi 3 tingkat hanya **0,30**
(di bawah ambang 0,5 yang dosen sebut untuk cluster kolektor): batas antar-tingkat lebih berupa kesepakatan bisnis daripada celah alami di data.
Cluster sebagian besar mencerminkan "pernah/masih menjual" dan umur akun, dan data sintetis, jadi bukan temuan perilaku nyata.

## Login & keamanan
Satu akun admin dari `backend/.env` (bukan tabel `users`): `ADMIN_EMAIL`, `ADMIN_PASSWORD_HASH` (bcrypt), `ADMIN_JWT_SECRET`.
Buat nilainya dengan `python scripts/buat_hash_admin.py` (dari `backend/`), tempel ke `.env`, lalu **restart penuh** uvicorn
(`--reload` tidak memantau `.env`). Web memanggil `POST /api/admin/login` → JWT (60 menit; "Ingat saya" 7 hari) → header
`Authorization: Bearer` ke semua `/api/admin/*`. Salah 5× → IP dikunci 5 menit (disimpan di memori server).
`X-Admin-Key` (`ADMIN_API_KEY`) lama masih diterima untuk skrip.
Belum ada: banyak admin, 2FA, rate-limit terdistribusi; CORS backend masih `*`. Ganti dengan Auth asli sebelum rilis.
