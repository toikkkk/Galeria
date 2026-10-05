# Laporan Clustering Kolektor — `clustering-v1`

> **DATA SINTETIS.** Segmen di sini menggambarkan struktur yang kita tanam di `src/generate.py`, **bukan** perilaku kolektor nyata.
> Dibuat otomatis oleh `scripts/latih_clustering.py` (seed 42); semua angka dihitung dari data, bukan diketik tangan.

## Ringkasan
* **K = 5** (dipilih otomatis), algoritma K-Means, 19 fitur perilaku, 200 kolektor.
* Silhouette **0.178** (rendah: batas antar segmen **tidak tegas**), stabilitas bootstrap **0.70**, stabilitas antar seed inisialisasi **0.95** (ARI rata-rata 7 seed).
* Validasi terhadap label asli generator (dilakukan **setelah** K dipilih): **ARI 0.356**, **NMI 0.497**.

## 1. Keputusan fitur
11 kolom `porsi_gaya_<aliran>` **dikeluarkan** dari fitur klaster agar segmen mewakili *perilaku belanja* (anggaran, frekuensi, keterpusatan selera,
minat pada seniman besar/tren), bukan "penggemar aliran X". Kolom itu tetap dipakai untuk profil (aliran terbanyak). Transformasi: `log1p` pada kolom `*_idr`
dan hitungan/durasi, lalu `StandardScaler` (`RobustScaler` memperbesar outlier harga dan menghasilkan klaster kecil berisi outlier).

| kumpulan fitur | K | silhouette | stabilitas | Davies-Bouldin |
|---|---|---|---|---|
| A: semua fitur (30) | 3 | 0.166 | 0.93 ± 0.05 | 1.853 |
| A: semua fitur (30) | 4 | 0.138 | 0.70 ± 0.09 | 2.175 |
| A: semua fitur (30) | 5 | 0.123 | 0.58 ± 0.09 | 2.336 |
| A: semua fitur (30) | 6 | 0.105 | 0.52 ± 0.08 | 2.189 |
| B: perilaku (tanpa porsi aliran) (19) | 3 | 0.246 | 0.89 ± 0.07 | 1.429 |
| B: perilaku (tanpa porsi aliran) (19) | 4 | 0.193 | 0.73 ± 0.13 | 1.666 |
| B: perilaku (tanpa porsi aliran) (19) | 5 | 0.178 | 0.70 ± 0.12 | 1.731 |
| B: perilaku (tanpa porsi aliran) (19) | 6 | 0.170 | 0.64 ± 0.11 | 1.736 |

Kumpulan B lebih baik di semua K pada semua kriteria tanpa label.

## 2. Pemilihan K
Aturan yang ditetapkan **sebelum** melihat label asli: *di antara K yang stabil (ARI bootstrap ≥ 0.70), pilih BIC GMM terendah.*

| K | silhouette | Calinski-Harabasz | Davies-Bouldin | BIC GMM | stabilitas (ARI bootstrap ± sd) | layak (stabil >= 0,70) | terpilih |
|---|---|---|---|---|---|---|---|
| 2 | 0.268 | 75.5 | 1.386 | 8801 | 0.95 ± 0.14 | ya |  |
| 3 | 0.246 | 74.5 | 1.429 | 7430 | 0.89 ± 0.07 | ya |  |
| 4 | 0.193 | 61.5 | 1.666 | 7348 | 0.73 ± 0.13 | ya |  |
| 5 | 0.178 | 54.4 | 1.731 | 6946 | 0.70 ± 0.12 | ya | <-- |
| 6 | 0.170 | 49.4 | 1.736 | 6926 | 0.64 ± 0.11 | tidak |  |
| 7 | 0.174 | 45.4 | 1.530 | 7104 | 0.61 ± 0.11 | tidak |  |
| 8 | 0.171 | 41.6 | 1.481 | 6791 | 0.56 ± 0.08 | tidak |  |

## 3. Profil segmen
| id | nama | ukuran | pembelian (median) | harga rata-rata | beli/bulan | porsi aliran teratas | dari seniman mapan | dari seniman pemula | aliran terbanyak |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Kolektor Premium | 38 | 3 | Rp145 jt | 0.25 | 0.67 | 1.00 | 0.00 | Impressionism |
| 2 | Kolektor Menengah Aktif | 52 | 11 | Rp52 jt | 0.80 | 0.38 | 0.30 | 0.14 | Impressionism |
| 3 | Spesialis Aliran | 49 | 6 | Rp50 jt | 0.39 | 0.60 | 0.33 | 0.00 | Impressionism |
| 4 | Pemburu Karya Terjangkau | 34 | 6 | Rp10 jt | 0.42 | 0.40 | 0.00 | 0.68 | Impressionism |
| 5 | Pemula Hemat | 27 | 3 | Rp7 jt | 0.15 | 0.67 | 0.00 | 0.75 | Realism |

Nama diturunkan dari karakteristik centroid dengan aturan di `src/clustering.py: beri_nama` (tingkat harga → frekuensi/keterpusatan selera), **bukan** dari label generator.

**1. Kolektor Premium** — 38 kolektor (19%). Median 3 pembelian, harga rata-rata sekitar Rp145 jt, 0.25 pembelian/bulan. Selera terpusat pada sedikit aliran (aliran terbanyak: Impressionism); paling sering membeli dari seniman mapan.

**2. Kolektor Menengah Aktif** — 52 kolektor (26%). Median 11 pembelian, harga rata-rata sekitar Rp52 jt, 0.80 pembelian/bulan. Selera beragam antar aliran (aliran terbanyak: Impressionism); paling sering membeli dari seniman menengah.

**3. Spesialis Aliran** — 49 kolektor (24%). Median 6 pembelian, harga rata-rata sekitar Rp50 jt, 0.39 pembelian/bulan. Selera terpusat pada sedikit aliran (aliran terbanyak: Impressionism); paling sering membeli dari seniman menengah.

**4. Pemburu Karya Terjangkau** — 34 kolektor (17%). Median 6 pembelian, harga rata-rata sekitar Rp10 jt, 0.42 pembelian/bulan. Selera beragam antar aliran (aliran terbanyak: Impressionism); paling sering membeli dari seniman pemula.

**5. Pemula Hemat** — 27 kolektor (14%). Median 3 pembelian, harga rata-rata sekitar Rp7 jt, 0.15 pembelian/bulan. Selera terpusat pada sedikit aliran (aliran terbanyak: Realism); paling sering membeli dari seniman pemula.

## 4. Validasi terhadap label asli (hanya setelah K final)
ARI = **0.356**, NMI = **0.497**. Tabel silang (baris = segmen hasil clustering, kolom = segmen asli generator):

| segmen hasil clustering | menengah_aktif | pemula_hemat | pengikut_tren | premium_selektif | spesialis_aliran |
|---|---|---|---|---|---|
| 1. Kolektor Premium | 5 | 0 | 1 | 25 | 7 |
| 2. Kolektor Menengah Aktif | 28 | 0 | 21 | 0 | 3 |
| 3. Spesialis Aliran | 25 | 0 | 7 | 0 | 17 |
| 4. Pemburu Karya Terjangkau | 2 | 31 | 1 | 0 | 0 |
| 5. Pemula Hemat | 1 | 24 | 2 | 0 | 0 |

Ke mana tiap segmen asli pergi:
* `menengah_aktif` (61 kolektor): tersebar (terbesar hanya 46% di 'Kolektor Menengah Aktif').
* `pemula_hemat` (55 kolektor): tersebar (terbesar hanya 56% di 'Pemburu Karya Terjangkau').
* `pengikut_tren` (32 kolektor): 66% masuk 'Kolektor Menengah Aktif'.
* `premium_selektif` (25 kolektor): 100% masuk 'Kolektor Premium'.
* `spesialis_aliran` (27 kolektor): 63% masuk 'Spesialis Aliran'.

## 5. Skor evaluasi lengkap (model akhir)
| metrik | skor | catatan |
|---|---|---|
| Silhouette (rata-rata) | 0.178 | tidak ada struktur klaster yang berarti |
| Sampel dgn silhouette negatif | 4.5% | negatif = kemungkinan salah klaster |
| Davies-Bouldin (makin rendah makin baik) | 1.731 | pedoman kasar: <1 baik, 1-2 sedang, >2 kurang |
| Calinski-Harabasz | 54.4 | tak punya skala absolut |
| Inertia | 1796.4 | tak punya skala absolut |
| Jarak dua pusat klaster terdekat | 3.01 | satuan z-score |
| Stabilitas bootstrap (ARI) | 0.702 | ambang >= 0.7 |
| Stabilitas antar seed (ARI) | 0.945 | 1 = identik |
| ARI vs label asli* | 0.356 | 0 = acak, 1 = identik |
| NMI* | 0.497 |  |
| Homogenitas* | 0.504 |  |
| Kelengkapan* | 0.491 |  |
| V-measure* | 0.497 |  |
| Purity* | 0.665 |  |

\* eksternal = hanya validasi terhadap label generator; tidak dipakai memilih K/fitur. Tafsir silhouette memakai skala Kaufman–Rousseeuw (> 0,70 kuat · 0,51–0,70 wajar · 0,26–0,50 lemah · ≤ 0,25 tidak ada struktur berarti).

Silhouette per segmen (segmen dengan nilai terendah = batasnya paling kabur):

| segmen | ukuran | silhouette | % sampel negatif |
|---|---|---|---|
| 1. Kolektor Premium | 38 | 0.196 | 3% |
| 2. Kolektor Menengah Aktif | 52 | 0.183 | 2% |
| 3. Spesialis Aliran | 49 | 0.148 | 0% |
| 4. Pemburu Karya Terjangkau | 34 | 0.263 | 0% |
| 5. Pemula Hemat | 27 | 0.092 | 26% |

## 6. Mengapa silhouette-nya rendah? (diagnosis)
Silhouette mengukur seberapa terpisah kelompok yang **memang ada di data**, bukan mutu pekerjaan. Pembanding:

| pembanding | silhouette |
|---|---|
| Label ASLI generator (plafon: jawaban benar) | 0.069 |
| Baseline TANPA struktur (Gaussian, K=5, 30 ulangan) | 0.138 ± 0.010 |
| K-Means model ini (K=5, 19 fitur) | 0.178 |
| [ilustrasi] K-Means K=3, semua fitur | 0.246 |
| [ilustrasi] K-Means K=2, semua fitur | 0.268 |
| [ilustrasi] K-Means K=5, hanya 4 fitur terkuat | 0.379 |

* **Plafon rendah:** label asli generator hanya 0.07 pada fitur yang sama — segmen yang ditanam saling tumpang tindih, jadi silhouette tinggi memang tidak mungkin dicapai.
* **Struktur ada tapi lemah:** model 0.18 vs data tanpa struktur 0.14 (selisih ±4.1 simpangan baku).
* **Data per orang berisik:** median 6 pembelian per kolektor; 47 dari 200 kolektor hanya ≤ 3 pembelian.
* Baris `[ilustrasi]` **bukan** dasar memilih model: memilih fitur/K demi menaikkan silhouette itu sirkular. Jangan melaporkan K=2/3 atau subset fitur hanya karena angkanya lebih tinggi.

## 7. Keterbatasan (jujur)
* Data **sintetis** dengan hanya 200 kolektor dan median ±6 pembelian per kolektor: fitur per kolektor berisik, sehingga batas segmen kabur (silhouette rendah).
* Kecocokan dengan label asli hanya **sebagian** (ARI 0.36). Segmen yang tumpang tindih di generator tidak akan terpisah hanya dari ukuran perilaku ini; dan satu segmen asli bisa terbelah menjadi beberapa klaster (mis. menurut frekuensi beli).
* **Keputusan K sensitif.** Stabilitas K = 4, 5 berada dalam ±0,03 dari ambang 0.70; dengan data/seed lain pilihan bisa bergeser satu K. Perlakukan jumlah segmen sebagai perkiraan, bukan angka pasti.
* Nama & deskripsi segmen adalah **ringkasan statistik**, bukan kategori yang pasti. Jangan menampilkannya di UI sebagai fakta tentang orang tertentu.
* Segmen dihitung dari **seluruh riwayat sampai akhir periode data**. Jangan dipakai sebagai fitur model klasifikasi (membocorkan masa depan).
* Melatih ulang pada data berbeda dapat mengubah jumlah, nama, dan isi segmen. Naikkan versi (`clustering-v2`) bila itu terjadi, dan jalankan ulang `scripts/hitung_segmen.py`.
