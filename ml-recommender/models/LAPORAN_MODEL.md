# Laporan Model — Klasifikasi Pembelian (`klasifikasi-v1`)

> **Data SINTETIS** (`src/generate.py`, seed 42). Angka di laporan ini menunjukkan
> "generator terbaca model", BUKAN performa produksi/dunia nyata. Hanya 23 seniman
> dan 200 kolektor -- model rawan overfit pada skala sekecil ini, tiap angka harus
> dibaca dengan kehati-hatian itu.

Dilatih: 2026-10-05T15:15:03.337618+00:00  |  Versi: `klasifikasi-v1`

## Perbandingan 5 metode

### VAL (dipakai untuk pemilihan hyperparameter & model)
|                        |   HitRate@1 |   HitRate@3 |    MRR |   NDCG@3 |    AUC |
|:-----------------------|------------:|------------:|-------:|---------:|-------:|
| acak                   |      0.2286 |      0.6    | 0.4752 |   0.438  | 0.5107 |
| populer                |      0.2381 |      0.6714 | 0.4949 |   0.4847 | 0.5185 |
| aturan_sederhana       |      0.6476 |      0.9571 | 0.7902 |   0.8254 | 0.7338 |
| logistic_regression    |      0.5619 |      0.8905 | 0.7344 |   0.7555 | 0.7986 |
| hist_gradient_boosting |      0.5095 |      0.9238 | 0.7152 |   0.7559 | 0.8099 |

### TEST (disentuh SEKALI, setelah semua keputusan final dari VAL)
|                        |   HitRate@1 |   HitRate@3 |    MRR |   NDCG@3 |    AUC |
|:-----------------------|------------:|------------:|-------:|---------:|-------:|
| acak                   |      0.1857 |      0.581  | 0.4417 |   0.407  | 0.4917 |
| populer                |      0.2238 |      0.5762 | 0.4683 |   0.4237 | 0.4815 |
| aturan_sederhana       |      0.6238 |      0.9    | 0.7693 |   0.785  | 0.7155 |
| logistic_regression    |      0.4952 |      0.9238 | 0.6965 |   0.7419 | 0.7887 |
| hist_gradient_boosting |      0.481  |      0.8905 | 0.6847 |   0.7181 | 0.7828 |

Baseline acak HitRate@1 teoritis = 0,20 (1 dari 5 kandidat/grup).

**Model terpilih:** `HistGradientBoostingClassifier` dengan hyperparameter `{'max_iter': 300, 'learning_rate': 0.05, 'max_depth': 3}`
(dipilih berdasarkan NDCG@3 di VAL -- lihat tabel grid pencarian di notebook bagian 16).

**Mengalahkan baseline di TEST?** vs "populer" (HitRate@1): True.
vs "aturan_sederhana" (HitRate@1): False.

## Seberapa yakin hasil di atas? (bootstrap CI 95%, uji signifikansi berpasangan)

`val`/`test` masing-masing cuma 210 grup -- angka titik di atas BISA jadi kebetulan
sampel kecil. Bootstrap (2.000 resample per grup, TEST) dipakai utk cek ini:

| perbandingan                                  |   rata2_selisih |   ci_2.5% |   ci_97.5% |   p_dua_sisi |
|:----------------------------------------------|----------------:|----------:|-----------:|-------------:|
| aturan_sederhana vs hist_gradient_boosting    |          0.1431 |    0.0714 |     0.2144 |        0     |
| aturan_sederhana vs logistic_regression       |          0.1284 |    0.0524 |     0.2095 |        0.001 |
| hist_gradient_boosting vs logistic_regression |         -0.0147 |   -0.0763 |     0.0524 |        0.695 |

(selisih = HitRate@1 metode pertama - kedua; CI 95% yang TIDAK melewati 0 berarti
beda itu nyata secara statistik, bukan noise sampel. `p_dua_sisi < 0,05` = sinyal yang sama.)

Lihat notebook bagian 19 untuk CI per-metode lengkap (HitRate@1/3, MRR, NDCG@3).

## Fitur penting (permutation importance, dihitung di VAL, scoring=AUC)
| fitur                             |   importansi_rata2 |         std |
|:----------------------------------|-------------------:|------------:|
| match_rasio_harga_vs_rata2        |        0.0860153   | 0.0117802   |
| match_selisih_log_harga_vs_median |        0.0376395   | 0.00784906  |
| match_porsi_gaya_ini              |        0.0261253   | 0.00509472  |
| gaya_porsi_penjualan_30hari       |        0.00650057  | 0.00393035  |
| karya_harga_listing_idr           |        0.00538889  | 0.00222283  |
| karya_luas_cm2                    |        0.00473413  | 0.0050243   |
| karya_gaya                        |        0.00449717  | 0.00183182  |
| match_n_beli_seniman_ini          |        0.00393311  | 0.00284272  |
| seniman_n_terjual_total           |        0.00369444  | 0.00312735  |
| karya_umur_listing_hari           |        0.0034881   | 0.0023005   |
| seniman_n_terjual_30hari          |        0.00178628  | 0.00129368  |
| seniman_harga_rata2_90hari_idr    |        0.00160771  | 0.002492    |
| kolektor_harga_rata2_idr          |        0.00113946  | 0.000410659 |
| kolektor_harga_min_idr            |        0.00110601  | 0.000817072 |
| seniman_persentil_tren_30hari     |        0.000972789 | 0.00140747  |

## Ablation kelompok fitur (val, NDCG@3)
| dibuang                      |   NDCG@3 |     selisih |
|:-----------------------------|---------:|------------:|
| (tidak ada -- model lengkap) | 0.755946 |  0          |
| riwayat_kolektor             | 0.723859 | -0.0320864  |
| karya                        | 0.746819 | -0.00912623 |
| kecocokan_match              | 0.708214 | -0.047732   |
| tren_seniman_gaya            | 0.77165  |  0.0157043  |

Fitur `seniman_lonjakan_30hari` secara khusus (pertanyaan `genda.md`): NDCG@3 model
lengkap = 0.7559, tanpa fitur ini = 0.7513
(selisih -0.0046).

## Analisis kesalahan (val, HitRate@1 per kategori)
Lihat notebook bagian 22 untuk tabel per `seniman_level_reputasi`, `karya_gaya`, dan
`segmen_asli` (kolektor_label_asli.csv, HANYA dipakai di analisis ini, tidak pernah
sebagai fitur/target). **Catatan:** ukuran val per-kategori kecil (total 210 grup
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
