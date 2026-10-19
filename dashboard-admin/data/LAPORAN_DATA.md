# Laporan Data Dummy — Dashboard Admin GALERIA

_Dibuat otomatis oleh `data/validasi.py` pada 2026-10-19 11:55. Jalankan ulang bila parameter di `data/generate.py` berubah._

## 1. Apa data ini, dan apa yang BUKAN

Data ini **sintetis**: dibangkitkan oleh simulasi per-pengguna (`data/generate.py`) karena platform belum rilis dan belum ada transaksi nyata. Fungsinya: bahan untuk mengembangkan dan menguji pipeline forecasting serta tampilan dashboard.

Yang **dapat** dipertanggungjawabkan: (1) setiap parameter terdokumentasi beserta dasarnya, (2) data konsisten secara internal, (3) hasilnya reproduksibel, (4) efek yang ditanam terbukti muncul & dapat diestimasi balik, (5) kesimpulan perbandingan model tidak bergantung pada satu seed acak.

Yang **tidak** dapat diklaim: bahwa angka (pendapatan, pertumbuhan, pangsa Pro, besar efek Pro) mencerminkan perilaku pasar nyata. Skor forecasting di data ini mencerminkan **desain simulasi**, bukan performa produksi. Setelah ada data nyata, parameter bertanda *asumsi* harus dikalibrasi ulang dan seluruh evaluasi diulang.

## 2. Parameter simulasi dan dasarnya

| Parameter | Nilai | Dasar |
|---|---|---|
| Komisi platform | 2.5% dari harga final | Keputusan produk (permintaan tim) |
| Harga Pro kolektor | Rp50.000/bln | Keputusan produk (AR + gabung Komunitas) |
| Harga Pro seniman | Rp150.000/bln | Keputusan produk (promosi karya, buat event, buat komunitas); UI mobile kini Rp149.000 -- perlu disamakan |
| Siklus penagihan | 30 hari | Asumsi: langganan bulanan |
| Rentang data | 36 bulan (2023-10-01 s.d. 2026-09-30) | Asumsi: 3 tahun operasi; waktu acuan = akhir data dummy proyek |
| Pengguna baru/bulan (awal) | 60 (+120 saat peluncuran) | Asumsi (platform belum rilis; tak ada data nyata) |
| Pertumbuhan pengguna | +4%/bln; promo pada bulan ke-14, 27 | Asumsi |
| Komposisi role | seniman 35% / kolektor 65% | Asumsi (kolektor lebih banyak dari seniman) |
| Peluang upgrade Pro/bln | kolektor 1.0% (+1.2% bertahap), seniman 0.6% (+0.8%) | Asumsi |
| Rata-rata lama langganan | kolektor 10 bln, seniman 8 bln | Asumsi |
| Efek Pro kolektor | belanja 1.9x lebih sering | Asumsi sebab-akibat -- WAJIB dikalibrasi dgn data nyata |
| Efek promosi seniman Pro | laju beli platform +30% x pangsa seniman Pro; penjual Pro 2.0x lebih sering terpilih | Asumsi sebab-akibat -- WAJIB dikalibrasi dgn data nyata |
| Laju beli dasar | 0.04 transaksi/kolektor/bln (+0.8%/bln) | Asumsi |
| Musim | bulan: 1:0.92, 2:1.0, 3:1.0, 4:1.0, 5:1.0, 6:0.98, 7:0.94, 8:1.0, 9:1.0, 10:1.02, 11:1.06, 12:1.2; Ramadan +25% | Tanggal Ramadan = fakta kalender Hijriah (perkiraan +-1 hari); besar efek = asumsi |
| Harga karya | median Rp38.000.000 (+0.4%/bln), lognormal sigma 0.75 | Asumsi (distribusi harga seni condong ke kanan) |
| Guncangan pasar bulanan | lognormal sigma 0.05 | Asumsi (sumber noise di luar Poisson) |
| Seed acak | 20260930 | Tetap -> data reproduksibel |

## 3. Uji integritas internal

| Uji | Hasil | Rincian |
|---|---|---|
| Komisi = 2,5% x harga final (setiap transaksi) | LULUS | 2496 transaksi, selisih maks 0 |
| Harga dalam batas [Rp1,5 jt; Rp1 M] & kelipatan Rp10.000 | LULUS | min Rp3.700.000, maks Rp501.520.000 |
| ID unik di semua tabel | LULUS | 17456 ID |
| Tidak ada waktu melewati waktu acuan | LULUS | waktu acuan 2026-09-30 |
| Transaksi terjadi setelah pembeli terdaftar | LULUS |  |
| Pembeli = kolektor, penjual = seniman | LULUS |  |
| Paket sesuai role (kolektor_pro->kolektor, seniman_pro->seniman) | LULUS | 1152 langganan |
| Langganan dimulai setelah pengguna terdaftar & berakhir > mulai | LULUS |  |
| Tidak ada langganan tumpang-tindih pada satu pengguna | LULUS | 0 tumpang-tindih |
| Status 'aktif' <=> berakhir setelah waktu acuan | LULUS |  |
| Jumlah pembayaran = jumlah siklus 30 hari yang sudah lewat (tiap langganan) | LULUS | 6305 pembayaran |
| Jumlah tiap pembayaran = harga paket | LULUS |  |
| Total pendapatan bulanan = komisi + langganan; jumlah seluruh bulan = jumlah data mentah | LULUS | total Rp4.004.190.500 |
| Seed sama -> data identik (dibangkitkan dua kali) | LULUS | seed 20260930 |
| Agregat bulanan di Neon (SQL) = hitungan langsung dari data (pandas) | LULUS | 10 kolom x 36 bulan, selisih maks 0 |

**Ringkasan: 15 dari 15 uji lulus.**

## 4. Uji pemulihan efek (apakah efek yang ditanam benar-benar terbaca dari data?)

Efek diestimasi **hanya dari tabel data** (tanpa melihat parameter), lalu dibandingkan dengan nilai yang ditanam. Interval 95% dari bootstrap antar-bulan (efek Pro kolektor, efek penjual Pro) atau galat baku WLS (regresi promosi).

| Efek | Nilai ditanam | Estimasi dari data | Selang 95% | Terpulihkan? |
|---|---|---|---|---|
| Kolektor Pro belanja lebih sering (rasio laju) | 1.9 | 1.81 | 1.65 – 1.97 | ya |
| Seniman Pro lebih sering terpilih sbg penjual (rasio laju) | 2.0 | 1.88 | 1.64 – 2.11 | ya |
| Laju beli dasar kolektor non-Pro (per bulan) | 0.040 | 0.046 | 0.040 – 0.052 | ya |
| Kenaikan laju beli per 100% pangsa seniman Pro (promosi beranda) | 0.012 | -0.095 | -0.200 – 0.011 | tidak |

Regresi promosi memakai 36 bulan (paparan > 20 kolektor non-Pro).

**Temuan: efek promosi seniman Pro TIDAK terpulihkan dari data ini.** Efek yang ditanam di akhir periode hanya ±2.2% kenaikan laju beli (30% x pangsa seniman Pro 7.2%), sedangkan noise acak bulanan jumlah transaksi ±8.7% (Poisson, ±133 transaksi/bln). Efek sekecil itu tenggelam dalam noise pada 36 titik bulanan. Akibatnya: (a) ini bukan bug generator — nilai yang ditanam memang kecil; (b) di data ini **jangan** menafsirkan Pro seniman sebagai pendorong penjualan, dan variabel `n_pro_seniman`/`pro_share_seniman` praktis tidak menambah informasi bagi model komisi; (c) bila efek promosi ingin menjadi variabel yang bermakna, besarnya harus diputuskan dari data nyata/uji A-B, bukan diubah di sini hanya agar uji ini lulus.

Tiga efek lain (kolektor Pro, penjual Pro, laju dasar) terpulihkan karena besarnya cukup di atas noise.

## 5. Gambaran data (tahun terakhir)

| Bulan | Pengguna (kolektor/seniman) | Pro kolektor | Pro seniman | Transaksi | Komisi 2,5% | Langganan | Total |
|---|---|---|---|---|---|---|---|
| Oct 2025 | 1.758/901 | 174 (9.9%) | 45 (5.0%) | 90 | Rp154.365.000 | Rp16.100.000 | Rp170.465.000 |
| Nov 2025 | 1.872/966 | 182 (9.7%) | 58 (6.0%) | 81 | Rp104.289.500 | Rp17.800.000 | Rp122.089.500 |
| Dec 2025 | 1.992/1.024 | 183 (9.2%) | 67 (6.5%) | 147 | Rp223.978.250 | Rp19.850.000 | Rp243.828.250 |
| Jan 2026 | 2.160/1.127 | 225 (10.4%) | 77 (6.8%) | 108 | Rp143.939.750 | Rp23.650.000 | Rp167.589.750 |
| Feb 2026 | 2.303/1.193 | 287 (12.5%) | 91 (7.6%) | 117 | Rp164.526.750 | Rp26.850.000 | Rp191.376.750 |
| Mar 2026 | 2.426/1.259 | 320 (13.2%) | 100 (7.9%) | 140 | Rp211.367.250 | Rp31.400.000 | Rp242.767.250 |
| Apr 2026 | 2.548/1.328 | 335 (13.1%) | 100 (7.5%) | 147 | Rp200.611.500 | Rp31.750.000 | Rp232.361.500 |
| May 2026 | 2.670/1.411 | 336 (12.6%) | 103 (7.3%) | 128 | Rp172.418.500 | Rp33.100.000 | Rp205.518.500 |
| Jun 2026 | 2.829/1.492 | 367 (13.0%) | 108 (7.2%) | 130 | Rp188.913.250 | Rp34.550.000 | Rp223.463.250 |
| Jul 2026 | 2.982/1.569 | 380 (12.7%) | 108 (6.9%) | 159 | Rp215.205.000 | Rp36.150.000 | Rp251.355.000 |
| Aug 2026 | 3.124/1.648 | 389 (12.5%) | 121 (7.3%) | 167 | Rp259.644.750 | Rp38.950.000 | Rp298.594.750 |
| Sep 2026 | 3.267/1.740 | 400 (12.2%) | 129 (7.4%) | 181 | Rp288.003.000 | Rp39.350.000 | Rp327.353.000 |

Seluruh periode: komisi Rp3.543.740.500, langganan Rp460.450.000 (11.5% dari total pendapatan platform).

## 6. Ketahanan kesimpulan forecasting antar-seed

Data dibangkitkan ulang dengan 4 seed berbeda (20260930, 20260931, 20260932, 20260933); seluruh model di-backtest ulang pada tiap seed (titik potong 24–30, horizon 6). Tabel: WAPE rata-rata ± simpangan baku antar-seed (makin kecil makin baik) dan berapa kali model jadi pemenang.

**Target: total**

| Model | WAPE rata-rata | Simpangan baku | Menang (dari 4 seed) |
|---|---|---|---|
| chronos2_log_kalender | 15.0% | 5.0 | 1 |
| ensemble_chronos_theta | 15.2% | 5.9 | 2 |
| theta | 15.4% | 4.3 | 0 |
| chronos2_kovariat_pro | 16.5% | 0.9 | 1 |
| chronos2_log_kovariat_pro | 18.3% | 8.3 | 0 |
| chronos2_kalender | 19.8% | 0.8 | 0 |
| seasonal_naive_tren | 21.4% | 6.7 | 0 |
| lightgbm | 26.3% | 14.6 | 0 |
| ets_redaman | 32.6% | 10.7 | 0 |

**Target: komisi**

| Model | WAPE rata-rata | Simpangan baku | Menang (dari 4 seed) |
|---|---|---|---|
| chronos2_kovariat_pro | 17.1% | 0.8 | 2 |
| chronos2_log_kalender | 17.7% | 6.2 | 0 |
| ensemble_chronos_theta | 20.6% | 11.9 | 2 |
| theta | 20.8% | 11.5 | 0 |
| chronos2_kalender | 21.0% | 0.7 | 0 |
| chronos2_log_kovariat_pro | 23.3% | 12.9 | 0 |
| seasonal_naive_tren | 26.0% | 8.3 | 0 |
| lightgbm | 34.3% | 19.0 | 0 |
| ets_redaman | 45.4% | 30.7 | 0 |

Cara membaca: bila pemenang berganti-ganti antar-seed dan selisih rata-rata antar-model kecil dibanding simpangan bakunya, jangan klaim satu model "terbaik secara umum" — hanya "kompetitif". Hanya selisih yang konsisten di semua seed yang layak dilaporkan.

## 7. Keterbatasan yang harus disebut di laporan/presentasi

- Seluruh angka bersifat sintetis; tidak ada validasi terhadap pasar nyata atau pembanding eksternal.
- Hanya 36 titik data bulanan: selisih kecil antar-model bisa noise; interval ketidakpastian lebih bermakna daripada satu angka titik.
- Struktur data ditentukan oleh kita sendiri, sehingga model yang kebetulan cocok dengan struktur itu akan tampak bagus. Ini alasan uji antar-seed (bagian 6) dan pemulihan efek (bagian 4) ada.
- Efek Pro/promosi diasumsikan sebab-akibat; pada data nyata efek ini harus diestimasi, bukan diasumsikan (kemungkinan bias seleksi: pengguna yang aktif lebih mungkin upgrade).
- Forecast bukan jaminan pendapatan; pakai rentang P10–P90.
