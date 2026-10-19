-- Schema TERPISAH utk ulasan + hasil sentimen (data dummy). Tidak menyentuh public.* maupun
-- dummy_rekomendasi.*; FK sengaja tidak dipasang (schema ini di luar rantai migrasi tim).
CREATE SCHEMA IF NOT EXISTS dummy_sentimen;

CREATE TABLE IF NOT EXISTS dummy_sentimen.ulasan (
    ulasan_id         uuid PRIMARY KEY,
    transaksi_id      uuid NOT NULL,
    karya_id          uuid NOT NULL,
    kolektor_id       uuid NOT NULL,          -- penulis ulasan (pembeli)
    seniman_id        uuid NOT NULL,          -- yang diulas (penjual)
    teks              text NOT NULL,
    rating            smallint NOT NULL CHECK (rating BETWEEN 1 AND 5),
    sentimen_label    text NOT NULL CHECK (sentimen_label IN ('negatif','netral','positif')),  -- label buatan generator, HANYA utk evaluasi
    split             text NOT NULL CHECK (split IN ('train','val','test')),
    sentimen_prediksi text NOT NULL CHECK (sentimen_prediksi IN ('negatif','netral','positif')), -- keluaran model; ini yg dipakai aplikasi
    prob_negatif      real NOT NULL,
    prob_netral       real NOT NULL,
    prob_positif      real NOT NULL,
    model_version     text NOT NULL,
    created_at        timestamptz NOT NULL,
    dihitung_pada     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_ulasan_seniman_waktu ON dummy_sentimen.ulasan (seniman_id, created_at DESC);
