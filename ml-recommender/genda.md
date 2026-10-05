# genda.md — Arahan untuk Genda: Model Klasifikasi Rekomendasi

> File ini ditulis untuk **Claude Code milikmu**. Baca seluruhnya sebelum menulis kode. Bahasa kerja: **Indonesia**.
> Baca juga: `CLAUDE.md` (root), `ml-recommender/README.md` (terutama bagian **"Kontrak antar-bagian"**), dan `data/training/KAMUS_DATA.md`.

## 0. Konteks singkat
GALERIA = marketplace lukisan. Fitur baru: **rekomendasi katalog ke kolektor** berdasarkan kebiasaan beli (berapa banyak, harga berapa, aliran apa)
digabung dengan **tren seniman** (siapa yang sedang ramai), plus **segmentasi kolektor** (clustering, dikerjakan Thoriq). Hasil modelmu dibaca **Vika** (katalog) dan **Aulya** (dashboard seniman) —
mereka menunggu dua tabel Neon yang kamu isi.

**Pembagian modeling (final):** **kamu = klasifikasi** (siapa-membeli-karya-mana) → mengisi tabel `rekomendasi_kolektor`.
**Thoriq = clustering kolektor** → mengisi tabel `kolektor_segmen` (`kolektor_id`, `segmen_id`, `segmen_nama`). Kamu **tidak** mengerjakan clustering.
**Jangan memakai segmen hasil clustering sebagai fitur klasifikasi**: segmen dihitung dari *seluruh* riwayat sampai akhir periode, jadi memasukkannya ke model
**membocorkan masa depan** (pembelian setelah waktu prediksi ikut menentukan fiturnya).

### Yang WAJIB dipahami (kejujuran)
* **Seluruh data SINTETIS.** Gambar & aliran lukisan nyata (dataset Visual Search v1, 11 kelas), tetapi kolektor, harga, dan riwayat beli dibangkitkan program
  (`src/generate.py`). Model hanya mempelajari aturan buatan kita. **Jangan mengklaim skor sebagai performa nyata** — di laporan tulis "pada data sintetis".
* **Hanya 23 seniman** (subset v1 berasal dari 23 pelukis) dan 200 kolektor — kecil. Hati-hati overfit.
* Fitur "Estimasi Harga Jual" sudah **di-drop** dari scope. Jangan membuat model prediksi harga.
* `kolektor_label_asli` (segmen buatan generator) **dilarang** jadi fitur. Hanya untuk analisis kesalahan model; jangan jadi fitur.

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
Patokan sanity (`scripts/cek_sinyal_data.py`, GBM default): AUC ≈ 0,79–0,80, HitRate@1 ≈ 0,46–0,50. Itu **patokan, bukan target** — modelmu harus **mengalahkan baseline**.

**Baseline wajib dibandingkan:** (a) acak, (b) "populer" = urut `gaya_n_terjual_30hari`/`seniman_n_terjual_30hari`, (c) aturan sederhana (mis. `match_porsi_gaya_ini` + `match_harga_dalam_rentang`),
(d) Logistic Regression (di-scale), (e) `HistGradientBoostingClassifier`. Boleh LightGBM/XGBoost **hanya jika** ditambahkan ke `requirements.txt` ml-recommender dan tidak perlu dipasang di backend.

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
- [ ] Model klasifikasi **mengalahkan baseline "populer" dan aturan sederhana** pada val dan test (tabel di `LAPORAN_MODEL.md`)
- [ ] `models/*.joblib` + `LAPORAN_MODEL.md` (termasuk keterbatasan sintetis) ter-commit, ukuran kecil
- [ ] Uji md5 refactor lolos; uji paritas fitur inferensi vs CSV lolos
- [ ] `scripts/hitung_rekomendasi.py` dijalankan; query kriteria bagian 4 lolos; tabel Neon terisi
- [ ] PR dibuka ke `develop`; **kabari Vika** (dan Thoriq) bahwa tabel sudah terisi + versi model (`klasifikasi-v1`)
