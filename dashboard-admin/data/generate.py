"""Generator data dummy dashboard admin GALERIA (users, subscriptions, transaksi).

Data SINTETIS, dibuat dari simulasi per-pengguna dengan variabel-variabel yang
memang menggerakkan pendapatan komisi -- bukan angka acak per bulan:

  pengguna baru  ~ Poisson(PENGGUNA_BARU_AWAL * (1+g)^t * kampanye_t)
  upgrade Pro    ~ Bernoulli(hazard_t[role])  (naik bertahap + lonjakan promo)
  lama langganan ~ Geometric(p = 1 / rata-rata lama[role]), lalu bisa berlangganan lagi
  pembayaran     = 1x per siklus 30 hari: kolektor Rp50.000, seniman Rp150.000
  transaksi/bln  ~ Poisson(laju_dasar * tren_t * musim_bulan * (1+0.25*ramadan)
                           * (UPLIFT_PRO_KOLEKTOR jika kolektor sedang Pro)
                           * (1 + PROMO_LIFT * pangsa seniman Pro))
  penjual        : seniman Pro lebih sering terpilih (karyanya dipromosikan di beranda)
  harga          ~ Lognormal(median_t, sigma)   median_t naik (inflasi harga karya)
  komisi         = 2,5% * harga_final   (KOMISI_PLATFORM)

Pendapatan platform = komisi 2,5% penjualan karya + langganan Pro kolektor (AR + gabung
Komunitas) + langganan Pro seniman (promosi karya, buat event, buat komunitas); langganan
masuk 100% ke platform.

Konsekuensi yang disengaja: pangsa Pro kolektor menaikkan jumlah transaksi dan pangsa
Pro seniman menaikkan laju pembelian platform -- sehingga kovariat Pro punya sinyal nyata
utk model forecasting.
Skor forecasting di data ini mencerminkan desain simulasi, BUKAN performa
produksi (lihat README dashboard-admin).

Deterministik: seed tetap -> hasil identik tiap dijalankan.
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass

import numpy as np
import pandas as pd

SEED = 20260930

# Waktu acuan = akhir data dummy (sama dgn REKOMENDASI_WAKTU_ACUAN proyek lain).
WAKTU_ACUAN = pd.Timestamp("2026-09-30 23:59:59", tz="UTC")
BULAN_AWAL = pd.Timestamp("2023-10-01", tz="UTC")
N_BULAN = 36

KOMISI_PLATFORM = 0.025  # 2,5% dari harga_final

# --- parameter simulasi (semua dikumpulkan di sini agar mudah dilaporkan) ---
PENGGUNA_BARU_AWAL = 60.0  # pengguna baru/bulan di t=0
PENGGUNA_AWAL_LAUNCH = 120  # lonjakan hari peluncuran (t=0)
PERTUMBUHAN_PENGGUNA = 0.04  # +4%/bulan
KAMPANYE = {14: 1.5, 27: 1.4}  # indeks bulan -> pengali pengguna baru (promo)
PROB_ROLE = {"seniman": 0.35, "kolektor": 0.65}

# Paket Pro per role: (plan_type, harga per bulan IDR). Kolektor: AR + gabung Komunitas.
# Seniman: satu paket berisi promosi karya (tampil di beranda kolektor), buat event, buat komunitas.
PLAN = {"kolektor": ("kolektor_pro", 50_000), "seniman": ("seniman_pro", 150_000)}
SIKLUS_HARI = 30

HAZARD_UPGRADE_DASAR = {"kolektor": 0.010, "seniman": 0.006}  # peluang upgrade/bulan (non-Pro)
HAZARD_UPGRADE_NAIK = {"kolektor": 0.012, "seniman": 0.008}  # tambahan bertahap (sigmoid, tengah t=18)
HAZARD_PROMO = {"kolektor": {27: 0.018, 28: 0.018}, "seniman": {27: 0.010, 28: 0.010}}
HAZARD_BALIK_X = 0.5  # peluang berlangganan lagi setelah pernah Pro
RATA2_LAMA_PRO_BLN = {"kolektor": 10.0, "seniman": 8.0}  # rata-rata lama langganan (bulan)

LAJU_BELI_DASAR = 0.040  # transaksi/kolektor/bulan (non-Pro, t=0)
TREN_LAJU_BULANAN = 0.008  # kedewasaan platform: +0,8%/bulan
UPLIFT_PRO_KOLEKTOR = 1.9  # kolektor Pro belanja 1,9x lebih sering
PROMO_LIFT = 0.30  # laju beli platform naik 30% x pangsa seniman Pro (karya dipromosikan)
BOBOT_PENJUAL_PRO = 2.0  # seniman Pro lebih sering terpilih sbg penjual
EFEK_RAMADAN = 0.25
GUNCANG_BULANAN_SIGMA = 0.05  # guncangan pasar bulanan (lognormal)

MUSIM_BULAN = {1: 0.92, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 0.98,
               7: 0.94, 8: 1.0, 9: 1.0, 10: 1.02, 11: 1.06, 12: 1.20}

HARGA_MEDIAN_AWAL = 38_000_000  # IDR
INFLASI_HARGA_BULANAN = 0.004
HARGA_SIGMA = 0.75
HARGA_MIN, HARGA_MAKS = 1_500_000, 1_000_000_000

# Ramadan (tanggal awal, akhir) -- utk fraksi bulan yg jatuh di Ramadan.
RAMADAN = [
    ("2023-03-23", "2023-04-21"), ("2024-03-11", "2024-04-09"),
    ("2025-03-01", "2025-03-30"), ("2026-02-18", "2026-03-19"),
    ("2027-02-08", "2027-03-09"), ("2028-01-28", "2028-02-26"),
]


def awal_bulan(i: int) -> pd.Timestamp:
    return (BULAN_AWAL + pd.DateOffset(months=i)).normalize()


def fraksi_ramadan(bulan_awal: pd.Timestamp) -> float:
    """Porsi hari dalam bulan tsb yang jatuh di bulan Ramadan (0..1)."""
    akhir = bulan_awal + pd.offsets.MonthBegin(1)
    hari = pd.date_range(bulan_awal, akhir - pd.Timedelta(days=1), tz="UTC")
    n = 0
    for a, b in RAMADAN:
        a, b = pd.Timestamp(a, tz="UTC"), pd.Timestamp(b, tz="UTC")
        n += int(((hari >= a) & (hari <= b)).sum())
    return n / len(hari)


def kalender_bulanan(bulan_awal_list) -> pd.DataFrame:
    """Kovariat KALENDER (diketahui di masa depan) per bulan."""
    rows = []
    for b in bulan_awal_list:
        rows.append({"bulan": b, "flag_ramadan": fraksi_ramadan(b),
                     "flag_desember": 1.0 if b.month == 12 else 0.0,
                     "musim": MUSIM_BULAN[b.month]})
    return pd.DataFrame(rows)


@dataclass
class DataDummy:
    users: pd.DataFrame
    subscriptions: pd.DataFrame
    pembayaran: pd.DataFrame  # pembayaran langganan per siklus 30 hari
    transaksi: pd.DataFrame


def buat_data(seed: int = SEED) -> DataDummy:
    rng = np.random.default_rng(seed)

    # ---------- 1. pengguna ----------
    rows_user = []
    for t in range(N_BULAN):
        lam = PENGGUNA_BARU_AWAL * (1 + PERTUMBUHAN_PENGGUNA) ** t * KAMPANYE.get(t, 1.0)
        n = int(rng.poisson(lam)) + (PENGGUNA_AWAL_LAUNCH if t == 0 else 0)
        mulai = awal_bulan(t)
        hari_di_bulan = (mulai + pd.offsets.MonthBegin(1) - mulai).days
        for _ in range(n):
            rows_user.append((t, mulai + pd.Timedelta(days=int(rng.integers(0, hari_di_bulan)),
                                                      hours=int(rng.integers(0, 24)))))
    n_user = len(rows_user)
    roles = rng.choice(list(PROB_ROLE), size=n_user, p=list(PROB_ROLE.values()))
    users = pd.DataFrame({
        "id": [str(uuid.UUID(int=int(rng.integers(0, 2**63)) << 64 | int(rng.integers(0, 2**63))))
               for _ in range(n_user)],
        "role": roles,
        "bulan_daftar": [r[0] for r in rows_user],
        "created_at": [r[1] for r in rows_user],
    })
    users["display_name"] = [f"Pengguna {i + 1:05d}" for i in range(n_user)]

    # ---------- 2. langganan Pro (simulasi bulanan per pengguna) ----------
    def _uid() -> str:
        return str(uuid.UUID(int=int(rng.integers(0, 2**63)) << 64 | int(rng.integers(0, 2**63))))

    daftar = users["bulan_daftar"].to_numpy()
    created = users["created_at"].to_numpy()
    role_arr = users["role"].to_numpy()
    pro_sampai = np.full(n_user, np.datetime64("1970-01-01"), dtype="datetime64[ns]")
    pernah_pro = np.zeros(n_user, dtype=bool)
    spells = []  # (idx_user, mulai, berakhir, lama_bulan)
    pro_mid = np.zeros((N_BULAN, n_user), dtype=bool)  # status Pro tengah bulan t

    for t in range(N_BULAN):
        ms = awal_bulan(t)
        mid = ms + pd.Timedelta(days=14)
        sig = 1 / (1 + np.exp(-(t - 18) / 4))
        sedang_pro = pro_sampai > np.datetime64(ms.tz_localize(None))
        for role in PLAN:  # kolektor & seniman punya hazard/lama langganan masing-masing
            h = (HAZARD_UPGRADE_DASAR[role] + HAZARD_UPGRADE_NAIK[role] * sig
                 + HAZARD_PROMO[role].get(t, 0.0))
            kandidat = np.where((role_arr == role) & (daftar <= t) & ~sedang_pro)[0]
            h_i = np.where(pernah_pro[kandidat], h * HAZARD_BALIK_X, h)
            naik = kandidat[rng.random(len(kandidat)) < h_i]
            for i in naik:
                mulai = ms + pd.Timedelta(days=int(rng.integers(0, 28)), hours=int(rng.integers(0, 24)))
                mulai = max(mulai, pd.Timestamp(created[i]) + pd.Timedelta(hours=1))
                lama = int(rng.geometric(1 / RATA2_LAMA_PRO_BLN[role]))
                berakhir = mulai + pd.Timedelta(days=SIKLUS_HARI * lama)
                spells.append((i, mulai, berakhir, lama))
                pro_sampai[i] = np.datetime64(berakhir.tz_localize(None))
                pernah_pro[i] = True
        for (i, mulai, berakhir, _) in spells:
            if mulai <= mid < berakhir:
                pro_mid[t, i] = True

    sub_rows, bayar_rows = [], []
    for (i, mulai, berakhir, lama) in spells:
        role = role_arr[i]
        plan, harga = PLAN[role]
        sid = _uid()
        if berakhir > WAKTU_ACUAN:
            status = "aktif"
        else:
            status = "kadaluarsa" if rng.random() < 0.7 else "dibatalkan"
        sub_rows.append({"id": sid, "user_id": users["id"].iat[i], "plan_type": plan,
                         "status": status, "harga_bulanan_idr": harga,
                         "mulai_at": mulai, "berakhir_at": berakhir})
        for k in range(lama):  # satu pembayaran di awal tiap siklus 30 hari
            waktu = mulai + pd.Timedelta(days=SIKLUS_HARI * k)
            if waktu > WAKTU_ACUAN:
                break
            bayar_rows.append({"id": _uid(), "subscription_id": sid, "dibayar_at": waktu,
                               "jumlah_idr": harga})
    subscriptions = pd.DataFrame(sub_rows)
    pembayaran = pd.DataFrame(bayar_rows)

    # ---------- 3. transaksi ----------
    kolektor_idx = np.where(role_arr == "kolektor")[0]
    seniman_idx = np.where(role_arr == "seniman")[0]
    popularitas = rng.lognormal(0, 1.1, size=len(seniman_idx))  # sebagian seniman lebih laris
    tx_rows = []
    for t in range(N_BULAN):
        ms = awal_bulan(t)
        me = ms + pd.offsets.MonthBegin(1)
        n_hari = (me - ms).days
        musim = MUSIM_BULAN[ms.month] * (1 + EFEK_RAMADAN * fraksi_ramadan(ms))
        tren = 1 + TREN_LAJU_BULANAN * t
        guncang = float(rng.lognormal(0, GUNCANG_BULANAN_SIGMA))
        median_harga = HARGA_MEDIAN_AWAL * (1 + INFLASI_HARGA_BULANAN) ** t

        ada_k = kolektor_idx[daftar[kolektor_idx] <= t]
        ada_s_mask = daftar[seniman_idx] <= t
        ada_s = seniman_idx[ada_s_mask]
        if len(ada_k) == 0 or len(ada_s) == 0:
            continue
        pro_s = pro_mid[t, ada_s]
        bobot = popularitas[ada_s_mask] * np.where(pro_s, BOBOT_PENJUAL_PRO, 1.0)
        bobot = bobot / bobot.sum()
        promo = 1 + PROMO_LIFT * float(pro_s.mean())  # karya seniman Pro dipromosikan di beranda
        laju = LAJU_BELI_DASAR * tren * musim * guncang * promo
        laju_i = np.where(pro_mid[t, ada_k], laju * UPLIFT_PRO_KOLEKTOR, laju)
        laju_i = np.where(daftar[ada_k] == t, laju_i * 0.5, laju_i)  # baru gabung: separuh bulan
        jumlah = rng.poisson(laju_i)
        for pos in np.where(jumlah > 0)[0]:
            for _ in range(int(jumlah[pos])):
                k = ada_k[pos]
                harga = int(np.clip(rng.lognormal(np.log(median_harga), HARGA_SIGMA),
                                    HARGA_MIN, HARGA_MAKS))
                harga = int(round(harga / 10_000) * 10_000)
                waktu = ms + pd.Timedelta(days=int(rng.integers(0, n_hari)),
                                          hours=int(rng.integers(0, 24)),
                                          minutes=int(rng.integers(0, 60)))
                waktu = max(waktu, pd.Timestamp(created[k]) + pd.Timedelta(hours=1))
                waktu = min(waktu, WAKTU_ACUAN)
                s_idx = ada_s[rng.choice(len(ada_s), p=bobot)]
                tx_rows.append({
                    "id": _uid(), "karya_id": _uid(),
                    "pembeli_id": users["id"].iat[k], "penjual_id": users["id"].iat[s_idx],
                    "harga_final_idr": harga,
                    "komisi_platform_idr": int(round(harga * KOMISI_PLATFORM)),
                    "created_at": waktu,
                })
    transaksi = pd.DataFrame(tx_rows).sort_values("created_at").reset_index(drop=True)

    return DataDummy(users=users.drop(columns=["bulan_daftar"]), subscriptions=subscriptions,
                     pembayaran=pembayaran, transaksi=transaksi)


if __name__ == "__main__":
    d = buat_data()
    print("users", len(d.users), d.users["role"].value_counts().to_dict())
    print("subscriptions", len(d.subscriptions), d.subscriptions.groupby(["plan_type", "status"]).size().to_dict())
    print("pembayaran", len(d.pembayaran), "transaksi", len(d.transaksi))
    t = d.transaksi.assign(b=d.transaksi["created_at"].dt.strftime("%Y-%m")).groupby("b")["komisi_platform_idr"].sum()
    pb = d.pembayaran.merge(d.subscriptions[["id", "plan_type"]], left_on="subscription_id", right_on="id")
    pb["b"] = pb["dibayar_at"].dt.strftime("%Y-%m")
    lang = pb.pivot_table(index="b", columns="plan_type", values="jumlah_idr", aggfunc="sum", fill_value=0)
    out = pd.concat([t.rename("komisi"), lang], axis=1).fillna(0).astype(int)
    out["total"] = out.sum(axis=1)
    print(out.to_string())
