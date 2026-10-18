# Laporan Clustering Kolektor — `clustering-v2` (UMAP + HDBSCAN)

> **DATA SINTETIS YANG DIRANCANG TERPISAH.** Skor di sini mencerminkan struktur yang kita tanam di `src/generate.py` (generator-v2 membuat
> lima arketipe kolektor yang berbeda tegas, atas arahan dosen "sesuaikan data dengan algoritma"). Ini **bukan** bukti bahwa pembeli lukisan nyata
> terbagi serapi ini; pada data nyata silhouette akan lebih rendah. Dibuat otomatis oleh `scripts/latih_clustering.py` (seed 42).

## Ringkasan
* **Algoritma: UMAP + HDBSCAN** (menggantikan K-Means v1). Jumlah segmen **ditemukan** otomatis: **K = 5**. 200 kolektor, 5 fitur perilaku.
* **Silhouette = 0.649** (struktur klaster wajar; skala Kaufman–Rousseeuw: > 0,50 wajar, > 0,70 kuat), dihitung di **ruang fitur asli**, bukan ruang UMAP.
  Pembanding v1 (K-Means, data lama): 0,18.
* Stabilitas bootstrap **0.99**, noise **0.0%**, ARI terhadap label asli **0.965** (validasi setelah model final).
* Silhouette label asli generator (plafon) = **0.643**: batas atas skor bergantung pada seberapa rapat data itu sendiri, bukan pada algoritma.

## 1. Mengapa bukan K-Means, dan perbandingan algoritma
K-Means (1957) memaksa jumlah klaster ditebak di awal dan mengasumsikan klaster berbentuk bola berukuran serupa. Dipilih **UMAP + HDBSCAN** karena: (a) K ditemukan dari kepadatan data,
(b) bentuk klaster bebas dan outlier ditandai noise, (c) kolektor baru bisa ditetapkan tanpa melatih ulang (`umap.transform` + `hdbscan.approximate_predict`).

Perbandingan pada fitur yang sama (silhouette di ruang fitur asli):

| algoritma | K | noise | silhouette | ARI vs label asli* | bisa menetapkan kolektor baru | catatan |
|---|---|---|---|---|---|---|
| K-Means K=5 (acuan v1, tidak dipilih) | 5 | 0% | 0.649 | 0.976 | ya | K harus ditebak; klaster berbentuk bola |
| Gaussian Mixture K=5 | 5 | 0% | 0.256 | 0.595 | ya | K harus ditebak |
| Agglomerative (Ward) K=5 | 5 | 0% | 0.648 | 0.976 | tidak | tak punya fungsi predict |
| Spectral K=5 | 5 | 0% | 0.649 | 0.965 | tidak | tak punya fungsi predict |
| HDBSCAN (fitur asli) | 5 | 4% | 0.649 | 0.965 | ya (approximate_predict) | tanpa reduksi dimensi |
| **UMAP + HDBSCAN (dipakai)** | 5 | 0% | 0.649 | 0.965 | ya (transform + approximate_predict) | K ditemukan sendiri; model dilatih satu kali |

\* ARI vs label asli = hanya validasi. Aturan seleksi (ditetapkan sebelum melihat hasil): bukan K-Means · bisa menetapkan kolektor baru · noise ≤ 10% · silhouette tertinggi di ruang fitur asli.
**Catatan jujur:** pada data ini beberapa algoritma lain (mis. Spectral, GMM) juga menemukan struktur yang sama; selisih antar-algoritma kecil dibanding pengaruh data. Silhouette
UMAP+HDBSCAN **tidak** dibesar-besarkan dengan menghitungnya di ruang UMAP (skor di sana hampir selalu menggelembung).

## 2. Fitur dan transformasi
Lima fitur perilaku yang bersih: `harga_rata2_idr` (log1p), `frekuensi_beli_per_bulan` (log1p), `rata2_persentil_tren_saat_beli`, `porsi_beli_seniman_mapan`, `porsi_beli_seniman_pemula`; lalu `StandardScaler`.
**Keterpusatan selera aliran sengaja tidak dipakai memisahkan klaster:** dengan 6 pembelian per kolektor (median) nilainya hanya bisa 0,33/0,5/1,0 sehingga berisik.
Bukti pada data ini: menambahkan `porsi_gaya_teratas` menurunkan silhouette menjadi **0.464** (dari 0.649). Kolom `porsi_gaya_*` tetap dipakai utk profil segmen (aliran terbanyak) dan utk model klasifikasi.
Kolektor dengan < 3 pembelian diberi segmen "Belum Cukup Riwayat" (tidak dipaksa masuk klaster).

## 3. Pemilihan hiperparameter
Aturan (sebelum melihat label asli): noise ≤ 10% dan 3 ≤ K ≤ 8 → silhouette tertinggi; seri → noise lebih sedikit → `min_cluster_size` lebih besar.

| n_neighbors UMAP | min_cluster_size HDBSCAN | k | noise (%) | silhouette | terpilih |
|---|---|---|---|---|---|
| 10 | 5 | 5 | 0.0 | 0.649 |  |
| 10 | 8 | 5 | 0.0 | 0.649 |  |
| 10 | 10 | 5 | 0.0 | 0.649 |  |
| 10 | 15 | 5 | 0.0 | 0.649 | <-- |
| 15 | 5 | 5 | 0.0 | 0.649 |  |
| 15 | 8 | 5 | 0.0 | 0.649 |  |
| 15 | 10 | 5 | 0.0 | 0.649 |  |
| 15 | 15 | 5 | 0.0 | 0.649 |  |
| 25 | 5 | 5 | 0.0 | 0.649 |  |
| 25 | 8 | 5 | 0.0 | 0.649 |  |
| 25 | 10 | 5 | 0.0 | 0.649 |  |
| 25 | 15 | 5 | 0.0 | 0.649 |  |

## 4. Profil segmen
| id | nama | ukuran | pembelian (median) | harga rata-rata | beli/bulan | persentil tren | dari seniman mapan | dari seniman pemula | aliran terbanyak |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Kolektor Premium | 23 | 3 | Rp287 jt | 0.20 | 0.86 | 1.00 | 0.00 | Impressionism |
| 2 | Kolektor Aktif Bernilai Tinggi | 50 | 11 | Rp119 jt | 0.57 | 0.82 | 0.83 | 0.00 | Impressionism |
| 3 | Pemburu Tren | 31 | 14 | Rp44 jt | 0.72 | 0.73 | 0.23 | 0.00 | Impressionism |
| 4 | Kolektor Menengah Rutin | 56 | 5 | Rp18 jt | 0.30 | 0.63 | 0.00 | 0.00 | Realism |
| 5 | Pemula Hemat | 40 | 3 | Rp5 jt | 0.18 | 0.25 | 0.00 | 1.00 | Realism |

Nama diturunkan dari karakteristik centroid dengan aturan di `src/clustering.py: beri_nama`, **bukan** dari label generator.

**1. Kolektor Premium** — 23 kolektor (12%). Median 3 pembelian, harga rata-rata sekitar Rp287 jt, 0.20 pembelian/bulan; cenderung membeli seniman yang sedang ramai; paling sering membeli dari seniman mapan. Aliran terbanyak: Impressionism.

**2. Kolektor Aktif Bernilai Tinggi** — 50 kolektor (25%). Median 11 pembelian, harga rata-rata sekitar Rp119 jt, 0.57 pembelian/bulan; cenderung membeli seniman yang sedang ramai; paling sering membeli dari seniman mapan. Aliran terbanyak: Impressionism.

**3. Pemburu Tren** — 31 kolektor (16%). Median 14 pembelian, harga rata-rata sekitar Rp44 jt, 0.72 pembelian/bulan; cenderung membeli seniman yang sedang ramai; paling sering membeli dari seniman menengah. Aliran terbanyak: Impressionism.

**4. Kolektor Menengah Rutin** — 56 kolektor (28%). Median 5 pembelian, harga rata-rata sekitar Rp18 jt, 0.30 pembelian/bulan; tidak terlalu mengikuti tren; paling sering membeli dari seniman menengah. Aliran terbanyak: Realism.

**5. Pemula Hemat** — 40 kolektor (20%). Median 3 pembelian, harga rata-rata sekitar Rp5 jt, 0.18 pembelian/bulan; cenderung membeli seniman yang tidak sedang ramai; paling sering membeli dari seniman pemula. Aliran terbanyak: Realism.

## 5. Validasi terhadap label asli (hanya setelah model final)
ARI = **0.965**, NMI = **0.960**. Tabel silang (baris = segmen hasil, kolom = segmen asli generator):

| segmen hasil clustering | kakap_aktif | menengah_rutin | pemburu_tren | pemula_hemat | premium_mapan |
|---|---|---|---|---|---|
| 1. Kolektor Premium | 0 | 0 | 0 | 0 | 23 |
| 2. Kolektor Aktif Bernilai Tinggi | 48 | 0 | 2 | 0 | 0 |
| 3. Pemburu Tren | 1 | 0 | 30 | 0 | 0 |
| 4. Kolektor Menengah Rutin | 0 | 56 | 0 | 0 | 0 |
| 5. Pemula Hemat | 0 | 0 | 0 | 40 | 0 |

## 6. Skor evaluasi lengkap (model final)
| metrik | skor | catatan |
|---|---|---|
| Silhouette (ruang fitur asli, rata-rata) | 0.649 | struktur klaster wajar |
| Sampel dgn silhouette negatif | 0.0% | negatif = kemungkinan salah klaster |
| Davies-Bouldin (makin rendah makin baik) | 0.490 | pedoman kasar: <1 baik |
| Calinski-Harabasz | 706.6 | tak punya skala absolut |
| Stabilitas bootstrap (ARI, 80% subsampel) | 0.994 ± 0.014 | ambang baik >= 0.80 |
| Noise HDBSCAN saat pelatihan | 0.0% | titik noise ditetapkan ke klaster terdekat |
| Kesesuaian label latih vs penugasan out-of-sample | 1.000 | 1 = identik |
| Kepastian keanggotaan (median) | 1.00 | 0% bernilai 0 (noise) |
| ARI vs label asli* | 0.965 | 0 = acak, 1 = identik |
| NMI* | 0.960 |  |
| Homogenitas* | 0.959 |  |
| Kelengkapan* | 0.960 |  |
| V-measure* | 0.960 |  |
| Purity* | 0.985 |  |
| Silhouette label asli generator* (plafon) | 0.643 | silhouette bila jawaban benar dipakai |

\* eksternal = hanya validasi terhadap label generator; tidak dipakai memilih fitur/hiperparameter.

Silhouette per segmen (nilai terendah = batas paling kabur):

| segmen | ukuran | silhouette | % sampel negatif |
|---|---|---|---|
| 1. Kolektor Premium | 23 | 0.645 | 0% |
| 2. Kolektor Aktif Bernilai Tinggi | 50 | 0.575 | 0% |
| 3. Pemburu Tren | 31 | 0.597 | 0% |
| 4. Kolektor Menengah Rutin | 56 | 0.635 | 0% |
| 5. Pemula Hemat | 40 | 0.801 | 0% |

## 7. Model "cutoff" untuk klasifikasi (tanpa kebocoran)
Fitur `kolektor_segmen` di dataset klasifikasi harus dihitung dengan model yang **tidak pernah melihat val/test**. Karena itu dilatih model kedua dengan pipeline dan aturan seleksi yang sama,
hanya pada pembelian sebelum batas train (hari ke-595): 147 kolektor, konfigurasi 25/15, silhouette 0.504,
segmen yang ditemukan: Kolektor Aktif Bernilai Tinggi (61), Pemburu Tren (25), Kolektor Menengah Rutin (46), Pemula Hemat (15)
(BERBEDA dari model final: riwayat tren seniman di periode awal masih tipis sehingga beberapa arketipe belum terpisah; nilai kategori `kolektor_segmen` mengikuti model ini). Model final (di atas) dipakai utk dashboard dan tabel `kolektor_segmen`; **jangan** dipakai sebagai fitur klasifikasi.

## 8. Keterbatasan (jujur)
* **Data sintetis yang dirancang terpisah.** Silhouette tinggi di sini = hasil desain generator (arketipe berbeda tegas, tiap kolektor ≥ 3 pembelian), bukan temuan tentang perilaku nyata.
  Di data nyata, perilaku saling tumpang tindih dan skor akan jauh lebih rendah.
* Hanya 200 kolektor dan median 6 pembelian per kolektor; fitur berbasis hitungan kecil tetap berisik.
* **Fitur dipilih berdasarkan kebersihan sinyal** (lihat bagian 2) setelah percobaan pada data ini; ini disclosure, bukan klaim bahwa fitur lain "salah".
* Nama & deskripsi segmen adalah **ringkasan statistik**, bukan kategori pasti. Jangan menampilkannya di UI sebagai fakta tentang orang tertentu.
* Melatih ulang pada data lain dapat mengubah jumlah, nama, dan isi segmen; naikkan `VERSI` dan jalankan ulang `scripts/hitung_segmen.py`.
* Model memuat objek UMAP/HDBSCAN: butuh `umap-learn` dan `hdbscan` terpasang utk memuatnya. Backend tidak memuatnya (hanya membaca tabel).
