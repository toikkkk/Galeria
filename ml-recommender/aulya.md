# aulya.md — Arahan untuk Aulya: Dashboard Seniman (backend FastAPI + Flutter)

> File ini ditulis untuk **Claude Code milikmu**. Baca seluruhnya sebelum menulis kode. Bahasa kerja & **semua teks UI: Indonesia**.
> Baca juga: `CLAUDE.md` (root), `backend/CLAUDE.md`, dan `ml-recommender/README.md` bagian **"Kontrak antar-bagian"**.

## 0. Tugasmu
Mengaktifkan **dashboard seniman** (`mobile/lib/screens/dashboard/dashboard_screen.dart`, 763 baris, **semuanya hardcode sekarang**) dengan data nyata dari backend:
informasi yang seharusnya didapat setiap seniman — penjualan, harga, aliran terlaris, siapa pembelinya, dan **pelukis/aliran yang sedang ramai di pasar**.

Pembagian: **Genda** = model klasifikasi; **Thoriq** = clustering (mengisi `kolektor_segmen`); **Vika** = katalog + rekomendasi kolektor; **kamu** = dashboard seniman. Jangan mengerjakan katalog/rekomendasi.

### Kamu bisa mulai SEKARANG
Hampir semua dashboard hanya butuh **data dasar Thoriq** yang sudah ada di Neon (`transaksi`, `karya`, `seniman`, view `v_seniman_metrik_bulanan`). Satu-satunya yang menunggu model:
bagian **"Segmen pembeli"** (tabel `kolektor_segmen`, hasil clustering **Thoriq**). Sebelum terisi, endpoint-nya mengembalikan `tersedia: false` dan UI menyembunyikan bagian itu.

### Kejujuran & batas scope
* Data **sintetis**. Beri label kecil "Data contoh" di dashboard. Pelukis = tokoh sungguhan, tetapi penjualan/harganya fiktif.
* **Dashboard hanya statistik deskriptif.** Fitur "Estimasi Harga Jual" sudah **di-DROP** — jangan membuat "harga yang disarankan", prediksi harga, atau prediksi penjualan. Perbandingan "harga rata-rata kamu vs rata-rata pasar" itu statistik, boleh.
* **Jangan mengarang angka.** Elemen UI yang tidak punya data (kunjungan karya, saldo tarik dana, pesanan perlu dikemas, lot lelang) → bagian 4 menjelaskan apa yang dilakukan.
* Jangan menyentuh `public.*` di Neon; jangan mengubah endpoint yang sudah ada.

## 1. Setup
```powershell
git fetch origin
git checkout feature/ml-recommender                 # sampai PR Thoriq masuk develop; lalu pakai develop
git checkout -b feature/dashboard-seniman
```
Backend: `cd backend ; .venv\Scripts\activate ; pip install -r requirements.txt`. Isi `backend/.env` (minta ke Thoriq **lewat jalur aman**; jangan commit):
`DATABASE_URL=...` (Neon `neondb`), opsional `REKOMENDASI_SCHEMA=dummy_rekomendasi`, `REKOMENDASI_WAKTU_ACUAN=2026-09-30T23:59:59Z`.
Jalankan `uvicorn main:app --reload` → `http://localhost:8000/docs`. HP via USB: `adb reverse tcp:8000 tcp:8000` (`mobile/docs/SETUP_ANDROID.md`).

**Waktu acuan.** Semua jendela waktu ("30 hari terakhir") dihitung mundur dari `REKOMENDASI_WAKTU_ACUAN` (akhir data dummy), **bukan** `now()` — kalau pakai `now()`, jendela akan kosong begitu data menua.

## 2. Backend — ikuti pola yang ada
Pola: `routers/*.py` (`APIRouter(prefix="/api")`) + `schemas/*.py` (Pydantic) + `database.get_db`; router didaftarkan di `backend/main.py` (`from routers import ...`, `app.include_router(...)`). Acuan: `backend/routers/katalog.py`.

* Buat `backend/routers/dashboard_seniman.py`, `backend/schemas/dashboard.py`, `backend/services/dashboard_repo.py`.
* Akses data: **SQL mentah `text()` dengan parameter ter-bind**. Nama schema dari env `REKOMENDASI_SCHEMA`, **divalidasi regex** `^[a-z_][a-z0-9_]*$` baru disisipkan. **Jangan** menambah model ke `Base.metadata`/Alembic.
  (Vika membuat modul serupa untuk katalog — nama file berbeda, jangan saling menimpa; fungsi kecil seperti validasi schema boleh diduplikasi.)
* `seniman_id` bukan UUID / tidak ada → 404. Uang = integer Rupiah. Persen = angka (mis. `12.5`), bukan desimal 0,125. `null` bila pembagi 0.

### Endpoint (path & pemilik: lihat README kontrak)
**`GET /api/dashboard/demo-seniman`** → daftar seniman contoh: `id`, `display_name`, `level_reputasi`, `n_terjual` (urut terbanyak). Pengganti login sampai Auth selesai.

**`GET /api/dashboard/seniman/{id}/ringkasan?periode=30`** (`periode` ∈ 30/90/365):
```json
{ "seniman": {"id": "...", "display_name": "Claude Monet", "level_reputasi": "mapan"},
  "periode_hari": 30,
  "n_terjual": 18, "omzet_idr": 1140000000, "komisi_platform_idr": 114000000,
  "pendapatan_bersih_idr": 1026000000, "harga_rata2_idr": 63300000, "n_pembeli_unik": 15,
  "karya_tersedia": 41, "karya_terjual_total": 220,
  "perubahan_pct": {"n_terjual": 12.5, "omzet_idr": -3.0} }
```
`perubahan_pct` = periode ini vs periode sama persis sebelumnya. Sketsa SQL (`:t` = waktu acuan, `:p` = periode, `S` = schema):
```sql
SELECT count(*) AS n, COALESCE(sum(harga_final_idr),0)::bigint AS omzet, COALESCE(sum(komisi_platform_idr),0)::bigint AS komisi,
       COALESCE(round(avg(harga_final_idr)),0)::bigint AS rata2, count(DISTINCT pembeli_id) AS pembeli
FROM S.transaksi
WHERE penjual_id = :sid AND created_at >  CAST(:t AS timestamptz) - make_interval(days => :p) AND created_at <= CAST(:t AS timestamptz);
-- periode sebelumnya = (t - 2p, t - p]: ganti batas atas menjadi CAST(:t AS timestamptz) - make_interval(days => :p) dan batas bawah menjadi make_interval(days => 2 * :p)
SELECT count(*) FILTER (WHERE tr.id IS NULL) AS tersedia, count(*) FILTER (WHERE tr.id IS NOT NULL) AS terjual
FROM S.karya k LEFT JOIN S.transaksi tr ON tr.karya_id = k.id WHERE k.seniman_id = :sid AND k.created_at <= CAST(:t AS timestamptz);
```
**Penting (asyncpg):** parameter waktu **wajib** `CAST(:t AS timestamptz)`. Tanpa itu Postgres salah menebak tipenya dan melempar `operator does not exist: timestamp with time zone > interval`. Jangan pakai `:t::timestamptz` — SQLAlchemy `text()` tidak mengenali `:t` bila langsung diikuti `::`.

**`GET /api/dashboard/seniman/{id}/penjualan-bulanan?bulan=12`** → deret **lengkap** N bulan terakhir (bulan tanpa penjualan diisi nol — view `v_seniman_metrik_bulanan` hanya memuat bulan yang ada penjualannya, jadi isi celahnya di Python):
`[{"bulan": "2026-09-01", "n_terjual": 9, "omzet_idr": ..., "harga_rata2_idr": ..., "n_pembeli_unik": ..., "gaya_terlaris": "Impressionism" | null}]`.

**`GET /api/dashboard/seniman/{id}/aliran`** → per aliran: `style_name`, `n_terjual`, `omzet_idr`, `harga_rata2_idr`, `harga_pasar_rata2_idr` (rata-rata harga jual aliran itu dari **semua** seniman), `selisih_pct`. Urut `n_terjual` turun.

**`GET /api/dashboard/seniman/{id}/segmen-pembeli`** → `{"tersedia": true, "items": [{"segmen_id": 2, "segmen_nama": "...", "n_pembeli": 7, "porsi_pct": 46.7}]}`.
`JOIN kolektor_segmen` ke `transaksi.pembeli_id`. Tabel kosong → `{"tersedia": false, "items": []}` (bukan error).

**`GET /api/dashboard/pasar/tren`** → bagian "sedang ramai" (inilah informasi "pelukis apa yang lagi ramai dengan harga jual tinggi"):
```json
{ "seniman_ramai": [{"seniman_id": "...", "display_name": "...", "n_terjual_30hari": 12, "lonjakan": 2.1, "harga_rata2_30hari_idr": 85000000}],
  "aliran_ramai":  [{"style_name": "Impressionism", "n_terjual_30hari": 55, "porsi_penjualan_pct": 31.0, "harga_rata2_30hari_idr": 48000000}] }
```
`lonjakan = (n30 + 1) / ((n90 - n30) / 2 + 1)` (n30 = penjualan 30 hari, n90 = 90 hari, dari waktu acuan) — **rumus yang sama dengan fitur model**, supaya angka dashboard konsisten. 10 seniman teratas (urut `n_terjual_30hari`, lalu `lonjakan`) dan semua aliran.

### Cek backend
```powershell
curl "http://localhost:8000/api/dashboard/demo-seniman"
curl "http://localhost:8000/api/dashboard/seniman/<id>/ringkasan?periode=90"
curl "http://localhost:8000/api/dashboard/pasar/tren"
```
Cocokkan angka dengan data mentah: jumlah `n_terjual` semua seniman = 1.400; jumlah `omzet` seniman = jumlah `harga_final_idr` seniman itu (query langsung ke `transaksi`).
Setelah selesai, **tambahkan bagian "Bentuk respons dashboard" ke `ml-recommender/README.md`** dalam PR yang sama.

## 3. Flutter — peta kerja (sudah diverifikasi)
Struktur: `mobile/lib/{models,services,screens,widgets,theme,utils?}`. Klien HTTP: `services/api_client.dart` (`ApiClient.getJson`, `kApiBaseUrl`, `ApiException`). Contoh service: `services/katalog_service.dart`.
`DashboardScreen` dirakit di `main.dart` (route `/dashboard`, sekitar baris 134) dengan callback `onUploadKarya`, `onNavTap`, dst — **pertahankan semua callback & navigasi yang ada**.

File baru: `models/dashboard_seniman.dart`, `services/dashboard_service.dart` (pola `KatalogService`), `utils/format.dart` (`formatRupiah(int)` → "Rp36.200.000" seperti `Karya.priceFormatted`; `formatRupiahRingkas(int)` → "Rp36,2 jt"),
`config/demo_seniman.dart` (nama ini **khusus milikmu**; Vika memakai `demo_kolektor.dart` — jangan buat `demo_user.dart` bersama agar tak bentrok). `demo_seniman.dart` mengambil seniman demo pertama dari `/api/dashboard/demo-seniman`; override `--dart-define=DEMO_SENIMAN_ID=<uuid>`.

Pecah file besar: pindahkan kartu/section ke `widgets/dashboard/*.dart` seperlunya supaya `dashboard_screen.dart` tidak membengkak.

## 4. Pemetaan elemen dashboard yang ada → data
Nomor baris dari `dashboard_screen.dart` saat ini (bisa bergeser sedikit):

| Elemen sekarang (hardcode) | Ganti dengan |
|---|---|
| Nama "Sanggar Rupa Nusantara" (±104), lencana "Kurator Terakreditasi"/"Salon Utama" (±107/114) | `seniman.display_name`; lencana = level (`pemula`/`menengah`/`mapan` → "Seniman Pemula"/"Seniman Menengah"/"Seniman Mapan") |
| Kartu saldo "+Rp 36.200.000 pekan kurasi ini" (±144–189) | `pendapatan_bersih_idr` periode terpilih; ubah label menjadi "Pendapatan bersih · {periode} hari"; subjudul = `perubahan_pct.omzet_idr` |
| Tombol "Tarik Dana"/"Riwayat" (±200/213) | **Biarkan sebagai placeholder** (tidak ada data penarikan); jangan dihubungkan ke angka palsu |
| Stat card "Koleksi Terpasang" (±236) | `karya_tersedia` |
| Stat card "Menunggu Kirim" (±258) | **tidak ada datanya** → ganti jadi "Karya Terjual" (`n_terjual`) atau "Pembeli Unik"; jangan dikarang |
| "Perlu Tindakan" + 2 baris (pesanan perlu dikemas, lelang berakhir) (±269–293) | tidak ada data (transaksi dummy semua `selesai`) → pertahankan sebagai contoh berlabel "Contoh", atau sembunyikan; **jangan** menghitung dari data dummy |
| "Performa 7 Hari" + grafik (±337, `_TrendChartPainter` ±631) | **"Penjualan 12 Bulan"** dari `penjualan-bulanan` |
| Legenda "Kunjungan Karya" (±358) | **hapus** (tidak ada data kunjungan); sisakan satu seri "Penjualan (karya terjual)"; opsi ganti ke omzet |
| "Lot unggulan berjalan" (±405, memakai `sampleKarya[3]`) | tidak ada data lelang → biarkan mock berlabel "Contoh" |

**Bagian baru** (di bawah grafik): **"Aliran Terlaris"** (daftar + selisih harga vs rata-rata pasar), **"Siapa Pembelimu"** (segmen, sembunyikan bila `tersedia:false`), **"Sedang Ramai di Pasar"** (`pasar/tren`: seniman & aliran dengan `lonjakan`).
Kata-kata netral dan deskriptif ("harga rata-rata 12% di atas rata-rata pasar"), **bukan** anjuran harga.

Grafik: **jangan menambah paket chart baru** tanpa konfirmasi tim. Generalisasi `_TrendChartPainter` agar menerima `List<double>` (+ label bulan) — sudah ada `CustomPainter`-nya.
State: ubah ke `FutureBuilder`/state dengan **loading** (kerangka/skeleton), **error + tombol "Coba lagi"**. Kalau backend gagal, **jangan** diam-diam menampilkan angka hardcode seolah nyata (beda dengan katalog; ini angka keuangan). Pemilih periode 30/90/365 hari sebagai segmented control.

## 5. Larangan umum
* Jangan hardcode kredensial/URL rahasia; jangan commit `.env`. Jangan mengubah bentuk JSON kontrak antar-bagian sepihak (README).
* Jangan mengubah `Karya`/layar kolektor (milik Vika). Jangan menyentuh Visual Search.
* Commit kecil, **tanpa baris `Co-Authored-By`**. Branch `feature/dashboard-seniman`, PR ke `develop`. Konflik kecil di `backend/main.py` (daftar router) dengan Vika wajar — gabungkan keduanya.

## 6. Pengujian
```powershell
cd mobile ; flutter analyze ; flutter test            # harus bersih
```
Manual di HP: (1) dashboard menampilkan nama & angka seniman demo dari backend; (2) ganti periode 30/90/365 → angka berubah; (3) grafik 12 bulan benar (bulan kosong = 0);
(4) matikan backend → muncul pesan error + "Coba lagi", bukan angka palsu; (5) bagian "Siapa Pembelimu" tersembunyi saat `tersedia:false` dan muncul setelah Thoriq mengisi tabel `kolektor_segmen`; (6) tombol Unggah Karya, Bottom Nav, Komunitas, Seniman PRO tetap bekerja.

## 7. Definition of Done
- [ ] 6 endpoint sesuai bentuk di atas; angka cocok dengan query langsung ke `transaksi`
- [ ] `dashboard_screen.dart` memakai data API; elemen tanpa data diperlakukan sesuai tabel bagian 4 (tidak ada angka karangan)
- [ ] Loading / error / coba-lagi; segmen disembunyikan bila belum tersedia
- [ ] Tidak ada fitur prediksi/saran harga; label "Data contoh" ada
- [ ] `flutter analyze` & `flutter test` bersih; tidak ada kredensial di diff
- [ ] "Bentuk respons dashboard" ditambahkan ke README; PR ke `develop`; kabari Thoriq
