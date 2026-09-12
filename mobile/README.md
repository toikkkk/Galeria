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

⚠️ **Catatan environment**: saat `flutter create`, muncul peringatan Java
(26.0.0) vs Gradle (8.14) berpotensi konflik untuk build Android. Kalau
`flutter run`/build Android gagal karena ini:
```bash
flutter config --jdk-dir=<path ke JDK 17-24>
```

## Rencana fitur & pemetaan ke backend

| Fitur | Peran mobile | Sumber data |
|---|---|---|
| Marketplace / lelang | Browse, detail karya, checkout | `backend` `/api/katalog`, `/api/karya/{id}` |
| **Visual Search** | Ambil foto kamera/galeri → kirim ke backend → tampilkan karya mirip + status yakin/tidak | `backend` `POST /api/visual-search` (lihat `backend/schemas/visual_search.py` utk bentuk response — field `verdict`: **tampilkan apa adanya**, jangan klaim "pasti sama" kalau `verdict != "confirmed"`) |
| **AR Simulation** | SDK ARCore (Android) / ARKit (iOS) — plane detection + scale, pakai metadata ukuran fisik karya (cm) | Input manual dari form upload karya (bukan hasil model) |
| Chatbot | Wrapper API GPT via n8n | endpoint terpisah (belum ada) |

## Konvensi struktur `lib/` (isi menyusul saat konversi UI/UX → kode)

```
lib/
├── main.dart        (bawaan Flutter, ganti sesuai desain)
├── screens/         halaman (Home, DetailKarya, VisualSearchScan, dll)
├── widgets/         komponen UI reusable (kartu karya, tombol, dll)
├── services/        API client ke backend/ (visual_search_service.dart, dll)
├── models/          data class (Karya, StylePrediction, CatalogMatch — cermin backend/schemas/)
└── theme/           design tokens (warna/font) dari hasil UI/UX
```

Belum dibuatkan filenya (menunggu desain UI/UX asli) — struktur ini cuma
konvensi supaya konsisten begitu mulai konversi.
