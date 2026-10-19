# ml-sentiment — Analisis sentimen ulasan (IndoBERT)

Mengklasifikasikan ulasan kolektor untuk karya/seniman menjadi **negatif / netral / positif** dengan IndoBERT,
lalu menampilkannya sebagai section **"Sentimen Ulasan"** di dashboard seniman.
Folder ini terpisah dari `ml-recommender/` dan `ml-visual-search/` (environment sendiri: torch CPU besar).

> **Status data: SINTETIS.** 500 ulasan dibuat generator (`src/generate.py`), label ditentukan generator — bukan
> dinilai manusia, bukan ulasan pengguna sungguhan. Skor di bawah mencerminkan desain generator, **bukan** performa produksi.

## Alur
```
src/generate.py  ──> data/ulasan_dummy.csv (500, split tetap 350/75/75)
src/train.py     ──> baseline TF-IDF+LogReg  +  fine-tune IndoBERT  ──> models/metrics.json
                     └─> data/hasil/sentimen_ulasan.csv (prediksi 500 ulasan)
scripts/muat_neon.py ──> Neon schema `dummy_sentimen.ulasan`  ──> backend GET /api/dashboard/seniman/{id}/sentimen ──> Flutter
```
Model dijalankan **batch** (bukan di server): backend hanya membaca tabel hasil, tanpa torch.

## Menjalankan
```powershell
cd ml-sentiment
python -m venv .venv ; .venv\Scripts\activate
pip install torch --index-url https://download.pytorch.org/whl/cpu
pip install -r requirements.txt
python src/generate.py          # data dummy (deterministik, seed tetap)
python src/train.py             # ±12 menit di CPU; unduh indobenchmark/indobert-base-p1 (~500MB) pertama kali
python scripts/muat_neon.py     # butuh DATABASE_URL di backend\.env; hanya menyentuh schema dummy_sentimen
```
Bobot model (`models/indobert_sentimen/`, ±440 MB) di-gitignore; `models/metrics.json` ikut git.

## Data
* 500 ulasan, masing-masing menempel pada **satu transaksi nyata** di data dummy rekomendasi (pembeli = penulis, penjual = yang diulas).
* Distribusi: positif 200 · netral 140 · negatif 160. Split stratified 70/15/15 (train 350 / val 75 / test 75).
* Teks disusun dari klausa per aspek (kualitas, warna, pengiriman, kemasan, kesesuaian, harga, komunikasi) dengan variasi gaya tulis
  (singkatan, huruf kecil, typo ringan). Sengaja ada negasi ("tidak mengecewakan" = positif), kalimat kontras ("bagus tapi …" —
  bagian setelah *tapi* menentukan), dan kalimat faktual/netral.

## Hasil (model `indobert-v1`, epoch terbaik = 2 menurut macro-F1 validasi)
| Model | Val macro-F1 | Test akurasi | Test macro-F1 (95% CI bootstrap) |
|---|---|---|---|
| TF-IDF + regresi logistik (baseline) | 0,985 | 0,960 | 0,962 [0,919 – 1,000] |
| IndoBERT (`indobert-base-p1`) | 0,985 | 1,000 | 1,000 [1,000 – 1,000] |

**Cara membaca angka ini dengan jujur:**
* Test hanya **75 ulasan**, dan selang kepercayaan kedua model **saling tumpang tindih** — selisih 0,96 vs 1,00 **tidak bisa dinyatakan signifikan**.
* Baseline sederhana saja sudah 0,96: generator menghasilkan pola kata yang mudah dipelajari, jadi data ini **terlalu mudah** untuk
  membedakan IndoBERT dari model biasa. Jangan klaim "IndoBERT jauh lebih baik".
* Satu-satunya kesalahan di seluruh 500 ulasan (3 salah) ada pada kelas **netral campuran** ("bagus … tapi tidak sepadan dengan harganya") —
  label netral untuk kalimat kontras memang ambigu bahkan bagi manusia.
* Nilai IndoBERT di dataset ini tidak bisa dipakai memperkirakan akurasi pada ulasan sungguhan (bahasa gaul, sarkasme, ulasan panjang, kelas tak seimbang).

Untuk menguji kemampuan sebenarnya dibutuhkan ulasan nyata berlabel manusia (mis. ulasan beta-tester), atau setidaknya generator yang lebih sulit
(lebih banyak ambiguitas dan sarkasme).

## Ulasan yang ditulis kolektor di aplikasi
Di halaman detail karya, tombol **Tulis ulasan** (rating 1–5 + alasan 10–500 karakter) mengirim `POST /api/ulasan`. Satu kolektor, satu ulasan per karya (409 bila ganda).
Sentimen **tidak dihitung saat request** (tidak ada torch di server): ulasan tersimpan dengan `sumber='app'` dan `sentimen_prediksi = NULL` (*menunggu analisis*),
belum ikut hitungan dashboard (endpoint sentimen menyertakan `n_menunggu`). Jalankan secara berkala:
```powershell
python scripts/analisis_ulasan_baru.py [--dry-run]    # IndoBERT mengisi sentimen_prediksi untuk yang masih NULL
```
`scripts/muat_neon.py` hanya menimpa baris `sumber='dummy'`, jadi ulasan dari aplikasi tidak ikut terhapus.
Belum ada Auth: penulis ulasan = kolektor contoh (`GET /api/ulasan/kolektor-demo`, atau `--dart-define=DEMO_KOLEKTOR_ID=<uuid>`); belum ada
moderasi isi ulasan dan belum ada syarat "harus sudah membeli". Untuk sentimen **instan** saat kirim, model perlu diekspor ke ONNX (onnxruntime, tanpa torch).

## Yang dipakai aplikasi
Aplikasi membaca `sentimen_prediksi` (keluaran model), **bukan** `sentimen_label` (label generator, disimpan hanya untuk evaluasi).
`prob_*` = probabilitas softmax, hanya untuk analisis — jangan ditampilkan sebagai "tingkat keyakinan" ke pengguna tanpa kalibrasi.
