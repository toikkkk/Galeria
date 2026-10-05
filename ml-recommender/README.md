# ml-recommender — Data & dataset training sistem rekomendasi lukisan

> **Semua data transaksi di sini SINTETIS.** Gambar & aliran lukisan nyata (dataset Visual Search **v1**:
> 5.659 gambar, 11 kelas), tetapi kolektor, harga, dan riwayat pembelian dibangkitkan program.
> Model yang dilatih di sini mempelajari aturan buatan kita, **bukan** perilaku pembeli nyata. Jangan klaim
> skornya sebagai performa produksi.

## Isi folder

| Path | Isi |
|---|---|
| `data/training/klasifikasi_pembelian.csv` | Dataset **klasifikasi** (bagian Thoriq): 7.000 baris = 1.400 grup × (1 positif + 4 negatif), split berdasarkan waktu |
| `data/training/clustering_kolektor.csv` | Dataset **clustering** (bagian Genda): 200 kolektor × 30 fitur |
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
| `src/clustering.py` · `notebooks/02_clustering.ipynb` | **Clustering kolektor (Thoriq, SELESAI)**: logika inti + notebook proses |
| `models/clustering_kolektor.joblib` · `models/LAPORAN_CLUSTERING.md` | Artefak model & laporan (angka dihitung otomatis; membahas keterbatasan) |
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
* **Sinyal klasifikasi** (audit `cek_sinyal_data.py`, model GBM sederhana): AUC ≈ 0,79–0,80, HitRate@1 ≈ 0,46–0,50
  (acak 0,20). Artinya bisa dipelajari tapi tidak trivial. Itu cuma bukti generator terbaca model.
* **Clustering tidak terpisah sempurna**: ARI vs segmen asli ≈ 0,48 pada k=4 (0,31 pada k=5); segmen `premium_selektif`
  dan `spesialis_aliran` saling tumpang tindih. Pakai `StandardScaler` pada log-harga — `RobustScaler` justru membuat
  klaster kecil berisi outlier (ARI ≈ 0,18).
* Negatif klasifikasi dipilih seragam acak dari karya yang tersedia (asumsi; tak ada data "dilihat tapi tak dibeli").
* Komisi 10% dan pengali harga per aliran adalah asumsi buatan, bukan keputusan bisnis.
* Gambar WikiArt berlisensi riset non-komersial — aman utk pengembangan, **bukan** utk katalog rilis Play Store.

## Kontrak antar-bagian (sumber kebenaran — jangan diubah sepihak, kabari Thoriq)

```
Thoriq: data dummy + CSV (SELESAI) ──> Thoriq: CLUSTERING kolektor ──> tabel `kolektor_segmen`
   │                                                                          ├─> Aulya: dashboard seniman (bagian "Siapa Pembelimu")
   │                                                                          └─> Vika : label segmen (opsional) di rekomendasi
   └─> Genda: KLASIFIKASI pembelian ──> tabel `rekomendasi_kolektor` ──> Vika: katalog + rekomendasi (backend + Flutter)
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
| `kolektor_segmen` | **Thoriq mengisi — SUDAH TERISI** (200 baris, `clustering-v1`, 5 segmen: Kolektor Premium · Kolektor Menengah Aktif · Spesialis Aliran · Pemburu Karya Terjangkau · Pemula Hemat) | `kolektor_id, segmen_id, segmen_nama, model_version, dihitung_pada` (1 baris per kolektor) |
| `rekomendasi_kolektor` | **Genda mengisi** (klasifikasi) | `kolektor_id, karya_id, peringkat (1..20), skor (0-1), alasan (JSONB list kode), strategi, model_version, dihitung_pada` |

`strategi`: `model` (kolektor punya riwayat beli) atau `cold_start` (belum pernah beli → peringkat berdasarkan keramaian/tren, bukan model personal).
`model_version`: mis. `klasifikasi-v1`, `clustering-v1` (naik versi tiap training ulang; baris lama diganti, bukan ditumpuk).

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
  "segmen": {"id": 2, "nama": "Kolektor Menengah Aktif"},
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

## Belum dikerjakan
Unggah ke R2 (berjalan/selesai — lihat bagian R2) · model klasifikasi (`genda.md`, Genda) · katalog + rekomendasi di backend & Flutter (`vika.md`) ·
dashboard seniman (`aulya.md`) · embedding Visual Search per karya (bisa di-join lewat `image_filename`
ke `ml-visual-search/data/cache/v1_11class_backup/catalog_embeddings.npz`).

## Catatan reprodusibilitas (pelajaran 2026-10-05)
`SELECT *` tanpa `ORDER BY` tidak menjamin urutan baris, dan urutan fisik Postgres **berubah setelah `UPDATE`** (mis. mengisi `image_key`). Pemilihan karya negatif di
`features.bangun_klasifikasi` memakai posisi baris, sehingga setelah unggahan R2 **seluruh negatif berubah** padahal datanya sama. Perbaikan: `src/urutan.py` memulihkan urutan
pembuatan generator dari id (`uuid5`) dan dipakai oleh `db.baca` serta `features._Konteks`. Terbukti: `klasifikasi_pembelian.csv` hasil pipeline **identik byte-per-byte** dengan versi
yang sudah dibagikan ke tim, dan tetap identik walau urutan baris masukan diacak. Jangan menghapus pengurutan itu.
