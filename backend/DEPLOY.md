# Deploy backend GALERIA (Google Cloud Run)

Hasil: HP memanggil `https://<layanan>.run.app` -- tanpa laptop, USB, atau `adb reverse`.
Image berisi backend + model v4 (ONNX, ~190 MB; file ini tidak ada di git, jadi deploy
dijalankan dari mesin yang punya `ml-visual-search/export/v4_11class/`).

## Sekali saja
1. Akun Google Cloud + proyek + billing aktif (Cloud Run punya tingkat gratis).
2. Pasang gcloud CLI, lalu: `gcloud auth login` dan `gcloud config set project <ID_PROYEK>`.
3. Aktifkan API: `gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com`

## Deploy (dari root repo)
```
gcloud run deploy galeria-api --source . --region asia-southeast2 ^
  --memory 2Gi --cpu 2 --allow-unauthenticated --port 8080 ^
  --set-env-vars "VS_STYLE_ABSTAIN_T=0.70,REKOMENDASI_SCHEMA=dummy_rekomendasi,PAYMENT_MODE=sandbox" ^
  --set-secrets "DATABASE_URL=DATABASE_URL:latest,JWT_SECRET=JWT_SECRET:latest,SIGNING_PRIVATE_KEY_V1=SIGNING_PRIVATE_KEY_V1:latest,ADMIN_EMAIL=ADMIN_EMAIL:latest,ADMIN_PASSWORD_HASH=ADMIN_PASSWORD_HASH:latest,ADMIN_JWT_SECRET=ADMIN_JWT_SECRET:latest,R2_ENDPOINT=R2_ENDPOINT:latest,R2_ACCESS_KEY_ID=R2_ACCESS_KEY_ID:latest,R2_SECRET_ACCESS_KEY=R2_SECRET_ACCESS_KEY:latest,R2_BUCKET=R2_BUCKET:latest,R2_PUBLIC_URL_BASE=R2_PUBLIC_URL_BASE:latest"
```

### Rahasia yang WAJIB ada di server (nilainya dari `backend/.env`)
| Rahasia | Kalau tidak ada |
|---|---|
| `DATABASE_URL` | semua endpoint data gagal (format `postgresql+asyncpg://...?ssl=require`) |
| `JWT_SECRET` | login/daftar gagal; HARUS tetap sama antar-deploy (kalau berubah, semua pengguna ter-logout) |
| `SIGNING_PRIVATE_KEY_V1` | **membuat pesanan/transaksi gagal (503)** -- harus key yang SAMA dengan yang tercatat di tabel `signing_keys` |
| `R2_ENDPOINT`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET` | unggah karya jatuh ke disk lokal container yang HILANG saat instance mati |
| `R2_PUBLIC_URL_BASE` | gambar tidak punya URL publik |
| `ADMIN_EMAIL`, `ADMIN_PASSWORD_HASH`, `ADMIN_JWT_SECRET` | login dashboard admin web gagal |

**Jangan set `MEDIA_MODE=public` dulu**: `r2.dev` terblokir DNS di sebagian provider Indonesia, jadi gambar dibiarkan lewat `/api/media` (backend mengambil dari R2). Ganti ke `public` hanya setelah R2 punya custom domain.

Opsional: `GOOGLE_OAUTH_CLIENT_ID` (login Google), `CORS_ORIGINS`, `ADMIN_*` (dashboard admin), `KOMISI_PERSEN`.
`PAYMENT_MODE=sandbox` = pembayaran SIMULASI (belum ada gateway/uang sungguhan).

### Migrasi database
Server TIDAK menjalankan Alembic sendiri. Jalankan dari laptop (menunjuk Neon yang sama) SEBELUM deploy versi yang menambah tabel:
`cd backend && .venv\Scripts\python.exe -m alembic upgrade head` (sekarang di `0015_edit_karya_keranjang`).

### Batasan Cloud Run yang perlu disadari
- **Disk container tidak permanen**: semua file yang harus awet (gambar karya) wajib di R2, bukan `uploads/`.
- **Pembatas percobaan login ada di memori per instance**: dengan banyak instance, batasnya tidak dibagi. Cukup untuk MVP; untuk rilis pakai Redis atau tabel DB.
- **Cold start**: instance idle dimatikan, permintaan pertama setelah sepi lambat karena model ONNX dimuat. Untuk demo/presentasi pasang `--min-instances 1` (berbayar kecil) supaya selalu hangat.
- Model sentimen ringan (`backend/artifacts/sentimen_tfidf.json`) ikut ter-bake ke image; ganti dengan `SENTIMEN_MODEL_PATH` bila perlu.
(`^` = lanjut baris di CMD; di PowerShell pakai backtick, di bash pakai `\`.)

Rahasia dibuat dulu di Secret Manager (nilai diambil dari `backend/.env`, JANGAN ditulis di repo):
```
echo -n "<nilai>" | gcloud secrets create DATABASE_URL --data-file=-
echo -n "<nilai>" | gcloud secrets create R2_PUBLIC_URL_BASE --data-file=-
```
Beri akun layanan Cloud Run izin `Secret Manager Secret Accessor`.

Variabel lain yang dibaca backend (isi bila fiturnya dipakai): `GAMBAR_PROXY_BASE`
(= `https://<layanan>.run.app/api/gambar`, diisi SETELAH URL layanan diketahui, lewat
`gcloud run services update galeria-api --update-env-vars GAMBAR_PROXY_BASE=...`),
`JWT_SECRET`, `R2_*`.

## Setelah deploy
- Cek: `https://<layanan>.run.app/docs` terbuka dan `/api/katalog` mengembalikan data.
- Jalankan app: `flutter run --dart-define=API_BASE_URL=https://<layanan>.run.app`
  (APK rilis: tanam nilai yang sama lewat `--dart-define` saat `flutter build apk`).
- Instance idle dimatikan; permintaan pertama setelah sepi butuh beberapa detik (cold start).

## Catatan
- `allow_origins=["*"]` di `main.py` masih longgar -- persempit sebelum rilis.
- Neon harus mengizinkan koneksi dari Cloud Run (default Neon terbuka; pakai `?ssl=require`).
- Uji lokal image: `docker build -t galeria-api .` lalu
  `docker run --env-file backend/.env -p 8000:8080 -e PORT=8080 galeria-api`.


## Urutan deploy seluruh sistem (backend, dashboard web, aplikasi)
1. Migrasi Neon sampai head (`alembic upgrade head`).
2. Rahasia ke Secret Manager (termasuk `ADMIN_*`), lalu `gcloud run deploy` backend -> catat URL.
3. Set `GAMBAR_PROXY_BASE=https://<URL>/api/gambar` (`gcloud run services update ... --update-env-vars`). Wajib: tanpa ini gambar katalog dummy menunjuk ke `r2.dev` yang terblokir di sebagian provider.
4. Cek `/docs`, `/api/katalog`, daftar+login, dan buat satu pesanan (menguji `SIGNING_PRIVATE_KEY_V1`).
5. Build dashboard dengan `VITE_API_BASE=https://<URL>`, unggah `dist/` ke hosting statis -> catat alamatnya.
6. Set `CORS_ORIGINS=<alamat dashboard>` di backend; cek login admin.
7. Build APK dengan `--dart-define=API_BASE_URL=https://<URL>`; uji di HP lewat data seluler.
8. Sebelum presentasi `--min-instances 1`; sesudahnya kembalikan ke 0.
