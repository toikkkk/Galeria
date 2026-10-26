-- Schema TERPISAH utk data contoh dashboard admin. Bukan tabel produksi (public.*),
-- DDL sengaja di luar Alembic. Hapus semua dgn: DROP SCHEMA dummy_admin CASCADE;
CREATE SCHEMA IF NOT EXISTS dummy_admin;

CREATE TABLE IF NOT EXISTS dummy_admin.users (
    id            uuid PRIMARY KEY,
    role          text NOT NULL CHECK (role IN ('seniman','kolektor')),
    display_name  text NOT NULL,
    created_at    timestamptz NOT NULL
);

CREATE TABLE IF NOT EXISTS dummy_admin.subscriptions (
    id           uuid PRIMARY KEY,
    user_id      uuid NOT NULL REFERENCES dummy_admin.users(id) ON DELETE CASCADE,
    -- kolektor_pro: AR + gabung Komunitas (Rp50.000/bln) | seniman_pro: promosi karya + buat event
    -- + buat komunitas (Rp150.000/bln). Nilai ini khusus data contoh dashboard admin.
    plan_type    text NOT NULL CHECK (plan_type IN ('kolektor_pro','seniman_pro')),
    status       text NOT NULL CHECK (status IN ('aktif','kadaluarsa','dibatalkan')),
    harga_bulanan_idr bigint NOT NULL,
    mulai_at     timestamptz NOT NULL,
    berakhir_at  timestamptz NOT NULL CHECK (berakhir_at > mulai_at)
);
CREATE INDEX IF NOT EXISTS ix_dadm_sub_user ON dummy_admin.subscriptions(user_id);

-- Satu baris per siklus penagihan 30 hari. Pendapatan langganan platform = jumlah_idr (100%).
CREATE TABLE IF NOT EXISTS dummy_admin.pembayaran_langganan (
    id               uuid PRIMARY KEY,
    subscription_id  uuid NOT NULL REFERENCES dummy_admin.subscriptions(id) ON DELETE CASCADE,
    dibayar_at       timestamptz NOT NULL,
    jumlah_idr       bigint NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_dadm_bayar_waktu ON dummy_admin.pembayaran_langganan(dibayar_at);

CREATE TABLE IF NOT EXISTS dummy_admin.transaksi (
    id                    uuid PRIMARY KEY,
    karya_id              uuid NOT NULL,
    pembeli_id            uuid NOT NULL REFERENCES dummy_admin.users(id),
    penjual_id            uuid NOT NULL REFERENCES dummy_admin.users(id),
    harga_final_idr       bigint NOT NULL,
    komisi_platform_idr   bigint NOT NULL,   -- 2,5% dari harga_final_idr
    created_at            timestamptz NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_dadm_tx_waktu ON dummy_admin.transaksi(created_at);

-- Hasil batch forecasting (ditulis dashboard-admin/forecasting/jalankan.py,
-- dibaca backend /api/admin/*; backend TIDAK menjalankan model).
-- target: total | komisi | langganan_kolektor | langganan_seniman
CREATE TABLE IF NOT EXISTS dummy_admin.forecast_pendapatan (
    target      text NOT NULL,
    bulan       date NOT NULL,
    model       text NOT NULL,
    p10_idr     bigint NOT NULL,
    p50_idr     bigint NOT NULL,
    p90_idr     bigint NOT NULL,
    dibuat_at   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (target, bulan, model)
);

CREATE TABLE IF NOT EXISTS dummy_admin.forecast_backtest (
    target       text NOT NULL,
    model        text NOT NULL,
    wape_pct     double precision NOT NULL,   -- sum|err| / sum|aktual| * 100
    smape_pct    double precision NOT NULL,
    mase         double precision NOT NULL,
    cakupan_p80  double precision,            -- porsi aktual di dalam P10-P90 (null utk model titik)
    n_evaluasi   integer NOT NULL,
    terpilih     boolean NOT NULL DEFAULT false,
    PRIMARY KEY (target, model)
);

CREATE TABLE IF NOT EXISTS dummy_admin.forecast_meta (
    kunci  text PRIMARY KEY,
    nilai  text NOT NULL
);

-- Kolom MAPE & RMSE (kriteria pemilihan ARIMA vs Fuzzy Time Series). Idempotent; jalankan juga oleh forecasting/jalankan.py.
ALTER TABLE dummy_admin.forecast_backtest ADD COLUMN IF NOT EXISTS mape_pct double precision;
ALTER TABLE dummy_admin.forecast_backtest ADD COLUMN IF NOT EXISTS rmse_idr double precision;

-- Hasil cek data series sebelum memilih metode (ditulis forecasting/diagnosa.py, dibaca /api/admin/diagnosa).
CREATE TABLE IF NOT EXISTS dummy_admin.diagnosa_deret (
    target     text PRIMARY KEY,
    hasil      jsonb NOT NULL,
    dibuat_at  timestamptz NOT NULL DEFAULT now()
);
