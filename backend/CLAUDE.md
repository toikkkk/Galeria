# CLAUDE.md — `backend/` — Skema Database Neon (GALERIA)

Referensi SQL **lengkap** untuk seluruh skema Neon Postgres proyek GALERIA.
Baca file ini (selain `CLAUDE.md` di root repo) sebelum mengerjakan apa pun
yang menyentuh `backend/models/`, `backend/alembic/`, atau database secara
langsung.

## Status saat ini (2026-10-01)

**Seluruh skema (Fase 1-5) SUDAH diterapkan ke Neon** — 19 tabel, migration
`0001_initial` s.d. `0007_fase5_engagement`, `alembic current` menunjukkan
`0007_fase5_engagement (head)`. Semua tag status per tabel di bawah ini
(✅/🔲) mencerminkan kondisi NYATA, bukan rencana. **Catatan penting:** ini
murni skema/struktur tabel — SEBAGIAN BESAR belum punya endpoint/business
logic yang memakainya (Auth, R2, sign/verify sertifikat, checkout transaksi,
bidding lelang, dst — lihat root `CLAUDE.md` bagian "Status Progress").

## Hubungan file ini dengan Alembic — WAJIB DIPAHAMI DULU

Proyek ini pakai **Alembic sebagai satu-satunya mekanisme migrasi produksi**
(lihat root `CLAUDE.md` bagian "Cara Kerja Neon"). File ini **BUKAN
pengganti Alembic** — ini adalah:

1. **Peta lengkap** seluruh skema target (yang sudah diterapkan MAUPUN yang
   masih draft), supaya siapa pun bisa lihat gambaran utuh database tanpa
   harus membongkar satu-satu file `alembic/versions/*.py`.
2. **Sumber SQL siap-pakai** kalau perlu prototyping cepat langsung di Neon
   SQL Editor (mis. coba query, cek index, debug data) — SQL di sini valid
   dijalankan langsung.
3. **Draft dasar** untuk ditulis ulang jadi migration Alembic resmi
   (`alembic revision -m "..."`) begitu sebuah fase mulai dikerjakan — JANGAN
   jalankan bagian "belum diterapkan" langsung ke Neon produksi di luar
   Alembic, supaya riwayat migrasi tetap konsisten & bisa di-rollback.

Setiap bagian diberi status:
- **✅ SUDAH DITERAPKAN** — sudah ada di `alembic/versions/`, SQL di bawah ini
  disalin PERSIS dari migration yang sudah di-apply (`0001_initial`,
  `0002_verification_engine`). Kalau mau ubah, buat migration baru — JANGAN
  edit file migration lama yang sudah di-apply ke Neon manapun (dev/staging).
- **🔲 BELUM DITERAPKAN** — desain sudah final (dibahas & disepakati di root
  `CLAUDE.md` bagian "Skema Data Utama"), tapi belum ada migration-nya. SQL
  di bawah ini siap jadi basis migration tsb.

## Prinsip desain (berlaku ke SEMUA tabel — lihat root CLAUDE.md untuk alasan lengkap)

- UUID sebagai PK, bukan auto-increment int.
- `created_at`/`updated_at` di semua tabel baru.
- Postgres ENUM native untuk kolom status, bukan string bebas.
- Uang = integer (IDR, tanpa desimal). **Catatan konsistensi:** `karya.price_idr`
  (sudah diterapkan) pakai `INTEGER` (maks ~2,1 miliar) — cukup untuk 8 data
  seed saat ini, tapi tabel finansial BARU (`transaksi`, `lelang`,
  `event_tiket`) di bawah sengaja pakai `BIGINT` (maks ~9,2 triliun triliun)
  supaya aman untuk karya bernilai sangat tinggi. Pertimbangkan migration
  pelebaran `karya.price_idr` ke `BIGINT` suatu saat untuk konsistensi penuh
  — tidak mendesak (perubahan tipe ini backward-compatible, tidak breaking).
- `TIMESTAMPTZ` untuk tabel BARU (aman dari ambiguitas timezone server).
  **Catatan konsistensi:** tabel yang SUDAH diterapkan (`karya`,
  `karya_fingerprints`, dst) pakai `TIMESTAMP` biasa (naive) — inkonsistensi
  kecil yang sudah ada, tidak dipaksa diubah sekarang (breaking change ke
  data eksisting), tapi SEMUA tabel baru mulai dari Fase 1 Auth wajib pakai
  `TIMESTAMPTZ`.
- FK `ON DELETE` dipilih sadar: `CASCADE` untuk data anak yang tak berarti
  tanpa induknya, `RESTRICT` untuk data historis/finansial yang wajib tetap
  ada, `SET NULL` untuk referensi opsional yang boleh putus.
- Soft-delete (`deleted_at`/`is_active`) untuk `karya` dan `users` — bukan
  `DELETE` fisik.

## Urutan eksekusi (dependency FK, WAJIB diikuti urutannya)

```
0. Extensions: vector, citext
1. ENUM types baru
2. users
3. auth_sessions
4. [ALTER] karya                    -- tabel sudah ada, tambah kolom baru
   (sertifikat_aktif_id BELUM di sini -- lihat langkah 10, circular FK)
5. karya_embeddings                 -- sudah ada, tidak berubah
6. karya_fingerprints                -- sudah ada, tidak berubah
7. [ALTER] karya_verifikasi_log      -- tambah FK reviewer_id -> users
8. signing_keys
9. sertifikat_keaslian
10. [ALTER] karya ADD sertifikat_aktif_id   -- circular FK karya<->sertifikat_keaslian, diselesaikan di sini
11. transaksi
12. kepemilikan_karya
13. lelang
14. lelang_bids
15. events
16. event_tiket
17. event_tiket_pembelian
18. koleksi_favorit
19. notifikasi
20. subscriptions
```

Alasan urutan #4/#10 dipisah: `karya.sertifikat_aktif_id` menunjuk ke
`sertifikat_keaslian.id`, TAPI `sertifikat_keaslian.karya_id` menunjuk balik
ke `karya.id` — dua tabel saling rujuk (circular FK). Postgres tidak bisa
`CREATE TABLE` keduanya sekaligus dengan FK lengkap; solusinya: buat `karya`
dulu (tanpa `sertifikat_aktif_id`), lalu `sertifikat_keaslian` (boleh langsung
FK ke `karya` krn `karya` sudah ada), baru `ALTER TABLE karya ADD COLUMN
sertifikat_aktif_id ...` belakangan.

---

## 0. Extensions

```sql
-- SUDAH DITERAPKAN (0001_initial)
CREATE EXTENSION IF NOT EXISTS vector;

-- SUDAH DITERAPKAN (0003_fase1_identity_auth)
CREATE EXTENSION IF NOT EXISTS citext;
```

## 1. ENUM types (semua SUDAH DITERAPKAN, lihat migration masing-masing)

```sql
-- tipe_cek & hasil_cek -> 0002_verification_engine
-- user_role & status_verifikasi_karya -> 0003_fase1_identity_auth
-- art_to_art_hasil_sertifikat, ai_detection_hasil_sertifikat, status_akhir_sertifikat, status_transaksi, sumber_kepemilikan -> 0004_fase2_sertifikat_transaksi
-- status_lelang -> 0005_fase3_lelang
-- status_event & status_tiket_pembelian -> 0006_fase4_event
-- tipe_notifikasi, plan_subscription & status_subscription -> 0007_fase5_engagement

CREATE TYPE user_role AS ENUM ('seniman', 'kolektor', 'komunitas', 'admin');
CREATE TYPE status_verifikasi_karya AS ENUM ('menunggu', 'terverifikasi', 'ditolak', 'perlu_ditinjau');
CREATE TYPE art_to_art_hasil_sertifikat AS ENUM ('bersih', 'duplikat_terdeteksi');
CREATE TYPE ai_detection_hasil_sertifikat AS ENUM ('asli', 'ai_generated_terdeteksi');
CREATE TYPE status_akhir_sertifikat AS ENUM ('terverifikasi', 'ditolak');
CREATE TYPE sumber_kepemilikan AS ENUM ('upload_asli', 'pembelian', 'lelang', 'transfer_manual');
CREATE TYPE status_transaksi AS ENUM ('menunggu_pembayaran', 'dibayar', 'dikonfirmasi', 'selesai', 'dibatalkan');
CREATE TYPE status_lelang AS ENUM ('akan_datang', 'berlangsung', 'selesai', 'dibatalkan');
CREATE TYPE status_event AS ENUM ('draft', 'dipublikasikan', 'selesai', 'dibatalkan');
CREATE TYPE status_tiket_pembelian AS ENUM ('aktif', 'terpakai', 'dibatalkan');
CREATE TYPE tipe_notifikasi AS ENUM ('transaksi', 'lelang', 'event', 'verifikasi_karya', 'sistem');
CREATE TYPE plan_subscription AS ENUM ('ar_akses', 'komunitas_pro');
CREATE TYPE status_subscription AS ENUM ('aktif', 'kedaluwarsa', 'dibatalkan');
```

---

## FASE 1 — Identity & Auth

### `users` ✅ SUDAH DITERAPKAN (`0003_fase1_identity_auth`)

```sql
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email           CITEXT UNIQUE NOT NULL,
    password_hash   TEXT NULL,              -- NULL kalau user Google-only
    google_sub      TEXT UNIQUE NULL,       -- Google 'sub' claim, stabil selamanya
    display_name    TEXT NOT NULL,
    avatar_url      TEXT NULL,
    role            user_role NOT NULL,
    email_verified  BOOLEAN NOT NULL DEFAULT false,
    is_active       BOOLEAN NOT NULL DEFAULT true,   -- soft-ban, bukan DELETE
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Minimal satu dari dua wajib terisi -- user tidak boleh "tanpa cara login sama sekali".
ALTER TABLE users
    ADD CONSTRAINT users_punya_kredensial_login
    CHECK (password_hash IS NOT NULL OR google_sub IS NOT NULL);
```

`gen_random_uuid()` dipakai sebagai default LEVEL DATABASE (fallback aman
kalau ada insert manual/lewat script tanpa app) -- built-in Postgres sejak
v13, tidak butuh extension `pgcrypto`. **Catatan:** `karya.id` (tabel sudah
diterapkan) TIDAK punya default seperti ini, selalu diisi dari sisi aplikasi
(`uuid.uuid4()` SQLAlchemy) — tabel baru di fase ini sengaja dibuat lebih
defensif.

### `auth_sessions` ✅ SUDAH DITERAPKAN (`0003_fase1_identity_auth`)

```sql
CREATE TABLE auth_sessions (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id              UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    refresh_token_hash   TEXT NOT NULL,     -- HASH token, bukan token mentah
    device_info          TEXT NULL,
    ip_address           INET NULL,
    issued_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at           TIMESTAMPTZ NOT NULL,
    revoked_at           TIMESTAMPTZ NULL   -- diisi = logout paksa / revoke
);

CREATE INDEX auth_sessions_user_id_idx ON auth_sessions(user_id);
```

### `[ALTER] karya` — tambah kolom ✅ SUDAH DITERAPKAN (`0003_fase1_identity_auth`)

```sql
ALTER TABLE karya
    ADD COLUMN seniman_id        UUID NULL REFERENCES users(id) ON DELETE RESTRICT,
    ADD COLUMN status_verifikasi status_verifikasi_karya NOT NULL DEFAULT 'menunggu',
    ADD COLUMN lebar_cm          NUMERIC(6,2) NULL,   -- wajib diisi utk AR, nullable di DB demi 8 baris seed lama
    ADD COLUMN tinggi_cm         NUMERIC(6,2) NULL,
    ADD COLUMN image_key         TEXT NULL,           -- lihat root CLAUDE.md "Cara Kerja Cloudflare R2"
    ADD COLUMN file_hash         TEXT NULL,           -- SHA-256 exact-integrity, lihat section 3
    ADD COLUMN deleted_at        TIMESTAMPTZ NULL;
```

`seniman_id`, `lebar_cm`, `tinggi_cm`, `file_hash` NULLABLE di level DB
walau konsepnya "wajib" — 8 baris seed (`scripts/seed_karya.py`) tidak
punya nilai ini. **Validasi "wajib diisi" untuk karya BARU dilakukan di
level aplikasi** (Pydantic schema endpoint upload), bukan `NOT NULL` DB,
supaya data lama tidak perlu di-backfill paksa sebelum migration jalan.

---

## FASE 2 — Karya & Verifikasi + Kriptografi Sertifikat

### `karya_embeddings` ✅ SUDAH DITERAPKAN (`0001_initial`)

```sql
CREATE TABLE karya_embeddings (
    karya_id    UUID PRIMARY KEY REFERENCES karya(id) ON DELETE CASCADE,
    embedding   VECTOR(768) NOT NULL   -- convnext_small, Visual Search
);

CREATE INDEX karya_embeddings_embedding_hnsw_idx
    ON karya_embeddings USING hnsw (embedding vector_cosine_ops);
```

### `karya_fingerprints` ✅ SUDAH DITERAPKAN (`0002_verification_engine`)

```sql
CREATE TABLE karya_fingerprints (
    karya_id                    UUID PRIMARY KEY REFERENCES karya(id) ON DELETE CASCADE,
    phash                       TEXT NOT NULL,
    embedding_arttoart          VECTOR(512) NOT NULL,   -- SiameseConvNeXt, Art-to-Art
    ai_generated_probability    FLOAT NOT NULL,
    ai_generated_flag           BOOLEAN NOT NULL,
    model_version_arttoart      TEXT NOT NULL,
    model_version_arttoai       TEXT NOT NULL,
    created_at                  TIMESTAMP DEFAULT now(),
    updated_at                  TIMESTAMP DEFAULT now()
);

-- L2 (Euclidean) -- BUKAN cosine, lihat models/verification.py kenapa.
CREATE INDEX karya_fingerprints_embedding_arttoart_hnsw_idx
    ON karya_fingerprints USING hnsw (embedding_arttoart vector_l2_ops);
```

### `karya_verifikasi_log` ✅ SUDAH DITERAPKAN (`0002_verification_engine`)

```sql
CREATE TYPE tipe_cek AS ENUM ('art_to_art', 'art_to_ai', 'manual_review');
CREATE TYPE hasil_cek AS ENUM (
    'lolos', 'duplikat_terdeteksi', 'ai_generated_terdeteksi',
    'ditolak_manual', 'disetujui_manual'
);

CREATE TABLE karya_verifikasi_log (
    id                   UUID PRIMARY KEY,
    karya_id             UUID NOT NULL REFERENCES karya(id) ON DELETE CASCADE,
    tipe_cek             tipe_cek NOT NULL,
    hasil                hasil_cek NOT NULL,
    skor                 FLOAT NULL,
    referensi_karya_id   UUID NULL REFERENCES karya(id) ON DELETE SET NULL,
    reviewer_id          UUID NULL,   -- FK ditambah di bawah, Fase 1 belum ada saat tabel ini dibuat
    catatan              TEXT NULL,
    created_at           TIMESTAMP DEFAULT now()
);

CREATE INDEX karya_verifikasi_log_karya_id_created_at_idx
    ON karya_verifikasi_log(karya_id, created_at);
```

### `[ALTER] karya_verifikasi_log` — tutup TODO FK reviewer ✅ SUDAH DITERAPKAN (`0003_fase1_identity_auth`)

```sql
-- Dijalankan SETELAH tabel `users` ada (Fase 1). Menutup TODO yang sengaja
-- ditinggalkan di models/verification.py saat tabel ini pertama dibuat.
ALTER TABLE karya_verifikasi_log
    ADD CONSTRAINT karya_verifikasi_log_reviewer_id_fkey
    FOREIGN KEY (reviewer_id) REFERENCES users(id) ON DELETE SET NULL;
```

### `signing_keys` ✅ SUDAH DITERAPKAN (`0004_fase2_sertifikat_transaksi`)

```sql
CREATE TABLE signing_keys (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    public_key    TEXT NOT NULL,
    algorithm     TEXT NOT NULL,     -- mis. 'Ed25519' -- eksplisit, jangan hardcode di kode
    kms_key_ref   TEXT NOT NULL,     -- pointer ke secret manager -- PRIVATE KEY TIDAK PERNAH DI SINI
    is_active     BOOLEAN NOT NULL DEFAULT true,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at    TIMESTAMPTZ NULL
);
```

### `sertifikat_keaslian` ✅ SUDAH DITERAPKAN (`0004_fase2_sertifikat_transaksi`)

```sql
CREATE TABLE sertifikat_keaslian (
    id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    karya_id               UUID NOT NULL REFERENCES karya(id) ON DELETE CASCADE,
    file_hash              TEXT NOT NULL,   -- SNAPSHOT, immutable, walau karya.file_hash berubah nanti
    art_to_art_result      art_to_art_hasil_sertifikat NOT NULL,
    ai_detection_result    ai_detection_hasil_sertifikat NOT NULL,
    status_akhir           status_akhir_sertifikat NOT NULL,
    verified_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    payload_hash           TEXT NOT NULL,       -- SHA-256(payload kanonik) yang ditandatangani
    digital_signature      TEXT NOT NULL,
    signing_key_id         UUID NOT NULL REFERENCES signing_keys(id) ON DELETE RESTRICT,
    created_at             TIMESTAMPTZ NOT NULL DEFAULT now()
    -- TIDAK ADA updated_at -- APPEND-ONLY, lihat root CLAUDE.md domain 3.
    -- Re-verifikasi = INSERT baris baru, JANGAN UPDATE baris lama.
);

CREATE INDEX sertifikat_keaslian_karya_id_idx ON sertifikat_keaslian(karya_id);
```

### `[ALTER] karya` — pointer sertifikat aktif ✅ SUDAH DITERAPKAN (`0004_fase2_sertifikat_transaksi`)

```sql
-- Dijalankan SETELAH sertifikat_keaslian ada -- resolusi circular FK, lihat
-- "Urutan eksekusi" di atas.
ALTER TABLE karya
    ADD COLUMN sertifikat_aktif_id UUID NULL REFERENCES sertifikat_keaslian(id) ON DELETE SET NULL;
```

---

## FASE 2 (lanjutan) — Kepemilikan & Transaksi

### `transaksi` ✅ SUDAH DITERAPKAN (`0004_fase2_sertifikat_transaksi`)

```sql
CREATE TABLE transaksi (
    id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    karya_id               UUID NOT NULL REFERENCES karya(id) ON DELETE RESTRICT,
    pembeli_id             UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    penjual_id             UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    harga_final_idr        BIGINT NOT NULL CHECK (harga_final_idr > 0),
    komisi_platform_idr    BIGINT NOT NULL CHECK (komisi_platform_idr >= 0),
    status                 status_transaksi NOT NULL DEFAULT 'menunggu_pembayaran',
    payload_hash           TEXT NOT NULL,
    digital_signature      TEXT NOT NULL,
    signing_key_id         UUID NOT NULL REFERENCES signing_keys(id) ON DELETE RESTRICT,
    created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX transaksi_karya_id_idx ON transaksi(karya_id);
CREATE INDEX transaksi_pembeli_id_idx ON transaksi(pembeli_id);
CREATE INDEX transaksi_penjual_id_idx ON transaksi(penjual_id);
```

`komisi_platform_idr` dicatat EKSPLISIT per baris (bukan dihitung ulang dari
persen saat laporan dibuat) — kalau tarif komisi berubah di masa depan,
laporan keuangan lama tetap benar.

### `kepemilikan_karya` ✅ SUDAH DITERAPKAN (`0004_fase2_sertifikat_transaksi`)

```sql
CREATE TABLE kepemilikan_karya (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    karya_id       UUID NOT NULL REFERENCES karya(id) ON DELETE CASCADE,
    pemilik_id     UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    sumber         sumber_kepemilikan NOT NULL,
    transaksi_id   UUID NULL REFERENCES transaksi(id) ON DELETE SET NULL,
    diperoleh_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    dilepas_at     TIMESTAMPTZ NULL,   -- NULL = pemilik AKTIF sekarang
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Partial unique index: menjamin DI LEVEL DATABASE tidak mungkin ada 2
-- "pemilik aktif" utk 1 karya di waktu bersamaan -- bukan cuma app logic.
CREATE UNIQUE INDEX kepemilikan_karya_satu_pemilik_aktif_idx
    ON kepemilikan_karya(karya_id) WHERE dilepas_at IS NULL;

CREATE INDEX kepemilikan_karya_pemilik_id_idx ON kepemilikan_karya(pemilik_id);
```

---

## FASE 3 — Lelang ✅ SUDAH DITERAPKAN (`0005_fase3_lelang`)

```sql
CREATE TABLE lelang (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    karya_id             UUID NOT NULL REFERENCES karya(id) ON DELETE RESTRICT,
    harga_awal_idr       BIGINT NOT NULL CHECK (harga_awal_idr > 0),
    kelipatan_bid_idr    BIGINT NOT NULL CHECK (kelipatan_bid_idr > 0),
    mulai_at             TIMESTAMPTZ NOT NULL,
    selesai_at           TIMESTAMPTZ NOT NULL,
    status               status_lelang NOT NULL DEFAULT 'akan_datang',
    pemenang_id          UUID NULL REFERENCES users(id) ON DELETE SET NULL,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT lelang_waktu_valid CHECK (selesai_at > mulai_at)
);

CREATE INDEX lelang_karya_id_idx ON lelang(karya_id);
CREATE INDEX lelang_status_idx ON lelang(status);

CREATE TABLE lelang_bids (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lelang_id    UUID NOT NULL REFERENCES lelang(id) ON DELETE CASCADE,
    bidder_id    UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    jumlah_idr   BIGINT NOT NULL CHECK (jumlah_idr > 0),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Riwayat SEMUA bid (bukan cuma tertinggi) -- transparansi & bahan dispute.
CREATE INDEX lelang_bids_lelang_id_created_at_idx ON lelang_bids(lelang_id, created_at DESC);
```

---

## FASE 4 — Event Komunitas ✅ SUDAH DITERAPKAN (`0006_fase4_event`)

```sql
CREATE TABLE events (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    komunitas_id   UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,  -- role='komunitas'
    judul          TEXT NOT NULL,
    deskripsi      TEXT NULL,
    lokasi         TEXT NULL,
    mulai_at       TIMESTAMPTZ NOT NULL,
    selesai_at     TIMESTAMPTZ NOT NULL,
    status         status_event NOT NULL DEFAULT 'draft',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT events_waktu_valid CHECK (selesai_at > mulai_at)
);

CREATE INDEX events_komunitas_id_idx ON events(komunitas_id);

CREATE TABLE event_tiket (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id     UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    nama_tiket   TEXT NOT NULL,
    harga_idr    BIGINT NOT NULL CHECK (harga_idr >= 0),
    kuota        INTEGER NOT NULL CHECK (kuota >= 0)
);

CREATE TABLE event_tiket_pembelian (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_tiket_id   UUID NOT NULL REFERENCES event_tiket(id) ON DELETE RESTRICT,
    pembeli_id       UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    kode_tiket       TEXT NOT NULL UNIQUE,   -- utk QR/check-in
    status           status_tiket_pembelian NOT NULL DEFAULT 'aktif',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX event_tiket_pembelian_pembeli_id_idx ON event_tiket_pembelian(pembeli_id);
```

---

## FASE 5 — Engagement & Monetisasi ✅ SUDAH DITERAPKAN (`0007_fase5_engagement`)

```sql
CREATE TABLE koleksi_favorit (
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    karya_id     UUID NOT NULL REFERENCES karya(id) ON DELETE CASCADE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, karya_id)
);

CREATE TABLE notifikasi (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tipe         tipe_notifikasi NOT NULL,
    judul        TEXT NOT NULL,
    isi          TEXT NULL,
    is_read      BOOLEAN NOT NULL DEFAULT false,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX notifikasi_user_id_created_at_idx ON notifikasi(user_id, created_at DESC);

CREATE TABLE subscriptions (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan_type     plan_subscription NOT NULL,
    status        status_subscription NOT NULL DEFAULT 'aktif',
    mulai_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    berakhir_at   TIMESTAMPTZ NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT subscriptions_waktu_valid CHECK (berakhir_at > mulai_at)
);

CREATE INDEX subscriptions_user_id_idx ON subscriptions(user_id);
```

---

## Rollback (urutan terbalik dari "Urutan eksekusi")

Hanya untuk bagian **BELUM DITERAPKAN** — rollback bagian yang sudah
diterapkan harus lewat `alembic downgrade`, bukan DROP manual.

```sql
DROP TABLE IF EXISTS subscriptions;
DROP TABLE IF EXISTS notifikasi;
DROP TABLE IF EXISTS koleksi_favorit;
DROP TABLE IF EXISTS event_tiket_pembelian;
DROP TABLE IF EXISTS event_tiket;
DROP TABLE IF EXISTS events;
DROP TABLE IF EXISTS lelang_bids;
DROP TABLE IF EXISTS lelang;
DROP TABLE IF EXISTS kepemilikan_karya;
DROP TABLE IF EXISTS transaksi;
ALTER TABLE karya DROP COLUMN IF EXISTS sertifikat_aktif_id;
DROP TABLE IF EXISTS sertifikat_keaslian;
DROP TABLE IF EXISTS signing_keys;
ALTER TABLE karya_verifikasi_log DROP CONSTRAINT IF EXISTS karya_verifikasi_log_reviewer_id_fkey;
ALTER TABLE karya
    DROP COLUMN IF EXISTS seniman_id,
    DROP COLUMN IF EXISTS status_verifikasi,
    DROP COLUMN IF EXISTS lebar_cm,
    DROP COLUMN IF EXISTS tinggi_cm,
    DROP COLUMN IF EXISTS image_key,
    DROP COLUMN IF EXISTS file_hash,
    DROP COLUMN IF EXISTS deleted_at;
DROP TABLE IF EXISTS auth_sessions;
DROP TABLE IF EXISTS users;

DROP TYPE IF EXISTS status_subscription;
DROP TYPE IF EXISTS plan_subscription;
DROP TYPE IF EXISTS tipe_notifikasi;
DROP TYPE IF EXISTS status_tiket_pembelian;
DROP TYPE IF EXISTS status_event;
DROP TYPE IF EXISTS status_lelang;
DROP TYPE IF EXISTS status_transaksi;
DROP TYPE IF EXISTS sumber_kepemilikan;
DROP TYPE IF EXISTS status_akhir_sertifikat;
DROP TYPE IF EXISTS ai_detection_hasil_sertifikat;
DROP TYPE IF EXISTS art_to_art_hasil_sertifikat;
DROP TYPE IF EXISTS status_verifikasi_karya;
DROP TYPE IF EXISTS user_role;
```

---

## Cara pakai file ini

1. **Prototyping cepat / eksplorasi** (bukan produksi): copy blok SQL fase
   yang relevan, jalankan langsung di Neon SQL Editor.
2. **Implementasi resmi** (yang akan benar-benar dipakai aplikasi): tulis
   ulang blok SQL fase tsb jadi migration Alembic
   (`alembic revision -m "fase 1: users + auth_sessions"` lalu isi
   `upgrade()`/`downgrade()` mengikuti pola `0001_initial.py`/
   `0002_verification_engine.py`), baru `alembic upgrade head`. JANGAN
   jalankan SQL mentah ke Neon yang sama dengan yang dipakai Alembic tanpa
   lewat migration — Alembic akan kehilangan jejak versi skema.
3. Begitu satu fase selesai di-migration-kan, update status section terkait
   di file ini dari 🔲 **BELUM DITERAPKAN** jadi ✅ **SUDAH DITERAPKAN**
   (sertakan nama file migration-nya), supaya file ini tetap jadi cermin
   akurat dari Neon yang sungguhan — JANGAN biarkan dokumen ini basi.
