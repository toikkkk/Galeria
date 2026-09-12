# CLAUDE.md — GALERIA

Konteks proyek untuk Claude Code. Baca file ini sebelum mengerjakan task apa pun di repo ini.

## Ringkasan Proyek

**Nama produk:** GALERIA (sebelumnya bernama "ArtKey" — nama lama ini masih mungkin muncul di beberapa dokumen/aset lama, abaikan, pakai "GALERIA" untuk semua materi baru).

**Judul lengkap (akademik):** GALERIA — Platform Cerdas Berbasis Agentic Artificial Intelligence, Augmented Reality, dan Kriptografi dengan Digital Art Identity untuk Autentikasi dan Perdagangan Karya Seni

**Deskripsi singkat:** Platform e-commerce/marketplace + lelang untuk lukisan, patung, dan karya seni lain, dengan diferensiasi utama pada sistem verifikasi keaslian karya berbasis digital fingerprinting, ditambah fitur AI/computer vision untuk pencarian visual dan simulasi AR.

**Konteks akademik:** Proyek kelompok (PBL/tugas kuliah, prodi Sains Data Terapan, PENS). Harus punya nilai jual B2B/B2C yang jelas dan komponen AI/computer vision yang genuinely defensible — bukan sekadar fitur tempelan.

## Target Pengguna & Model Bisnis

- **Target user:** seniman/pelukis (penjual) dan pengguna umum (pembeli/kolektor), plus role tambahan **komunitas** (menyelenggarakan event seperti pameran/lelang).
- **Revenue model:**
  1. Komisi dari penjualan karya (B2C, dipotong dari seniman/penjual)
  2. Subscription untuk akses fitur AR (upgrade berbayar bagi pembeli)
  3. Subscription PRO untuk komunitas yang ingin membuat event di platform

## 4 Fitur Utama

### 1. AR Simulation
- Simulasi peletakan karya di ruang nyata pengguna via kamera, dengan skala sesuai ukuran fisik asli karya.
- **Teknis:** murni computer vision terapan (plane detection + scale estimation via SLAM), menggunakan SDK **ARCore (Android) / ARKit (iOS)**, TIDAK dibuat dari nol, BUKAN deep learning.
- **Data:** tidak butuh dataset training. Butuh metadata ukuran fisik karya (panjang x lebar dalam cm) yang diinput manual oleh penjual saat upload karya — field wajib di form upload.

### 2. Visual Search ("cari karya mirip", gaya reverse image search)
- Pengguna foto/upload gambar karya yang mereka suka (dari galeri, medsos, dunia nyata) → sistem cocokkan ke katalog GALERIA saja (bukan seluruh internet) → kalau match, tampilkan info lengkap + bisa langsung beli.
- **Teknis:** deep learning genuinely — CNN (ResNet50, fine-tuned dari ImageNet pretrained) menghasilkan image embedding, dibandingkan pakai cosine similarity ke embedding katalog. Vector search idealnya pakai FAISS/pgvector untuk skala.
- **Data training:** dataset **WikiArt** (bukan Art Price Dataset — itu sudah tidak dipakai, lihat bagian "Riwayat Keputusan" di bawah).

### 3. Digital Art Identity (sertifikat keaslian digital)
- Setiap karya yang diupload dapat "unique key" berbasis fingerprint digital. Kalau ada upload lain dengan fingerprint yang sama/sangat mirip → otomatis diblokir/ditandai (mencegah klaim ganda kepemilikan karya yang sama di platform).
- **Teknis:** perceptual hashing (pHash) untuk deteksi cepat, dan/atau deep embedding (reuse model CNN yang sama dari fitur Visual Search) untuk deteksi yang lebih robust terhadap manipulasi ringan (crop, watermark).
- **PENTING — istilah wajib:** JANGAN PERNAH menyebut fitur ini sebagai **"Hak Paten"** di UI, dokumen, atau materi apa pun yang dilihat pengguna/dosen. Istilah yang benar: **"sertifikat digital keaslian"** atau **"bukti registrasi kepemilikan digital"**. "Hak Paten" adalah klaim hukum yang salah (paten ≠ hak cipta karya seni, dan sistem ini tidak menerbitkan hak hukum formal apa pun).
- **Batasan yang wajib disadari:** sistem ini mendeteksi duplikasi UPLOAD DIGITAL di platform, BUKAN mendeteksi pemalsuan fisik karya seni di dunia nyata (itu butuh forensik kimia/X-ray, di luar scope proyek ini). Jangan overclaim "AI kami deteksi lukisan palsu".
- **Sub-fitur tambahan (baru dikonfirmasi, belum detail teknisnya):** deteksi apakah karya yang diupload **AI-generated** (Midjourney/DALL-E/Stable Diffusion/dll) atau karya asli buatan manusia. Dikerjakan di folder terpisah `ml-digital-art-identity/` (bukan oleh modeler Visual Search) — update bagian ini dengan detail teknis (arsitektur, dataset) begitu didesain.
- **Kode/modeling fitur ini ada di `ml-digital-art-identity/`** (folder terpisah dari `ml-visual-search/`, dikerjakan anggota lain) — lihat README di dalamnya.

### 4. Chatbot
- Asisten tanya-jawab seputar karya/platform.
- **Teknis:** wrapping API GPT via **n8n** (role-based). BUKAN model yang dilatih/fine-tuned sendiri — jangan diklaim sebagai kontribusi deep learning tim.

### Fitur yang SUDAH DIHAPUS dari scope
- **Estimasi Harga Jual** — sempat direncanakan (parameter: ukuran, kelangkaan, kualitas cat, demand), sempat memilih Kaggle "Art Price Dataset" (`flkuhm/art-price-dataset`) sebagai data training tabular. **Fitur ini resmi di-drop dari scope proyek.** Jangan implementasikan, jangan sebut di materi baru, dan Art Price Dataset TIDAK relevan lagi untuk proyek ini.

## Arsitektur AI — Prinsip Penting

**Satu CNN backbone (ResNet50, fine-tuned dari WikiArt untuk task klasifikasi style) dipakai ulang di 2 fitur sekaligus:** Visual Search (image embedding untuk similarity search) dan opsional Digital Art Identity (kalau memilih deep embedding, bukan cuma hashing). Ini arsitektur yang disengaja untuk efisiensi dan koherensi — bukan model terpisah-pisah per fitur.

**Ringkasan klasifikasi teknis tiap fitur (penting untuk laporan akademik, jangan campur adukkan):**

| Fitur | Deep Learning? | Computer Vision? | Dibuat dari nol? |
|---|---|---|---|
| AR Simulation | Tidak | Ya (spatial/SLAM) | Tidak — pakai SDK |
| Visual Search | Ya | Ya | Tidak — transfer learning/fine-tuning dari pretrained |
| Digital Art Identity | Opsional (tergantung metode) | Ya (kalau pakai embedding) | Tidak — reuse model / algoritmik (hashing) |
| Chatbot | Tidak | Tidak | Tidak — wrapping API pihak ketiga |

## Dataset

- **WikiArt** (`huggan/wikiart` di Hugging Face Hub) — SATU-SATUNYA dataset eksternal yang dipakai untuk training model deep learning. Berisi 81.444 gambar dengan label artist (129 kelas), genre (11 kelas), style (27 kelas). Lisensi: riset non-komersial.
- **Subset yang dipakai:** diperluas bertahap dari 1.132 → **5.659 gambar** (shard 0-4 dari 72, `train-0000{0-4}-of-00072.parquet`, diunduh via `hf_hub_download` per-shard — lihat `ml-visual-search/notebooks/00_scrape_wikiart.ipynb`), disimpan di `ml-visual-search/data/raw/` (file .jpg + `metadata.csv`). **Catatan penting:** subset ini BUKAN random sample, representativeness terbatas (didominasi artist tertentu: Van Gogh, Roerich, Monet) — sudah didokumentasikan di Data Card project. Path lokal lama `C:\wikiart_sample\` sudah tidak dipakai, data sekarang self-contained di dalam repo (`ml-visual-search/data/`, di-gitignore krn ~500MB+lisensi non-komersial).
- **Data Card** sudah dibuat mengikuti template dosen, mencakup: sumber, lisensi, komposisi, proses cleaning, known issues (imbalance — rasio ~12,5x setelah filter kelas mayor, kelas minoritas <40 sampel di-exclude), rencana mitigasi.
- **Split:** stratified 70/15/15 (train 3.918 / val 840 / test 840, dari 5.598 gambar, **11 kelas style** setelah exclude kelas minoritas <40 sampel — naik dari 12 kelas awal saat data masih 1.132 gambar), tersimpan di `ml-visual-search/data/raw/{train,val,test}_split.csv`.
- **Art Price Dataset (Kaggle `flkuhm/art-price-dataset`)** — TIDAK DIPAKAI LAGI (lihat bagian fitur yang dihapus di atas).
- **Data ukuran fisik karya (untuk AR), data internal platform (histori transaksi, reputasi seniman, dll)** — bukan dataset yang didownload, tapi data operasional yang akan terbentuk dari form upload karya dan histori penggunaan platform setelah live.

## Struktur Repo (monorepo)

```
projek galeria/
├── CLAUDE.md
├── ml-visual-search/          Modeling CV utk Visual Search (dulu bernama ml/)
├── ml-digital-art-identity/    Modeling utk Digital Art Identity (anggota lain,
│                                unique-key/fingerprint + deteksi gambar AI-generated)
├── backend/                    API inference FastAPI — skeleton dibuat
├── mobile/                     Aplikasi mobile Flutter — skeleton dibuat (flutter create)
└── docs/                       Data Card, laporan akademik
```

`ml-visual-search/` dan `ml-digital-art-identity/` **sengaja folder terpisah**
— dua pipeline modeling berbeda orang, jangan dicampur.

Aplikasi target = **mobile (Flutter)**. Model TIDAK jalan di HP:
`ml-visual-search/` menghasilkan encoder (TorchScript/ONNX) + index katalog →
dilayani `backend/` (FastAPI + ONNXRuntime) → dipakai `mobile/`. Alur di
`ml-visual-search/`: `preprocess → train → evaluate → embedding → export`
(semua tahap sudah selesai & terverifikasi).

## Status Progress Saat Ini

- ✅ EDA WikiArt subset selesai (cleaning, distribusi kelas, ukuran, korelasi label, split, augmentasi) — `ml-visual-search/notebooks/eda_wikiart.ipynb`
- ✅ Data Card selesai dibuat
- ✅ **Modeling Visual Search selesai** (`ml-visual-search/`): dataset diperluas ke 5.659 gambar (shard 0-4, 11 kelas style setelah exclude minoritas), convnext_small fine-tuned + hyperparameter tuning (Optuna) → test macro-F1 0,78, accuracy 0,80. Embedding + index katalog dibuat & dievaluasi (Recall@1 style-similarity 0,81; instance-retrieval "scan lukisan" 90% top-1). Model diekspor ke TorchScript+ONNX (`ml-visual-search/export/`), terverifikasi cocok dengan PyTorch asli. Demo scan interaktif (upload file + live webcam) di `ml-visual-search/notebooks/03_demo_inference.ipynb`, termasuk `confidence_verdict` (confirmed/ambiguous/not_found) supaya tidak overclaim hasil kecocokan katalog.
- 🔄 **Sedang dikerjakan:** skeleton `backend/` (FastAPI) & `mobile/` (Flutter) sudah di-scaffold, logic/UI belum diisi.
- ⏳ Belum dikerjakan: implementasi AR (ARCore/ARKit), `ml-digital-art-identity/` (unique-key crypto + deteksi gambar AI-generated — scaffold folder sudah ada), integrasi backend↔mobile, chatbot n8n.

## Rencana Teknis Model (untuk Visual Search & basis Digital Art Identity)

- **Arsitektur:** ResNet50 pretrained (ImageNet) → freeze layer awal, fine-tune `layer4` + `fc` untuk klasifikasi 12 kelas style (setelah exclude minoritas) sebagai pretext task.
  - _Backbone configurable_ (`ml-visual-search/configs/config.yaml` → `model.name`): resnet50/101, convnext_tiny/small/base, efficientnet_v2_s, swin_v2_t, vit_b_16. **Dipilih: convnext_small** (dibanding ResNet50 baseline) — dataset 5.6k gambar cukup untuk convnext_small tanpa overfit berlebihan; convnext_base/large TIDAK dipakai (kapasitas kebesaran utk dataset ini, VRAM 4GB laptop, embedding lebih gemuk tanpa manfaat jelas).
- **Setelah training:** buang classifier head, ambil output penultimate layer sebagai embedding vector untuk similarity search & fingerprinting.
- **Augmentasi (train only):** Resize(256) → RandomCrop(224) → RandomHorizontalFlip(p=0.5) → ColorJitter ringan → RandomRotation(10°) → Normalize (mean/std ImageNet standar. **HINDARI vertical flip dan cutout agresif** — merusak makna komposisi/detail gaya lukisan.
- **Mitigasi imbalance:** `WeightedRandomSampler` berdasarkan inverse frekuensi kelas di training set.
- **Kandidat alternatif/pembanding (opsional):** CLIP pretrained sebagai baseline embedding tanpa fine-tuning, untuk dibandingkan hasilnya dengan ResNet50 fine-tuned.

## Riwayat Keputusan Penting (kronologis, untuk konteks "kenapa begini")

1. Nama produk berubah dari **ArtKey** → **GALERIA** (nama lama masih mungkin muncul di aset/dokumen lama).
2. Fitur **Estimasi Harga Jual** sempat direncanakan lengkap dengan Art Price Dataset, lalu **dihapus total dari scope** — jangan bangun ulang fitur ini kecuali ada instruksi eksplisit sebaliknya.
3. Istilah **"Hak Paten"** untuk Digital Art Identity diganti jadi **"sertifikat digital keaslian"** di semua materi user-facing.
4. WikiArt dipilih sebagai satu-satunya dataset visual (bukan gabungan banyak dataset) untuk menjaga fokus dan koherensi arsitektur model.
5. Proses download WikiArt penuh (81rb gambar / ~37GB) terbukti tidak realistis untuk kecepatan internet tim → strategi diubah ke **download per-shard via `hf_hub_download`** (1 file ~450-500MB, bukan `load_dataset` yang mencoba download semua file sekaligus meski di-slice).

## Batasan & Hal yang Harus Selalu Dijaga Kejujurannya

- Jangan overclaim akurasi model (riset serupa di literatur ~80%, banyak faktor pasar/subjektif yang tidak tertangkap data).
- Jangan klaim AR/Visual Search/Digital Art Identity sebagai "dibuat dari nol" — jujurkan mana yang transfer learning, mana yang SDK pihak ketiga, mana yang wrapping API.
- Selalu sebutkan keterbatasan representativeness dataset (1 dari 72 shard) di laporan/dokumentasi teknis apa pun yang menyinggung performa model.
- Digital Art Identity ≠ deteksi pemalsuan fisik karya seni — hanya deteksi duplikasi digital di platform.
