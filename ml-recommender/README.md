# ml-recommender — Data & dataset training sistem rekomendasi lukisan

> **Semua data transaksi di sini SINTETIS.** Gambar & aliran lukisan nyata (dataset Visual Search **v1**:
> 5.659 gambar, 11 kelas), tetapi kolektor, harga, dan riwayat pembelian dibangkitkan program.
> Model yang dilatih di sini mempelajari aturan buatan kita, **bukan** perilaku pembeli nyata. Jangan klaim
> skornya sebagai performa produksi.

## Perombakan 2026-10-18 — generator-v2 + clustering-v2 (BACA DULU)

Atas arahan dosen (silhouette > 0,5 dianggap valid, 0,3 cukup valid; K-Means dianggap terlalu tua; data dummy boleh disesuaikan dengan algoritma):

1. **Urutan kerja sekarang: CLUSTERING DULU, lalu KLASIFIKASI.** Segmen kolektor menjadi fitur klasifikasi (`kolektor_segmen`).
2. **Clustering = UMAP + HDBSCAN** (`src/clustering.py`, laporan `models/LAPORAN_CLUSTERING.md`), bukan K-Means. Jumlah segmen ditemukan sendiri (K = 5), kolektor baru ditetapkan lewat
   k-NN pada fitur terstandarisasi (artefak `.joblib` portabel: hanya scikit-learn, tanpa objek UMAP/HDBSCAN). Hasil: **silhouette 0,649** (ruang fitur asli, kategori "wajar" > 0,50), ARI 0,965 terhadap label asli, stabilitas bootstrap 0,99, noise 0%.
3. **Data dummy dirombak (`generator-v2`).** Lima arketipe kolektor yang berbeda tegas (anggaran, frekuensi, keikutan tren, level seniman), tiap kolektor ≥ 3 pembelian.
   **Tabel `seniman`, `karya`, gambar, dan harga IDENTIK dengan sebelumnya** (diverifikasi) — jadi R2, filter karya vulgar, dan katalog tidak perlu dibuat ulang. Yang berubah: `kolektor`, `transaksi`, dan semua turunannya.
4. **Klasifikasi dibangun ulang** dengan fitur tambahan `kolektor_segmen` (43 kolom). Skor sanity naik (HitRate@1 ≈ 0,77, AUC ≈ 0,89–0,93), **tetapi itu karena data kini jauh lebih terstruktur, bukan karena model lebih pintar.**
   Ablasi: `kolektor_segmen` **tidak** menambah akurasi berarti (selisih < 0,02, dalam derau) karena fitur riwayat kolektor sudah memuat informasinya. Dipertahankan sesuai urutan kerja dan untuk analisis per segmen.

**Kejujuran (wajib dibawa ke presentasi/laporan):**
* Silhouette 0,65 adalah **hasil desain generator**, bukan temuan tentang pembeli lukisan nyata. Pada data nyata skor akan jauh lebih rendah.
* Pada data ini K-Means dengan K=5 yang diberi tahu di awal juga mendapat 0,649; skornya ditentukan **datanya**. Keunggulan UMAP + HDBSCAN adalah K ditemukan sendiri, noise ditangani, dan kolektor baru bisa ditetapkan tanpa melatih ulang.
* Fitur klaster dipilih berdasarkan kebersihan sinyal setelah percobaan pada data ini (keterpusatan selera aliran dikeluarkan karena berisik); percobaannya tercatat di laporan.

**Yang menjadi basi dan harus dibuat ulang:** `models/klasifikasi_rekomendasi.joblib`, `data/hasil/rekomendasi_kolektor.csv`, `models/LAPORAN_MODEL.md` (Genda), dan — bila belum di-`--reset` — isi tabel Neon.
**STATUS NEON:** **SUDAH diisi ulang (2026-10-18)** dengan data generator-v2: `kolektor` 200, `transaksi` 1.400, `kolektor_segmen` 200 + `segmen_kamus` 5 (`clustering-v2`); `karya` 2.000 dengan `image_key` R2 terisi. `rekomendasi_kolektor` masih kosong (menunggu Genda).

## Isi folder

| Path | Isi |
|---|---|
| `data/training/klasifikasi_pembelian.csv` | Dataset **klasifikasi** (dibangun Thoriq, dimodelkan Genda): 7.000 baris × 43 kolom = 1.400 grup × (1 positif + 4 negatif), split berdasarkan waktu; termasuk fitur `kolektor_segmen` dari clustering |
| `data/training/clustering_kolektor.csv` | Dataset **clustering** (bagian Thoriq): 200 kolektor × 31 kolom; 5 di antaranya fitur klaster, sisanya untuk profil segmen |
| `data/training/kolektor_label_asli.csv` | Segmen asli generator — **hanya utk validasi clustering**, bukan fitur |
| `data/training/seniman_metrik_bulanan.csv` | Penjualan per seniman per bulan (bahan dashboard seniman) |
| `data/training/KAMUS_DATA.md` | **Baca ini dulu**: arti tiap kolom, aturan anti-kebocoran, cara evaluasi |
| `data/export/*.csv` | Salinan mentah tabel Neon (`seniman`, `kolektor`, `karya`, `transaksi`) |
| `data/sumber/pool_gambar.csv` | Daftar gambar v1 yang boleh jadi karya (5.563 gambar, 23 pelukis) |
| `src/generate.py` | Generator data (deterministik, seed 42) + penjelasan model perilaku |
| `src/features.py` | Pembuat fitur training (anti-kebocoran waktu) + kamus kolom |
| `src/db.py` | DDL + baca/tulis schema `dummy_rekomendasi` di Neon |
| `src/urutan.py` | Urutan baris **kanonik** (pipeline tidak boleh bergantung pada urutan fisik Postgres — lihat catatan di bawah) |
| `jalankan_pipeline.py` | Generate → isi Neon → baca ulang → CSV |
| `scripts/` | `siapkan_pool_gambar.py`, `upload_gambar_r2.py`, `cek_sinyal_data.py`, `latih_clustering.py`, `hitung_segmen.py` |
| `src/clustering.py` · `notebooks/02_clustering.ipynb` | **Clustering kolektor (Thoriq, `clustering-v2`, UMAP + HDBSCAN)**: logika inti + notebook proses (sudah dieksekusi) |
| `models/clustering_kolektor.joblib` · `models/clustering_kolektor_cutoff.joblib` · `models/LAPORAN_CLUSTERING.md` | Model FINAL (dashboard/Neon) · model CUTOFF (fitur klasifikasi tanpa kebocoran) · laporan (angka dihitung otomatis; membahas keterbatasan) |
| `SERAH_TERIMA_THORIQ.md` | Serah-terima hasil clustering untuk Aulya/Vika/Genda (apa yang siap, cara pakai, batasan) |
| `data/hasil/segmen_kamus.csv` | Deskripsi tiap segmen (salinan tabel `segmen_kamus`) |
| `data/hasil/segmen_kolektor.csv` | Segmen tiap kolektor (salinan tabel `kolektor_segmen`) |
| `genda.md` · `vika.md` · `aulya.md` | **Arahan kerja per orang** (utk Claude Code masing-masing): pemodelan · katalog+rekomendasi · dashboard seniman |
| `models/` · `notebooks/` · `data/hasil/` | Tempat hasil pemodelan (artefak `.joblib`, notebook, CSV hasil) — diisi Genda |

## Di database (Neon)

Schema terpisah **`dummy_rekomendasi`**: `seniman` (23), `kolektor` (200), `kolektor_label_asli` (200),
`karya` (2.000), `transaksi` (1.400), view `v_seniman_metrik_bulanan`. Ukuran total ~2 MB. Tabel `public.*` tidak disentuh.

Kenapa schema terpisah, bukan tabel produksi: `transaksi` asli mewajibkan tanda tangan digital (`digital_signature`,
`signing_key_id`) — data dummy di sana berarti memalsukan bukti order; `public.karya` tampil di katalog aplikasi;
dan DDL-nya sengaja **tidak** lewat Alembic supaya tidak bentrok dengan rantai migrasi tim. Nama kolom meniru tabel
produksi (`pembeli_id`, `penjual_id`, `harga_final_idr`, `price_idr`, `created_at`, `image_key`) sehingga pipeline
bisa diarahkan ke tabel asli nanti. Hapus bersih: `DROP SCHEMA dummy_rekomendasi CASCADE;`

## Menjalankan

```powershell
cd ml-recommender
python -m venv .venv ; .venv\Scripts\activate ; pip install -r requirements.txt
python jalankan_pipeline.py             # pakai data yg ada di Neon (isi dulu kalau kosong)
python jalankan_pipeline.py --reset     # bangun ulang dari generator
python jalankan_pipeline.py --dry-run   # tanpa database (CSV dari memori)
python scripts/cek_sinyal_data.py       # audit kebocoran + sanity check sinyal
```
Butuh `DATABASE_URL` (env var atau `backend/.env`). Pipeline deterministik: dijalankan ulang menghasilkan CSV identik.
Parameter jumlah data: `--n-karya 2000 --n-transaksi 1400 --n-kolektor 200 --n-seniman 23` (1 karya = 1 penjualan,
jadi `n-karya ≥ 1,1 × n-transaksi`; seniman maks 23).

## Gambar → Cloudflare R2 (SUDAH aktif, 2.000/2.000 gambar)

Gambar **tidak** disimpan di Neon (2.000 gambar = 1,6 GB > free tier Neon 0,5 GB). `karya.image_filename` = nama file
dataset v1; `karya.image_key` = kunci objek di R2, **NULL sampai gambarnya diunggah**. R2 belum dikonfigurasi di repo
(tak ada bucket/key) — **kini sudah dikonfigurasi dan terunggah**. Cara awal: bucket + token dibuat (CLAUDE.md root, "Checklist setup bucket sungguhan") dan 4 variabel
`R2_*` diisi di `backend/.env`:

```powershell
python scripts/upload_gambar_r2.py --dry-run   # cek: 2000 gambar, 1606 MB
python scripts/upload_gambar_r2.py             # unggah ke katalog-dummy/<file>, lalu isi image_key
```
Aman diulang (objek yang sudah ada dilewati). Setelah `--reset`, jalankan lagi untuk mengisi ulang `image_key`.

**Peringatan `r2.dev` di Indonesia (terverifikasi 2026-10-05):** DNS provider internet Thoriq menjawab `*.r2.dev` dengan IP
non-Cloudflare (`36.86.63.185`, sertifikat tidak cocok), sedangkan DNS 1.1.1.1/8.8.8.8 menjawab IP Cloudflare asli dan bucket
merespons normal (`404` utk objek yg belum ada). Artinya URL `r2.dev` kemungkinan **tidak terbuka di sebagian provider
Indonesia** (dev: ganti DNS Windows ke 1.1.1.1/8.8.8.8 atau pakai VPN; HP di jaringan yang sama ikut terdampak). `r2.dev` juga
dibatasi lajunya & bukan utk produksi, jadi **utk rilis Play Store wajib custom domain** (mis. `img.<domain-galeria>` di Cloudflare).

## Sifat data yang perlu diketahui (jujur)

* **Cuma 23 seniman.** Subset v1 (shard 0–4 WikiArt) berasal dari 23 pelukis bernama; sisi penjual terbatas itu.
  Pelukisnya tokoh sungguhan karena gambarnya milik mereka — riwayat penjualannya fiktif.
* **Sinyal klasifikasi** (audit `cek_sinyal_data.py`, model GBM sederhana, generator-v2): AUC ≈ 0,89–0,93, HitRate@1 ≈ 0,77–0,78
  (acak 0,20). Jauh lebih tinggi dari generator lama (0,46–0,50) karena perilaku kolektor kini konsisten — itu bukti generator terbaca model, **bukan** performa nyata.
* **Clustering (generator-v2) terpisah rapi karena dirancang begitu**: silhouette 0,649, ARI vs segmen asli 0,965. Pakai `StandardScaler` pada log-harga dan hanya 5 fitur perilaku; selera aliran sengaja tidak jadi fitur klaster (berisik).
  Plafon (silhouette label asli) 0,643 — skor dibatasi kerapatan data, bukan algoritma.
* Negatif klasifikasi dipilih seragam acak dari karya yang tersedia (asumsi; tak ada data "dilihat tapi tak dibeli").
* Komisi 10% dan pengali harga per aliran adalah asumsi buatan, bukan keputusan bisnis.
* Gambar WikiArt berlisensi riset non-komersial — aman utk pengembangan, **bukan** utk katalog rilis Play Store.

## Kontrak antar-bagian (sumber kebenaran — jangan diubah sepihak, kabari Thoriq)

```
(1) Thoriq: data dummy generator-v2 ──> (2) Thoriq: CLUSTERING (UMAP + HDBSCAN) ──┬─> model FINAL ──> tabel `kolektor_segmen` ──┬─> Aulya: dashboard ("Siapa Pembelimu")
                                                                                    │                                          └─> Vika : label segmen (opsional)
                                                                                    └─> model CUTOFF ──> fitur `kolektor_segmen` di CSV klasifikasi
(3) Genda: KLASIFIKASI pembelian (memakai fitur segmen) ──> tabel `rekomendasi_kolektor` ──> Vika: katalog + rekomendasi (backend + Flutter)
                                        Aulya: dashboard seniman (backend + Flutter) — sebagian besar tidak menunggu model
```

**Waktu acuan.** "Sekarang" di dunia dummy = akhir data: `2026-09-30T23:59:59Z` (`src/generate.py: WINDOW_END`).
Karya *tersedia* = ada di `karya` dan belum ada di `transaksi`. Semua perhitungan hasil memakai waktu ini kecuali `--waktu` diberikan.

**Schema.** Semua tabel di schema `dummy_rekomendasi` (backend membacanya dari env `REKOMENDASI_SCHEMA`, default itu, supaya nanti bisa
dialihkan ke tabel produksi tanpa mengubah kode). Env backend yang dipakai bersama: `REKOMENDASI_SCHEMA` (default `dummy_rekomendasi`), `REKOMENDASI_WAKTU_ACUAN` (default `2026-09-30T23:59:59Z`; semua jendela "N hari terakhir" dihitung mundur dari sini, **bukan** `now()`), `R2_PUBLIC_URL_BASE`. Jangan menulis ke `public.*`. Tabel `public.karya`/`/api/katalog` (8 karya Visual Search) tidak berubah.

| Tabel | Pemilik | Isi |
|---|---|---|
| `seniman`, `kolektor`, `karya`, `transaksi`, view `v_seniman_metrik_bulanan` | Thoriq (sudah terisi) | data dasar, lihat `data/training/KAMUS_DATA.md` |
| `kolektor_label_asli` | Thoriq | segmen buatan generator — **hanya utk validasi clustering, dilarang dipakai di aplikasi/fitur** |
| `segmen_kamus` | Thoriq (5 baris, dari `hitung_segmen.py`) | `segmen_id, segmen_nama, deskripsi, ukuran, aliran_favorit, profil JSONB, model_version, dihitung_pada` — teks penjelasan segmen untuk UI |
| `kolektor_segmen` | **Thoriq mengisi** (200 baris, `clustering-v2`, 5 segmen: Kolektor Premium · Kolektor Aktif Bernilai Tinggi · Pemburu Tren · Kolektor Menengah Rutin · Pemula Hemat; nama dibuat otomatis dari centroid) | `kolektor_id, segmen_id, segmen_nama, model_version, dihitung_pada` (1 baris per kolektor) |
| `rekomendasi_kolektor` | **Genda mengisi** (klasifikasi) | `kolektor_id, karya_id, peringkat (1..20), skor (0-1), alasan (JSONB list kode), strategi, model_version, dihitung_pada` |

`strategi`: `model` (kolektor punya riwayat beli) atau `cold_start` (belum pernah beli → peringkat berdasarkan keramaian/tren, bukan model personal).
`model_version`: mis. `klasifikasi-v2`, `clustering-v2` (naik versi tiap training ulang; baris lama diganti, bukan ditumpuk). Klasifikasi pada data generator-v2 sebaiknya diberi versi baru (`klasifikasi-v2`).

**Kode `alasan` (kosakata tetap; teks Indonesia dibuat di backend, ambang batas final oleh Genda):**

| Kode | Teks | Kira-kira muncul bila |
|---|---|---|
| `gaya_favorit` | Sesuai aliran favoritmu: {aliran} | `match_porsi_gaya_ini` ≥ 0,25 |
| `harga_sesuai` | Harga sesuai kebiasaan belanjamu | `match_harga_dalam_rentang` = 1 dan rasio harga 0,6–1,6 |
| `seniman_naik_daun` | Penjualan seniman ini sedang naik | `seniman_lonjakan_30hari` ≥ 1,5 |
| `gaya_ramai` | Aliran ini sedang ramai | `gaya_porsi_penjualan_30hari` jauh di atas rata-rata |
| `pernah_beli_seniman` | Kamu pernah membeli dari seniman ini | `match_n_beli_seniman_ini` ≥ 1 |
| `karya_baru` | Baru terpasang | `karya_umur_listing_hari` ≤ 14 |
| `populer_umum` | Sedang diminati kolektor lain | khusus `cold_start` |

**Gambar.** `karya.image_key` = kunci objek di Cloudflare R2 (NULL = belum diunggah). URL publik = `R2_PUBLIC_URL_BASE` + `/` + `image_key`
(dibangun di **backend**, dikirim ke app sebagai `image_url`, `null` bila `image_key` kosong). Catatan jaringan: `r2.dev` bisa terblokir DNS sebagian
provider Indonesia — saat dev ganti DNS ke 1.1.1.1/8.8.8.8 atau pakai data seluler; rilis wajib custom domain.

**API (dibuat Vika & Aul; semua JSON berbahasa Indonesia untuk label, uang = integer Rupiah, rasio = persen):**

| Endpoint | Pemilik | Fungsi |
|---|---|---|
| `GET /api/rekomendasi/demo-kolektor` | Vika | daftar ±5 kolektor contoh (id, nama, segmen) — pengganti login sampai Auth jadi |
| `GET /api/rekomendasi/{kolektor_id}?top_k=10` | Vika | rekomendasi (bentuk respons di bawah) |
| `GET /api/katalog-dummy?page&page_size&gaya&harga_min&harga_maks&q&urut&hanya_tersedia` | Vika | katalog 2.000 karya dummy; bentuk respons = `KatalogPage` yang sudah ada |
| `GET /api/dashboard/demo-seniman` | Aul | daftar seniman contoh — pengganti login |
| `GET /api/dashboard/seniman/{id}/ringkasan?periode=30` | Aul | KPI periode (30/90/365 hari) + perubahan vs periode sebelumnya |
| `GET /api/dashboard/seniman/{id}/penjualan-bulanan?bulan=12` | Aul | deret bulanan dari `v_seniman_metrik_bulanan` |
| `GET /api/dashboard/seniman/{id}/aliran` | Aul | penjualan per aliran + perbandingan harga rata-rata vs pasar |
| `GET /api/dashboard/seniman/{id}/segmen-pembeli` | Aul | sebaran segmen kolektor yang membeli (butuh `kolektor_segmen`) |
| `GET /api/dashboard/pasar/tren` | Aul | seniman & aliran yang sedang ramai |

Bentuk respons rekomendasi (Vika wajib mengikuti persis supaya `Karya.fromJson` yang sudah ada tidak crash — field `gallery_name` **non-null** di Flutter):
```json
{
  "kolektor_id": "uuid", "strategi": "model", "model_version": "klasifikasi-v1",
  "dihitung_pada": "2026-09-30T23:59:59Z",
  "segmen": {"id": 2, "nama": "Kolektor Aktif Bernilai Tinggi"},
  "items": [{
    "peringkat": 1, "skor": 0.8123,
    "alasan": [{"kode": "gaya_favorit", "teks": "Sesuai aliran favoritmu: Impressionism"}],
    "karya": {"id": "uuid", "title": "Tanpa Judul (Impressionism)", "artist_name": "Claude Monet",
              "style_name": "Impressionism", "gallery_name": "Studio Claude Monet", "price_idr": 65000000,
              "is_promoted": false, "image_filename": "wikiart_01234.jpg",
              "image_url": "https://pub-xxxx.r2.dev/katalog-dummy/wikiart_01234.jpg",
              "seniman_id": "uuid", "lebar_cm": 70.5, "tinggi_cm": 55.0}
  }]
}
```
`gallery_name` utk karya dummy diisi `"Studio " + nama seniman`, `is_promoted` selalu `false`. `skor` hanya dipakai utk mengurutkan — **bukan** peluang beli sesungguhnya.

**Aturan lintas-bagian:** (1) semua teks UI & label API Bahasa Indonesia; (2) fitur "Estimasi Harga Jual" sudah di-DROP dari scope — dashboard & rekomendasi hanya
statistik/peringkat, **jangan** membuat prediksi/saran harga; (3) data ini SINTETIS — beri label "data contoh" di UI demo dan jangan mengklaim performa nyata;
(4) kerja di branch masing-masing, commit tanpa baris `Co-Authored-By` (agar Claude tidak tercatat sebagai kontributor GitHub), jangan commit `.env`/`.venv`;
(5) kontrak di atas berubah → ubah README ini dalam PR yang sama dan kabari yang lain.

## Bentuk respons dashboard seniman (Aulya — `backend/routers/dashboard_seniman.py`)
Statistik deskriptif atas data dummy; jendela waktu dihitung dari `REKOMENDASI_WAKTU_ACUAN`, bukan `now()`. Uang = integer Rupiah, persen = angka biasa (`12.5`), `null` bila pembagi 0.
`seniman_id` bukan UUID / tidak ada → 404.

| Endpoint | Isi |
|---|---|
| `GET /api/dashboard/demo-seniman` | `[{"id","display_name","level_reputasi","n_terjual"}]`, urut terbanyak terjual |
| `GET /api/dashboard/seniman/{id}/ringkasan?periode=30\|90\|365` | lihat contoh di bawah; `periode` lain → 422 |
| `GET /api/dashboard/seniman/{id}/penjualan-bulanan?bulan=12` | deret LENGKAP N bulan (bulan kosong = 0): `[{"bulan":"2026-09-01","n_terjual","omzet_idr","harga_rata2_idr","n_pembeli_unik","gaya_terlaris"\|null}]` |
| `GET /api/dashboard/seniman/{id}/aliran` | `[{"style_name","n_terjual","omzet_idr","harga_rata2_idr","harga_pasar_rata2_idr","selisih_pct"}]`, urut `n_terjual` turun |
| `GET /api/dashboard/seniman/{id}/segmen-pembeli` | `{"tersedia":true,"items":[{"segmen_id","segmen_nama","n_pembeli","porsi_pct","deskripsi"}]}`; tabel `kolektor_segmen` kosong → `{"tersedia":false,"items":[]}` |
| `GET /api/dashboard/pasar/tren` | `{"seniman_ramai":[{"seniman_id","display_name","n_terjual_30hari","lonjakan","harga_rata2_30hari_idr"}],"aliran_ramai":[{"style_name","n_terjual_30hari","porsi_penjualan_pct","harga_rata2_30hari_idr"}]}` |

```json
// ringkasan
{ "seniman": {"id": "uuid", "display_name": "Vincent Van Gogh", "level_reputasi": "mapan"},
  "periode_hari": 30, "n_terjual": 9, "omzet_idr": 1201300000, "komisi_platform_idr": 120130000,
  "pendapatan_bersih_idr": 1081170000, "harga_rata2_idr": 133477778, "n_pembeli_unik": 9,
  "karya_tersedia": 17, "karya_terjual_total": 204,
  "perubahan_pct": {"n_terjual": -40.0, "omzet_idr": -40.1} }
```
`perubahan_pct` = periode ini vs periode sama persis sebelumnya (`null` bila periode sebelumnya kosong; data dummy mulai 2024-11, jadi periode 365 hari bisa bernilai ratusan persen). `lonjakan = (n30+1) / ((n90-n30)/2 + 1)` — rumus yang sama dengan fitur model.
`seniman_ramai` = 10 teratas (urut `n_terjual_30hari`, lalu `lonjakan`). Mobile: `mobile/lib/services/dashboard_service.dart`; seniman demo = seniman pertama dari `demo-seniman` (override `--dart-define=DEMO_SENIMAN_ID=<uuid>`).

## Versi lingkungan & portabilitas artefak
Artefak `models/clustering_kolektor*.joblib` hanya berisi scaler + `KNeighborsClassifier` (scikit-learn) dan tipe bawaan -- **tanpa objek UMAP/HDBSCAN/numba**, jadi bisa dimuat di environment lain
(versi awal memuat objek numba dan gagal: `TypeError: code expected at most 16 arguments`). `umap-learn`/`hdbscan` hanya dibutuhkan untuk **melatih ulang**.
Lingkungan tempat artefak dibuat (kunci lengkap di `requirements-lock.txt`): Python 3.11.8 · scikit-learn 1.9.1 · numpy 2.4.6 · pandas 3.0.6 · umap-learn 0.5.12 · numba 0.68.0.
Untuk reproduksi persis: `pip install -r requirements-lock.txt`. Bila memakai versi scikit-learn lain dan `joblib.load` mengeluh, jalankan ulang `python jalankan_pipeline.py --dry-run` (deterministik).

## Urutan menjalankan (clustering dulu, lalu klasifikasi)
```powershell
pip install -r requirements.txt                  # termasuk umap-learn & hdbscan (clustering-v2)
python jalankan_pipeline.py --dry-run            # tanpa database: generate -> CLUSTERING (2 model + laporan) -> CSV klasifikasi/clustering
python scripts/uji_paritas_fitur.py              # fitur_pasangan() == CSV (butuh models/clustering_kolektor_cutoff.joblib)
python scripts/cek_sinyal_data.py                # audit kebocoran + sanity sinyal klasifikasi + sanity clustering
python scripts/hitung_segmen.py --dari-csv       # segmen + kamus -> data/hasil/*.csv (tanpa DB); tanpa --dari-csv membaca Neon
# ke Neon (butuh persetujuan; menimpa isi schema dummy_rekomendasi):
python jalankan_pipeline.py --reset ; python scripts/hitung_segmen.py ; python scripts/upload_gambar_r2.py
```
`jalankan_pipeline.py` memanggil `scripts/latih_clustering.py` (melatih model final + cutoff, menulis `models/` dan `LAPORAN_CLUSTERING.md`) SEBELUM membangun CSV klasifikasi.
Deterministik: dua kali jalan menghasilkan semua CSV identik (diverifikasi). Model yang dipakai fitur `kolektor_segmen` adalah model **cutoff** (hanya melihat data sampai batas train), bukan model final.

## Belum dikerjakan
Isi ulang Neon dengan data generator-v2 (menunggu persetujuan Thoriq) · model klasifikasi pada data baru (`genda.md`, Genda) · katalog + rekomendasi di backend & Flutter (`vika.md`) ·
dashboard seniman (`aulya.md`; endpoint segmen sudah ada, hanya angka yang berubah) · embedding Visual Search per karya (bisa di-join lewat `image_filename`).

## Catatan reprodusibilitas (pelajaran 2026-10-05)
`SELECT *` tanpa `ORDER BY` tidak menjamin urutan baris, dan urutan fisik Postgres **berubah setelah `UPDATE`** (mis. mengisi `image_key`). Pemilihan karya negatif di
`features.bangun_klasifikasi` memakai posisi baris, sehingga setelah unggahan R2 **seluruh negatif berubah** padahal datanya sama. Perbaikan: `src/urutan.py` memulihkan urutan
pembuatan generator dari id (`uuid5`) dan dipakai oleh `db.baca` serta `features._Konteks`. Terbukti: `klasifikasi_pembelian.csv` hasil pipeline **identik byte-per-byte** dengan versi
yang sudah dibagikan ke tim, dan tetap identik walau urutan baris masukan diacak. Jangan menghapus pengurutan itu.
