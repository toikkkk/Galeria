# mobile/ — Aplikasi Mobile GALERIA (Flutter)

Project Flutter sudah di-scaffold (`flutter create`, Flutter 3.38, Dart 3.10).
Target platform utama: **Android (ARCore) & iOS (ARKit)** — folder `linux/`,
`macos/`, `windows/`, `web/` ikut ke-generate default oleh Flutter, boleh
diabaikan/dihapus kalau memang tidak dipakai.

## Cara jalan

```bash
cd mobile
flutter pub get
flutter run                 # pilih device/emulator yang aktif
```

⚠️ **Setup Android SDK/emulator/JDK (sampai `flutter run` jalan)**: lihat
panduan lengkap step-by-step + tabel troubleshooting di
[`docs/SETUP_ANDROID.md`](docs/SETUP_ANDROID.md) — mencakup instalasi SDK
Command-line Tools, bikin emulator (AVD), dan fix konflik JDK vs Gradle yang
paling sering muncul (`flutter config --jdk-dir=...`).

### Menyambungkan ke `backend/` (Katalog & Visual Search)

Fitur yang bergantung ke backend (Beranda Kolektor, Pindai/Visual Search)
manggil `http://127.0.0.1:8000` (lihat `lib/services/api_client.dart`).
Karena HP kita terhubung ke laptop lewat **USB** (bukan WiFi), sambungkan
port itu lewat `adb reverse` — jalankan ini **setiap kali HP baru
disambungkan / adb baru di-restart**, SEBELUM `flutter run`:

```bash
adb reverse tcp:8000 tcp:8000
```

Lalu pastikan backend jalan di terminal terpisah (`cd backend && uvicorn
main:app --reload --port 8000`, lihat `backend/README.md`) sebelum test fitur
ini di HP. Kalau backend mati/tidak sengaja lupa `adb reverse`, app **tidak
crash** — Beranda Kolektor diam-diam fallback ke data contoh lokal
(`sampleKarya`), tapi Visual Search akan tampilkan pesan error via SnackBar.

## Rencana fitur & pemetaan ke backend

| Fitur | Peran mobile | Sumber data |
|---|---|---|
| Marketplace / lelang | Browse, detail karya, checkout | `backend` `/api/katalog`, `/api/karya/{id}` |
| **Visual Search** | Ambil foto kamera/galeri → kirim ke backend → tampilkan karya mirip + status yakin/tidak | `backend` `POST /api/visual-search` (lihat `backend/schemas/visual_search.py` utk bentuk response — field `verdict`: **tampilkan apa adanya**, jangan klaim "pasti sama" kalau `verdict != "confirmed"`) |
| **AR Simulation** | SDK ARCore (Android) / ARKit (iOS) — plane detection + scale, pakai metadata ukuran fisik karya (cm) | Input manual dari form upload karya (bukan hasil model) |
| Chatbot | Wrapper API GPT via n8n | endpoint terpisah (belum ada) |

## Struktur `lib/`

```
lib/
├── main.dart        entrypoint + routing (go_router), semua layar seniman & kolektor
├── screens/         halaman per role (auth/, dashboard/, karya/, kolektor/, onboarding/, profile/, community/)
├── widgets/         komponen UI reusable (kartu karya, bottom nav, camera preview, dll)
├── services/        API client ke backend/ (api_client, katalog_service, visual_search_service)
├── models/          data class (Karya, Lelang, EventPameran, Notifikasi)
└── theme/           design tokens (AppColors/AppSpacing/AppTextStyles) dari hasil UI/UX
```
