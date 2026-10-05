# Kamus Data -- Sistem Rekomendasi Lukisan GALERIA

> **DATA SINTETIS.** Gambar & aliran lukisan nyata (dataset Visual Search v1: 5.659 gambar, 11 kelas),
> tetapi kolektor, harga, dan riwayat pembelian dibangkitkan program (`src/generate.py`, seed 42).
> Model yang dilatih di sini mempelajari aturan buatan kita, **bukan** perilaku pembeli nyata -- jangan
> mengklaim skornya sebagai performa produksi. File ini dibuat otomatis oleh `jalankan_pipeline.py`.

Parameter: 2000 karya, 1400 transaksi, 200 kolektor,
23 seniman, 4 negatif per pembelian.

## 1. `klasifikasi_pembelian.csv` -- 7000 baris (1400 positif)

Tugas: **untuk kolektor X pada waktu t, karya mana yang akan dibeli?** (klasifikasi biner `dibeli`,
dievaluasi sebagai ranking).

Aturan penting:
* **Jangan pakai kolom pengenal sbg fitur**: `grup_id`, `split`, `waktu`, `transaksi_id`, `kolektor_id`, `karya_id`, `seniman_id`.
* **Tanpa kebocoran waktu**: semua fitur riwayat dihitung dari kejadian SEBELUM `waktu`.
* **Pakai kolom `split`** (berdasarkan waktu), bukan acak -- acak akan membocorkan masa depan ke masa lalu.
* **Evaluasi ranking per `grup_id`** (HitRate@K, NDCG@K). 1 grup = 1 positif + 4 negatif, jadi tebakan acak
  HitRate@1 = 20%. Akurasi biasa menyesatkan.
* Negatif = karya lain yang masih tersedia saat itu, dipilih seragam acak (asumsi; tak ada data "dilihat tapi tak dibeli").
* Kategorikal: `karya_gaya`, `seniman_level_reputasi`. Kosong (NaN) berarti belum ada riwayat (mis. pembelian pertama kolektor) -- bukan error.

| Kolom | Arti |
|---|---|
| `grup_id` | Nomor grup. 1 grup = 1 pembelian nyata (1 baris dibeli=1) + karya lain yang masih tersedia saat itu (dibeli=0). Evaluasi ranking dilakukan DI DALAM grup. |
| `split` | train / val / test, berdasarkan WAKTU pembelian (70% / 15% / 15%). Satu grup tidak terpecah. |
| `waktu` | Waktu pembelian (UTC, ISO-8601) -- titik acuan 't' utk semua fitur 'sebelum t'. |
| `transaksi_id` | ID transaksi (UUID), hanya terisi utk baris positif. JANGAN dipakai sbg fitur. |
| `kolektor_id` | ID kolektor (UUID). Pengenal, BUKAN fitur. |
| `karya_id` | ID karya (UUID). Pengenal, BUKAN fitur. |
| `seniman_id` | ID seniman penjual karya (UUID). Pengenal, BUKAN fitur. |
| `dibeli` | TARGET. 1 = karya ini yang dibeli kolektor pada waktu t; 0 = karya lain yang tersedia tapi tidak dibeli. |
| `kolektor_n_beli_sebelumnya` | Jumlah pembelian kolektor SEBELUM t. 0 = pembelian pertama (fitur riwayat lain jadi kosong). |
| `kolektor_hari_sejak_bergabung` | Hari sejak kolektor bergabung sampai t. |
| `kolektor_hari_sejak_beli_terakhir` | Hari sejak pembelian terakhir kolektor sebelum t (kosong kalau belum pernah beli). |
| `kolektor_n_beli_90hari` | Jumlah pembelian kolektor dalam 90 hari sebelum t. |
| `kolektor_harga_rata2_idr` | Rata-rata harga final pembelian sebelumnya (Rp). |
| `kolektor_harga_median_idr` | Median harga final pembelian sebelumnya (Rp). |
| `kolektor_harga_min_idr` | Harga final terendah yang pernah dibeli (Rp). |
| `kolektor_harga_maks_idr` | Harga final tertinggi yang pernah dibeli (Rp). |
| `kolektor_harga_std_log` | Simpangan baku ln(harga) pembelian sebelumnya = seberapa lebar rentang harga yang biasa dibeli. 0 kalau baru 1 pembelian. |
| `kolektor_n_gaya_unik` | Jumlah aliran berbeda yang pernah dibeli. |
| `kolektor_porsi_gaya_teratas` | Porsi aliran favorit dari seluruh pembelian sebelumnya (1.0 = selalu aliran yang sama). |
| `karya_gaya` | Aliran (style) karya, 1 dari 11 kelas model Visual Search v1. Kategorikal. |
| `karya_harga_listing_idr` | Harga pasang karya (Rp). |
| `karya_log_harga` | ln(harga pasang). |
| `karya_luas_cm2` | Luas karya (lebar x tinggi, cm2). |
| `karya_umur_listing_hari` | Sudah berapa hari karya terpasang saat t. |
| `match_porsi_gaya_ini` | Porsi pembelian sebelumnya kolektor yang berupa aliran karya ini (0-1). |
| `match_pernah_beli_gaya_ini` | 1 kalau kolektor pernah membeli aliran ini sebelum t. |
| `match_n_beli_seniman_ini` | Berapa kali kolektor pernah membeli dari seniman ini (loyalitas). |
| `match_rasio_harga_vs_rata2` | Harga pasang / rata-rata harga beli kolektor. ~1 = sesuai kebiasaan. |
| `match_selisih_log_harga_vs_median` | ln(harga pasang) - ln(median harga beli kolektor). 0 = sesuai kebiasaan. |
| `match_harga_dalam_rentang` | 1 kalau harga pasang berada di antara harga beli terendah dan tertinggi kolektor. |
| `seniman_n_terjual_total` | Total karya seniman terjual sebelum t. |
| `seniman_n_terjual_30hari` | Karya seniman terjual dalam 30 hari sebelum t. |
| `seniman_n_terjual_90hari` | Karya seniman terjual dalam 90 hari sebelum t. |
| `seniman_harga_rata2_90hari_idr` | Rata-rata harga jual seniman dalam 90 hari sebelum t (Rp), kosong kalau tak ada penjualan. |
| `seniman_pertumbuhan_harga` | Rata-rata harga jual 90 hari terakhir / 90 hari sebelumnya. >1 = harga naik. Kosong kalau salah satu periode tak ada penjualan. |
| `seniman_momentum_30hari` | Penjualan 30 hari terakhir dikurangi rata-rata per-30-hari pada 60 hari sebelumnya. Positif = sedang naik. |
| `seniman_lonjakan_30hari` | Penjualan 30 hari terakhir relatif terhadap kebiasaan seniman itu sendiri: (n30+1)/(rata2 per-30-hari pada 60 hari sebelumnya+1). >1 = sedang melonjak. Beda dgn persentil: tidak ikut naik hanya karena seniman besar. |
| `seniman_persentil_tren_30hari` | Peringkat persentil (0-1) penjualan 30 hari seniman dibanding semua seniman. Dekat 1 = sedang paling ramai. |
| `seniman_n_karya_tersedia` | Jumlah karya seniman yang masih tersedia saat t. |
| `seniman_level_reputasi` | pemula / menengah / mapan. Kategorikal. |
| `gaya_n_terjual_30hari` | Penjualan aliran karya ini (semua seniman) dalam 30 hari sebelum t. |
| `gaya_porsi_penjualan_30hari` | Porsi aliran ini dari seluruh penjualan 30 hari sebelum t. |

## 2. `clustering_kolektor.csv` -- 200 baris (1 per kolektor)

Tugas: **segmentasi kolektor** (clustering, tanpa label). Snapshot di akhir periode data memakai seluruh riwayat.
Lakukan scaling yang robust (mis. `RobustScaler`) -- harga sangat condong ke kanan; pertimbangkan `log` utk kolom `*_idr`.
Tidak ada NaN. `kolektor_id` bukan fitur.

| Kolom | Arti |
|---|---|
| `kolektor_id` | ID kolektor (UUID). Pengenal, BUKAN fitur. |
| `n_pembelian` | Total pembelian kolektor. |
| `total_belanja_idr` | Total uang yang dibelanjakan (Rp). |
| `harga_rata2_idr` | Rata-rata harga final per pembelian (Rp). |
| `harga_median_idr` | Median harga final (Rp). |
| `harga_min_idr` | Harga final terendah (Rp). |
| `harga_maks_idr` | Harga final tertinggi (Rp). |
| `harga_std_log` | Simpangan baku ln(harga) = lebar rentang harga yang dibeli. |
| `hari_sejak_bergabung` | Hari sejak bergabung sampai akhir periode data. |
| `hari_sejak_beli_terakhir` | Recency: hari sejak pembelian terakhir sampai akhir periode data. |
| `frekuensi_beli_per_bulan` | Pembelian per bulan sejak bergabung (minimal pembagi 1 bulan). |
| `n_gaya_unik` | Jumlah aliran berbeda yang pernah dibeli. |
| `porsi_gaya_teratas` | Porsi aliran favorit (1.0 = hanya 1 aliran). |
| `entropi_gaya_norm` | Keberagaman aliran, entropi Shannon dinormalisasi 0-1 (0 = 1 aliran saja, 1 = merata di semua aliran). |
| `porsi_beli_seniman_mapan` | Porsi pembelian dari seniman level mapan. |
| `porsi_beli_seniman_menengah` | Porsi pembelian dari seniman level menengah. |
| `porsi_beli_seniman_pemula` | Porsi pembelian dari seniman level pemula. |
| `rata2_persentil_tren_saat_beli` | Rata-rata persentil tren (0-1) seniman pada SAAT dibeli. Tinggi = kolektor cenderung membeli dari seniman yang sedang ramai. |
| `rata2_lonjakan_saat_beli` | Rata-rata 'lonjakan' penjualan seniman pada SAAT dibeli (>1 = seniman sedang melonjak). Bebas dari ukuran seniman, jadi lebih bersih utk mendeteksi pengikut tren drpd persentil. |
| `rata2_diskon_negosiasi` | Rata-rata potongan harga final terhadap harga pasang (0-1). |
| `porsi_gaya_Art_Nouveau` | Porsi pembelian aliran Art Nouveau (0-1). kolom porsi_gaya_* berjumlah 1. |
| `porsi_gaya_Baroque` | Porsi pembelian aliran Baroque (0-1). kolom porsi_gaya_* berjumlah 1. |
| `porsi_gaya_Cubism` | Porsi pembelian aliran Cubism (0-1). kolom porsi_gaya_* berjumlah 1. |
| `porsi_gaya_Expressionism` | Porsi pembelian aliran Expressionism (0-1). kolom porsi_gaya_* berjumlah 1. |
| `porsi_gaya_Impressionism` | Porsi pembelian aliran Impressionism (0-1). kolom porsi_gaya_* berjumlah 1. |
| `porsi_gaya_Naive_Art_Primitivism` | Porsi pembelian aliran Naive Art Primitivism (0-1). kolom porsi_gaya_* berjumlah 1. |
| `porsi_gaya_Northern_Renaissance` | Porsi pembelian aliran Northern Renaissance (0-1). kolom porsi_gaya_* berjumlah 1. |
| `porsi_gaya_Post_Impressionism` | Porsi pembelian aliran Post Impressionism (0-1). kolom porsi_gaya_* berjumlah 1. |
| `porsi_gaya_Realism` | Porsi pembelian aliran Realism (0-1). kolom porsi_gaya_* berjumlah 1. |
| `porsi_gaya_Romanticism` | Porsi pembelian aliran Romanticism (0-1). kolom porsi_gaya_* berjumlah 1. |
| `porsi_gaya_Symbolism` | Porsi pembelian aliran Symbolism (0-1). kolom porsi_gaya_* berjumlah 1. |

### `kolektor_label_asli.csv` -- HANYA utk validasi
Segmen yang dipakai generator (`premium_selektif`, `menengah_aktif`, `pemula_hemat`, `spesialis_aliran`, `pengikut_tren`).
**Jangan dipakai sbg fitur atau target latihan.** Gunakan setelah clustering selesai utk membandingkan (mis. Adjusted Rand Index).
Di data nyata label ini tidak ada. Segmen ini hasil rancangan kita, jadi cocok/tidaknya dgn cluster hanya menunjukkan
generator terbaca model, bukan kebenaran tentang kolektor sungguhan.

## 3. `seniman_metrik_bulanan.csv` -- 363 baris

Isi dashboard seniman: penjualan per seniman per bulan. Berasal dari view `dummy_rekomendasi.v_seniman_metrik_bulanan`.

| Kolom | Arti |
|---|---|
| `seniman_id` | ID seniman (UUID). |
| `bulan` | Bulan (tanggal 1, UTC). |
| `n_terjual` | Jumlah karya terjual bulan itu. |
| `omzet_idr` | Total harga final (Rp). |
| `komisi_platform_idr` | Total komisi platform (Rp). |
| `pendapatan_bersih_idr` | Omzet dikurangi komisi (Rp). |
| `harga_rata2_idr` | Rata-rata harga jual (Rp). |
| `harga_maks_idr` | Harga jual tertinggi (Rp). |
| `n_pembeli_unik` | Jumlah kolektor berbeda yang membeli. |
| `gaya_terlaris` | Aliran paling banyak terjual bulan itu. |

## 4. `data/export/*.csv`

Salinan mentah 4 tabel dari Neon (`seniman`, `kolektor`, `karya`, `transaksi`) -- bahan feature engineering sendiri.
`karya.image_filename` = nama file gambar di `ml-visual-search/data/raw/` (dataset v1), jadi embedding Visual Search
(`ml-visual-search/data/cache/v1_11class_backup/catalog_embeddings.npz`) bisa di-join lewat nama file itu.
