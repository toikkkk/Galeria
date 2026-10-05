"""Bangun dataset TRAINING dari tabel mentah (seniman, kolektor, karya, transaksi).

Dipakai pada data yang DIBACA ULANG dari database (bukan dari memori generator),
jadi CSV training selalu sama persis dgn isi database.

ATURAN ANTI-KEBOCORAN (penting!)
--------------------------------
Dataset klasifikasi = 1 baris per pasangan (kolektor, karya) pada saat t
(= waktu sebuah pembelian terjadi). SEMUA fitur riwayat dihitung hanya dari
kejadian SEBELUM t (``< t`` ketat). Pembelian itu sendiri tidak ikut menghitung
fitur barisnya -- kalau ikut, model "mengintip jawaban".

Struktur: tiap pembelian nyata membentuk 1 GRUP berisi 1 baris positif
(``dibeli=1``) + ``neg_per_pos`` baris negatif (karya lain yang MASIH tersedia
pada saat t -- sudah terpasang dan belum terjual). Negatif diambil seragam acak;
ini asumsi (tidak ada data "dilihat tapi tidak dibeli" di dummy ini). Evaluasi
ranking yang benar: urutkan baris DI DALAM ``grup_id`` yang sama, lalu hitung
HitRate@K / NDCG@K -- bukan akurasi.

Split waktu (kolom ``split``): train = 70% pembelian pertama, val = 15%, test = 15%
terakhir (berdasarkan waktu pembelian). Satu grup tidak pernah terpecah antar split.
"""

from __future__ import annotations

import numpy as np
import pandas as pd

from .generate import GAYA, HARI_TOTAL, WINDOW_START
from .urutan import urutkan

G = {n: i for i, n in enumerate(GAYA)}
N_GAYA = len(GAYA)


# --------------------------------------------------------------------- util
def _hari(ts: pd.Series) -> np.ndarray:
    """Timestamp tz-aware -> hari (float) sejak WINDOW_START."""
    return ((pd.to_datetime(ts, utc=True) - WINDOW_START).dt.total_seconds() / 86400.0).to_numpy()


def _iso(hari: float) -> str:
    return (WINDOW_START + pd.Timedelta(days=float(hari))).strftime("%Y-%m-%dT%H:%M:%SZ")


def _norm(seniman, kolektor, karya, transaksi):
    s, k, kr, tx = (d.copy() for d in (seniman, kolektor, karya, transaksi))
    for df, kolom in ((s, ["id"]), (k, ["id"]), (kr, ["id", "seniman_id"]),
                      (tx, ["id", "karya_id", "pembeli_id", "penjual_id"])):
        for c in kolom:
            df[c] = df[c].astype(str)
    return s, k, kr, tx


class _Konteks:
    """Indeks waktu-urut supaya fitur 'sebelum t' dihitung cepat (searchsorted)."""

    def __init__(self, seniman, kolektor, karya, transaksi):
        s, k, kr, tx = _norm(seniman, kolektor, karya, transaksi)
        # hasil tidak boleh bergantung pada urutan baris masukan (pemilihan negatif memakai posisi baris)
        s, k, kr, tx = (urutkan(s, "id", "seniman"), urutkan(k, "id", "kolektor"),
                        urutkan(kr, "id", "karya"), urutkan(tx, "id", "transaksi"))
        kr["t_list"] = _hari(kr["created_at"])
        tx["t"] = _hari(tx["created_at"])
        tx = tx.merge(
            kr[["id", "style_name", "price_idr", "t_list"]].rename(columns={"id": "karya_id"}),
            on="karya_id", how="left", validate="one_to_one",
        ).sort_values("t").reset_index(drop=True)
        tx["gaya_idx"] = tx["style_name"].map(G).astype(int)

        self.s, self.k, self.kr, self.tx = s, k, kr, tx
        self.kol_join = dict(zip(k["id"], _hari(k["created_at"])))
        self.sen_level = dict(zip(s["id"], s["level_reputasi"]))
        self.sen_ids = list(s["id"])
        self.t_all = tx["t"].to_numpy()

        self.by_kol = {
            kid: (g["t"].to_numpy(), g["harga_final_idr"].to_numpy(float),
                  g["gaya_idx"].to_numpy(), g["penjual_id"].to_numpy(), g["price_idr"].to_numpy(float))
            for kid, g in tx.groupby("pembeli_id", sort=False)
        }
        kosong = (np.array([]), np.array([]))
        by_sen = {sid: (g["t"].to_numpy(), g["harga_final_idr"].to_numpy(float))
                  for sid, g in tx.groupby("penjual_id", sort=False)}
        self.by_sen = {sid: by_sen.get(sid, kosong) for sid in self.sen_ids}
        self.by_gaya = {gi: g["t"].to_numpy() for gi, g in tx.groupby("gaya_idx", sort=False)}
        self.list_sen = {sid: np.sort(g["t_list"].to_numpy()) for sid, g in kr.groupby("seniman_id")}

        sold = dict(zip(tx["karya_id"], tx["t"]))
        self.kr["t_jual"] = self.kr["id"].map(sold).fillna(np.inf)

    # -- tren seniman sebelum t ------------------------------------------------
    def n_jual(self, sid: str, t: float, jendela: float) -> int:
        ts = self.by_sen[sid][0]
        return int(np.searchsorted(ts, t, "left") - np.searchsorted(ts, t - jendela, "left"))

    def n30_semua(self, t: float) -> np.ndarray:
        return np.array([self.n_jual(sid, t, 30) for sid in self.sen_ids])

    def persentil(self, n30_semua: np.ndarray, n30: int) -> float:
        return float((n30_semua < n30).mean() + 0.5 * (n30_semua == n30).mean())

    def fitur_seniman(self, sid: str, t: float, n30_semua: np.ndarray) -> dict:
        ts, hg = self.by_sen[sid]
        a = np.searchsorted(ts, t, "left")
        n30, n90 = self.n_jual(sid, t, 30), self.n_jual(sid, t, 90)
        i90, i180 = np.searchsorted(ts, t - 90, "left"), np.searchsorted(ts, t - 180, "left")
        m90 = hg[i90:a].mean() if a > i90 else np.nan
        mprev = hg[i180:i90].mean() if i90 > i180 else np.nan
        listed = np.searchsorted(self.list_sen.get(sid, np.array([])), t, "right")
        return {
            "seniman_n_terjual_total": int(a),
            "seniman_n_terjual_30hari": n30,
            "seniman_n_terjual_90hari": n90,
            "seniman_harga_rata2_90hari_idr": m90,
            "seniman_pertumbuhan_harga": (m90 / mprev) if (m90 == m90 and mprev == mprev) else np.nan,
            "seniman_momentum_30hari": n30 - (n90 - n30) / 2.0,
            "seniman_lonjakan_30hari": (n30 + 1.0) / ((n90 - n30) / 2.0 + 1.0),
            "seniman_persentil_tren_30hari": self.persentil(n30_semua, n30),
            "seniman_n_karya_tersedia": int(listed - a),
            "seniman_level_reputasi": self.sen_level[sid],
        }

    def fitur_gaya(self, gi: int, t: float) -> dict:
        ts = self.by_gaya.get(gi, np.array([]))
        n30 = int(np.searchsorted(ts, t, "left") - np.searchsorted(ts, t - 30, "left"))
        tot = int(np.searchsorted(self.t_all, t, "left") - np.searchsorted(self.t_all, t - 30, "left"))
        return {"gaya_n_terjual_30hari": n30, "gaya_porsi_penjualan_30hari": (n30 / tot) if tot else np.nan}

    # -- riwayat kolektor sebelum t ---------------------------------------------
    def riwayat_kolektor(self, kid: str, t: float):
        ts, hg, st, sl, _ = self.by_kol[kid]
        n = int(np.searchsorted(ts, t, "left"))
        return ts[:n], hg[:n], st[:n], sl[:n]


# ------------------------------------------------------------- klasifikasi
KOLOM_IDENTITAS = ["grup_id", "split", "waktu", "transaksi_id", "kolektor_id", "karya_id", "seniman_id", "dibeli"]


def bangun_klasifikasi(seniman, kolektor, karya, transaksi, neg_per_pos: int = 4, seed: int = 42) -> pd.DataFrame:
    rng = np.random.default_rng(seed)
    cx = _Konteks(seniman, kolektor, karya, transaksi)
    kr, tx = cx.kr, cx.tx
    kr_ids = kr["id"].to_numpy()
    kr_t_list, kr_t_jual = kr["t_list"].to_numpy(), kr["t_jual"].to_numpy()
    kr_price = kr["price_idr"].to_numpy(float)
    kr_gaya = kr["style_name"].map(G).to_numpy(int)
    kr_sen = kr["seniman_id"].to_numpy()
    kr_luas = (kr["lebar_cm"].astype(float) * kr["tinggi_cm"].astype(float)).to_numpy()
    idx_karya = {kid: i for i, kid in enumerate(kr_ids)}

    b1, b2 = np.quantile(tx["t"].to_numpy(), [0.70, 0.85])
    baris = []
    for grup, ev in enumerate(tx.itertuples(index=False), start=1):
        t = float(ev.t)
        kid = ev.pembeli_id
        pos = idx_karya[ev.karya_id]
        kandidat = np.flatnonzero((kr_t_list <= t) & (kr_t_jual > t))      # masih tersedia pada t
        kandidat = kandidat[kandidat != pos]
        m = min(neg_per_pos, kandidat.size)
        negatif = rng.choice(kandidat, size=m, replace=False) if m else np.array([], dtype=int)

        ts, hg, st, sl = cx.riwayat_kolektor(kid, t)
        n = len(ts)
        porsi = np.bincount(st, minlength=N_GAYA) / n if n else np.zeros(N_GAYA)
        kol = {
            "kolektor_n_beli_sebelumnya": n,
            "kolektor_hari_sejak_bergabung": t - cx.kol_join[kid],
            "kolektor_hari_sejak_beli_terakhir": (t - ts[-1]) if n else np.nan,
            "kolektor_n_beli_90hari": int((ts >= t - 90).sum()) if n else 0,
            "kolektor_harga_rata2_idr": hg.mean() if n else np.nan,
            "kolektor_harga_median_idr": np.median(hg) if n else np.nan,
            "kolektor_harga_min_idr": hg.min() if n else np.nan,
            "kolektor_harga_maks_idr": hg.max() if n else np.nan,
            "kolektor_harga_std_log": float(np.log(hg).std()) if n else np.nan,
            "kolektor_n_gaya_unik": int((porsi > 0).sum()),
            "kolektor_porsi_gaya_teratas": float(porsi.max()) if n else np.nan,
        }
        n30_semua = cx.n30_semua(t)
        for k_idx, label in [(pos, 1)] + [(int(x), 0) for x in negatif]:
            sid, gi, price = kr_sen[k_idx], int(kr_gaya[k_idx]), float(kr_price[k_idx])
            baris.append({
                "grup_id": grup,
                "split": "train" if t <= b1 else "val" if t <= b2 else "test",
                "waktu": _iso(t),
                "transaksi_id": ev.id if label else "",
                "kolektor_id": kid, "karya_id": kr_ids[k_idx], "seniman_id": sid,
                "dibeli": label,
                **kol,
                "karya_gaya": GAYA[gi],
                "karya_harga_listing_idr": price,
                "karya_log_harga": float(np.log(price)),
                "karya_luas_cm2": float(kr_luas[k_idx]),
                "karya_umur_listing_hari": t - float(kr_t_list[k_idx]),
                "match_porsi_gaya_ini": float(porsi[gi]) if n else np.nan,
                "match_pernah_beli_gaya_ini": int(porsi[gi] > 0),
                "match_n_beli_seniman_ini": int((sl == sid).sum()) if n else 0,
                "match_rasio_harga_vs_rata2": (price / hg.mean()) if n else np.nan,
                "match_selisih_log_harga_vs_median": float(np.log(price) - np.log(np.median(hg))) if n else np.nan,
                "match_harga_dalam_rentang": float(hg.min() <= price <= hg.max()) if n else np.nan,
                **cx.fitur_seniman(sid, t, n30_semua),
                **cx.fitur_gaya(gi, t),
            })
    df = pd.DataFrame(baris)
    for c in [c for c in df.columns if c.endswith("_idr")]:
        df[c] = df[c].round().astype("Int64")
    for c in df.select_dtypes("float").columns:
        df[c] = df[c].round(4)
    return df


# --------------------------------------------------------------- clustering
def bangun_clustering(seniman, kolektor, karya, transaksi) -> pd.DataFrame:
    """1 baris per kolektor, snapshot di akhir periode data (memakai SELURUH riwayat)."""
    cx = _Konteks(seniman, kolektor, karya, transaksi)
    T = HARI_TOTAL
    tx = cx.tx.copy()
    # persentil tren seniman pada saat beli (skala 0-1, bebas dari ukuran pasar)
    pers, lonjak = [], []
    for ev in tx.itertuples(index=False):
        n30_all = cx.n30_semua(float(ev.t))
        n30 = cx.n_jual(ev.penjual_id, float(ev.t), 30)
        n90 = cx.n_jual(ev.penjual_id, float(ev.t), 90)
        pers.append(cx.persentil(n30_all, n30))
        lonjak.append((n30 + 1.0) / ((n90 - n30) / 2.0 + 1.0))
    tx["persentil_tren"] = pers
    tx["lonjakan"] = lonjak
    tx["diskon"] = 1.0 - tx["harga_final_idr"] / tx["price_idr"]
    tx["level"] = tx["penjual_id"].map(cx.sen_level)

    baris = []
    for kid, g in tx.groupby("pembeli_id", sort=False):
        hg = g["harga_final_idr"].to_numpy(float)
        n = len(g)
        porsi = np.bincount(g["gaya_idx"].to_numpy(), minlength=N_GAYA) / n
        nz = porsi[porsi > 0]
        bulan_aktif = max((T - cx.kol_join[kid]) / 30.4375, 1.0)
        baris.append({
            "kolektor_id": kid,
            "n_pembelian": n,
            "total_belanja_idr": hg.sum(),
            "harga_rata2_idr": hg.mean(),
            "harga_median_idr": np.median(hg),
            "harga_min_idr": hg.min(),
            "harga_maks_idr": hg.max(),
            "harga_std_log": float(np.log(hg).std()),
            "hari_sejak_bergabung": T - cx.kol_join[kid],
            "hari_sejak_beli_terakhir": T - g["t"].max(),
            "frekuensi_beli_per_bulan": n / bulan_aktif,
            "n_gaya_unik": int((porsi > 0).sum()),
            "porsi_gaya_teratas": float(porsi.max()),
            "entropi_gaya_norm": float(-(nz * np.log(nz)).sum() / np.log(N_GAYA)),
            "porsi_beli_seniman_mapan": float((g["level"] == "mapan").mean()),
            "porsi_beli_seniman_menengah": float((g["level"] == "menengah").mean()),
            "porsi_beli_seniman_pemula": float((g["level"] == "pemula").mean()),
            "rata2_persentil_tren_saat_beli": float(g["persentil_tren"].mean()),
            "rata2_lonjakan_saat_beli": float(g["lonjakan"].mean()),
            "rata2_diskon_negosiasi": float(g["diskon"].mean()),
            **{f"porsi_gaya_{nama}": float(p) for nama, p in zip(GAYA, porsi)},
        })
    df = pd.DataFrame(baris)
    # kolektor tanpa pembelian tidak muncul di groupby -- generator menjamin >=1, tapi data nyata bisa 0
    tanpa = set(cx.k["id"]) - set(df["kolektor_id"])
    if tanpa:
        raise ValueError(f"{len(tanpa)} kolektor tanpa pembelian -- fitur clustering tidak terdefinisi")
    for c in [c for c in df.columns if c.endswith("_idr")]:
        df[c] = df[c].round().astype("Int64")
    for c in df.select_dtypes("float").columns:
        df[c] = df[c].round(4)
    return df.sort_values("kolektor_id").reset_index(drop=True)


# ---------------------------------------------------------- metrik seniman
def bangun_metrik_seniman_bulanan(karya, transaksi) -> pd.DataFrame:
    """Padanan pandas dari view SQL ``v_seniman_metrik_bulanan`` (dipakai utk memverifikasi
    bahwa view di database menghitung hal yang sama)."""
    kr = karya[["id", "style_name"]].astype({"id": str}).rename(columns={"id": "karya_id"})
    tx = transaksi.astype({"karya_id": str, "penjual_id": str, "pembeli_id": str}).merge(kr, on="karya_id")
    tx = tx[tx["status"] == "selesai"].copy()
    tx["bulan"] = pd.to_datetime(tx["created_at"], utc=True).dt.tz_convert("UTC").dt.strftime("%Y-%m-01")

    def modus(s: pd.Series) -> str:           # seri -> nama alfabetis terkecil (sama dgn mode() Postgres)
        vc = s.value_counts()
        return sorted(vc[vc == vc.max()].index)[0]

    g = tx.groupby(["penjual_id", "bulan"])
    out = g.agg(
        n_terjual=("id", "size"),
        omzet_idr=("harga_final_idr", "sum"),
        komisi_platform_idr=("komisi_platform_idr", "sum"),
        harga_rata2_idr=("harga_final_idr", "mean"),
        harga_maks_idr=("harga_final_idr", "max"),
        n_pembeli_unik=("pembeli_id", "nunique"),
        gaya_terlaris=("style_name", modus),
    ).reset_index().rename(columns={"penjual_id": "seniman_id"})
    out["pendapatan_bersih_idr"] = out["omzet_idr"] - out["komisi_platform_idr"]
    out["harga_rata2_idr"] = out["harga_rata2_idr"].round().astype("int64")
    return out[["seniman_id", "bulan", "n_terjual", "omzet_idr", "komisi_platform_idr",
                "pendapatan_bersih_idr", "harga_rata2_idr", "harga_maks_idr", "n_pembeli_unik",
                "gaya_terlaris"]].sort_values(["seniman_id", "bulan"]).reset_index(drop=True)


# -------------------------------------------------------------------- kamus
_ID = {
    "grup_id": "Nomor grup. 1 grup = 1 pembelian nyata (1 baris dibeli=1) + karya lain yang masih tersedia saat itu (dibeli=0). Evaluasi ranking dilakukan DI DALAM grup.",
    "split": "train / val / test, berdasarkan WAKTU pembelian (70% / 15% / 15%). Satu grup tidak terpecah.",
    "waktu": "Waktu pembelian (UTC, ISO-8601) -- titik acuan 't' utk semua fitur 'sebelum t'.",
    "transaksi_id": "ID transaksi (UUID), hanya terisi utk baris positif. JANGAN dipakai sbg fitur.",
    "kolektor_id": "ID kolektor (UUID). Pengenal, BUKAN fitur.",
    "karya_id": "ID karya (UUID). Pengenal, BUKAN fitur.",
    "seniman_id": "ID seniman penjual karya (UUID). Pengenal, BUKAN fitur.",
    "dibeli": "TARGET. 1 = karya ini yang dibeli kolektor pada waktu t; 0 = karya lain yang tersedia tapi tidak dibeli.",
}
KAMUS_KLASIFIKASI = {
    **_ID,
    "kolektor_n_beli_sebelumnya": "Jumlah pembelian kolektor SEBELUM t. 0 = pembelian pertama (fitur riwayat lain jadi kosong).",
    "kolektor_hari_sejak_bergabung": "Hari sejak kolektor bergabung sampai t.",
    "kolektor_hari_sejak_beli_terakhir": "Hari sejak pembelian terakhir kolektor sebelum t (kosong kalau belum pernah beli).",
    "kolektor_n_beli_90hari": "Jumlah pembelian kolektor dalam 90 hari sebelum t.",
    "kolektor_harga_rata2_idr": "Rata-rata harga final pembelian sebelumnya (Rp).",
    "kolektor_harga_median_idr": "Median harga final pembelian sebelumnya (Rp).",
    "kolektor_harga_min_idr": "Harga final terendah yang pernah dibeli (Rp).",
    "kolektor_harga_maks_idr": "Harga final tertinggi yang pernah dibeli (Rp).",
    "kolektor_harga_std_log": "Simpangan baku ln(harga) pembelian sebelumnya = seberapa lebar rentang harga yang biasa dibeli. 0 kalau baru 1 pembelian.",
    "kolektor_n_gaya_unik": "Jumlah aliran berbeda yang pernah dibeli.",
    "kolektor_porsi_gaya_teratas": "Porsi aliran favorit dari seluruh pembelian sebelumnya (1.0 = selalu aliran yang sama).",
    "karya_gaya": f"Aliran (style) karya, 1 dari {N_GAYA} kelas model Visual Search v1. Kategorikal.",
    "karya_harga_listing_idr": "Harga pasang karya (Rp).",
    "karya_log_harga": "ln(harga pasang).",
    "karya_luas_cm2": "Luas karya (lebar x tinggi, cm2).",
    "karya_umur_listing_hari": "Sudah berapa hari karya terpasang saat t.",
    "match_porsi_gaya_ini": "Porsi pembelian sebelumnya kolektor yang berupa aliran karya ini (0-1).",
    "match_pernah_beli_gaya_ini": "1 kalau kolektor pernah membeli aliran ini sebelum t.",
    "match_n_beli_seniman_ini": "Berapa kali kolektor pernah membeli dari seniman ini (loyalitas).",
    "match_rasio_harga_vs_rata2": "Harga pasang / rata-rata harga beli kolektor. ~1 = sesuai kebiasaan.",
    "match_selisih_log_harga_vs_median": "ln(harga pasang) - ln(median harga beli kolektor). 0 = sesuai kebiasaan.",
    "match_harga_dalam_rentang": "1 kalau harga pasang berada di antara harga beli terendah dan tertinggi kolektor.",
    "seniman_n_terjual_total": "Total karya seniman terjual sebelum t.",
    "seniman_n_terjual_30hari": "Karya seniman terjual dalam 30 hari sebelum t.",
    "seniman_n_terjual_90hari": "Karya seniman terjual dalam 90 hari sebelum t.",
    "seniman_harga_rata2_90hari_idr": "Rata-rata harga jual seniman dalam 90 hari sebelum t (Rp), kosong kalau tak ada penjualan.",
    "seniman_pertumbuhan_harga": "Rata-rata harga jual 90 hari terakhir / 90 hari sebelumnya. >1 = harga naik. Kosong kalau salah satu periode tak ada penjualan.",
    "seniman_momentum_30hari": "Penjualan 30 hari terakhir dikurangi rata-rata per-30-hari pada 60 hari sebelumnya. Positif = sedang naik.",
    "seniman_lonjakan_30hari": "Penjualan 30 hari terakhir relatif terhadap kebiasaan seniman itu sendiri: (n30+1)/(rata2 per-30-hari pada 60 hari sebelumnya+1). >1 = sedang melonjak. Beda dgn persentil: tidak ikut naik hanya karena seniman besar.",
    "seniman_persentil_tren_30hari": "Peringkat persentil (0-1) penjualan 30 hari seniman dibanding semua seniman. Dekat 1 = sedang paling ramai.",
    "seniman_n_karya_tersedia": "Jumlah karya seniman yang masih tersedia saat t.",
    "seniman_level_reputasi": "pemula / menengah / mapan. Kategorikal.",
    "gaya_n_terjual_30hari": "Penjualan aliran karya ini (semua seniman) dalam 30 hari sebelum t.",
    "gaya_porsi_penjualan_30hari": "Porsi aliran ini dari seluruh penjualan 30 hari sebelum t.",
}
KAMUS_CLUSTERING = {
    "kolektor_id": "ID kolektor (UUID). Pengenal, BUKAN fitur.",
    "n_pembelian": "Total pembelian kolektor.",
    "total_belanja_idr": "Total uang yang dibelanjakan (Rp).",
    "harga_rata2_idr": "Rata-rata harga final per pembelian (Rp).",
    "harga_median_idr": "Median harga final (Rp).",
    "harga_min_idr": "Harga final terendah (Rp).",
    "harga_maks_idr": "Harga final tertinggi (Rp).",
    "harga_std_log": "Simpangan baku ln(harga) = lebar rentang harga yang dibeli.",
    "hari_sejak_bergabung": "Hari sejak bergabung sampai akhir periode data.",
    "hari_sejak_beli_terakhir": "Recency: hari sejak pembelian terakhir sampai akhir periode data.",
    "frekuensi_beli_per_bulan": "Pembelian per bulan sejak bergabung (minimal pembagi 1 bulan).",
    "n_gaya_unik": "Jumlah aliran berbeda yang pernah dibeli.",
    "porsi_gaya_teratas": "Porsi aliran favorit (1.0 = hanya 1 aliran).",
    "entropi_gaya_norm": "Keberagaman aliran, entropi Shannon dinormalisasi 0-1 (0 = 1 aliran saja, 1 = merata di semua aliran).",
    "porsi_beli_seniman_mapan": "Porsi pembelian dari seniman level mapan.",
    "porsi_beli_seniman_menengah": "Porsi pembelian dari seniman level menengah.",
    "porsi_beli_seniman_pemula": "Porsi pembelian dari seniman level pemula.",
    "rata2_persentil_tren_saat_beli": "Rata-rata persentil tren (0-1) seniman pada SAAT dibeli. Tinggi = kolektor cenderung membeli dari seniman yang sedang ramai.",
    "rata2_lonjakan_saat_beli": "Rata-rata 'lonjakan' penjualan seniman pada SAAT dibeli (>1 = seniman sedang melonjak). Bebas dari ukuran seniman, jadi lebih bersih utk mendeteksi pengikut tren drpd persentil.",
    "rata2_diskon_negosiasi": "Rata-rata potongan harga final terhadap harga pasang (0-1).",
    **{f"porsi_gaya_{n}": f"Porsi pembelian aliran {n.replace('_', ' ')} (0-1). kolom porsi_gaya_* berjumlah 1." for n in GAYA},
}
KAMUS_METRIK = {
    "seniman_id": "ID seniman (UUID).",
    "bulan": "Bulan (tanggal 1, UTC).",
    "n_terjual": "Jumlah karya terjual bulan itu.",
    "omzet_idr": "Total harga final (Rp).",
    "komisi_platform_idr": "Total komisi platform (Rp).",
    "pendapatan_bersih_idr": "Omzet dikurangi komisi (Rp).",
    "harga_rata2_idr": "Rata-rata harga jual (Rp).",
    "harga_maks_idr": "Harga jual tertinggi (Rp).",
    "n_pembeli_unik": "Jumlah kolektor berbeda yang membeli.",
    "gaya_terlaris": "Aliran paling banyak terjual bulan itu.",
}


def periksa_kamus(df: pd.DataFrame, kamus: dict, nama: str) -> None:
    kurang = [c for c in df.columns if c not in kamus]
    lebih = [c for c in kamus if c not in df.columns]
    if kurang or lebih:
        raise AssertionError(f"kamus {nama} tidak sinkron: kolom tanpa deskripsi={kurang}, deskripsi tanpa kolom={lebih}")
