# Laporan Model — Klasifikasi Pembelian (`klasifikasi-v2`)

> **Data SINTETIS** (`src/generate.py` generator-v2, seed 42). Angka di laporan ini menunjukkan
> "generator terbaca model", BUKAN performa produksi/dunia nyata. Hanya 23 seniman
> dan 200 kolektor -- model rawan overfit pada skala sekecil ini, tiap angka harus
> dibaca dengan kehati-hatian itu.

Dilatih: 2026-10-19T08:53:54.650096+00:00  |  Versi: `klasifikasi-v2`

## Perbandingan 5 metode

### VAL (dipakai untuk pemilihan hyperparameter & model)
|                        |   HitRate@1 |   HitRate@3 |    MRR |   NDCG@3 |    AUC |
|:-----------------------|------------:|------------:|-------:|---------:|-------:|
| acak                   |      0.2286 |      0.6    | 0.4752 |   0.438  | 0.5107 |
| populer                |      0.3857 |      0.8524 | 0.6156 |   0.6508 | 0.6604 |
| aturan_sederhana       |      0.7    |      0.9619 | 0.8297 |   0.8571 | 0.7765 |
| logistic_regression    |      0.7667 |      0.9714 | 0.8644 |   0.8871 | 0.926  |
| hist_gradient_boosting |      0.7857 |      0.981  | 0.8775 |   0.9008 | 0.9307 |

### TEST (disentuh SEKALI, setelah semua keputusan final dari VAL)
|                        |   HitRate@1 |   HitRate@3 |    MRR |   NDCG@3 |    AUC |
|:-----------------------|------------:|------------:|-------:|---------:|-------:|
| acak                   |      0.1857 |      0.581  | 0.4417 |   0.407  | 0.4917 |
| populer                |      0.4238 |      0.8048 | 0.6339 |   0.6442 | 0.6629 |
| aturan_sederhana       |      0.7143 |      0.9476 | 0.8266 |   0.8478 | 0.765  |
| logistic_regression    |      0.7476 |      0.9714 | 0.8556 |   0.8807 | 0.8992 |
| hist_gradient_boosting |      0.719  |      0.9762 | 0.8356 |   0.8676 | 0.8903 |

Baseline acak HitRate@1 teoritis = 0,20 (1 dari 5 kandidat/grup).

**Model terpilih:** `HistGradientBoostingClassifier` dengan hyperparameter `{'max_iter': 100, 'learning_rate': 0.1, 'max_depth': None}`
(dipilih berdasarkan NDCG@3 di VAL -- lihat tabel grid pencarian di notebook bagian 16).

**Mengalahkan baseline di TEST?** vs "populer" (HitRate@1): True.
vs "aturan_sederhana" (HitRate@1): True.

## Seberapa yakin hasil di atas? (bootstrap CI 95%, uji signifikansi berpasangan)

`val`/`test` masing-masing cuma 210 grup -- angka titik di atas BISA jadi kebetulan
sampel kecil. Bootstrap (2.000 resample per grup, TEST) dipakai utk cek ini:

| perbandingan                                  |   rata2_selisih |   ci_2.5% |   ci_97.5% |   p_dua_sisi |
|:----------------------------------------------|----------------:|----------:|-----------:|-------------:|
| aturan_sederhana vs hist_gradient_boosting    |         -0.0048 |   -0.0762 |     0.0667 |        0.95  |
| aturan_sederhana vs logistic_regression       |         -0.0339 |   -0.1    |     0.0286 |        0.343 |
| hist_gradient_boosting vs logistic_regression |         -0.0291 |   -0.0857 |     0.0238 |        0.342 |

(selisih = HitRate@1 metode pertama - kedua; CI 95% yang TIDAK melewati 0 berarti
beda itu nyata secara statistik, bukan noise sampel. `p_dua_sisi < 0,05` = sinyal yang sama.)

Lihat notebook bagian 19 untuk CI per-metode lengkap (HitRate@1/3, MRR, NDCG@3).

## Fitur penting (permutation importance, dihitung di VAL, scoring=AUC)
| fitur                             |   importansi_rata2 |         std |
|:----------------------------------|-------------------:|------------:|
| match_rasio_harga_vs_rata2        |        0.274091    | 0.0179325   |
| karya_harga_listing_idr           |        0.0215499   | 0.00416912  |
| match_selisih_log_harga_vs_median |        0.00748413  | 0.00237075  |
| seniman_harga_rata2_90hari_idr    |        0.00704592  | 0.0031284   |
| seniman_n_terjual_total           |        0.00649717  | 0.00144265  |
| seniman_persentil_tren_30hari     |        0.00437528  | 0.000920478 |
| karya_umur_listing_hari           |        0.00266383  | 0.000713428 |
| match_n_beli_seniman_ini          |        0.00237245  | 0.000994623 |
| karya_luas_cm2                    |        0.00205499  | 0.000622367 |
| kolektor_harga_rata2_idr          |        0.00185431  | 0.000876119 |
| kolektor_harga_min_idr            |        0.00157993  | 0.00081291  |
| karya_gaya                        |        0.0012398   | 0.00136082  |
| kolektor_hari_sejak_bergabung     |        0.00112528  | 0.000679555 |
| kolektor_harga_std_log            |        0.000818594 | 0.00055862  |
| seniman_level_reputasi            |        0.000736961 | 0.000358257 |

## Ablation kelompok fitur (val, NDCG@3)
| dibuang                      |   NDCG@3 |    selisih |
|:-----------------------------|---------:|-----------:|
| (tidak ada -- model lengkap) | 0.900791 |  0         |
| riwayat_kolektor             | 0.86893  | -0.0318605 |
| karya                        | 0.887639 | -0.0131517 |
| kecocokan_match              | 0.866947 | -0.0338439 |
| tren_seniman_gaya            | 0.877094 | -0.0236966 |

Fitur `seniman_lonjakan_30hari` secara khusus (pertanyaan `genda.md`): NDCG@3 model
lengkap = 0.9008, tanpa fitur ini = 0.8856
(selisih -0.0152).

## Ablasi `kolektor_segmen` (fitur dari clustering Thoriq, 3 seed berbeda)
|   seed |   NDCG@3_dengan_segmen |   NDCG@3_tanpa_segmen |   selisih |
|-------:|-----------------------:|----------------------:|----------:|
|      0 |               0.900791 |              0.886618 | 0.0141728 |
|      1 |               0.900791 |              0.886618 | 0.0141728 |
|      2 |               0.900791 |              0.886618 | 0.0141728 |

Rata-rata selisih NDCG@3 (dengan - tanpa `kolektor_segmen`): +0.0142
(std antar-seed: 0.0000). Fitur ini menambah nilai.

**Status `bundle["klaster_cutoff"]` (`genda.md` poin 6):** berhasil disertakan di `models/klasifikasi_rekomendasi.joblib`.

## Analisis kesalahan (val, HitRate@1 per kategori)
Lihat notebook bagian 22 untuk tabel per `seniman_level_reputasi`, `karya_gaya`,
`segmen_asli` (kolektor_label_asli.csv, HANYA dipakai di analisis ini, tidak pernah
sebagai fitur/target), dan **`kolektor_segmen`** (fitur model -- kategori `Belum Cukup
Riwayat` = kasus cold-start, yang di jalur produksi sebenarnya TIDAK lewat model ini,
lihat `genda.md` bagian 4). **Catatan:** ukuran val per-kategori kecil (total 210 grup
dipecah banyak kategori) -- perbedaan HitRate@1 antar kategori di sini observasi awal,
bukan kesimpulan statistik kuat.

## Keterbatasan
- Seluruh data sintetis -- skor TIDAK mencerminkan perilaku pembeli nyata.
- Hanya 23 seniman & 200 kolektor -- sampel kecil, generalisasi terbatas.
- Negatif per grup dipilih acak dari karya yang tersedia (bukan "dilihat tapi tidak
  dibeli" sungguhan) -- model belajar membedakan dari kandidat acak, bukan kandidat
  yang benar-benar dipertimbangkan kolektor.
- Fitur tren seniman/aliran (grup "tren_seniman_gaya") perlu dibaca bersama hasil
  ablation di atas -- kontribusinya terhadap NDCG@3 TIDAK diasumsikan besar begitu saja.
- `kolektor_segmen` (fitur clustering Thoriq) terbukti menambah nilai prediksi -- lihat seksi ablasi di atas.
- 42,9% baris data (`kolektor_segmen` = `Belum Cukup Riwayat`) adalah kasus cold-start -- model prediktif ini secara desain paling berguna untuk sisa 57,1% kolektor berpengalaman.
