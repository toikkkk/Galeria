# Serah-terima hasil kerja Thoriq → Aulya, Vika, Genda

Dokumen ini menjawab: **apa yang sudah jadi, di mana letaknya, bagaimana memakainya, dan apa yang TIDAK boleh diklaim.**
Baca bagian untuk perananmu saja; bagian "Batasan jujur" berlaku untuk semua.

## 1. Yang sudah siap (semua di Neon, schema `dummy_rekomendasi`)

| Artefak | Isi | Siapa memakai |
|---|---|---|
| `kolektor_segmen` | 1 baris per kolektor (200): `kolektor_id, segmen_id, segmen_nama, model_version, dihitung_pada` | Aulya (wajib), Vika (opsional) |
| `segmen_kamus` (BARU) | 1 baris per segmen (5): `segmen_id, segmen_nama, deskripsi, ukuran, aliran_favorit, profil (JSONB), model_version` | Aulya, Vika — **ambil teks deskripsi dari sini, bukan hardcode** |
| `karya.image_key` | 2.000 karya, semua sudah terunggah ke R2 | Vika |
| `v_seniman_metrik_bulanan` | metrik seniman per bulan | Aulya |
| `seniman`, `kolektor`, `karya`, `transaksi` | data dummy (seed 42) | semua |

Kunci join: `transaksi.pembeli_id = kolektor_segmen.kolektor_id`. Backend **hanya membaca tabel**; tidak perlu sklearn, joblib, maupun file `models/`.

Gambar: URL = `R2_PUBLIC_URL_BASE` + `/` + `image_key`. `r2.dev` diblokir DNS sebagian provider Indonesia — saat dev pakai DNS 1.1.1.1/8.8.8.8 atau data seluler.

## 2. Lima segmen (clustering-v1, K-Means K=5)

| id | Nama | Ciri ringkas |
|---|---|---|
| 1 | Kolektor Premium | 38 orang, beli sedikit tapi mahal (±Rp145 jt), seniman mapan |
| 2 | Kolektor Menengah Aktif | 52 orang, paling sering beli (median 11), ±Rp52 jt, selera beragam |
| 3 | Spesialis Aliran | 49 orang, selera terpusat pada sedikit aliran, ±Rp50 jt |
| 4 | Pemburu Karya Terjangkau | 34 orang, ±Rp10 jt, seniman pemula, selera beragam |
| 5 | Pemula Hemat | 27 orang, beli jarang, ±Rp7 jt, seniman pemula |

Teks lengkap per segmen ada di `segmen_kamus.deskripsi` (dibuat otomatis dari centroid, jadi selalu cocok dengan angka).

## 3. Untuk Aulya — "Siapa Pembelimu"

Query siap pakai (ganti `S` dengan schema dari env `REKOMENDASI_SCHEMA`):
```sql
SELECT ks.segmen_id, ks.segmen_nama, count(DISTINCT tr.pembeli_id) AS n_pembeli
FROM S.transaksi tr
JOIN S.kolektor_segmen ks ON ks.kolektor_id = tr.pembeli_id
WHERE tr.penjual_id = :sid AND tr.created_at <= CAST(:t AS timestamptz)
GROUP BY ks.segmen_id, ks.segmen_nama ORDER BY n_pembeli DESC;
```
`:t` harus berupa objek `datetime` ber-timezone (dari `REKOMENDASI_WAKTU_ACUAN`), bukan string. Hitung `porsi_pct` di Python. Tambahkan `deskripsi` dengan JOIN `segmen_kamus` bila UI memunculkan penjelasan segmen (mis. tooltip).

* Tabel kosong → `{"tersedia": false, "items": []}`, sembunyikan bagian di UI.
* Seniman tanpa penjualan → `items: []` dengan `tersedia: true` (beda dari "tabel kosong").
* Tampilkan sebagai **ringkasan deskriptif** ("pembelimu didominasi Kolektor Menengah Aktif"). Jangan menulis saran harga atau prediksi (fitur Estimasi Harga sudah di-drop dari scope).

## 4. Untuk Vika

* Label segmen di kartu rekomendasi **opsional** dan boleh `null`. Jangan menampilkannya sebagai "profil kamu pasti begini" — lihat batasan.
* Gambar katalog: pakai `image_key` + `R2_PUBLIC_URL_BASE` lewat satu widget `KaryaImage` (lihat `vika.md`). Karya lama (8 seed) tetap `Image.asset`.
* `rekomendasi_kolektor` diisi Genda, bukan dari clustering. Sampai Genda selesai, pakai mock `REKOMENDASI_MOCK=1`.

## 5. Untuk Genda

* **Jangan** pakai `kolektor_segmen` atau `kolektor_label_asli` sebagai fitur klasifikasi. Segmen dihitung dari *seluruh* riwayat sampai akhir periode, jadi memasukkannya membocorkan masa depan ke fitur.
* `kolektor_segmen` boleh dipakai **setelah** model jadi, hanya untuk analisis kesalahan per segmen.
* Cold-start (kolektor baru tanpa riwayat) bukan tugas clustering; segmen belum bisa ditetapkan untuk orang yang belum punya riwayat.

## 6. Batasan jujur (jangan dilanggar di presentasi)

1. **Silhouette rendah (±0,18)** bukan kegagalan algoritma: plafon dari label asli generator hanya ±0,07 dan data tanpa struktur ±0,14. Struktur ada tapi lemah. Rinciannya di `models/LAPORAN_CLUSTERING.md` bagian 6.
2. **Stabilitas bootstrap tepat di ambang (≈0,70).** Jumlah segmen K=5 adalah perkiraan, bukan fakta alam. K=4 juga masuk akal.
3. **Segmen = ringkasan deskriptif** atas perilaku yang sebenarnya menerus. Jangan dipakai untuk keputusan per orang.
4. **Data sintetis.** Semua kolektor, transaksi, dan segmen "asli" dibuat generator; angka di dashboard bukan data pasar nyata. Gambar dan aliran berasal dari dataset Visual Search v1 (5.659 gambar, hanya 23 pelukis bernama).
5. **Bukan prediksi harga** dan bukan rekomendasi harga jual.

## 7. Cara menghitung ulang (hanya jika data berubah)

Dari `ml-recommender/` dengan `.venv`:
```
python jalankan_pipeline.py --reset    # data dummy → Neon → CSV (hanya bila data memang ingin dibuat ulang)
python scripts/latih_clustering.py      # latih + models/clustering_kolektor.joblib + LAPORAN_CLUSTERING.md
python scripts/hitung_segmen.py         # isi kolektor_segmen + segmen_kamus (idempotent, satu transaksi)
```
`hitung_segmen.py --dry-run` hanya menulis CSV, tidak menyentuh database. Tabel `public.*` tidak pernah disentuh (diverifikasi otomatis di skrip).

## 8. Kredensial

`backend/.env` tidak ada di git. Minta `DATABASE_URL` dan `R2_PUBLIC_URL_BASE` langsung ke Thoriq lewat jalur aman (bukan lewat grup chat/screenshot), lalu isi sendiri di `backend/.env` lokal.
