# Laporan — Kriptografi Digital Art Identity (Implementasi Final)

> Status: **implementasi SELESAI & teruji** (Tahap 1-5 `TODO_KRIPTOGRAFI.md`, 2026-10-26 s/d
> 2026-10-27). Dokumen ini melaporkan apa yang BENAR-BENAR dibangun & terbukti bekerja —
> `kriptografi.md` tetap jadi acuan desain/filosofi awal, dokumen ini laporan hasil akhirnya.

---

## 1. Kalimat Metode (untuk Bab Metodologi Laporan/Presentasi)

> *"Galeria menerapkan cryptographic artwork identity dan provenance menggunakan **SHA-256**
> sebagai mekanisme integritas data serta **asymmetric cryptography (Ed25519) melalui digital
> signature** untuk autentikasi penerbit dan verifikasi record. Payload yang ditandatangani
> diserialisasi secara kanonik (JSON terurut alfabetis, tanpa spasi, UTF-8 — lihat
> `SPEC_PAYLOAD.md`) sebelum di-hash, memastikan hasil hash deterministik di seluruh sistem.
> Hasil verifikasi artwork (Art-to-Art + Art-to-AI) kemudian diikat dengan digital certificate
> (`sertifikat_keaslian`, append-only), sedangkan setiap perpindahan kepemilikan dicatat sebagai
> signed ownership transfer record (`transaksi` + `kepemilikan_karya`) sehingga riwayat
> kepemilikan dapat ditelusuri dan diverifikasi ulang kapan saja secara independen, tanpa
> bergantung pada status yang di-cache di database."*

**Jawaban siap pakai untuk pertanyaan dosen yang sering muncul:**

| Pertanyaan | Jawaban |
|---|---|
| "Apakah kriptografi mendeteksi plagiarisme?" | Tidak. Deteksi kemiripan dilakukan Art-to-Art Similarity Model. Kriptografi dipakai SETELAH proses itu, untuk menjaga integritas identitas, record verifikasi, sertifikat, dan catatan kepemilikan. |
| "Kalau karya berpindah tangan bagaimana?" | `artwork_id` dan sertifikat verifikasi awal TIDAK diterbitkan ulang. Yang dibuat baru adalah Ownership Transfer Record (`transaksi` + `kepemilikan_karya`) — dibuktikan lewat uji 5.3: `sertifikat_aktif_id` TIDAK berubah setelah 2x penjualan berurutan. |
| "Kenapa bukan blockchain/NFT?" | Blockchain menjawab "percaya tanpa otoritas pusat" — Galeria justru SENGAJA jadi otoritas pusat (model bisnis komisi). SHA-256+Digital Signature sudah cukup membuktikan "data ini tidak diubah sejak ditandatangani Galeria", tanpa overhead biaya/kompleksitas smart contract. NFT secara desain mendorong transaksi peer-to-peer di luar platform — bertentangan dengan model komisi Galeria. |
| "Algoritma signature-nya apa, kenapa itu?" | Ed25519 — deterministic signing (tidak butuh sumber acak eksternal saat menandatangani, beda dari ECDSA yang rawan bocor private key kalau nonce lemah/berulang), signature kecil (64 byte), cepat. |

---

## 2. Arsitektur Final yang Terbangun

```
Upload Karya (POST /api/karya)
        │
        ▼
Verification Engine (POST /api/karya/{id}/verify) -- Art-to-Art + Art-to-AI SUNGGUHAN
        │
        ▼ (hanya kalau rekomendasi = "terverifikasi")
terbitkan_sertifikat() -- services/sertifikat_service.py
  → payload kanonik (karya_id, creator_id, file_hash, hasil verifikasi, verified_at)
  → SHA-256 → Ed25519 sign → simpan sertifikat_keaslian + artwork_id (GAL-ART-2026-NNNNNN)
        │
        ▼
GET /api/verifikasi/{artwork_id} -- PUBLIK, tanpa login
  → hitung ulang hash dari data TERKINI + verifikasi signature matematis TIAP REQUEST
  → status_keseluruhan: VALID / INVALID (2 pengecekan independen: hash_cocok & signature_valid)

(Terpisah) Transaksi & Kepemilikan
  buat_transaksi() -- tanda tangan SEKALI saat order dibuat (status TIDAK ikut ditandatangani)
  catat_transfer_kepemilikan() -- dipanggil saat status = selesai, tutup pemilik lama + buka baru
```

---

## 3. Bukti Observasi Nyata (Hasil Uji Tahap 5, Lewat HTTP Sungguhan)

Berikut kutipan APA ADANYA dari pengujian end-to-end (server `uvicorn` nyata, model AI nyata,
database Neon nyata) — dipakai sebagai pengganti screenshot di laporan tertulis. Untuk demo
langsung, jalankan ulang `uvicorn main:app` lalu akses URL yang sama lewat browser/Postman
untuk tangkapan layar hidup (lihat bagian 5).

### 3.1 — Sebelum Tamper (Sertifikat VALID)

Request: `POST /api/karya/{id}/verify` dengan gambar asli →
```json
{
  "art_to_art_result": "lolos",
  "ai_detection_result": "lolos",
  "rekomendasi_status": "terverifikasi",
  "ai_generated_probability": 0.19526243209838867
}
```

Lalu `GET /api/verifikasi/GAL-ART-2026-000001` →
```json
{
  "artwork_id": "GAL-ART-2026-000001",
  "status_akhir": "terverifikasi",
  "hash_cocok": true,
  "signature_valid": true,
  "status_keseluruhan": "VALID",
  "peringatan_key_dicabut": false
}
```

### 3.2 — Setelah Tamper Langsung di Database (Sertifikat INVALID)

`digital_signature` diubah manual lewat SQL (simulasi serangan/korup data), lalu
`GET /api/verifikasi/GAL-ART-2026-000001` dipanggil ulang (request HTTP baru) →
```json
{
  "artwork_id": "GAL-ART-2026-000001",
  "hash_cocok": true,
  "signature_valid": false,
  "status_keseluruhan": "INVALID",
  "peringatan_key_dicabut": false
}
```
**Catatan penting:** `hash_cocok` tetap `true` (data payload-nya sendiri tidak diubah), tapi
`signature_valid` jadi `false` — membuktikan sistem bisa membedakan 2 jenis masalah berbeda
secara independen (data berubah vs signature rusak/dipalsukan).

### 3.3 — Setelah Rotasi Key (Sertifikat Lama Tetap VALID)

Key signing lama dicabut (`revoked_at` terisi), key baru dibuat aktif. Sertifikat yang
ditandatangani key LAMA diverifikasi ulang →
```json
{
  "signature_valid": true,
  "status_keseluruhan": "VALID",
  "peringatan_key_dicabut": true
}
```
Rotasi key **tidak membatalkan** sertifikat lama — sesuai kebijakan `SPEC_PAYLOAD.md` §1.4 —
sambil tetap transparan memberi tahu bahwa key penandatangannya sudah dicabut.

---

## 4. Keterbatasan (WAJIB disampaikan apa adanya, jangan ditutupi)

1. **Private key disimpan di environment variable** (`backend/.env`, ter-enkripsi di level
   filesystem server), **BUKAN** di layanan Key Management System (KMS) komersial (AWS KMS,
   HashiCorp Vault, dll). Skema database (`signing_keys.kms_key_ref`) sudah dirancang generik
   sejak awal sehingga migrasi ke KMS sungguhan di masa depan tidak memerlukan perubahan skema.
2. **Format payload kanonik adalah desain internal tim** (`SPEC_PAYLOAD.md`) — bukan standar
   industri resmi seperti RFC 8785 (JSON Canonicalization Scheme), meski terinspirasi prinsip
   yang sama (urutan key tetap, tanpa ambiguitas serialisasi).
3. **Sertifikat yang ditandatangani key yang kemudian bocor TIDAK BISA "diperbaiki" secara
   retroaktif** — signature lama tetap matematis valid sampai terbukti sebaliknya, kebijakan
   mitigasinya adalah menampilkan peringatan (`peringatan_key_dicabut`) di endpoint verifikasi,
   bukan membatalkan otomatis.
4. **Nomor urut `artwork_id` BUKAN atomic sequence** — pada skala prototipe akademik (upload
   tidak terjadi ribuan/detik) risiko 2 request bersamaan mendapat nomor sama diterima sebagai
   keterbatasan MVP; migrasi ke `sa.Sequence` Postgres adalah perbaikan wajar untuk skala
   produksi.
5. **Endpoint upload (`POST /api/karya`) belum terhubung ke sistem Auth** (Auth belum dibangun
   di proyek ini) — `seniman_id` (creator) sengaja NULL dari endpoint itu. Fungsi
   `terbitkan_sertifikat()` secara eksplisit MENOLAK menerbitkan sertifikat untuk karya tanpa
   `seniman_id` (divalidasi & diuji) — begitu Auth dibangun, celah ini otomatis tertutup tanpa
   perlu ubah kode kriptografi.
6. **Alur checkout/pembayaran lengkap belum dibangun** — `buat_transaksi()`/
   `catat_transfer_kepemilikan()` adalah PRIMITIF yang sudah teruji penuh, siap dipanggil
   endpoint checkout yang akan dibangun terpisah (di luar scope fitur kriptografi).
7. **Seluruh pengujian memakai data sintetis/uji** (karya & user dummy, dibuat dan dihapus
   khusus untuk pengujian) — bukan transaksi marketplace nyata.

---

## 5. Untuk Demo Langsung (Screenshot Hidup)

```powershell
cd backend
.venv\Scripts\python.exe -m uvicorn main:app --reload --port 8000
```
Lalu buka di browser: `http://localhost:8000/api/verifikasi/GAL-ART-2026-000001`
(atau `artwork_id` lain hasil upload+verifikasi nyata saat demo) — ini menampilkan JSON hasil
verifikasi secara LIVE, bisa langsung di-screenshot saat presentasi. Dokumentasi interaktif
semua endpoint juga tersedia otomatis di `http://localhost:8000/docs`.

**Catatan:** data uji dari Tahap 5 (`GAL-ART-2026-000001` dkk) sudah DIBERSIHKAN dari database
setelah pengujian selesai (lihat `TODO_KRIPTOGRAFI.md` Tahap 5) — untuk demo, upload & verifikasi
karya baru dulu lewat `POST /api/karya` → `POST /api/karya/{id}/verify`, baru `artwork_id`-nya
bisa dipakai di endpoint verifikasi publik.
