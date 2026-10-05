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
| `jalankan_pipeline.py` | Generate → isi Neon → baca ulang → CSV |
| `scripts/` | `siapkan_pool_gambar.py`, `upload_gambar_r2.py`, `cek_sinyal_data.py` |

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

## Gambar → Cloudflare R2 (BELUM aktif)

Gambar **tidak** disimpan di Neon (2.000 gambar = 1,6 GB > free tier Neon 0,5 GB). `karya.image_filename` = nama file
dataset v1; `karya.image_key` = kunci objek di R2, **NULL sampai gambarnya diunggah**. R2 belum dikonfigurasi di repo
(tak ada bucket/key). Setelah bucket + token dibuat (CLAUDE.md root, "Checklist setup bucket sungguhan") dan 4 variabel
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

## Belum dikerjakan
Unggah ke R2 (menunggu bucket & kunci) · model klasifikasi & clustering · endpoint rekomendasi di backend ·
dashboard seniman di mobile · embedding Visual Search per karya (bisa di-join lewat `image_filename`
ke `ml-visual-search/data/cache/v1_11class_backup/catalog_embeddings.npz`).
