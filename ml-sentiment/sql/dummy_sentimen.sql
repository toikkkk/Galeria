-- Schema TERPISAH utk ulasan + hasil sentimen (data dummy). Tidak menyentuh public.* maupun
-- dummy_rekomendasi.*; FK sengaja tidak dipasang (schema ini di luar rantai migrasi tim).
CREATE SCHEMA IF NOT EXISTS dummy_sentimen;

CREATE TABLE IF NOT EXISTS dummy_sentimen.ulasan (
    ulasan_id         uuid PRIMARY KEY,
    transaksi_id      uuid,                   -- NULL utk ulasan dari app (belum ada pembelian terkait)
    karya_id          uuid NOT NULL,
    kolektor_id       uuid NOT NULL,          -- penulis ulasan (pembeli)
    seniman_id        uuid NOT NULL,          -- yang diulas (penjual)
    teks              text NOT NULL,
    rating            smallint NOT NULL CHECK (rating BETWEEN 1 AND 5),
    sentimen_label    text CHECK (sentimen_label IN ('negatif','netral','positif')),  -- label buatan generator, HANYA utk evaluasi
    split             text CHECK (split IN ('train','val','test')),
    sentimen_prediksi text CHECK (sentimen_prediksi IN ('negatif','netral','positif')), -- keluaran model; ini yg dipakai aplikasi
    prob_negatif      real,
    prob_netral       real,
    prob_positif      real,
    model_version     text,
    created_at        timestamptz NOT NULL,
    dihitung_pada     timestamptz,
    sumber            text NOT NULL DEFAULT 'dummy'  -- 'dummy' (generator) | 'app' (ditulis kolektor di aplikasi)
);
CREATE INDEX IF NOT EXISTS ix_ulasan_seniman_waktu ON dummy_sentimen.ulasan (seniman_id, created_at DESC);

-- Migrasi idempotent utk tabel yang sudah ada (dibuat sebelum fitur tulis ulasan). Ulasan 'app' disimpan
-- dulu TANPA sentimen (sentimen_prediksi NULL = menunggu analisis), diisi skrip scripts/analisis_ulasan_baru.py.
ALTER TABLE dummy_sentimen.ulasan ADD COLUMN IF NOT EXISTS sumber text NOT NULL DEFAULT 'dummy';
ALTER TABLE dummy_sentimen.ulasan ALTER COLUMN transaksi_id DROP NOT NULL;
ALTER TABLE dummy_sentimen.ulasan ALTER COLUMN sentimen_label DROP NOT NULL;
ALTER TABLE dummy_sentimen.ulasan ALTER COLUMN split DROP NOT NULL;
ALTER TABLE dummy_sentimen.ulasan ALTER COLUMN sentimen_prediksi DROP NOT NULL;
ALTER TABLE dummy_sentimen.ulasan ALTER COLUMN prob_negatif DROP NOT NULL;
ALTER TABLE dummy_sentimen.ulasan ALTER COLUMN prob_netral DROP NOT NULL;
ALTER TABLE dummy_sentimen.ulasan ALTER COLUMN prob_positif DROP NOT NULL;
ALTER TABLE dummy_sentimen.ulasan ALTER COLUMN model_version DROP NOT NULL;
ALTER TABLE dummy_sentimen.ulasan ALTER COLUMN dihitung_pada DROP NOT NULL;
ALTER TABLE dummy_sentimen.ulasan ALTER COLUMN dihitung_pada DROP DEFAULT;
-- satu kolektor, satu ulasan per karya
CREATE UNIQUE INDEX IF NOT EXISTS ux_ulasan_kolektor_karya ON dummy_sentimen.ulasan (kolektor_id, karya_id);
