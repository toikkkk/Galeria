# CLAUDE.md — GALERIA

Konteks proyek untuk Claude Code. Baca file ini sebelum mengerjakan task apa pun di repo ini.

## Ringkasan Proyek

**Nama produk:** GALERIA (sebelumnya bernama "ArtKey" — nama lama ini masih mungkin muncul di beberapa dokumen/aset lama, abaikan, pakai "GALERIA" untuk semua materi baru).

**Judul lengkap (akademik):** GALERIA — Platform Cerdas Berbasis Agentic Artificial Intelligence, Augmented Reality, dan Kriptografi dengan Digital Art Identity untuk Autentikasi dan Perdagangan Karya Seni

**Deskripsi singkat:** Platform e-commerce/marketplace + lelang untuk lukisan, patung, dan karya seni lain, dengan diferensiasi utama pada sistem verifikasi keaslian karya berbasis digital fingerprinting, ditambah fitur AI/computer vision untuk pencarian visual dan simulasi AR.

**Konteks akademik:** Proyek kelompok (PBL/tugas kuliah, prodi Sains Data Terapan, PENS). Harus punya nilai jual B2B/B2C yang jelas dan komponen AI/computer vision yang genuinely defensible — bukan sekadar fitur tempelan.

**Konteks komersial (PENTING — mempengaruhi banyak keputusan teknis):** Proyek ini TIDAK berhenti di tugas akademik. Rencana pasti: **rilis ke Google Play Store sebagai aplikasi mobile berbayar/komersial**. Karena itu, semua keputusan arsitektur (database, storage, auth, deploy) diambil dengan asumsi production traffic real user, bukan demo lokal. Contoh konkret: pilih Neon+R2 (bukan SQLite lokal), custom JWT+refresh token (bukan session cookie stateless demo), R2 zero-egress fee (kritis untuk app yang serving gambar berulang ke user Play Store).

## Core Aplikasi — Arsitektur Global

Aplikasi target = **mobile Android (Flutter)**, backend terpisah, model ML jalan di server (bukan on-device).

```
┌─────────────────────┐         ┌──────────────────────┐         ┌─────────────────┐
│  mobile/ (Flutter)  │ ──HTTPS─▶│  backend/ (FastAPI) │ ──SQL──▶│  Neon Postgres  │
│  - UI 5 role screens│  JWT     │  - REST API         │         │  (+ pgvector)   │
│  - google_sign_in   │  Bearer  │  - ONNXRuntime      │         └─────────────────┘
│  - secure_storage   │          │  - auth (bcrypt/JWT)│         ┌─────────────────┐
│  - camera/AR SDK    │          │  - inference CV     │ ──S3───▶│  Cloudflare R2  │
└─────────────────────┘          └──────────────────────┘  API   │  (image files)  │
                                          │                      └─────────────────┘
                                          ├── ml-visual-search/  (ONNX encoder + index katalog)
                                          └── ml-digital-art-identity/  (pHash + AI-detect)
```

**Prinsip pemisahan:**
- **Model ML TIDAK ke-bundle di APK** — ukuran & update model harus lewat backend, bukan Play Store release baru.
- **Gambar TIDAK disimpan di database** — hanya URL/key R2 di kolom Postgres. R2 dipilih karena **zero egress fee** (kritis: 1 karya bisa di-load ribuan kali oleh viewer, egress traffic AWS S3 akan mahal cepat).
- **Auth stateful (dengan JWT + refresh)** — walaupun JWT stateless, kita simpan refresh token & session di DB supaya bisa revoke (logout paksa, ban user, dll).

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

## Backend & Database

### Stack Terpilih
- **Backend framework:** FastAPI (Python) — sudah scaffold di `backend/`.
- **Database:** **Neon** (serverless PostgreSQL, managed). Alasan: tim sudah familiar, connection pooling built-in, database branching (bisa bikin branch dev/staging tanpa provision instance baru), free tier cukup untuk MVP, scaling ke paid tier lancar untuk production Play Store.
- **Extension Postgres yang dipakai:** `pgvector` — untuk simpan embedding karya (output CNN dari `ml-visual-search/`) langsung di DB & lakukan nearest-neighbor search via `<->` operator. Ini menggantikan kebutuhan FAISS terpisah untuk skala awal (kalau nanti > 100k karya, migrate ke FAISS/dedicated vector DB baru dipertimbangkan).
- **ORM & Migration:** SQLAlchemy 2.0 (async) + Alembic (migration versioning). Standard industri, well-documented, bagus untuk audit trail schema change.
- **File storage:** **Cloudflare R2** (S3-compatible). Alasan: **zero egress fee** (kritis untuk aplikasi image-heavy di Play Store — user scroll katalog = download gambar berulang), harga storage kompetitif, kompatibel dengan library boto3/aioboto3 (S3 SDK biasa).

### Alternatif yang Dipertimbangkan & Ditolak
- **Supabase** (Postgres+Storage+Auth all-in-one): ditolak karena storage-nya bukan zero egress (jadi mahal untuk skala Play Store), dan tim lebih terbiasa Neon+R2.
- **Firebase**: ditolak karena vendor lock-in (NoSQL Firestore susah utk relasi kompleks marketplace), plus egress juga tidak gratis.
- **SQLite lokal / server VPS + Postgres self-hosted**: ditolak karena bukan production-grade untuk Play Store (backup, HA, scaling manual).

### Skema Data Utama (draft, belum diimplementasi)
Tabel utama yang akan ada di `backend/`:
- `users` — akun (multi-role: seniman, kolektor, komunitas, admin)
- `karya` — metadata karya seni (judul, deskripsi, harga, ukuran fisik cm untuk AR, seniman_id, status verifikasi, image_key ke R2)
- `karya_embeddings` — vector `pgvector` (dim = output encoder ml-visual-search) untuk similarity search
- `karya_fingerprints` — pHash + hash lain dari ml-digital-art-identity untuk deteksi duplikasi
- `transaksi` — order/pembayaran (komisi platform)
- `events` — event komunitas (pameran, lelang) — untuk role komunitas
- `auth_sessions` — refresh token & device tracking (untuk logout paksa)

**Aturan file layout:** File .env berisi `DATABASE_URL` (Neon connection string dengan `?sslmode=require`), `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET`, `R2_ENDPOINT`, `JWT_SECRET`, `GOOGLE_OAUTH_CLIENT_ID` — **wajib di-gitignore**, gunakan `backend/.env.example` sebagai template.

## Autentikasi

### Stack Terpilih
- **Custom auth di FastAPI** (bukan Auth0/Clerk/Firebase Auth). Alasan: kontrol penuh atas UX (form register + verifikasi + role selection sudah didesain di Stitch), biaya nol per-MAU (Auth0 mahal di skala Play Store), tim familiar dengan JWT.
- **Password hashing:** `bcrypt` (via `passlib[bcrypt]`) — cost factor 12.
- **Token:** JWT (access token pendek 15 menit + refresh token panjang 30 hari, refresh disimpan di `auth_sessions` supaya bisa revoke).
- **Library JWT backend:** `python-jose[cryptography]` atau `pyjwt` (belum diputuskan, pilih saat implementasi).
- **Storage token di mobile:** `flutter_secure_storage` (Android Keystore, bukan SharedPreferences plain).

### Provider Login yang Didukung
1. **Email + Password** — jalur utama, custom implementation.
2. **Google Sign-In** — provider OAuth kedua. **Wajib ada** karena user Play Store expect "Login dengan Google" sebagai one-tap experience.
   - Flutter: package `google_sign_in` → dapat Google ID token → kirim ke backend.
   - Backend: verify ID token pakai library `google-auth` (`google.oauth2.id_token.verify_oauth2_token`) → ambil `sub`, `email`, `email_verified`, `name`, `picture` → cari atau create user → issue JWT kita sendiri.
3. **(Opsional masa depan)** Apple Sign-In — kalau ekspansi ke iOS App Store (App Store review mewajibkan Apple Sign-In kalau ada Google Sign-In).

### Skema Coexistence Email + Google (Pola A — single users table)
```
users:
  id                UUID PRIMARY KEY
  email             CITEXT UNIQUE NOT NULL
  password_hash     TEXT NULL       -- NULL kalau Google-only user
  google_sub        TEXT UNIQUE NULL  -- Google 'sub' claim, stabil selamanya
  display_name      TEXT
  avatar_url        TEXT
  role              ENUM('seniman', 'kolektor', 'komunitas', 'admin')
  email_verified    BOOLEAN DEFAULT false
  created_at, updated_at
```
- Register email/password → isi `password_hash`, `google_sub` NULL.
- Login Google pertama kali dengan email yang sudah ada → link akun (isi `google_sub` di row yang sama, jangan bikin duplikat user).
- Login Google user baru → auto-create user dengan `password_hash` NULL, `google_sub` diisi, `email_verified=true` (Google sudah verify email-nya).

Pola B (tabel `auth_providers` terpisah) **sengaja tidak dipakai sekarang** — cuma worth it kalau nanti ada 3+ provider (Apple, Facebook, dll). Kalau kebutuhan itu muncul, migrasi ke Pola B via Alembic.

### Yang Perlu Disiapkan Sebelum Implementasi Google Sign-In
- **Google Cloud Console:** bikin OAuth 2.0 Client ID (tipe Android + Web) — Client ID Web dipakai sebagai `audience` di verifier backend, Client ID Android dipakai di Flutter.
- **SHA-1 fingerprint** APK (debug keystore & release keystore) — daftarkan di Google Console. Salah SHA-1 = Google Sign-In di HP langsung gagal tanpa error jelas.
- **Domain verification** kalau nanti ada web version (belum relevan, aplikasi mobile-first).

### Aturan Kejujuran Auth
- **Jangan pernah** klaim "enkripsi end-to-end" atau "zero-knowledge" — password kita bcrypt-hash di server (standar aman, tapi bukan E2E).
- Token access **jangan** disimpan di SharedPreferences plain / localStorage-equivalent — wajib `flutter_secure_storage` (Android Keystore).
- **Jangan** simpan Google ID token setelah verifikasi awal — dipakai sekali untuk verify identitas, lalu buang. Session selanjutnya pakai JWT kita sendiri.

## Status Progress Saat Ini

- ✅ EDA WikiArt subset selesai (cleaning, distribusi kelas, ukuran, korelasi label, split, augmentasi) — `ml-visual-search/notebooks/eda_wikiart.ipynb`
- ✅ Data Card selesai dibuat
- ✅ **Modeling Visual Search selesai** (`ml-visual-search/`): dataset diperluas ke 5.659 gambar (shard 0-4, 11 kelas style setelah exclude minoritas), convnext_small fine-tuned + hyperparameter tuning (Optuna) → test macro-F1 0,78, accuracy 0,80. Embedding + index katalog dibuat & dievaluasi (Recall@1 style-similarity 0,81; instance-retrieval "scan lukisan" 90% top-1). Model diekspor ke TorchScript+ONNX (`ml-visual-search/export/`), terverifikasi cocok dengan PyTorch asli. Demo scan interaktif (upload file + live webcam) di `ml-visual-search/notebooks/03_demo_inference.ipynb`, termasuk `confidence_verdict` (confirmed/ambiguous/not_found) supaya tidak overclaim hasil kecocokan katalog.
- ✅ **UI Flutter — Seniman (14/24 layar Stitch role seniman)** — konversi dari desain HTML/Tailwind Google Stitch ke Flutter widget: 9 layar ROLE SENIMAN 1 (onboarding, login, register, dashboard, komunitas, profil) + 5 layar ROLE SENIMAN 2 (unggah karya, verifikasi keaslian, karya terverifikasi/ditolak/perlu ditinjau). Berjalan real di HP Android (vivo 1919) — lihat `mobile/docs/SETUP_ANDROID.md`.
- ✅ **UI Flutter — Kolektor (21 layar)** — auth (daftar, preferensi genre), beranda, katalog karya (semua karya, detail, profil toko), lelang (list, detail, pasang bid), event (list, checkout tiket, e-tiket), pesanan (daftar, konfirmasi, pembayaran, selesai), koleksi saya, notifikasi, profil, scan (AR ruangan + visual search camera). Semua layar (seniman + kolektor) ter-wire dengan `go_router`, `flutter analyze` bersih, `flutter test` pass.
- ✅ **Backend Visual Search + database (Fase 1) selesai** (`backend/`): FastAPI + Neon Postgres (pgvector), endpoint `POST /api/visual-search` & `GET /api/katalog`/`GET /api/karya/{id}` sudah jalan (bukan skeleton lagi). Model ONNX di-load sekali saat startup, preprocessing (SquarePad+resize+normalize) pure numpy/PIL (server tidak perlu PyTorch). Katalog embedding disimpan di tabel `karya_embeddings` (pgvector, cosine distance), bukan lagi file `.npz` statis. 8 karya contoh (sama seperti `mobile/lib/models/karya.dart`) tersedia lewat `scripts/seed_karya.py`. **Catatan koreksi:** dimensi embedding yang benar **768** (convnext_small), bukan 2048 seperti tertulis di komentar lama `ml-visual-search/configs/config.yaml` (sisa baseline ResNet50) — sudah diverifikasi langsung dari graph ONNX.
- 🔄 **Sedang dikerjakan:** integrasi `mobile/lib/models/karya.dart` untuk fetch dari `GET /api/katalog` asli (masih pakai `sampleKarya` hardcoded). Auth (JWT + Google Sign-In), Cloudflare R2, tabel `users`/`transaksi`/`events`/`auth_sessions`: **arsitektur sudah diputuskan** (lihat section Backend/Database & Autentikasi di atas), implementasi belum dimulai (fase berikutnya setelah Visual Search).
- ⏳ Belum dikerjakan: 10 layar Stitch role Seniman sisa (Event mgmt ×5, Order mgmt ×3, Shop profile ×1, Promote artwork ×1 — domain terpisah dari 21 layar Kolektor di atas, belum tentu overlap, cek ulang `docs/design/` sebelum asumsi), implementasi AR (ARCore/ARKit nyata — layar `ar_ruangan_screen.dart` masih UI-only), `ml-digital-art-identity/` (unique-key crypto + deteksi gambar AI-generated — scaffold folder sudah ada), `style_predictions` di response Visual Search (butuh re-export ONNX dgn output logit tambahan), chatbot n8n.

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
6. Proyek diputuskan **untuk dirilis ke Google Play Store secara komersial**, bukan berhenti di demo akademik — mempengaruhi semua keputusan infrastruktur (production-grade stack, bukan lokal/demo).
7. **Stack backend/DB/storage:** Neon (Postgres+pgvector) + Cloudflare R2 (S3-compatible, zero egress). Supabase & Firebase dipertimbangkan tapi ditolak (alasan detail di section Backend/Database).
8. **Auth:** custom FastAPI (email+bcrypt+JWT+refresh) — bukan Auth0/Clerk/Firebase Auth. Alasan: kontrol UX (form Stitch sudah didesain), biaya nol per-MAU, tim familiar JWT.
9. **Login Google (`google_sign_in` di Flutter + `google-auth` verifier di backend)** ditambahkan sebagai provider kedua wajib — user Play Store expect one-tap Google login. Skema coexistence pakai Pola A (single `users` table dengan `google_sub` nullable).

## Batasan & Hal yang Harus Selalu Dijaga Kejujurannya

- Jangan overclaim akurasi model (riset serupa di literatur ~80%, banyak faktor pasar/subjektif yang tidak tertangkap data).
- Jangan klaim AR/Visual Search/Digital Art Identity sebagai "dibuat dari nol" — jujurkan mana yang transfer learning, mana yang SDK pihak ketiga, mana yang wrapping API.
- Selalu sebutkan keterbatasan representativeness dataset (1 dari 72 shard) di laporan/dokumentasi teknis apa pun yang menyinggung performa model.
- Digital Art Identity ≠ deteksi pemalsuan fisik karya seni — hanya deteksi duplikasi digital di platform.
