# TODO — Implementasi Kriptografi "Digital Art Identity"

> Checklist kerja untuk membangun fitur kriptografi (SHA-256 + Asymmetric Digital Signature/Ed25519).
> Baca dulu `kriptografi.md` (desain konsep & alur bisnis) sebelum mulai — file ini cuma berisi
> urutan kerja teknis, bukan ulangan konsepnya.
>
> **Urutan WAJIB diikuti sesuai nomor** — jangan mulai coding (bagian 2) sebelum bagian 1 selesai.
> Bagian 1 adalah celah desain yang kalau dilewati akan jadi bug keamanan nyata, bukan detail kosmetik.

## 0. Status Saat Ini (jangan kerjakan ulang yang sudah ada)

- [x] Skema tabel sudah dibuat & dimigrasikan: `signing_keys`, `sertifikat_keaslian`
      (`backend/models/sertifikat.py`, migrasi `0004_fase2_sertifikat_transaksi.py`)
- [x] Kolom `payload_hash`, `digital_signature`, `signing_key_id` sudah ada di `sertifikat_keaslian` DAN `transaksi`
- [x] `karya.file_hash` sudah ada
- [ ] **Semua logic (sign, verify, generate key, endpoint) BELUM ditulis — ini scope file ini**

---

## 1. Finalisasi Desain (WAJIB sebelum menulis kode apa pun)

Ini celah yang ditemukan saat review — kalau dilewati, implementasi akan rapuh secara keamanan
meski algoritmanya (SHA-256 + Ed25519) sudah benar.

- [x] **1.1 Tulis spesifikasi payload kanonik** — selesai, lihat `ml-digital-art-identity/SPEC_PAYLOAD.md`.
      Format: JSON `sort_keys=True`, tanpa spasi, UTF-8, timestamp presisi detik+`Z`. Contoh konkret
      SUDAH dijalankan nyata (bukan ilustrasi) — `payload_hash` SHA-256 dihitung & dikutip apa adanya.
- [x] **1.2 Payload `sertifikat_keaslian.v1` vs `transaksi.v1` didefinisikan terpisah** — lihat
      `SPEC_PAYLOAD.md` bagian 1.2. Temuan penting saat menyusun: `transaksi.status` bersifat MUTABLE
      (berubah seiring lifecycle order) sementara `digital_signature` kolomnya `NOT NULL` sejak INSERT
      — diputuskan `status` SENGAJA DIKECUALIKAN dari payload yang ditandatangani, supaya perubahan
      status tidak pernah membuat signature yang sudah ada jadi invalid.
      **Diaudit ulang & diperbaiki (2026-10-26):** ditemukan 2 celah — (a) konvensi signing (sign
      string hex `payload_hash`, BUKAN byte mentah digest) belum eksplisit, ditambahkan sebagai aturan
      wajib di bagian 1.1 poin 7; (b) `creator_id` (`karya.seniman_id`) TIDAK ikut dikunci payload
      sertifikat — padahal `kriptografi.md` §12 eksplisit menyebut "Original Creator" sbg bagian
      sertifikat. Ditambahkan ke payload `sertifikat_keaslian.v1`, contoh hash dihitung ULANG nyata
      (bukan dikarang) setelah perubahan.
- [x] **1.3 Kebijakan penyimpanan private key** — selesai, `SPEC_PAYLOAD.md` bagian 1.3. Kalimat jujur
      untuk laporan sudah disiapkan (env var ter-enkripsi untuk MVP, bukan klaim KMS komersial).
- [x] **1.4 Aturan rotasi key** — selesai, `SPEC_PAYLOAD.md` bagian 1.4. Konsekuensi konkret untuk
      Tahap 3: `verifikasi_signature()` WAJIB menerima `signing_key_id` sebagai parameter.
- [x] **1.5 Rencana jika private key bocor** — selesai, `SPEC_PAYLOAD.md` bagian 1.5, termasuk saran
      UI tambahan di endpoint verifikasi untuk key yang sudah `revoked_at`.

**Tahap 1 SELESAI (2026-10-26).** Library `cryptography>=42.0` sudah ditambahkan ke
`backend/requirements.txt` dan diinstal di `.venv` — mekanisme Ed25519 sign/verify + deteksi
tamper sudah dibuktikan jalan nyata (generate keypair → sign → verify VALID → ubah 1 field →
verify INVALID) sebelum spesifikasi ditulis, supaya contoh di `SPEC_PAYLOAD.md` bukan karangan.

---

## 2. Setup Kunci Ed25519

- [x] **2.1** Library `cryptography>=42.0` ditambahkan ke `backend/requirements.txt` & terinstal
      (sudah dilakukan di Tahap 1, dipakai jg utk uji coba mekanisme sign/verify).
- [x] **2.2** `backend/scripts/buat_signing_key.py` ditulis — generate keypair Ed25519 → tulis
      private key ke `.env` → insert 1 baris ke `signing_keys`. **Fitur tambahan (bukan cuma
      checklist dasar):** idempotent & aman — menolak jalan kalau sudah ada key aktif, KECUALI
      `--force` dipakai (lalu otomatis `revoked_at` key lama, bukan menghapusnya — sesuai kebijakan
      rotasi di `SPEC_PAYLOAD.md` 1.4-1.5). Nomor versi env var (`_V1`, `_V2`, ...) dihitung dari
      TOTAL key yang pernah ada (bukan cuma yang aktif), supaya nama env var tidak pernah bentrok.
- [x] **2.3** Dijalankan nyata (`python -m scripts.buat_signing_key`) — hasil **diverifikasi
      langsung lewat query SQL ke Neon**, bukan cuma percaya output skrip:
      ```
      Total baris di signing_keys: 1
      {'id': UUID('11159676-6e83-488a-ad42-227d0ec78d97'), 'algorithm': 'Ed25519',
       'kms_key_ref': 'env:SIGNING_PRIVATE_KEY_V1', 'is_active': True, ...}
      ```
      `id` di database cocok persis dengan yang dicetak skrip.
- [x] **2.4** `SIGNING_PRIVATE_KEY_V1=` (kosong) ditambahkan ke `backend/.env.example` dengan
      komentar penjelasan — rekan tim tahu variabel ini wajib ada, tanpa key asli ter-expose.

**Tahap 2 SELESAI (2026-10-26).** 1 signing key aktif tersimpan di Neon, private key tersimpan
aman di `backend/.env` (gitignored), siap dipakai Tahap 3.

---

## 3. Implementasi Fungsi Inti (`backend/services/kripto.py`, modul baru)

- [x] **3.1** `hitung_payload_hash(payload: dict) -> str` — implementasi persis sesuai
      `SPEC_PAYLOAD.md` 1.1. Unit test `test_hash_cocok_dgn_nilai_di_spec_payload_md` adalah
      regression test LANGSUNG terhadap hash yang terdokumentasi di spec — kalau implementasi
      menyimpang dari dokumen, test ini gagal duluan.
- [x] **3.2** `tanda_tangani(payload_hash, private_key) -> str` — Ed25519 sign, output base64.
      Memakai konvensi signing eksplisit (sign bytes UTF-8 dari string hex, lihat SPEC_PAYLOAD.md
      1.1 poin 7) yang ditemukan saat audit Tahap 1.
- [x] **3.3** `verifikasi_signature(payload_hash, signature, public_key) -> bool` — Ed25519 verify,
      menerima `public_key` sebagai PARAMETER (bukan diam-diam ambil key aktif) — mengimplementasikan
      langsung kebijakan rotasi key di SPEC_PAYLOAD.md 1.4. Catatan penting utk Tahap 4: fungsi ini
      HARUS dipanggil ULANG tiap endpoint verifikasi diakses, bukan hasil cache dibaca dari DB.
- [x] **3.4** 8 unit test ditulis (`backend/tests/test_kripto.py`) & **DIJALANKAN, 8/8 PASSED**:
      - Hash deterministic & tidak peduli urutan key dict
      - Avalanche effect (1 field beda → hash beda >25% karakter)
      - Regression test vs `SPEC_PAYLOAD.md`
      - **Signature invalid kalau payload diubah setelah ditandatangani** (uji tamper inti, 3.4/5.2)
      - Signature invalid kalau pakai public key yang salah (cegah key confusion)
      - `muat_public_key()` menghasilkan objek yang benar
      - **Uji integrasi tambahan** (di luar pytest, dijalankan manual): key asli dari Tahap 2
        (dibaca via `muat_private_key()`) dipakai sign+verify end-to-end — HASIL: `True`,
        membuktikan Tahap 2 & 3 benar-benar terhubung, bukan cuma lolos terpisah-pisah.

**Tahap 3 SELESAI (2026-10-26).** `pytest>=9.1` ditambahkan ke `backend/requirements.txt`
(belum ada framework test sebelumnya di backend).

---

## 4. Endpoint Backend

- [x] **4.1** `services/sertifikat_service.py::terbitkan_sertifikat()` — dihubungkan ke
      `routers/verification.py` (dipanggil SEKALI, hanya saat `rekomendasi_status ==
      "terverifikasi"`). Payload dibangun persis sesuai `SPEC_PAYLOAD.md` 1.2.a (termasuk
      `creator_id`, temuan audit Tahap 1). Validasi eksplisit: raise error jelas kalau
      `karya.file_hash`/`karya.seniman_id` belum terisi, atau tidak ada signing key aktif.
      **Diuji end-to-end nyata** (karya+user disposable, dihapus setelah uji): sertifikat
      terbit, `artwork_id` ter-generate (`GAL-ART-2026-NNNNNN`), VALID sebelum tamper.
- [x] **4.2** `services/transaksi_service.py::buat_transaksi()` + `catat_transfer_kepemilikan()`
      — dipisah sesuai keputusan `SPEC_PAYLOAD.md` 1.2.b. **Diuji end-to-end nyata**: signature
      transaksi dibuat sekali, **terbukti TETAP VALID setelah status berubah 3x** (menunggu →
      dibayar → dikonfirmasi → selesai) — membuktikan keputusan mengecualikan `status` dari
      payload benar bekerja. Transfer kepemilikan menutup baris lama + buka baris baru, partial
      unique index DB dikonfirmasi tetap menjaga tepat 1 pemilik aktif.
- [x] **4.3** `GET /api/verifikasi/{artwork_id}` (`routers/verifikasi_publik.py`, tanpa login) —
      **2 pengecekan independen** dihitung ulang tiap request (hash_cocok + signature_valid,
      BUKAN baca kolom status): `status_keseluruhan` cuma "VALID" kalau keduanya benar.
      **Diuji end-to-end nyata dengan uji tamper sungguhan**: VALID sebelum tamper →
      `karya.seniman_id` diganti langsung di DB (simulasi serangan ambil-alih pengakuan karya)
      → **INVALID terdeteksi otomatis**, tanpa perlu kode tambahan apa pun.
- [x] **4.4** Migrasi `0008_artwork_id` (`karya.artwork_id`, Text, UNIQUE, nullable) — dijalankan
      nyata ke Neon (`alembic upgrade head`), kolom terverifikasi ada via query langsung.
      Keterbatasan jujur dicatat di kode: penomoran urut BUKAN atomic sequence (cukup untuk
      skala prototipe, race condition mungkin di skala produksi tinggi).

**Tahap 4 SELESAI (2026-10-26).** Semua 4 bagian diuji dengan data NYATA di Neon (bukan mock/dry
run), termasuk 2 skenario tamper eksplisit yang keduanya berhasil terdeteksi, lalu data uji
dibersihkan sampai 0 sisa (diverifikasi query ulang).

---

## 5. Pengujian End-to-End

Semua 4 item diuji **lewat HTTP sungguhan** (server `uvicorn` dijalankan nyata di
`127.0.0.1:8077`, request pakai `httpx`, bukan panggil fungsi Python langsung) — lebih kuat
dari Tahap 4 yang masih panggil service langsung. Model AI (Art-to-Art/Art-to-AI) sungguhan
dimuat & dipakai (Visual Search graceful-degrade, tidak dibutuhkan di uji ini).

- [x] **5.1** `POST /api/karya` (upload nyata, gambar asli dari `mobile/assets/images/catalog/`)
      → `POST /api/karya/{id}/verify` (Art-to-Art+Art-to-AI SUNGGUHAN, bukan mock — hasil
      `ai_detection_result="lolos"`, `rekomendasi_status="terverifikasi"`) → sertifikat & `artwork_id`
      (`GAL-ART-2026-000001`) terbit OTOMATIS lewat hook di 4.1, tanpa dipanggil manual → `GET
      /api/verifikasi/GAL-ART-2026-000001` → **`status_keseluruhan: "VALID"`**.
- [x] **5.2** `digital_signature` sertifikat dirusak LANGSUNG via SQL (`UPDATE sertifikat_keaslian
      SET digital_signature = 'RUSAK_SENGAJA...'`) → `GET /api/verifikasi/...` (request HTTP BARU,
      server terpisah dari proses pengujian) → **`signature_valid: false`, `status_keseluruhan:
      "INVALID"`** — tanpa server crash (HTTP 200, bukan 500), tamper murni terdeteksi.
- [x] **5.3** 2 penjualan berurutan (upload_asli → kolektor A → kolektor B) via
      `buat_transaksi()`+`catat_transfer_kepemilikan()` → **`sertifikat_aktif_id` TERBUKTI TIDAK
      berubah**, 3 baris riwayat kepemilikan (1 upload_asli + 2 pembelian), tepat 1 baris aktif
      (`dilepas_at IS NULL`) — partial unique index DB terbukti konsisten.
- [x] **5.4** Rotasi key (`buat_signing_key.py --force`) → key lama `revoked_at` terisi → `GET
      /api/verifikasi/GAL-ART-2026-000001` (sertifikat ditandatangani key LAMA) → **`status_keseluruhan:
      "VALID"` tetap**, plus `peringatan_key_dicabut: true` (transparansi tambahan, bukan di
      spesifikasi awal tapi masuk akal ditambahkan). Membuktikan kebijakan rotasi SPEC_PAYLOAD.md
      1.4 benar terimplementasi.

**Insiden kecil saat uji (dicatat jujur):** proses cleanup data uji sempat tidak sengaja menghapus
SEMUA baris `signing_keys` (termasuk key produksi asli dari Tahap 2, bukan cuma key uji rotasi) --
`DELETE FROM signing_keys` tanpa `WHERE` sempat dipakai. Ketahuan karena `scripts/buat_signing_key.py`
**menolak jalan** (pengaman "jangan timpa env var yang sudah ada" justru menangkap inkonsistensi ini).
Diperbaiki: baris `SIGNING_PRIVATE_KEY_*` lama dibersihkan dari `.env` (TANPA pernah menampilkan
nilainya di log mana pun), key produksi baru di-generate ulang bersih. **Semua data uji (karya, user,
transaksi, kepemilikan, signing_keys uji) sudah dibersihkan -- diverifikasi 0 sisa**, sistem kembali
ke 1 signing key aktif yang valid.

---

## 6. Dokumentasi untuk Laporan/Demo

- [x] **6.1** Kalimat metode final + 3 jawaban siap pakai (deteksi plagiarisme? pindah tangan?
      kenapa bukan blockchain/NFT?) — lihat `ml-digital-art-identity/LAPORAN_KRIPTOGRAFI.md`
      bagian 1, disesuaikan dengan implementasi akhir (bukan cuma draf konsep).
- [x] **6.2** Bagian "Keterbatasan" ditulis eksplisit — 7 poin (`LAPORAN_KRIPTOGRAFI.md` bagian 4),
      termasuk kebijakan key non-KMS, payload kanonik desain internal, celah Auth belum ada,
      checkout belum dibangun, data pengujian sintetis.
- [x] **6.3** Bukti observasi nyata (pengganti screenshot statis) — kutipan JSON APA ADANYA dari
      3 skenario hasil uji Tahap 5 (VALID sebelum tamper, INVALID setelah tamper, VALID+peringatan
      setelah rotasi key) dicantumkan di `LAPORAN_KRIPTOGRAFI.md` bagian 3. Perintah siap pakai
      utk screenshot LIVE saat demo sungguhan ada di bagian 5 dokumen yang sama.

**Tahap 6 SELESAI (2026-10-27).** Seluruh `TODO_KRIPTOGRAFI.md` (Tahap 1-6) kini selesai.

---

## Urutan Pengerjaan Ringkas

```
1 (desain, tulis dokumen)  →  2 (setup key)  →  3 (fungsi inti + unit test)
   →  4 (endpoint)  →  5 (uji end-to-end, termasuk uji tamper)  →  6 (dokumentasi)
```

Jangan lompat ke bagian 2 sebelum bagian 1 selesai ditulis — keputusan di bagian 1 (format
payload, kebijakan key) akan menentukan bentuk kode di bagian 3 & 4; mengubahnya belakangan
berarti menulis ulang.
