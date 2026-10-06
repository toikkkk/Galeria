# kriptografi.md — Brainstorming Desain Kriptografi Digital Art Identity

> **Status: dokumen ACUAN desain** (hasil brainstorming pribadi dengan ChatGPT, 2026-10). Dipakai sebagai
> sumber keputusan utama untuk membangun lapisan kriptografi "Digital Art Identity" GALERIA — menyusul
> Verification Engine (Art-to-Art + Art-to-AI) yang sudah dibangun & diintegrasikan ke `backend/`.
>
> Istilah di dokumen ini pakai Bahasa Inggris konseptual (ARTWORK, VERIFICATION_RECORD, dst) — saat
> implementasi nyata, dipetakan ke tabel Neon yang SUDAH ADA di skema GALERIA (lihat tabel pemetaan di
> akhir dokumen ini, bagian "Catatan Pemetaan ke Skema GALERIA").

---

# GALERIA — CRYPTOGRAPHIC ARTWORK IDENTITY & PROVENANCE

## 1. Konsep Utama

Fitur kriptografi Galeria dirancang untuk memberikan **identitas digital yang unik, integritas data, autentikasi penerbit, serta riwayat kepemilikan yang dapat diverifikasi** pada setiap artwork.

Konsepnya bukan:

> "Kriptografi membuktikan bahwa artwork 100% asli dan bukan plagiarisme."

Tetapi:

> **Kriptografi digunakan untuk mengamankan identitas dan catatan digital artwork serta membuat certificate dan riwayat transaksi dapat diverifikasi secara kriptografis.**

Dengan demikian, Galeria memiliki tiga lapisan utama:

```text
┌─────────────────────────────────────────────┐
│           GALERIA ARTWORK SYSTEM            │
├─────────────────────────────────────────────┤
│  1. VERIFICATION                            │
│     Art-to-Art + Art-to-AI                  │
│                                             │
│  2. CRYPTOGRAPHIC IDENTITY                  │
│     Artwork ID + SHA-256 + Digital Signature│
│                                             │
│  3. PROVENANCE & OWNERSHIP                  │
│     Certificate + Transaction + Ownership   │
└─────────────────────────────────────────────┘
```

---

## 2. Masalah Bisnis yang Ingin Diselesaikan

Dalam marketplace seni digital, terdapat beberapa masalah:

### A. Sulit membedakan artwork yang pernah terdaftar
Satu karya dapat diunggah, dijual, lalu muncul kembali dengan identitas yang berbeda.

### B. Sulit menjaga integritas record
Informasi seperti: creator, tanggal verifikasi, artwork hash, status verification, ownership — dapat berubah jika sistem tidak memiliki mekanisme integritas.

### C. Sulit mengetahui riwayat kepemilikan
Ketika artwork berpindah:
```text
Artist A
   ↓
Collector B
   ↓
Collector C
```
platform perlu mengetahui sejarah perpindahan tersebut.

### D. Certificate biasa mudah hanya menjadi dokumen visual
PDF certificate saja belum tentu membuktikan bahwa dokumen tersebut benar-benar diterbitkan Galeria dan tidak diubah.

---

## 3. Solusi yang Ditawarkan Galeria

Galeria membuat: **Cryptographically Verifiable Artwork Identity**

Setiap artwork yang berhasil melewati proses verification mendapatkan identitas digital yang terikat dengan:

```text
Artwork → Artwork ID → SHA-256 → Verification Record → Digital Signature → Certificate → Ownership / Transaction History
```

---

## 4. Posisi Kriptografi dalam Arsitektur Galeria

Kriptografi **tidak menggantikan AI/CV**. Masing-masing mempunyai fungsi berbeda.

```text
                 ARTWORK
                    │
                    ▼
        ┌──────────────────────┐
        │   VERIFICATION ENGINE │
        └──────────────────────┘
             │            │
             ▼            ▼
       Art-to-Art       Art-to-AI
       Similarity       Detection
             │            │
             └─────┬──────┘
                   ▼
          Verification Result
                   │
                   ▼
       ┌───────────────────────┐
       │ CRYPTOGRAPHIC LAYER   │
       │                       │
       │ Artwork ID            │
       │ SHA-256               │
       │ Digital Signature     │
       └───────────────────────┘
                   │
                   ▼
              Certificate
                   │
                   ▼
             Marketplace
                   │
                   ▼
           Ownership Transfer
                   │
                   ▼
          Provenance History
```

---

## 5. Komponen Kriptografi

### 5.1 Artwork ID

Setiap artwork memiliki identifier unik. Contoh: `GAL-ART-2026-000001`

Artwork ID adalah **identitas aplikasi**, bukan hash. Fungsinya untuk memudahkan: database lookup, certificate, QR code, transaksi, ownership history, verification page.

---

## 6. SHA-256

Setelah artwork diverifikasi, file artwork dapat dihitung menggunakan **SHA-256 cryptographic hash**.

Contoh: `SHA-256: 8f7a91d8c4...91cd`

```text
Artwork File → SHA-256 → Unique Hash
```

Hash digunakan untuk **integrity checking**. Jika file berubah:
```text
Original Artwork   SHA-256 = ABC123
Modified Artwork    SHA-256 = XYZ789
```
maka sistem dapat mengetahui bahwa data/file yang dibandingkan tidak identik secara byte-level.

### Penting
SHA-256 **bukan alat untuk mendeteksi plagiarisme**. Itu tugas **Art-to-Art Similarity Model**.

---

## 7. Asymmetric Cryptography / Digital Signature

Ini merupakan bagian yang paling penting dari pengembangan konsep terbaru.

Galeria menggunakan pasangan: **Private Key** (menandatangani record) dan **Public Key** (memverifikasi signature).

```text
Verification Record → SHA-256 → Digital Signature ← Galeria Private Key
```

Kemudian pihak yang ingin memverifikasi menggunakan:
```text
Digital Signature + Verification Record + Galeria Public Key → VALID / INVALID
```

Dengan demikian sistem dapat memberikan bukti kriptografis bahwa record tersebut ditandatangani oleh pihak yang memegang private key Galeria dan record tidak berubah setelah ditandatangani.

---

## 8. Kenapa SHA-256 Saja Tidak Cukup?

Ini perbedaan yang penting untuk presentasi.

**SHA-256** memberikan **Integrity** — "Apakah data ini berubah?" Tetapi SHA-256 tidak menjawab "Siapa yang membuat hash ini?"

**Digital Signature** memberikan **Integrity + signer authentication** — "Record ini ditandatangani oleh pemilik private key yang sesuai dengan public key tersebut, dan record tersebut tidak berubah."

Maka konsep Galeria lebih kuat jika menggunakan **SHA-256 + Digital Signature**, bukan hanya SHA-256.

---

## 9. Algoritma Digital Signature

Untuk implementasi nyata, Galeria **tidak perlu membuat algoritma kriptografi sendiri**. Gunakan standar yang sudah mapan: RSA, ECDSA, atau EdDSA.

Untuk project akademik:
> Galeria menggunakan asymmetric cryptography melalui digital signature untuk memberikan autentikasi penerbit dan integritas terhadap verification serta ownership records.

**Jangan membuat custom cryptographic algorithm.**

---

## 10. Verification Engine

Sebelum certificate diterbitkan, artwork masuk ke verification engine.

```text
Uploaded Artwork
       │
       ├───────────────┐
       ▼               ▼
Art-to-Art          Art-to-AI
Similarity          Detection
       │               │
       ▼               ▼
Similarity Score   AI Probability
       │               │
       └───────┬───────┘
               ▼
       Verification Engine
               │
        ┌──────┴──────┐
        ▼             ▼
      PASS         REVIEW/REJECT
```

**Art-to-Art**: model similarity berbasis visual embedding/metric learning. Tujuan: menemukan indikasi kemiripan tinggi dengan artwork yang sudah terdaftar. Ini **screening**, bukan keputusan hukum tentang plagiarisme.

**Art-to-AI**: binary image classification. Tujuan: memperkirakan apakah artwork memiliki indikasi AI-generated. Hasilnya berupa **probabilitas/likelihood**, bukan bukti absolut.

---

## 11. Setelah Artwork Lolos Verification

```text
VERIFICATION PASSED
        │
        ▼
Generate Artwork ID
        │
        ▼
Calculate SHA-256
        │
        ▼
Create Verification Record
        │
        ▼
Digital Signature
        │
        ▼
Generate Certificate
```

Contoh:
```text
Artwork ID: GAL-ART-2026-000001
Verification: VERIFIED
SHA-256: 8f7a91...c21d
Verified At: 28 September 2026
Signature: VALID
```

---

## 12. Certificate of Verification

Certificate pertama diterbitkan ketika artwork pertama kali diverifikasi.

```text
┌───────────────────────────────────────────────┐
│                  GALERIA                      │
│       DIGITAL ARTWORK CERTIFICATE             │
│       CERTIFICATE OF VERIFICATION             │
│                                               │
│ Artwork ID: GAL-ART-2026-000001               │
│ Title: Sunset Over Bromo                      │
│ Original Creator: Andi Pratama                │
│ Verification Status: ✓ VERIFIED BY GALERIA    │
│ SHA-256: 8f7a91...c21d                        │
│ Issued At: 28 September 2026                  │
│ Digital Signature: ✓ VALID                    │
│ [ QR — VERIFY CERTIFICATE ]                   │
└───────────────────────────────────────────────┘
```

---

## 13. Apa yang Sebenarnya Disertifikasi?

Certificate **bukan sertifikat hukum yang menyatakan 100% keaslian fisik**. Yang dicatat:
```text
Artwork Identity + Verification Result + Creator Information
+ Cryptographic Integrity + Timestamp + Galeria Signature
```

Kalimat yang lebih aman:
> **"Verified by Galeria based on the verification procedures and models applied at the time of issuance."**

Bukan: ❌ "100% Original Artwork" atau ❌ "Guaranteed Not Plagiarized"

---

## 14. Ketika Artwork Dijual

```text
Artist A → menjual → Collector B
```
**Artwork ID tidak berubah.** Creator juga tetap. Yang berubah: `Current Owner: Andi → Budi`

---

## 15. Jangan Membuat Certificate Verification Baru

> **Jangan menerbitkan ulang Certificate of Verification setiap kali artwork berpindah tangan.**

Karena verification terhadap artwork adalah historical event. Yang dibuat baru adalah **Ownership Transfer Record**.

---

## 16. Ownership Transfer Record

```text
┌───────────────────────────────────────────────┐
│                  GALERIA                      │
│        OWNERSHIP TRANSFER RECORD              │
│                                               │
│ Artwork ID: GAL-ART-2026-000001               │
│ Artwork: Sunset Over Bromo                    │
│ Original Creator: Andi Pratama                │
│ Previous Owner: Andi Pratama                  │
│ New Owner: Budi Santoso                       │
│ Transaction ID: TX-2026-004582                │
│ Transfer Date: 15 October 2026                │
│ Status: ✓ COMPLETED                           │
│ Digital Signature: ✓ VALID                    │
│ [ QR — VIEW PROVENANCE ]                      │
└───────────────────────────────────────────────┘
```

---

## 17. Kenapa Ownership Record Perlu Ditandatangani?

Karena transaksi adalah event baru.
```text
Ownership Transfer (Andi → Budi) → SHA-256 → Digital Signature ← Galeria Private Key
```
Sehingga transaksi mempunyai bukti integritas dan signature tersendiri.

---

## 18. Jika Dijual Lagi

```text
Andi → Budi → Citra
```
```text
GAL-ART-2026-000001
        ├── Verification Record
        ├── Certificate
        ├── TX-001 (Andi → Budi)
        └── TX-002 (Budi → Citra)
```
Artwork ID tetap sama. Creator tetap sama. Ownership history bertambah.

---

## 19. Ownership ≠ Creator

Ini harus sangat jelas dalam sistem. `Creator: Andi` ≠ `Owner: Budi`. Budi **bukan pencipta artwork**.

Database harus memisahkan `creator_id` dan `current_owner_id`.

---

## 20. Contoh Full Lifecycle

```text
                    ARTIST A
                       │ Upload
                       ▼
                ┌───────────────┐
                │   VERIFICATION│
                │    ENGINE     │
                └───────────────┘
                       │
             ┌─────────┴─────────┐
             ▼                   ▼
       Art-to-Art             Art-to-AI
       Similarity             Detection
             │                   │
             └─────────┬─────────┘
                       ▼
               Verification Pass
                       │
                       ▼
                 Generate ID → SHA-256 → Verification Record
                       │
                       ▼
             Digital Signature → Certificate Issued
                       │
                       ▼
                 Marketplace
                       │
                       │ Sell
                       ▼
                  COLLECTOR B
                       │
                       ▼
      Transaction Record → Digital Signature → Ownership Transfer
                       │
                       ▼
                Current Owner B
                       │
                       │ Sell Again
                       ▼
                  COLLECTOR C → Ownership Transfer → Current Owner C
```

---

## 21. Halaman Verification

QR code pada certificate dapat mengarah ke halaman publik:
```text
GALERIA VERIFICATION
────────────────────────────
Artwork ID: GAL-ART-2026-000001
Title: Sunset Over Bromo
Original Creator: Andi Pratama
Verification: ✓ VERIFIED
Original Verification Date: 28 September 2026
Cryptographic Integrity: ✓ VALID
Digital Signature: ✓ VALID
Current Owner: Citra Wijaya
Ownership History: 3 recorded transfers
[ View Certificate ]  [ View Ownership History ]
```
Ini membuat certificate **tidak hanya berupa PDF**, tetapi dapat diverifikasi melalui sistem Galeria.

---

## 22. Struktur Data Konseptual

```text
ARTWORK: artwork_id, title, creator_id, file_hash, verification_status, created_at
VERIFICATION_RECORD: verification_id, artwork_id, art_to_art_result, ai_detection_result,
                      verified_at, record_hash, digital_signature, certificate_id
CERTIFICATE: certificate_id, artwork_id, issued_at, verification_id, signature, status
OWNERSHIP: ownership_id, artwork_id, owner_id, acquired_at, released_at, status
TRANSACTION: transaction_id, artwork_id, seller_id, buyer_id, price, timestamp, status,
             record_hash, digital_signature
```

---

## 23. Hubungan Antar-Komponen

```text
ARTWORK (1:1) VERIFICATION RECORD (1:1) CERTIFICATE → OWNERSHIP → TRANSACTION → Previous/New Owner
```
Cryptography sebagai lapisan integritas: Artwork→SHA-256; Verification Record→Digital Signature;
Certificate→Digital Signature/reference; Transaction→Digital Signature; Ownership Record→Digital Signature.

---

## 24. Perbedaan Fungsi Setiap Teknologi

| Teknologi | Fungsi |
|---|---|
| OpenCV | preprocessing/acquisition image |
| Deep Learning | visual feature extraction / classification |
| Art-to-Art Model | screening kemiripan artwork |
| Art-to-AI Model | screening indikasi AI-generated |
| Artwork ID | identitas aplikasi artwork |
| SHA-256 | integrity / content fingerprint |
| Asymmetric Cryptography | mekanisme signing & verification |
| Digital Signature | autentikasi penerbit + integritas record |
| Certificate | representasi digital hasil verification |
| QR Code | akses ke verification/provenance page |
| Ownership Record | mencatat pemilik |
| Transaction Record | mencatat perpindahan |
| Watermark | provenance/marking pada media, jika digunakan |

---

## 25. Bagaimana dengan Watermark?

Watermark **tetap bisa digunakan**, tetapi jangan dicampur dengan fungsi kriptografi.

```text
ARTWORK
  ├── CRYPTOGRAPHIC LAYER → Hash/Signature → Integrity & Authentication
  └── WATERMARK LAYER     → Visible/Invisible → Provenance/Identification
```
Watermark tidak menggantikan SHA-256, digital signature, certificate, ownership record.

---

## 26. Apa yang Terjadi Jika File Artwork Diubah?

```text
Artwork A   SHA-256 = ABC123
Artwork A'  SHA-256 = XYZ789  (file diubah)
→ Expected ABC123 vs Received XYZ789 → ⚠ INTEGRITY MISMATCH
```
Namun: **Hash mismatch ≠ otomatis plagiarisme.** Untuk plagiarisme/kemiripan visual, pakai **Art-to-Art similarity model**.

---

## 27. Apa yang Terjadi Jika Ada Orang Mengubah Certificate?

```text
Original Record → Digital Signature → Verify → VALID ✓
Modified Record → Verify Signature  → INVALID ✕
```

---

## 28. Apa yang Terjadi Saat Ownership Berpindah?

**Sebelum transaksi:** Artwork ID GAL-ART-2026-000001, Creator Andi, Owner Andi.
**Setelah transaksi:** Creator Andi, Previous Owner Andi, Current Owner Budi, Transaction TX-2026-004582.
**Setelah dijual lagi:** Ownership History Andi → Budi → Citra, Current Owner Citra.

---

## 29. Apakah Perlu Blockchain?

**Tidak wajib.** Supaya project Galeria tidak menjadi over-engineering.

Konsep ini dapat berjalan menggunakan: **PostgreSQL + SHA-256 + Digital Signature + Backend Verification API** — tanpa blockchain.

Blockchain baru relevan jika Galeria membutuhkan: decentralized verification, shared ledger antarorganisasi, trust tanpa satu central authority, public immutable ledger. Untuk Galeria saat ini, **centralized cryptographic provenance system sudah jauh lebih realistis**.

---

## 30. Apakah Ini NFT?

**Tidak.** Jangan menyebut sistem ini NFT hanya karena terdapat ownership, certificate, hash, digital signature. NFT memiliki konsep blockchain/tokenization yang berbeda. Galeria dapat memiliki **Digital Artwork Certificate + Cryptographic Provenance** tanpa menjadi NFT marketplace.

---

## 31. Apakah Ini Membuktikan Legal Ownership?

Sistem dapat mencatat **"recorded ownership within Galeria"**, tapi itu tidak otomatis berarti **"legal ownership secara universal"** (bergantung kontrak, hukum, pembayaran, yurisdiksi). Istilah yang lebih aman: **"Galeria Recorded Owner"** atau **"Current Owner on Galeria"**.

---

## 32. Model Bisnisnya

**Untuk Artist:** verified artwork identity, certificate, provenance, ownership history.
**Untuk Collector:** informasi creator, verification status, certificate, transaction history, current ownership record.
**Untuk Galeria:** trusted marketplace, traceable transactions, artwork provenance, differentiation dari marketplace biasa.

---

## 33. Potensi Monetisasi (opsi bisnis, BUKAN wajib untuk prototype akademik)

- **Basic:** Marketplace + verification dasar.
- **Verified Artwork:** Verification + Artwork ID + Certificate.
- **Premium Provenance:** + Cryptographic Signature + Ownership History + Transfer Record.
- **Premium Collector:** + Complete Provenance + Transfer History + Verification Page.

---

## 34. Konsep Akhir yang Direkomendasikan

```text
┌─────────────────────────────────────────────┐
│                  GALERIA                    │
│              ARTWORK UPLOAD                 │
│                     │                       │
│                     ▼                       │
│            VERIFICATION ENGINE              │
│             │             │                 │
│             ▼             ▼                 │
│        ART-TO-ART       ART-TO-AI           │
│        Similarity       Detection           │
│             │             │                 │
│             └──────┬──────┘                 │
│                    ▼                        │
│             VERIFICATION RESULT             │
│                    │                        │
│                    ▼                        │
│          CRYPTOGRAPHIC IDENTITY             │
│        ┌───────────┼───────────┐            │
│        ▼           ▼           ▼            │
│   Artwork ID    SHA-256    Digital          │
│                             Signature       │
│        └───────────┬───────────┘            │
│                    ▼                        │
│          CERTIFICATE OF VERIFICATION        │
│                    │                        │
│                    ▼                        │
│               MARKETPLACE                   │
│                    │                        │
│                    ▼                        │
│                PURCHASE                     │
│                    │                        │
│                    ▼                        │
│          OWNERSHIP TRANSFER                 │
│        ┌───────────┴───────────┐            │
│        ▼                       ▼            │
│   Transaction ID         Digital Signature  │
│        │                       │            │
│        └───────────┬───────────┘            │
│                    ▼                        │
│            PROVENANCE HISTORY              │
│                    │                        │
│                    ▼                        │
│             CURRENT OWNER                  │
└─────────────────────────────────────────────┘
```

---

## 35. Kalimat Metode untuk Proposal / Presentasi

**"Metode kriptografi yang digunakan Galeria apa?"**
> "Galeria menerapkan cryptographic artwork identity dan provenance menggunakan SHA-256 sebagai mekanisme integritas data serta asymmetric cryptography melalui digital signature untuk autentikasi dan verifikasi record. Hasil verification artwork kemudian diikat dengan digital certificate, sedangkan setiap perpindahan kepemilikan dicatat sebagai signed ownership transfer record sehingga riwayat kepemilikan dapat ditelusuri dan diverifikasi."

**"Apakah kriptografi mendeteksi plagiarisme?"**
> "Tidak. Deteksi kemiripan artwork dilakukan oleh Art-to-Art Similarity Model. Kriptografi digunakan setelah proses tersebut untuk menjaga integritas identitas, verification record, certificate, dan ownership record."

**"Kalau artwork berpindah tangan bagaimana?"**
> "Artwork ID dan Certificate of Verification tetap melekat pada artwork. Sistem tidak membuat identitas artwork baru. Yang dibuat adalah Ownership Transfer Record baru yang mencatat previous owner, new owner, transaction ID, timestamp, dan digital signature. Dengan demikian creator, verification history, dan ownership history dapat dibedakan dengan jelas."

---

## 36. Kesimpulan Konsep Final

Inti fitur kriptografi Galeria bukan sekadar "membuat hash artwork". Konsep yang lebih matang:

> ### **Cryptographic Artwork Identity & Provenance System**

terdiri dari: **(1) Artwork Identity** → Artwork ID; **(2) Content Integrity** → SHA-256;
**(3) Publisher Authentication** → Asymmetric Digital Signature; **(4) Verification Record** →
hasil Art-to-Art + Art-to-AI; **(5) Digital Certificate** → bukti digital hasil verification saat
penerbitan; **(6) Ownership Transfer Record** → pencatatan perpindahan kepemilikan;
**(7) Provenance History** → histori creator dan ownership; **(8) Verification Page / QR** →
sarana publik untuk memeriksa status certificate dan provenance.

Prinsip paling penting:
> **Artwork ID tetap, Creator tetap, Certificate awal tetap; yang berubah setiap kali terjadi transaksi adalah Ownership Record dan Current Owner.**

---

## Catatan Pemetaan ke Skema GALERIA (ditambahkan saat dokumen ini disalin ke repo)

Istilah konseptual di atas sudah punya padanan tabel Neon yang **sudah dibangun** (lihat `backend/CLAUDE.md`):

| Konsep di atas | Tabel GALERIA yang sudah ada | Gap yang belum ada |
|---|---|---|
| `ARTWORK` | `karya` (`id` UUID, `seniman_id`, `file_hash`) | Kolom "Artwork ID" human-readable (mis. `GAL-ART-2026-000001`) belum ada |
| `VERIFICATION_RECORD` | `karya_verifikasi_log` (append-only, per cek) + `karya_fingerprints` (snapshot) | Sudah terintegrasi backend |
| `CERTIFICATE` | `sertifikat_keaslian` (append-only) + `signing_keys` | Logic sign/verify payload belum ditulis |
| `OWNERSHIP` | `kepemilikan_karya` (partial unique index "1 pemilik aktif") | — |
| `TRANSACTION` | `transaksi` (sudah punya kolom `payload_hash`/`digital_signature`/`signing_key_id`) | Logic sign/verify belum ditulis |
| Verification Page + QR | belum ada | Endpoint publik baru, belum dibangun |

Prinsip #15 & #19 ("certificate tidak diterbitkan ulang saat pindah tangan", "creator ≠ owner") **sudah
konsisten** dengan desain `karya.sertifikat_aktif_id` (terpisah dari kepemilikan) dan
`karya.seniman_id` vs `kepemilikan_karya.pemilik_id` yang sudah ada di skema sejak awal.
