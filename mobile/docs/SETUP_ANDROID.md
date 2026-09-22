# Setup Android Studio & SDK — sampai `flutter run` jalan di HP Android

Panduan ini disusun dari pengalaman setup nyata di proyek GALERIA (Windows 11,
Android Studio versi terbaru dengan SDK 36+). Fokus ke **HP Android fisik**
(bukan emulator) — lebih simpel, lebih cepat, dan lebih representatif untuk
fitur AR (ARCore sering terbatas/tidak jalan optimal di emulator).

Ikuti urut dari atas — beberapa langkah sengaja mencatat masalah yang
benar-benar ditemui + solusinya, supaya anggota tim lain tidak perlu debug
ulang dari nol.

## Prasyarat

- Android Studio sudah terpasang (kalau belum, download dari
  [developer.android.com/studio](https://developer.android.com/studio)) —
  dibutuhkan untuk SDK & build tools, walau kita tidak pakai emulatornya.
- Flutter SDK sudah terpasang dan `flutter doctor` bisa dijalankan dari terminal.
- HP Android fisik + kabel USB data (bukan kabel charging-only).
- VS Code + extension **Dart-Code.flutter** (opsional tapi disarankan).

---

## 1. Install Android SDK Command-line Tools

`flutter doctor` butuh komponen ini, dan biasanya **belum otomatis terpasang**
walau Android Studio sendiri sudah ke-install.

1. Buka Android Studio → **More Actions → SDK Manager** (atau **Tools → SDK
   Manager** kalau sudah ada project terbuka).
2. Klik tab **"SDK Tools"** (bukan "SDK Platforms" — beda tab, sering
   ketuker).
3. Centang **"Android SDK Command-line Tools (latest)"**.
4. Klik **Apply** → tunggu download & instalasi selesai.

Cek hasilnya:
```bash
flutter doctor
```
Baris "Android toolchain" seharusnya tidak lagi menampilkan
`X cmdline-tools component is missing`.

## 2. Terima lisensi SDK

```bash
flutter doctor --android-licenses
```
Tekan `y` Enter untuk tiap prompt lisensi yang muncul (biasanya 5-7 halaman).

> **Catatan (SDK versi sangat baru):** di SDK Command-line Tools versi
> terbaru, perintah ini kadang cuma menampilkan
> `Warning: The --licenses option is no longer needed` tanpa proses apa pun —
> tool lisensi lama (`sdkmanager`) sudah digantikan tool baru bernama
> `android` yang menangani ini secara berbeda. Kalau ini terjadi ke kamu:
> **abaikan saja**, lanjut ke langkah berikutnya. `flutter doctor` mungkin
> tetap menampilkan `X Android license status unknown` secara permanen — ini
> **false-positive** yang tidak menghalangi build/run, selama `flutter
> devices` sudah mendeteksi HP kamu dengan benar (lihat langkah 3).

## 3. Aktifkan Developer Mode & sambungkan HP

1. Di HP: **Settings → About Phone** (Tentang Ponsel) → cari **"Build
   Number"** (Nomor Build) → ketuk **7 kali berturut-turut** sampai muncul
   notifikasi "You are now a developer".
2. Balik ke **Settings**, buka menu baru **"Developer Options"** (biasanya di
   bawah "System" atau dekat "About Phone") → aktifkan toggle **"USB
   Debugging"**.
3. Sambungkan HP ke laptop pakai kabel USB data.
4. Di HP akan muncul popup **"Allow USB debugging?"** dengan fingerprint
   komputer — centang **"Always allow from this computer"** → **Allow/OK**.
5. Verifikasi dari terminal:
   ```bash
   flutter devices
   ```
   HP kamu harus muncul dengan nama aslinya (misal `vivo 1919`), bukan
   `emulator-xxxx`.

## 4. Perbaiki konflik JDK vs Gradle (kalau build gagal)

Android Studio versi terbaru sering bundling JDK yang **lebih baru dari yang
didukung Gradle**. Gejalanya: `flutter run` sampai tahap
`Running Gradle task 'assembleDebug'...` lalu gagal dengan pesan aneh
(contoh nyata: `BUILD FAILED`, "What went wrong: 25.0.2" — itu sebenarnya
nomor versi JDK, bukan pesan error yang jelas). Ini soal proses build APK,
**bukan soal device target** — tetap muncul walau langsung ke HP fisik.

**Solusi: install JDK 17 (LTS) terpisah, arahkan Flutter ke situ.**

Opsi A — lewat `winget` (tercepat):
```powershell
winget install EclipseAdoptium.Temurin.17.JDK
```
Setelah selesai, cek folder instalasinya:
```powershell
dir "C:\Program Files\Eclipse Adoptium"
```

Opsi B — lewat Android Studio (tanpa keluar aplikasi):
1. Buka folder `mobile/android` sebagai project di Android Studio (atau
   project lain yang sudah terbuka).
2. **File → Settings → Build, Execution, Deployment → Build Tools → Gradle**.
3. Dropdown **"Gradle JDK"** → pilih **"Download JDK..."**.
4. Version **17**, Vendor **Eclipse Temurin** → **Download**.
5. Catat path yang muncul (biasanya `C:\Users\<user>\.jdks\temurin-17.x.x`).

Setelah punya path JDK 17 (dari opsi A atau B), arahkan Flutter ke situ:
```powershell
flutter config --jdk-dir="<path-JDK-17-yang-benar>"
```
⚠️ **Ganti path placeholder dengan nama folder ASLI** yang ada di komputer
kamu (`dir` dulu untuk cek) — Flutter tidak akan error kalau kamu salah ketik
path yang tidak ada, cuma diam-diam gagal nanti saat build.

## 5. Jalankan aplikasi

```bash
cd mobile
flutter run
```
Kalau ada lebih dari satu device terdeteksi (HP + Windows desktop + Chrome),
pilih nomor HP-nya dari daftar yang muncul.

Build pertama kali lama (Gradle download dependency + compile penuh, bisa
beberapa menit). Build berikutnya jauh lebih cepat (Gradle cache).

Kalau di tengah proses build yang lama HP sempat terkunci/kabel goyang dan
muncul error `adb.exe: device '<id>' not found` saat instalasi APK padahal
build-nya sukses — buka kunci HP, pastikan kabel tersambung kencang, lalu
`flutter run` ulang (build kedua sudah cepat karena cache).

## Ringkasan masalah yang pernah ditemui (cepat cari solusinya)

| Gejala | Penyebab | Solusi |
|---|---|---|
| `X cmdline-tools component is missing` | Command-line Tools belum di-install | Langkah 1 |
| `X Android license status unknown` (menetap terus) | SDK versi baru, cek lisensi Flutter lama tidak cocok lagi | Biasanya aman diabaikan (lihat catatan Langkah 2) — cek `flutter devices` beneran jalan dulu |
| HP tidak muncul di `flutter devices` | USB debugging belum aktif, atau popup "Allow USB debugging" belum di-Allow | Ulangi Langkah 3, cek layar HP tidak terkunci |
| `adb : term not recognized` di PowerShell | `adb` tidak ada di PATH langsung | Pakai `flutter devices`/`flutter run` (otomatis cari adb sendiri) |
| `BUILD FAILED` dgn pesan aneh mirip nomor versi (mis. "25.0.2") | JDK bawaan Android Studio kelewat baru utk Gradle | Langkah 4 |
| `adb.exe: device '<id>' not found` saat install APK (build sukses) | Koneksi USB ke HP putus di tengah build lama (layar terkunci, dll) | Buka kunci HP, cek kabel, `flutter run` ulang |
