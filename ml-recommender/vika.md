# vika.md — Arahan untuk Vika: Katalog + Rekomendasi (backend FastAPI + Flutter)

> File ini ditulis untuk **Claude Code milikmu**. Baca seluruhnya sebelum menulis kode. Bahasa kerja & **semua teks UI: Indonesia**.
> Baca juga: `CLAUDE.md` (root), `backend/CLAUDE.md`, dan `ml-recommender/README.md` bagian **"Kontrak antar-bagian"** (bentuk tabel, kode alasan, bentuk JSON — **ikuti persis**).

## 0. Tugasmu
Menyambungkan hasil pemodelan ke **bagian katalog kolektor**:
1. **Katalog 2.000 karya dummy** tampil di app (daftar, filter, pencarian) lengkap dengan **gambar dari Cloudflare R2**.
2. Bagian **"Rekomendasi untukmu"** di beranda kolektor menampilkan karya yang direkomendasikan model, lengkap dengan **alasan** ("Sesuai aliran favoritmu: Impressionism").

Pembagian: **Genda** = model + mengisi tabel hasil; **Aulya** = dashboard seniman; **kamu** = katalog + rekomendasi. Jangan mengerjakan dashboard.

### Yang bisa dikerjakan kapan
| Bagian | Mulai | Bergantung pada |
|---|---|---|
| Gambar dari R2 di Flutter, `GET /api/katalog-dummy`, layar katalog | **Sekarang** | data dasar Thoriq (sudah ada) |
| `GET /api/rekomendasi/...` + UI "Rekomendasi untukmu" | Kerangka sekarang (pakai mock, bagian 5), data asli **setelah Genda mengisi** `rekomendasi_kolektor` | tabel hasil Genda |

### Kejujuran & batas scope
* Data **sintetis** (kolektor, transaksi, harga). Beri label kecil "Data contoh" di UI yang menampilkannya. Pelukis di katalog tokoh sungguhan; harga/riwayatnya fiktif.
* Fitur **"Estimasi Harga Jual" sudah di-DROP** — jangan membuat prediksi/saran harga. `skor` rekomendasi hanya untuk urutan, **jangan** ditampilkan sebagai "peluang 83%".
* Jangan menyentuh `public.*` di Neon dan jangan mengubah `GET /api/katalog` / `POST /api/visual-search` (dipakai Visual Search yang sudah jalan).

## 1. Setup
```powershell
git fetch origin
git checkout feature/ml-recommender              # sampai PR Thoriq masuk develop; lalu pakai develop
git checkout -b feature/katalog-rekomendasi
```
* Backend: `cd backend ; .venv\Scripts\activate ; pip install -r requirements.txt`. Isi `backend/.env` (minta ke Thoriq **lewat jalur aman**, bukan chat publik/commit):
  `DATABASE_URL=...` (Neon `neondb`), `R2_PUBLIC_URL_BASE=https://pub-....r2.dev`, opsional `REKOMENDASI_SCHEMA=dummy_rekomendasi`, `REKOMENDASI_WAKTU_ACUAN=2026-09-30T23:59:59Z`.
* Jalankan: `uvicorn main:app --reload` → cek `http://localhost:8000/docs`. HP via USB: `adb reverse tcp:8000 tcp:8000` (lihat `mobile/docs/SETUP_ANDROID.md`).
* **Gambar R2:** domain `r2.dev` bisa **terblokir DNS** sebagian provider Indonesia (sertifikat error / gambar kosong). Saat dev: ganti DNS ke `1.1.1.1` / `8.8.8.8` atau pakai data seluler. Ini bukan bug kodemu. Rilis nanti memakai custom domain.

## 2. Backend (FastAPI) — ikuti pola yang sudah ada
Pola proyek: `routers/*.py` (`APIRouter(prefix="/api")`) + `schemas/*.py` (Pydantic) + `database.get_db` (async session); router didaftarkan di `backend/main.py` (baris `from routers import ...` dan `app.include_router(...)`). Contoh acuan: `backend/routers/katalog.py`, `backend/schemas/katalog.py`.

### 2.1 Akses data — satu modul saja
Buat `backend/services/rekomendasi_repo.py`:
* Pakai SQL mentah `text()` dengan **parameter ter-bind** (jangan f-string untuk nilai dari user). Nama schema dari env `REKOMENDASI_SCHEMA` (default `dummy_rekomendasi`),
  **divalidasi regex** `^[a-z_][a-z0-9_]*$` lalu baru disisipkan ke SQL — supaya nanti bisa dialihkan ke tabel produksi hanya dengan mengganti env/satu modul ini.
* **Jangan** menambah model ke `Base.metadata` / Alembic (schema ini di luar rantai migrasi tim). Pakai SQL mentah.
* `gallery_name` karya dummy = `'Studio ' || seniman.display_name`; `is_promoted` = `false` (Flutter `Karya.fromJson` mewajibkan `gallery_name` non-null → kalau null, **app crash**).
* `image_url` = `R2_PUBLIC_URL_BASE.rstrip('/') + '/' + image_key`, atau `null` bila `image_key` kosong / env belum diisi.

### 2.2 Endpoint
**`GET /api/katalog-dummy`** — parameter: `page=1`, `page_size=20` (maks 100), `gaya`, `harga_min`, `harga_maks`, `q` (cari di judul & nama seniman, `ILIKE`), `urut` (`terbaru` | `harga_asc` | `harga_desc`), `hanya_tersedia=true`.
Respons = bentuk `KatalogPage` yang sudah ada, ditambah `image_url` dan `seniman_id` per item. "Tersedia" = `LEFT JOIN transaksi ... WHERE transaksi.id IS NULL`. Validasi: `page`/`page_size` < 1 → 400 (seperti `katalog.py`).

**`GET /api/rekomendasi/demo-kolektor`** — ±5 kolektor contoh (pilih yang punya baris di `rekomendasi_kolektor`, variasikan segmen): `id`, `display_name`, `segmen`, `n_pembelian`. Pengganti login sampai Auth selesai.

**`GET /api/rekomendasi/{kolektor_id}?top_k=10`** — baca `rekomendasi_kolektor` JOIN `karya` JOIN `seniman` JOIN `kolektor_segmen`, urut `peringkat`, `LIMIT top_k` (maks 20).
Bentuk JSON **persis** seperti di README (kontrak). `alasan`: ubah kode → teks Indonesia dengan satu dict di backend (7 kode di README; `gaya_favorit` memuat nama aliran).
Perilaku: `kolektor_id` bukan UUID / tidak ada → 404; tabel hasil belum terisi untuk kolektor itu → **503** dengan pesan "Rekomendasi belum dihitung" (Flutter akan diam-diam jatuh ke katalog biasa); jangan 500.

Daftarkan router baru di `main.py`. Tambahkan skema di `backend/schemas/rekomendasi.py`.

### 2.3 Cek backend
```powershell
curl "http://localhost:8000/api/katalog-dummy?page_size=3&gaya=Impressionism"
curl "http://localhost:8000/api/rekomendasi/demo-kolektor"
curl "http://localhost:8000/api/rekomendasi/<id>?top_k=5"
```
Pastikan: `image_url` terisi & bisa dibuka di browser; `gallery_name` tidak pernah null; urutan `peringkat` naik; tidak ada karya yang sudah terjual di hasil rekomendasi.

## 3. Flutter — file & baris yang relevan (sudah diverifikasi)
Struktur: `mobile/lib/{models,services,screens,widgets,theme}`; klien HTTP `services/api_client.dart` (`ApiClient.getJson`, `kApiBaseUrl`, `ApiException`); contoh service `services/katalog_service.dart`.

### 3.1 Gambar dari URL (inti masalah)
Sekarang `Karya.fromJson` (di `models/karya.dart`) membangun `assetPath: 'assets/images/catalog/${image_filename}'` dan layar memakai `Image.asset(karya.assetPath)`. Gambar dummy **tidak ada di aset** → harus dari R2.
1. `models/karya.dart`: tambah `final String? imageUrl;` dan `final String? senimanId;` (opsional, **jangan** ubah parameter `required` yang sudah ada — banyak layar memakai `sampleKarya`). Baca `json['image_url']` di `fromJson`.
2. Buat `widgets/karya_image.dart` → `KaryaImage(karya: ..., fit: BoxFit.cover)`: jika `imageUrl != null` pakai `Image.network` (dengan `loadingBuilder` placeholder & `errorBuilder` ikon gambar-rusak), selain itu `Image.asset(assetPath)`.
3. Ganti `Image.asset(karya.assetPath ...)` → `KaryaImage` **hanya** di layar yang menampilkan data dari API:
   `widgets/kolektor/karya_grid_card.dart:53`, `screens/kolektor/beranda/beranda_kolektor_screen.dart:237` dan `:635`, `screens/kolektor/karya/detail_karya_screen.dart:57`, `screens/kolektor/koleksi/koleksi_saya_screen.dart:228`.
   **Jangan** mengubah layar yang memakai `sampleKarya` murni sebagai mock (onboarding, lelang, pesanan, dst.) — tidak perlu dan menambah risiko.

### 3.2 Service & model
* `services/katalog_service.dart`: tambah `fetchKatalogDummy({page, pageSize, gaya, hargaMin, hargaMaks, q, urut})` → memakai `Karya.fromJson`.
* `models/karya_rekomendasi.dart`: `KaryaRekomendasi { Karya karya; int peringkat; double skor; List<AlasanRekomendasi> alasan; }`; `RekomendasiResult { String strategi; String? segmenNama; List<KaryaRekomendasi> items; }`.
* `services/rekomendasi_service.dart`: `fetchDemoKolektor()` dan `fetchRekomendasi(kolektorId, {topK})`. Ikuti pola `KatalogService` (membungkus `ApiClient`, melempar `ApiException`).
* `config/demo_kolektor.dart` (nama file ini **khusus milikmu** supaya tidak bentrok dgn Aulya): ambil kolektor demo pertama dari backend sekali, simpan di memori; boleh dioverride `--dart-define=DEMO_KOLEKTOR_ID=<uuid>`. Beranda masih menulis "Halo, Rani" (hardcode) — biarkan, Auth belum ada.

### 3.3 Layar
* **Beranda** (`beranda_kolektor_screen.dart`): bagian "Rekomendasi untukmu" (judul di sekitar baris 406) sudah ada tetapi memakai `_karya` (katalog). Muat rekomendasi via `RekomendasiService`; tampilkan di grid/list yang sama. Pola yang sudah dipakai file itu: **mulai dari data lokal, ganti begitu fetch sukses, gagal → diam-diam tetap data lokal** — pertahankan.
  Subjudul: `strategi == 'model'` → "Berdasarkan kebiasaan belanjamu"; `cold_start` → "Sedang ramai di GALERIA". Tampilkan **1 alasan teratas** sebagai chip kecil di kartu (tambahkan parameter opsional `alasan` di `KaryaGridCard`, default `null` agar pemakai lama tidak berubah). Tampilkan label "Data contoh".
* **Semua karya** (`screens/kolektor/karya/semua_karya_screen.dart`): sumber data dari `fetchKatalogDummy` dengan paging (muat halaman berikut saat scroll mendekati akhir), filter aliran, rentang harga, urutan. Pencarian di beranda saat ini memfilter daftar lokal (`matchesQuery`) — dengan 2.000 karya, kirim `q` ke server (debounce ±300 ms).
* Tambahkan flag `const kPakaiDataDummy = bool.fromEnvironment('DATA_DUMMY', defaultValue: true);` (di `api_client.dart`) untuk berpindah ke `/api/katalog` lama.

## 4. Larangan umum
* Jangan hardcode URL R2 / kredensial di kode Flutter atau backend. Jangan commit `.env`.
* Jangan menambah paket Flutter baru (mis. `cached_network_image`) tanpa konfirmasi tim — mulai dengan `Image.network`.
* Jangan mengubah bentuk JSON kontrak sepihak — ubah README dalam PR yang sama dan kabari Genda/Aulya.
* Commit kecil, **tanpa baris `Co-Authored-By`**. Branch `feature/katalog-rekomendasi`, PR ke `develop`.

## 5. Mock sebelum tabel Genda terisi (agar tidak menunggu)
Buat `backend/fixtures/rekomendasi_mock.json` (bentuk sama dgn kontrak, 10 item, ambil karya nyata dari `GET /api/katalog-dummy`) dan sajikan bila env `REKOMENDASI_MOCK=1`. Dengan itu seluruh UI rekomendasi bisa dikerjakan lebih dulu.
**Jangan** menulis baris tiruan ke tabel `rekomendasi_kolektor` di Neon (itu tabel Genda; skripnya akan menimpanya).

## 6. Pengujian
```powershell
cd mobile ; flutter analyze ; flutter test            # harus bersih
```
Manual di HP (backend jalan + `adb reverse`): (1) beranda menampilkan rekomendasi dgn gambar R2 & chip alasan; (2) matikan backend → app tetap tampil data lokal tanpa crash;
(3) "Semua karya" → scroll memuat halaman berikut, filter aliran & harga bekerja; (4) detail karya menampilkan gambar R2; (5) layar Visual Search & onboarding tidak berubah.

## 7. Definition of Done
- [ ] `/api/katalog-dummy`, `/api/rekomendasi/demo-kolektor`, `/api/rekomendasi/{id}` sesuai kontrak (diuji dgn curl, `gallery_name` tak pernah null)
- [ ] Gambar dari R2 tampil di grid, beranda, dan detail; fallback aset tetap jalan
- [ ] "Rekomendasi untukmu" memakai data model (atau mock) + chip alasan; gagal fetch → fallback tanpa crash
- [ ] Katalog dummy ter-paging + filter + pencarian server-side
- [ ] `flutter analyze` & `flutter test` bersih; tidak ada kredensial di diff
- [ ] PR ke `develop` + catatan singkat cara menjalankan; kabari Thoriq
