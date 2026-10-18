# Serah-terima hasil kerja Thoriq → Aulya, Vika, Genda (versi 2026-10-18, `clustering-v2`)

Dokumen ini menjawab: **apa yang sudah jadi, di mana letaknya, bagaimana memakainya, dan apa yang TIDAK boleh diklaim.**
Baca bagian untuk perananmu saja; bagian "Batasan jujur" berlaku untuk semua.

> **Apa yang berubah dari versi sebelumnya:** clustering diganti dari K-Means ke **UMAP + HDBSCAN**; data dummy dirombak (generator-v2) agar kolektor berkelompok tegas; urutan kerja menjadi
> **clustering dulu → klasifikasi** (segmen kolektor jadi fitur klasifikasi). Seniman, karya, gambar R2, dan harga **tidak berubah**. Ringkasan lengkap: `README.md` bagian "Perombakan 2026-10-18".

## 1. Yang sudah siap

| Artefak | Isi | Siapa memakai |
|---|---|---|
| `data/training/clustering_kolektor.csv` | 200 kolektor × 31 kolom (5 fitur klaster + kolom profil) | Thoriq (clustering) |
| `models/clustering_kolektor.joblib` | model **FINAL** (seluruh periode): UMAP + HDBSCAN | Thoriq (mengisi Neon) |
| `models/clustering_kolektor_cutoff.joblib` | model **CUTOFF** (data sampai batas train) | pembuat fitur klasifikasi; Genda via `src/inference.py` |
| `models/LAPORAN_CLUSTERING.md` | laporan otomatis: perbandingan algoritma, hiperparameter, profil, skor, keterbatasan | semua |
| `data/hasil/segmen_kolektor.csv`, `segmen_kamus.csv` | hasil segmen (salinan tabel Neon) | Aulya, Vika |
| `data/training/klasifikasi_pembelian.csv` | 7.000 baris × 43 kolom, termasuk `kolektor_segmen` (dari model cutoff, as-of t) | Genda |
| Neon: `kolektor_segmen`, `segmen_kamus` | ****SUDAH diisi ulang (2026-10-18)** dengan data generator-v2: `kolektor` 200, `transaksi` 1.400, `kolektor_segmen` 200 + `segmen_kamus` 5 (`clustering-v2`); `karya` 2.000 dengan `image_key` R2 terisi. `rekomendasi_kolektor` masih kosong (menunggu Genda).** | Aulya (wajib), Vika (opsional) |

Kunci join: `transaksi.pembeli_id = kolektor_segmen.kolektor_id`. Backend **hanya membaca tabel**; tidak perlu sklearn, joblib, UMAP, maupun file `models/`.

## 2. Lima segmen (`clustering-v2`, UMAP + HDBSCAN, K ditemukan otomatis)

| id | Nama | Ciri ringkas (dari centroid) |
|---|---|---|
| 1 | Kolektor Premium | 23 orang, beli jarang tapi sangat mahal (±Rp287 jt), seniman mapan |
| 2 | Kolektor Aktif Bernilai Tinggi | 50 orang, ±Rp119 jt, sering beli (median 11) |
| 3 | Pemburu Tren | 31 orang, ±Rp44 jt, paling sering beli (median 14), mengikuti seniman yang sedang ramai |
| 4 | Kolektor Menengah Rutin | 56 orang, ±Rp18 jt, tidak mengikuti tren |
| 5 | Pemula Hemat | 40 orang, ±Rp5 jt, beli jarang, seniman pemula |

Nama dibuat **otomatis dari centroid** (`src/clustering.py: beri_nama`), jadi bisa berubah bila model dilatih ulang. Teks lengkap per segmen ada di `segmen_kamus.deskripsi` — **ambil dari tabel, jangan hardcode**.
Kolektor dengan < 3 pembelian tidak dipaksa masuk klaster (`Belum Cukup Riwayat`, `segmen_id = 0`); di data sekarang semua kolektor punya ≥ 3 pembelian sehingga tidak ada.

## 3. Untuk Aulya — "Siapa Pembelimu"

Query siap pakai (ganti `S` dengan schema dari env `REKOMENDASI_SCHEMA`):
```sql
SELECT ks.segmen_id, ks.segmen_nama, count(DISTINCT tr.pembeli_id) AS n_pembeli
FROM S.transaksi tr
JOIN S.kolektor_segmen ks ON ks.kolektor_id = tr.pembeli_id
WHERE tr.penjual_id = :sid AND tr.created_at <= CAST(:t AS timestamptz)
GROUP BY ks.segmen_id, ks.segmen_nama ORDER BY n_pembeli DESC;
```
`:t` harus berupa objek `datetime` ber-timezone (dari `REKOMENDASI_WAKTU_ACUAN`), bukan string. Hitung `porsi_pct` di Python. Tambahkan `deskripsi` dengan JOIN `segmen_kamus` bila UI memunculkan penjelasan segmen.

* Tabel kosong → `{"tersedia": false, "items": []}`, sembunyikan bagian di UI.
* Seniman tanpa penjualan → `items: []` dengan `tersedia: true` (beda dari "tabel kosong").
* Tampilkan sebagai **ringkasan deskriptif** ("pembelimu didominasi Pemburu Tren"). Jangan menulis saran harga atau prediksi (fitur Estimasi Harga sudah di-drop dari scope).
* Angka dashboard akan berubah setelah Neon diisi ulang (transaksi dibangun ulang); kode tidak perlu diubah.

## 4. Untuk Vika

* Label segmen di kartu rekomendasi **opsional** dan boleh `null`. Jangan menampilkannya sebagai "profil kamu pasti begini" — lihat batasan.
* Gambar katalog: pakai `image_key` + `R2_PUBLIC_URL_BASE` lewat satu widget `KaryaImage`. Karya dan gambar **tidak berubah** (diverifikasi identik), jadi R2 tidak perlu diunggah ulang.
* `rekomendasi_kolektor` diisi Genda, bukan dari clustering, dan **perlu dihitung ulang** pada data baru. Sampai itu selesai, pakai mock `REKOMENDASI_MOCK=1`.

## 5. Untuk Genda

* **Aturan berubah:** `kolektor_segmen` di CSV klasifikasi **boleh** dipakai sebagai fitur — itu dari model **cutoff**, dihitung as-of `t` dari riwayat sebelum `t`, jadi tidak membocorkan masa depan.
* **Tetap dilarang:** segmen dari Neon / model final (`kolektor_segmen` tabel) dan `kolektor_label_asli` sebagai fitur.
* Model klasifikasi lama dan `data/hasil/rekomendasi_kolektor.csv` **basi**; latih ulang (`genda.md` bagian 0b). Hasil ablasi Thoriq: segmen tidak menambah akurasi berarti (< 0,02).
* Cold-start (kolektor tanpa riwayat) bukan tugas clustering; segmennya `Belum Cukup Riwayat`.

## 6. Batasan jujur (jangan dilanggar di presentasi)
1. **Silhouette 0,649 adalah hasil desain data, bukan temuan nyata.** Generator-v2 sengaja membuat lima arketipe kolektor yang berbeda tegas (atas arahan dosen). Pada data nyata skor akan jauh lebih rendah.
2. **Pada data ini K-Means K=5 juga mendapat 0,649**; skor ditentukan datanya. Keunggulan UMAP + HDBSCAN: K ditemukan sendiri, noise ditangani, kolektor baru ditetapkan tanpa melatih ulang. Jangan menyiratkan algoritma yang "menaikkan" skor.
3. **Silhouette dihitung di ruang fitur asli**, bukan ruang UMAP (di sana skor menggelembung). Plafon (silhouette label asli generator) = 0,643.
4. **Fitur klaster dipilih setelah percobaan di data ini** (keterpusatan selera aliran dikeluarkan karena menurunkan silhouette ke 0,46). Itu disclosure, bukan klaim fitur lain "salah".
5. **Segmen = ringkasan statistik**, bukan fakta tentang orang tertentu. Jangan dipakai untuk keputusan per orang.
6. **Data sintetis.** Semua kolektor, transaksi, dan segmen "asli" dibuat generator; angka di dashboard bukan data pasar nyata. Gambar dan aliran berasal dari dataset WikiArt (riset non-komersial).
7. Skor klasifikasi yang tinggi (HitRate@1 ≈ 0,77) mencerminkan data yang terstruktur, bukan kemampuan model pada pembeli nyata.

## 7. Cara membangun ulang
```powershell
cd ml-recommender
pip install -r requirements.txt                  # termasuk umap-learn & hdbscan
python jalankan_pipeline.py --dry-run            # generate -> clustering (final + cutoff + laporan) -> CSV; tanpa database
python scripts/hitung_segmen.py --dari-csv       # segmen + kamus ke data/hasil/*.csv, tanpa database
python scripts/hitung_segmen.py                  # tulis kolektor_segmen + segmen_kamus ke Neon (idempotent, satu transaksi)
```
Pengisian ulang Neon penuh (menimpa `kolektor`, `transaksi`, dst.): `python jalankan_pipeline.py --reset`, lalu `hitung_segmen.py`, lalu `upload_gambar_r2.py` (aman diulang). Tabel `public.*` tidak pernah disentuh.
Pipeline deterministik (seed 42): dua kali jalan menghasilkan semua CSV identik.
