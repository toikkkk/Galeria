# genda.md — Arahan untuk Genda: Model Klasifikasi Rekomendasi

> File ini ditulis untuk **Claude Code milikmu**. Baca seluruhnya sebelum menulis kode. Bahasa kerja: **Indonesia**.
> Baca juga: `CLAUDE.md` (root), `ml-recommender/README.md` (terutama bagian **"Kontrak antar-bagian"**), dan `data/training/KAMUS_DATA.md`.

## 0. Konteks singkat
GALERIA = marketplace lukisan. Fitur baru: **rekomendasi katalog ke kolektor** berdasarkan kebiasaan beli (berapa banyak, harga berapa, aliran apa)
digabung dengan **tren seniman** (siapa yang sedang ramai), plus **segmentasi kolektor** (clustering, dikerjakan Thoriq). Hasil modelmu dibaca **Vika** (katalog) dan **Aulya** (dashboard seniman) —
mereka menunggu dua tabel Neon yang kamu isi.

**Pembagian modeling (final):** **kamu = klasifikasi** (siapa-membeli-karya-mana) → mengisi tabel `rekomendasi_kolektor`.
**Thoriq = clustering kolektor** (UMAP + HDBSCAN) → mengisi tabel `kolektor_segmen` dan menyediakan fitur `kolektor_segmen` di CSV klasifikasi. Kamu **tidak** mengerjakan clustering.
**Urutan kerja: clustering dulu, lalu klasifikasi.** Pakai kolom `kolektor_segmen` yang sudah ada di CSV (dari model *cutoff*, as-of `t`). **Jangan** memakai segmen dari Neon atau dari model final:
itu dihitung dari *seluruh* riwayat, jadi **membocorkan masa depan**. Lihat bagian 0b.

### Yang WAJIB dipahami (kejujuran)
* **Seluruh data SINTETIS.** Gambar & aliran lukisan nyata (dataset Visual Search v1, 11 kelas), tetapi kolektor, harga, dan riwayat beli dibangkitkan program
  (`src/generate.py`). Model hanya mempelajari aturan buatan kita. **Jangan mengklaim skor sebagai performa nyata** — di laporan tulis "pada data sintetis".
* **Hanya 23 seniman** (subset v1 berasal dari 23 pelukis) dan 200 kolektor — kecil. Hati-hati overfit. Kolektor kini ≥ 3 pembelian dan berkelompok tegas (generator-v2).
* Fitur "Estimasi Harga Jual" sudah **di-drop** dari scope. Jangan membuat model prediksi harga.
* `kolektor_label_asli` (segmen buatan generator) **dilarang** jadi fitur. Hanya untuk analisis kesalahan model; jangan jadi fitur.


## 0b. PERUBAHAN 2026-10-18 — baca ini dulu (data & fitur berubah)
Atas arahan dosen, urutan kerja proyek sekarang **clustering dulu, lalu klasifikasi**, dan data dummy dirombak (`generator-v2`). Untukmu:

1. **Data berubah.** `kolektor`, `transaksi`, dan CSV turunannya dibangun ulang (seniman/karya/gambar **identik**). Konsekuensinya **`models/klasifikasi_rekomendasi.joblib`, `models/LAPORAN_MODEL.md`,
   dan `data/hasil/rekomendasi_kolektor.csv` milikmu sekarang BASI** (dilatih di data lama) — latih ulang dan hitung ulang. `scripts/hitung_rekomendasi.py` tidak akan cocok dengan model lama (kolom fitur beda).
2. **Ada fitur baru `kolektor_segmen`** (kategorikal) — segmen kolektor dari clustering **UMAP + HDBSCAN**, dihitung as-of waktu `t` dari riwayat SEBELUM `t`. Nilainya: `Kolektor Aktif Bernilai Tinggi`, `Pemburu Tren`,
   `Kolektor Menengah Rutin`, `Pemula Hemat`, atau `Belum Cukup Riwayat` (< 3 pembelian sebelum t). **Ini mengubah aturan lama**: segmen *boleh* jadi fitur, tetapi **hanya yang dari model "cutoff"**
   (`models/clustering_kolektor_cutoff.joblib`, dilatih hanya pada data sampai batas train) — sudah ada di kolom CSV. **Tetap DILARANG**: memakai `kolektor_segmen` dari Neon (model final, melihat seluruh periode)
   atau `kolektor_label_asli` sebagai fitur — itu membocorkan masa depan.
3. **`FITUR_KATEGORIKAL` kini 3 kolom**: `karya_gaya`, `seniman_level_reputasi`, `kolektor_segmen` (`src/features.py`). Notebook `01_klasifikasi.ipynb` menulis daftar itu manual (bagian 6/10) — perbarui. Dataset kini 43 kolom (35 fitur).
4. **Skor sanity naik tajam** (GBM default: AUC ≈ 0,89–0,93, HitRate@1 ≈ 0,77–0,78 pada val/test; sebelumnya 0,79–0,80 dan 0,46–0,50). **Jangan dibaca sebagai model lebih pintar**: perilaku kolektor di generator-v2
   jauh lebih konsisten. Baseline "aturan sederhana" kemungkinan ikut kuat — laporkan apa adanya. Di `LAPORAN_MODEL.md` tulis jelas bahwa data dirancang terstruktur.
5. **Yang diharapkan darimu terkait segmen (analisis, bukan klaim):**
   * **Ablasi** `kolektor_segmen` (dengan vs tanpa, beberapa seed). Hasil sementara Thoriq: **tidak menambah akurasi berarti** (selisih < 0,02, dalam derau) karena fitur riwayat sudah memuat informasinya. Laporkan hasilmu sendiri, jujur.
   * **Analisis kesalahan per segmen** (HitRate@1 per `kolektor_segmen`; segmen `Belum Cukup Riwayat` = cold-start). `kolektor_label_asli` tetap hanya untuk analisis.
6. **Inferensi:** simpan model klasteringnya di bundle: `bundle["klaster_cutoff"] = joblib.load("models/clustering_kolektor_cutoff.joblib")`. `src/inference.py` sudah memakainya (atau memuat file itu otomatis) lewat
   `cx.pasang_klaster(...)` dan memakai ulang satu `_Konteks` per tabel supaya tidak lambat. **Artefak kini portabel** (hanya scikit-learn: scaler + k-NN, tanpa objek UMAP/HDBSCAN/numba) sehingga bisa dimuat tanpa `umap-learn`/`hdbscan`; kunci versi ada di `requirements-lock.txt`. Backend tidak memuat model ini.
7. **Uji ulang:** `python scripts/uji_paritas_fitur.py` (kini memuat model cutoff) harus 0 selisih; `python scripts/cek_sinyal_data.py` harus "ketidakcocokan: 0". Patokan md5 baru = CSV yang sekarang ada di repo
   (hasil `python jalankan_pipeline.py --dry-run`, deterministik).
8. Beri `model_version` baru (`klasifikasi-v2`) karena datanya berbeda.

## 1. Setup (±10 menit)
```powershell
git fetch origin
git checkout feature/ml-recommender          # branch Thoriq; berisi semua data & kode
cd ml-recommender
python -m venv .venv ; .venv\Scripts\activate
pip install -r requirements.txt
python scripts/cek_sinyal_data.py             # harus: "[audit kebocoran] ketidakcocokan: 0 -> OK"
```
* **Modeling hanya butuh CSV** di `data/training/` — tidak perlu database/R2.
* `DATABASE_URL` (di `backend/.env`, minta Thoriq) hanya dibutuhkan di bagian 4 (menulis hasil ke Neon). **Jangan commit `.env`.**
* Buat branch kerjamu: `git checkout -b feature/ml-model-rekomendasi`.

## 2. Tugas 1 — Klasifikasi pembelian
**Masalah:** untuk kolektor X pada waktu t, karya mana (di antara yang tersedia) yang akan dibeli? Klasifikasi biner `dibeli` per pasangan (kolektor, karya),
**dievaluasi sebagai ranking** per `grup_id`.

**Input:** `data/training/klasifikasi_pembelian.csv` (7.000 baris = 1.400 grup × 1 positif + 4 negatif). Baca `KAMUS_DATA.md` untuk arti tiap kolom.

**Aturan keras:**
1. **Pakai kolom `split`** (train/val/test berdasarkan waktu). **Dilarang split acak** — membocorkan masa depan.
2. **Bukan fitur:** `grup_id, split, waktu, transaksi_id, kolektor_id, karya_id, seniman_id`. Target = `dibeli`.
3. Kategorikal: `karya_gaya`, `seniman_level_reputasi`. **NaN itu bermakna** (mis. pembelian pertama = belum ada riwayat), bukan error — jangan di-drop;
   pilih model yang mendukung NaN (`HistGradientBoosting`) atau imputasi + indikator.
4. **Jangan resampling** (rasio 1:4 memang desain evaluasi grup). Pakai validasi **terhadap grup** (jangan memecah satu grup).
5. Pilih hyperparameter dengan **val**; sentuh **test hanya sekali** di akhir.

**Metrik utama (per grup):** HitRate@1, HitRate@3, MRR, NDCG@3. AUC boleh sebagai pelengkap. **Acak: HitRate@1 = 0,20; HitRate@3 = 0,60.**
Patokan sanity (`scripts/cek_sinyal_data.py`, GBM default, data generator-v2): AUC ≈ 0,89–0,93, HitRate@1 ≈ 0,77–0,78. Itu **patokan, bukan target**, dan tinggi karena datanya terstruktur — modelmu harus **mengalahkan baseline**, dan angkanya jangan diklaim sebagai performa nyata.

**Baseline wajib dibandingkan:** (a) acak, (b) "populer" = urut `gaya_n_terjual_30hari`/`seniman_n_terjual_30hari`, (c) aturan sederhana (mis. `match_porsi_gaya_ini` + `match_harga_dalam_rentang`),
(d) Logistic Regression (di-scale), (e) `HistGradientBoostingClassifier`. Boleh LightGBM/XGBoost **hanya jika** ditambahkan ke `requirements.txt` ml-recommender dan tidak perlu dipasang di backend.

### Catatan pemilihan metode (hasil EDA `notebooks/01_klasifikasi.ipynb`, 2026-10)

EDA sudah dijalankan penuh atas `klasifikasi_pembelian.csv` (struktur grup valid 0 masalah, split
kronologis tidak tumpang-tindih, NaN 14,3% terbukti terstruktur -- 100% di baris "pembelian pertama"
vs 0% di baris lain, korelasi tinggi antar fitur harga r=0,97/0,94/0,88). Temuan ini **mengonfirmasi**
(bukan mengubah) 5 baseline wajib di atas sudah tepat secara teknis -- dicatat di sini alasan/tujuan/
cara kerja tiap metode supaya tidak perlu dijelaskan ulang nanti saat menulis `LAPORAN_MODEL.md`.

1. **Acak** -- *tujuan:* patokan paling dasar, kalau model tidak mengalahkan ini berarti gagal total.
   *Cara kerja:* skor acak ke tiap kandidat dalam grup. HitRate@1 teoritis = 1/5 = 0,20 (1 positif dari
   5 kandidat/grup).
2. **"Populer"** (urut `gaya_n_terjual_30hari`/`seniman_n_terjual_30hari`) -- *tujuan:* uji apakah
   rekomendasi tanpa personalisasi (ikut tren umum) sudah cukup. *Cara kerja:* ranking murni dari
   angka tren, tidak melihat riwayat kolektor sama sekali. *Temuan EDA:* `gaya_porsi_penjualan_30hari`
   HAMPIR TIDAK beda antara `dibeli=1` vs `0` (selisih rata-rata -0,009) -- indikasi awal baseline ini
   lemah, tapi harus dibuktikan formal lewat metrik ranking, bukan cuma EDA univariat.
3. **Aturan sederhana** (`match_porsi_gaya_ini` + `match_harga_dalam_rentang`) -- *tujuan:* uji apakah
   rumus manual tanpa training sudah cukup bagus (kalau iya, model kompleks tidak perlu). *Cara kerja:*
   skor = kombinasi tetap dari 2 fitur match itu, tanpa `.fit()` apa pun. *Temuan EDA:*
   `match_harga_dalam_rentang` selisih rata-rata +0,25 antara dibeli/tidak -- baseline ini berpotensi
   kompetitif, bagus dijadikan pembanding serius.
4. **Logistic Regression** (di-scale) -- *tujuan:* baseline model linear yang "belajar" (beda dari #1-3
   yang tanpa training) -- kalau LogReg saja sudah cukup, model non-linear tidak perlu (prinsip model
   paling sederhana yang memadai). *Cara kerja:* bobot linear per fitur -> skor = kombinasi linear fitur
   (setelah preprocessing) -> sigmoid -> diurutkan per grup. *Konsekuensi dari temuan EDA (wajib
   dikerjakan sebelum `.fit()`):* (a) imputasi + kolom indikator `*_is_na` utk kolom ber-NaN -- LogReg
   tidak tahan NaN sama sekali, beda dari HGB; (b) one-hot utk `karya_gaya`/`seniman_level_reputasi`;
   (c) `StandardScaler` semua fitur numerik -- LogReg sensitif skala, pohon tidak; (d) korelasi tinggi
   antar fitur harga kolektor (r=0,97) berisiko bikin koefisien tidak stabil -- regularisasi L2 default
   scikit-learn sudah menangani ini, tidak perlu konfigurasi tambahan.
5. **`HistGradientBoostingClassifier`** -- *tujuan:* kandidat model UTAMA, diharapkan menangkap pola
   non-linear & interaksi antar fitur yang tidak bisa ditangkap LogReg. *Cara kerja:* ensemble banyak
   decision tree dangkal dibangun bertahap (boosting) -- tiap tree baru belajar memperbaiki residual
   tree sebelumnya; versi scikit-learn ini pakai histogram binning (makanya "Hist") supaya cepat di data
   besar. *Kecocokan dgn temuan EDA:* satu-satunya dari 5 metode yang HAMPIR TIDAK butuh preprocessing --
   NaN ditangani native, `categorical_features="from_dtype"` menangani 2 kolom kategorikal langsung,
   dan tidak terganggu multicollinearity/skew fitur harga (beda dari LogReg di #4).

**Catatan evaluasi:** karena dievaluasi sebagai *ranking per grup* (HitRate@K/MRR/NDCG@3), bukan
klasifikasi biner biasa, model **tidak perlu dikalibrasi** (`predict_proba` tidak harus akurat sbg
probabilitas sungguhan) -- yang penting cuma urutan relatif skor di dalam 1 grup benar. Jangan buang
waktu di `CalibratedClassifierCV`, di luar scope yang dibutuhkan.

**Soal LightGBM/XGBoost (opsional, diizinkan di atas):** TIDAK disarankan untuk dataset ini (cuma 7.000
baris) -- di skala ini performanya biasanya setara `HistGradientBoostingClassifier` bawaan sklearn,
tapi nambah dependency baru tanpa manfaat jelas. Baru pertimbangkan kalau dataset membesar signifikan.

**Analisis yang diharapkan:** feature importance (permutation), ablation kelompok fitur (riwayat kolektor / karya / kecocokan / tren seniman — apakah fitur tren `seniman_lonjakan_30hari` berguna?),
analisis kesalahan per `seniman_level_reputasi`, per `karya_gaya`, dan per segmen (pakai `kolektor_label_asli.csv` **hanya untuk analisis**).

**Keluaran:**
* Notebook `notebooks/01_klasifikasi.ipynb` (EDA singkat → baseline → model → evaluasi → analisis). Simpan output ringan (tanpa gambar besar).
* Artefak `models/klasifikasi_rekomendasi.joblib` berisi dict: `model` (pipeline sklearn lengkap termasuk preprocessing), `fitur` (urutan kolom), `kategorikal`, `versi` (mis. `klasifikasi-v1`),
  `dilatih_pada`, `metrik` (val & test). Ukuran harus kecil (< 5 MB).
* `models/LAPORAN_MODEL.md`: tabel metrik semua baseline vs model, fitur penting, **keterbatasan** (sintetis, 23 seniman, negatif acak).

## 3. Tugas 2 — Inferensi tanpa *train/serve skew*
Fitur saat inferensi **harus identik** dengan fitur saat training. Jangan menulis ulang rumusnya.

1. Di `src/features.py`, **refactor** pembuat satu baris fitur dari `bangun_klasifikasi` menjadi fungsi bersama, mis.
   `fitur_pasangan(cx, kolektor_id, idx_karya, t, n30_semua) -> dict`, dipakai oleh `bangun_klasifikasi` **dan** inferensi.
2. **Uji wajib:** setelah refactor, `python jalankan_pipeline.py --dry-run` harus menghasilkan CSV **identik byte-per-byte** (bandingkan `md5sum data/training/*.csv` sebelum/sesudah). Jangan lanjut kalau beda.
3. Buat `src/inference.py`:
   * `skor_kandidat(bundle, tabel, kolektor_id, t, karya_ids=None) -> DataFrame[karya_id, skor, alasan]`
   * `alasan_dari_fitur(baris_fitur) -> list[str]` memakai **kode alasan di README (kontrak)**; ambang batas final kamu tentukan dan dokumentasikan di `LAPORAN_MODEL.md`.
4. Uji: untuk 50 baris acak dari `klasifikasi_pembelian.csv`, fitur dari `fitur_pasangan` harus sama dengan baris CSV-nya (toleransi pembulatan 4 desimal).

## 4. Tugas 3 — Tulis hasil ke Neon (kontrak untuk Vika & Aulya)
Tabel `rekomendasi_kolektor` sudah dibuat **kosong** di Neon (schema `dummy_rekomendasi`) oleh Thoriq (DDL di `src/db.py`, spesifikasi kolom di README). `kolektor_segmen` **bukan** urusanmu — itu diisi Thoriq dari clustering.
Buat `scripts/hitung_rekomendasi.py`:

* Argumen: `--waktu` (default `2026-09-30T23:59:59Z` = `WINDOW_END`), `--top-k` (default 20), `--dry-run` (tanpa tulis DB, hanya CSV).
* Alur: `db.baca_semua()` → untuk **setiap kolektor** hitung kandidat = karya yang `created_at <= waktu` **dan belum ada di `transaksi`** → skor → ambil top-K.
* **`strategi`:** jika `kolektor_n_beli_sebelumnya == 0` pada `waktu` → `cold_start` (peringkat dari keramaian seniman/aliran; kode alasan `populer_umum`); selain itu `model`.
  (Generator menjamin tiap kolektor punya ≥1 pembelian, tetapi kolektor baru di dunia nyata tidak — kode tetap harus menanganinya.)
* **Tulis dalam SATU transaksi:** `DELETE` lalu `INSERT` ke `rekomendasi_kolektor` (idempotent: dijalankan ulang → hasil sama). `alasan` = JSONB list kode, mis. `["gaya_favorit","harga_sesuai"]`.
  Gunakan pola koneksi dari `src/db.py` (async SQLAlchemy). **Hanya sentuh tabel itu.**
* Salin hasil ke CSV: `data/hasil/rekomendasi_kolektor.csv` (Vika/Aulya bisa memeriksa tanpa DB).

**Kriteria selesai untuk data hasil (jalankan dan tempel hasilnya di PR):**
```sql
SELECT count(*) FROM dummy_rekomendasi.rekomendasi_kolektor;                     -- 200 x 20 = 4000
SELECT count(*) FROM dummy_rekomendasi.rekomendasi_kolektor r                    -- 0 (tak boleh merekomendasikan karya yang sudah terjual)
  JOIN dummy_rekomendasi.transaksi t ON t.karya_id = r.karya_id;
SELECT kolektor_id, count(DISTINCT peringkat) FROM dummy_rekomendasi.rekomendasi_kolektor
  GROUP BY 1 HAVING count(DISTINCT peringkat) <> 20;                             -- 0 baris
```
Periksa manual 3 kolektor (beda tingkat belanja): apakah alasan yang tercetak masuk akal terhadap riwayat belinya?

## 5. Git & kolaborasi
* Branch: `feature/ml-model-rekomendasi` (turunan `feature/ml-recommender`). PR ke `develop`. Commit kecil dan bermakna, **tanpa baris `Co-Authored-By`**.
* **Jangan ubah** `src/generate.py`, `data/training/*.csv`, atau `data/export/*` tanpa bicara dengan Thoriq (mengubahnya mengubah data semua orang). Kalau menemukan bug data, laporkan.
* Boleh mengubah `src/features.py` **hanya** untuk refactor di bagian 3 (dengan uji md5).
* Jangan menulis ke `public.*` di Neon. Jangan commit `.env`, `.venv`, atau artefak besar (> 5 MB).
* Kalau sesuatu di kontrak (README) tidak masuk akal, **bertanya/mengusulkan ke Thoriq** — jangan diam-diam menyimpang; Vika dan Aulya bergantung padanya.

## 6. Definition of Done
- [ ] `notebooks/01_klasifikasi.ipynb` rapi dan bisa dijalankan ulang dari awal
- [ ] Model klasifikasi **mengalahkan baseline "populer" dan aturan sederhana** pada val dan test (tabel di `LAPORAN_MODEL.md`); bila tidak, laporkan apa adanya
- [ ] Ablasi `kolektor_segmen` + analisis kesalahan per segmen ada di laporan; `bundle["klaster_cutoff"]` tersimpan di joblib; `model_version = klasifikasi-v2`
- [ ] `models/*.joblib` + `LAPORAN_MODEL.md` (termasuk keterbatasan sintetis) ter-commit, ukuran kecil
- [ ] Uji md5 refactor lolos; uji paritas fitur inferensi vs CSV lolos
- [ ] `scripts/hitung_rekomendasi.py` dijalankan; query kriteria bagian 4 lolos; tabel Neon terisi
- [ ] PR dibuka ke `develop`; **kabari Vika** (dan Thoriq) bahwa tabel sudah terisi + versi model (`klasifikasi-v1`)
