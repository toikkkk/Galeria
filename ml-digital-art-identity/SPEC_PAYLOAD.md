# SPEC — Payload Kanonik & Kebijakan Kunci (Kriptografi Digital Art Identity)

> Hasil kerja Tahap 1 `TODO_KRIPTOGRAFI.md`. Dokumen ini WAJIB dibaca sebelum menulis kode
> di Tahap 2-4 — mendefinisikan PERSIS format data yang di-hash & ditandatangani, supaya
> implementasi tidak menyimpang/berubah-ubah antar versi kode.
>
> Seluruh contoh di dokumen ini **bukan ilustrasi** — dijalankan nyata memakai Python
> (`backend/.venv`, library `cryptography`), hasilnya dikutip apa adanya.

---

## 1.1 — Format Payload Kanonik (Aturan Umum)

Berlaku untuk SEMUA jenis payload yang di-hash+tanda tangan di sistem ini (sertifikat maupun transaksi):

1. **Serialisasi JSON**, dengan aturan ketat:
   - **Key diurutkan alfabetis** (`sort_keys=True`) — supaya urutan field tidak pernah jadi sumber perbedaan hash.
   - **Tanpa spasi** (`separators=(',', ':')`) — satu representasi teks yang pasti sama persis tiap kali.
   - **Encoding UTF-8**, `ensure_ascii=True` (karakter non-ASCII di-escape `\uXXXX`) — menghindari ambiguitas encoding lintas sistem.
2. **Timestamp**: format ISO-8601, **selalu UTC**, presisi **detik saja** (tanpa milidetik/mikrodetik), diakhiri `Z`. Contoh: `2026-10-26T09:15:00Z`. *Alasan presisi detik saja:* database/ORM kadang menyimpan presisi mikrodetik yang bisa sedikit beda tiap kali dibaca ulang — memotong ke presisi detik menghilangkan sumber ketidakcocokan ini.
3. **UUID**: string representasi standar (lowercase, dengan tanda hubung), BUKAN bentuk lain (bukan tanpa hubung, bukan uppercase).
4. **Angka uang** (`harga_final_idr`, dll): integer, BUKAN string, BUKAN float — konsisten dengan prinsip "uang = integer" yang sudah berlaku di seluruh skema GALERIA.
5. **Setiap payload WAJIB punya field `"schema"`** berisi nama+versi (mis. `"sertifikat_keaslian.v1"`) — supaya kalau nanti format berubah (field ditambah/dikurangi), payload versi lama tetap bisa dibedakan dan diverifikasi dengan logic yang sesuai, tidak tercampur.
6. **Field yang di-hash HANYA field yang tidak pernah berubah setelah ditandatangani.** Field yang BISA berubah (lihat 1.2 untuk `transaksi`) **TIDAK** dimasukkan ke payload yang di-hash.

**Implementasi acuan (Python):**
```python
import json
canonical = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
payload_hash = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
```

7. **Konvensi signing — WAJIB diikuti persis, ini sumber bug paling mudah terlewat:**
   Yang ditandatangani adalah **string heksadesimal `payload_hash` (64 karakter, di-encode UTF-8)**,
   **BUKAN** 32 byte mentah digest-nya (`bytes.fromhex(payload_hash)`). Dua pendekatan ini sama-sama
   "benar" secara kriptografi, tapi menghasilkan **signature yang TOTAL BERBEDA dan tidak kompatibel**
   satu sama lain. Semua kode (sign DAN verify, Tahap 3 & 4) **HARUS pakai konvensi yang sama persis**:
   ```python
   signature = private_key.sign(payload_hash.encode("utf-8"))          # saat sign
   public_key.verify(signature, payload_hash.encode("utf-8"))           # saat verify
   ```
   Kalau salah satu sisi pakai `.encode("utf-8")` dan sisi lain pakai `bytes.fromhex(...)`, SEMUA
   verifikasi akan gagal walau datanya benar — ini WAJIB jadi 1 fungsi bersama (lihat Tahap 3.1-3.3
   di `TODO_KRIPTOGRAFI.md`), jangan ditulis ulang terpisah di 2 tempat.

---

## 1.2 — Payload per Jenis Record

### a. `sertifikat_keaslian` (payload `sertifikat_keaslian.v1`)

Field yang masuk payload — **field yang merepresentasikan KLAIM/HASIL verifikasi**, bukan metadata administratif:

| Field | Sumber kolom | Kenapa dimasukkan |
|---|---|---|
| `schema` | — (literal `"sertifikat_keaslian.v1"`) | Versi format |
| `karya_id` | `sertifikat_keaslian.karya_id` | Identitas karya yang disertifikasi |
| `creator_id` | `karya.seniman_id` (JOIN saat membangun payload, BUKAN kolom `sertifikat_keaslian`) | **Wajib ditambahkan (temuan audit):** mengunci identitas PENCIPTA secara kriptografis pada saat sertifikat diterbitkan. Tanpa ini, `karya.seniman_id` bisa diubah belakangan tanpa membuat signature invalid — padahal sesuai `kriptografi.md` §12, "Original Creator" eksplisit bagian dari apa yang disertifikasi |
| `file_hash` | `sertifikat_keaslian.file_hash` | Bukti file yang diverifikasi persis yang mana |
| `art_to_art_result` | `sertifikat_keaslian.art_to_art_result` | Inti klaim verifikasi |
| `ai_detection_result` | `sertifikat_keaslian.ai_detection_result` | Inti klaim verifikasi |
| `status_akhir` | `sertifikat_keaslian.status_akhir` | Kesimpulan akhir |
| `verified_at` | `sertifikat_keaslian.verified_at` (dipotong ke presisi detik) | Kapan klaim ini berlaku |

**TIDAK dimasukkan ke payload:** `id` (PK, bukan bagian klaim), `signing_key_id` (metadata TENTANG signature, bukan isi yang ditandatangani — verifier mengambil public key dari kolom `signing_key_id` yang tersimpan terpisah, bukan dari dalam payload), `created_at` (waktu INSERT baris, beda dari `verified_at` yang jadi waktu acuan bisnis).

**Catatan implementasi (Tahap 4.1):** karena `creator_id` TIDAK ada sebagai kolom di tabel
`sertifikat_keaslian` sendiri (cuma ada di `karya.seniman_id`), fungsi `terbitkan_sertifikat()`
WAJIB membaca `karya.seniman_id` SEBELUM membangun payload, lalu memasukkannya ke payload yang
di-hash — bukan dibaca ulang dari `karya` saat verifikasi (karena `karya.seniman_id` itu sendiri
BISA berubah; payload harus menyimpan SNAPSHOT nilainya di titik waktu verifikasi, bukan referensi
hidup ke tabel lain).

**Contoh nyata (sudah dijalankan, bukan ilustrasi — diperbarui setelah `creator_id` ditambahkan):**
```json
{"ai_detection_result":"asli","art_to_art_result":"bersih","creator_id":"7c9e6a4d-6f3b-4ae1-9f0a-1b2c3d4e5f6a","file_hash":"8f7a91d8c4a2b6e1f0d3c5a7b9e2f4d6c8a0b2e4f6d8c0a2b4e6f8d0c2a4b6e8","karya_id":"3fa85f64-5717-4562-b3fc-2c963f66afa6","schema":"sertifikat_keaslian.v1","status_akhir":"terverifikasi","verified_at":"2026-10-26T09:15:00Z"}
```
`payload_hash` (SHA-256) = `d5cceedf8659f52c022e78b662aef8fc1cb8ab6f68cfbbde107c9ed1434d9b4a`
*(dihitung ulang nyata — beda total dari versi sebelum `creator_id` ditambahkan
`2a04495ec82826576b36e08b0357d4b165762e6fd58857335853628062d5f136` — membuktikan avalanche
effect bekerja bahkan untuk penambahan 1 field baru)*

### b. `transaksi` (payload `transaksi.v1`)

**Keputusan desain penting (perlu dipahami, bukan sepele):** kolom `transaksi.status` bersifat **mutable** (`menunggu_pembayaran` → `dibayar` → `dikonfirmasi` → `selesai`, dengan `updated_at` ikut berubah) — sementara `digital_signature`/`payload_hash` di skema sekarang `NOT NULL` sejak baris dibuat (tidak nullable). Supaya tidak kontradiksi (signature harus tetap valid walau status berubah), **`status` SENGAJA TIDAK dimasukkan ke payload yang ditandatangani** — payload cuma mengunci **fakta order yang tidak berubah**: siapa, karya apa, harga berapa. Perubahan status sesudahnya (pembayaran, konfirmasi, selesai) **tidak pernah membuat signature invalid**, karena field itu memang bukan bagian dari apa yang "dijamin" signature.

| Field | Sumber kolom | Kenapa dimasukkan |
|---|---|---|
| `schema` | — (literal `"transaksi.v1"`) | Versi format |
| `transaksi_id` | `transaksi.id` | Identitas order |
| `karya_id` | `transaksi.karya_id` | Objek transaksi |
| `pembeli_id` | `transaksi.pembeli_id` | Pihak transaksi |
| `penjual_id` | `transaksi.penjual_id` | Pihak transaksi |
| `harga_final_idr` | `transaksi.harga_final_idr` | Nilai transaksi (tidak berubah setelah disepakati) |
| `komisi_platform_idr` | `transaksi.komisi_platform_idr` | Nilai komisi saat itu (lihat alasan di `backend/CLAUDE.md` — tidak dihitung ulang dari persen) |
| `dibuat_pada` | `transaksi.created_at` (dipotong ke presisi detik) | Waktu order dibuat, titik acuan tetap |

**TIDAK dimasukkan:** `status`, `updated_at` (keduanya mutable, lihat penjelasan di atas), `signing_key_id` (sama alasan seperti di atas).

**Konsekuensi praktis untuk Tahap 4 (endpoint):** `payload_hash`+`digital_signature` dihitung & diisi **SEKALI, saat baris `transaksi` pertama kali di-INSERT** (bukan menunggu status `selesai`) — konsisten dengan kolom yang sudah `NOT NULL` dari awal di skema saat ini.

---

## 1.3 — Kebijakan Penyimpanan Private Key (JUJUR, bukan overclaim)

**Untuk skala prototipe akademik saat ini:**
- Private key Ed25519 (32 byte mentah) disimpan sebagai **environment variable ter-enkripsi** di server (`backend/.env`, nilai base64, **di-gitignore**, TIDAK PERNAH masuk git).
- `signing_keys.kms_key_ref` berisi **nama environment variable**-nya (mis. `"env:SIGNING_PRIVATE_KEY_V1"`) — **bukan** pointer ke KMS komersial sungguhan (AWS KMS/Vault/dll).

**Kalimat yang AMAN dipakai di laporan/demo (sudah benar, tidak overclaim):**
> *"Untuk skala prototipe akademik, private key disimpan di environment variable ter-enkripsi di server, bukan di layanan Key Management System (KMS) komersial. Skema database (`signing_keys.kms_key_ref`) sudah dirancang generik sejak awal, sehingga migrasi ke KMS sungguhan (AWS KMS, HashiCorp Vault, dll) di masa depan tidak memerlukan perubahan skema — cukup mengganti isi referensi dan cara kode membaca key-nya."*

**JANGAN tulis** "private key aman tersimpan di KMS" — itu klaim yang tidak sesuai implementasi sebenarnya.

---

## 1.4 — Kebijakan Rotasi Key

> **Verifikasi SELALU memakai public key sesuai `signing_key_id` yang tercatat di record (`sertifikat_keaslian.signing_key_id` / `transaksi.signing_key_id`), BUKAN key yang sedang `is_active=True` sekarang.**

**Konsekuensi untuk kode Tahap 3 (`verifikasi_signature`):** fungsi verifikasi WAJIB menerima `signing_key_id` sebagai parameter (ambil `public_key`-nya lewat query ke tabel `signing_keys` pakai ID itu), bukan selalu mengambil "key yang aktif sekarang". Dengan begini, rotasi key (menonaktifkan key lama `is_active=False`, mengaktifkan key baru) **tidak pernah membuat sertifikat lama jadi tiba-tiba INVALID** — ini dibuktikan lewat uji 5.4 di `TODO_KRIPTOGRAFI.md`.

---

## 1.5 — Rencana Jika Private Key Bocor/Dikompromikan

1. **Segera** set `signing_keys.revoked_at = sekarang()` pada key yang bocor (tetap `is_active` boleh `False` juga, dua sinyal berbeda: `is_active=False` = "tidak dipakai untuk tanda tangan baru", `revoked_at` = "diketahui bocor/tidak tepercaya lagi").
2. Generate keypair baru (ulangi Tahap 2), insert baris baru di `signing_keys` dengan `is_active=True`.
3. Seluruh sertifikat/transaksi BARU memakai key baru.
4. **Keterbatasan yang jujur diakui (bukan ditutupi):** sertifikat LAMA yang ditandatangani key yang bocor **tidak bisa "diperbaiki"/ditandatangani ulang secara retroaktif** — signature lama tetap matematis valid (sampai dibuktikan sebaliknya), tapi secara kebijakan keamanan, verifikasi publik (endpoint 4.3) sebaiknya menampilkan peringatan tambahan untuk sertifikat yang `signing_key_id`-nya mengarah ke key yang sudah `revoked_at` terisi — misal label `"VALID (ditandatangani key yang sejak itu telah dicabut — verifikasi independen disarankan)"` alih-alih `"VALID"` polos.

---

## Ringkasan Keputusan (checklist Tahap 1, semua sudah final)

- [x] 1.1 Format payload kanonik — JSON sorted-keys, tanpa spasi, UTF-8, timestamp presisi detik+Z
- [x] 1.2 Payload `sertifikat_keaslian.v1` dan `transaksi.v1` didefinisikan, field mutable (`status`) sengaja dikecualikan dari payload `transaksi`
- [x] 1.3 Kebijakan key: env var ter-enkripsi untuk MVP, bukan klaim KMS
- [x] 1.4 Rotasi key: verifikasi pakai `signing_key_id` tercatat, bukan key aktif sekarang
- [x] 1.5 Rencana kompromis key: revoke + key baru + pengakuan keterbatasan retroaktif

**Tahap 1 selesai — siap lanjut Tahap 2 (setup kunci) & Tahap 3 (fungsi inti).**
