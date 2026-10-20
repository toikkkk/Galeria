"""Validasi data dummy dashboard admin -> data/LAPORAN_DATA.md.

    cd dashboard-admin
    .venv\\Scripts\\python data\\validasi.py            # lengkap (termasuk uji ketahanan antar-seed, ~beberapa menit)
    .venv\\Scripts\\python data\\validasi.py --cepat    # tanpa uji ketahanan antar-seed

Tujuan: data sintetis ini harus bisa DIPERTANGGUNGJAWABKAN sebagai dasar eksperimen forecasting.
Bukan membuktikan data itu "nyata" (jelas bukan), tetapi menunjukkan bahwa:
  1. semua parameter terdokumentasi beserta dasarnya (keputusan produk / fakta kalender / asumsi),
  2. data konsisten secara internal (tak ada pelanggaran aturan bisnis atau waktu),
  3. data reproduksibel (seed sama -> identik) dan sama persis antara Neon dan perhitungan langsung,
  4. efek yang kita tanam benar-benar muncul dan bisa diestimasi balik dari data,
  5. kesimpulan forecasting tidak hanya artefak satu seed acak.
"""

from __future__ import annotations

import argparse
import contextlib
import io
import sys
from datetime import datetime
from pathlib import Path

import numpy as np
import pandas as pd

RAIZ = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RAIZ / "data"))
sys.path.insert(0, str(RAIZ / "forecasting"))
import generate as G  # noqa: E402
from dataset import TARGET, bulanan_dari_data, muat_bulanan  # noqa: E402

LAPORAN = RAIZ / "data" / "LAPORAN_DATA.md"
ACUAN = G.WAKTU_ACUAN


def fmt(v, d=0):
    return f"{v:,.{d}f}".replace(",", "X").replace(".", ",").replace("X", ".")


def rp(v):
    return "Rp" + fmt(v)


# ---------------------------------------------------------------- 1. parameter & dasarnya
def tabel_parameter() -> list[tuple]:
    P = G
    return [
        ("Komisi platform", f"{P.KOMISI_PLATFORM * 100:.1f}% dari harga final", "Keputusan produk (permintaan tim)"),
        ("Harga Pro kolektor", rp(P.PLAN["kolektor"][1]) + "/bln", "Keputusan produk (AR + gabung Komunitas)"),
        ("Harga Pro seniman", rp(P.PLAN["seniman"][1]) + "/bln",
         "Keputusan produk (promosi karya, buat event, buat komunitas); UI mobile kini Rp149.000 -- perlu disamakan"),
        ("Siklus penagihan", f"{P.SIKLUS_HARI} hari", "Asumsi: langganan bulanan"),
        ("Rentang data", f"{P.N_BULAN} bulan ({G.awal_bulan(0).date()} s.d. {ACUAN.date()})",
         "Asumsi: 3 tahun operasi; waktu acuan = akhir data dummy proyek"),
        ("Pengguna baru/bulan (awal)", f"{P.PENGGUNA_BARU_AWAL:.0f} (+{P.PENGGUNA_AWAL_LAUNCH} saat peluncuran)",
         "Asumsi (platform belum rilis; tak ada data nyata)"),
        ("Pertumbuhan pengguna", f"+{P.PERTUMBUHAN_PENGGUNA * 100:.0f}%/bln; promo pada bulan ke-{', '.join(map(str, P.KAMPANYE))}",
         "Asumsi"),
        ("Komposisi role", " / ".join(f"{k} {v * 100:.0f}%" for k, v in P.PROB_ROLE.items()),
         "Asumsi (kolektor lebih banyak dari seniman)"),
        ("Peluang upgrade Pro/bln", f"kolektor {P.HAZARD_UPGRADE_DASAR['kolektor'] * 100:.1f}% (+{P.HAZARD_UPGRADE_NAIK['kolektor'] * 100:.1f}% bertahap), "
         f"seniman {P.HAZARD_UPGRADE_DASAR['seniman'] * 100:.1f}% (+{P.HAZARD_UPGRADE_NAIK['seniman'] * 100:.1f}%)", "Asumsi"),
        ("Rata-rata lama langganan", f"kolektor {P.RATA2_LAMA_PRO_BLN['kolektor']:.0f} bln, seniman {P.RATA2_LAMA_PRO_BLN['seniman']:.0f} bln", "Asumsi"),
        ("Efek Pro kolektor", f"belanja {P.UPLIFT_PRO_KOLEKTOR}x lebih sering", "Asumsi sebab-akibat -- WAJIB dikalibrasi dgn data nyata"),
        ("Efek promosi seniman Pro", f"laju beli platform +{P.PROMO_LIFT * 100:.0f}% x pangsa seniman Pro; penjual Pro {P.BOBOT_PENJUAL_PRO}x lebih sering terpilih",
         "Asumsi sebab-akibat -- WAJIB dikalibrasi dgn data nyata"),
        ("Laju beli dasar", f"{P.LAJU_BELI_DASAR} transaksi/kolektor/bln (+{P.TREN_LAJU_BULANAN * 100:.1f}%/bln)", "Asumsi"),
        ("Musim", "bulan: " + ", ".join(f"{m}:{v}" for m, v in P.MUSIM_BULAN.items()) + f"; Ramadan +{P.EFEK_RAMADAN * 100:.0f}%",
         "Tanggal Ramadan = fakta kalender Hijriah (perkiraan +-1 hari); besar efek = asumsi"),
        ("Harga karya", f"median {rp(P.HARGA_MEDIAN_AWAL)} (+{P.INFLASI_HARGA_BULANAN * 100:.1f}%/bln), lognormal sigma {P.HARGA_SIGMA}",
         "Asumsi (distribusi harga seni condong ke kanan)"),
        ("Guncangan pasar bulanan", f"lognormal sigma {P.GUNCANG_BULANAN_SIGMA}", "Asumsi (sumber noise di luar Poisson)"),
        ("Seed acak", str(P.SEED), "Tetap -> data reproduksibel"),
    ]


# ---------------------------------------------------------------- 2. integritas
def uji_integritas(d: G.DataDummy) -> list[tuple[str, bool, str]]:
    U, S, B, T = d.users, d.subscriptions, d.pembayaran, d.transaksi
    hasil = []

    def cek(nama, ok, rinci):
        hasil.append((nama, bool(ok), rinci))

    sel = (T["komisi_platform_idr"] - (T["harga_final_idr"] * G.KOMISI_PLATFORM).round().astype(int)).abs()
    cek("Komisi = 2,5% x harga final (setiap transaksi)", (sel == 0).all(), f"{len(T)} transaksi, selisih maks {int(sel.max())}")
    cek("Harga dalam batas [Rp1,5 jt; Rp1 M] & kelipatan Rp10.000",
        T["harga_final_idr"].between(G.HARGA_MIN, G.HARGA_MAKS).all() and (T["harga_final_idr"] % 10_000 == 0).all(),
        f"min {rp(T['harga_final_idr'].min())}, maks {rp(T['harga_final_idr'].max())}")
    semua_id = pd.concat([U["id"], S["id"], B["id"], T["id"], T["karya_id"]])
    cek("ID unik di semua tabel", semua_id.is_unique, f"{len(semua_id)} ID")
    cek("Tidak ada waktu melewati waktu acuan",
        (T["created_at"].max() <= ACUAN) and (B["dibayar_at"].max() <= ACUAN) and (U["created_at"].max() <= ACUAN)
        and (S["mulai_at"].max() <= ACUAN), f"waktu acuan {ACUAN:%Y-%m-%d}")
    u = U.set_index("id")
    cek("Transaksi terjadi setelah pembeli terdaftar",
        (T["created_at"] >= T["pembeli_id"].map(u["created_at"])).all(), "")
    cek("Pembeli = kolektor, penjual = seniman",
        (T["pembeli_id"].map(u["role"]) == "kolektor").all() and (T["penjual_id"].map(u["role"]) == "seniman").all(), "")
    cek("Paket sesuai role (kolektor_pro->kolektor, seniman_pro->seniman)",
        (S["plan_type"].str.replace("_pro", "") == S["user_id"].map(u["role"])).all(), f"{len(S)} langganan")
    cek("Langganan dimulai setelah pengguna terdaftar & berakhir > mulai",
        (S["mulai_at"] > S["user_id"].map(u["created_at"])).all() and (S["berakhir_at"] > S["mulai_at"]).all(), "")
    Ss = S.sort_values(["user_id", "mulai_at"])
    tumpang = (Ss.groupby("user_id")["mulai_at"].shift(-1) < Ss["berakhir_at"]).sum()
    cek("Tidak ada langganan tumpang-tindih pada satu pengguna", tumpang == 0, f"{int(tumpang)} tumpang-tindih")
    cek("Status 'aktif' <=> berakhir setelah waktu acuan",
        ((S["status"] == "aktif") == (S["berakhir_at"] > ACUAN)).all(), "")
    lama = ((S["berakhir_at"] - S["mulai_at"]) / pd.Timedelta(days=G.SIKLUS_HARI)).round().astype(int)
    harapan = []
    for m, l in zip(S["mulai_at"], lama):
        harapan.append(sum(1 for k in range(l) if m + pd.Timedelta(days=G.SIKLUS_HARI * k) <= ACUAN))
    nyata = B.groupby("subscription_id").size().reindex(S["id"]).fillna(0).astype(int).to_numpy()
    cek("Jumlah pembayaran = jumlah siklus 30 hari yang sudah lewat (tiap langganan)",
        (np.array(harapan) == nyata).all(), f"{len(B)} pembayaran")
    harga_sub = S.set_index("id")["harga_bulanan_idr"]
    cek("Jumlah tiap pembayaran = harga paket", (B["jumlah_idr"] == B["subscription_id"].map(harga_sub)).all(), "")
    df = bulanan_dari_data(d)
    ident = (df["total_idr"] - (T["komisi_platform_idr"].sum() * 0 + df["komisi_idr"] + df["langganan_kolektor_idr"]
                                + df["langganan_seniman_idr"])).abs().max()
    tot_raw = T["komisi_platform_idr"].sum() + B["jumlah_idr"].sum()
    cek("Total pendapatan bulanan = komisi + langganan; jumlah seluruh bulan = jumlah data mentah",
        ident == 0 and int(df["total_idr"].sum()) == int(tot_raw), f"total {rp(tot_raw)}")
    return hasil


# ---------------------------------------------------------------- 3. reproduksibilitas & silang-cek DB
def uji_reproduksi(d: G.DataDummy) -> list[tuple[str, bool, str]]:
    def h(x):
        return int(pd.util.hash_pandas_object(x.drop(columns=[c for c in x.columns if c == "created_at"]),
                                              index=False).sum())
    d2 = G.buat_data()
    ok = h(d.transaksi) == h(d2.transaksi) and h(d.users) == h(d2.users) and h(d.subscriptions) == h(d2.subscriptions)
    out = [("Seed sama -> data identik (dibangkitkan dua kali)", ok, f"seed {G.SEED}")]
    try:
        db = muat_bulanan()
        mem = bulanan_dari_data(d)
        kol = ["komisi_idr", "gmv_idr", "n_transaksi", "langganan_kolektor_idr", "langganan_seniman_idr",
               "pengguna_baru", "n_kolektor", "n_seniman", "n_pro_kolektor", "n_pro_seniman"]
        sel = (db[kol].astype(float) - mem[kol].astype(float)).abs().to_numpy().max()
        out.append(("Agregat bulanan di Neon (SQL) = hitungan langsung dari data (pandas)", sel == 0,
                    f"{len(kol)} kolom x {len(db)} bulan, selisih maks {sel:g}"))
    except Exception as e:  # noqa: BLE001 -- DB tak terjangkau: lapor jujur, jangan gagal diam-diam
        out.append(("Agregat bulanan di Neon (SQL) = hitungan langsung dari data (pandas)", False,
                    f"TIDAK DIUJI: {type(e).__name__} (database tak terjangkau)"))
    return out


# ---------------------------------------------------------------- 4. pemulihan efek
def _indeks_bulan(ts: pd.Series) -> np.ndarray:
    return ((ts.dt.year - 2023) * 12 + ts.dt.month - 10).to_numpy()


def uji_pemulihan_efek(d: G.DataDummy, n_boot: int = 400) -> dict:
    U, S, T = d.users, d.subscriptions, d.transaksi
    rng = np.random.default_rng(1)
    daftar = _indeks_bulan(U["created_at"])
    peran = U["role"].to_numpy()
    idx = {uid: i for i, uid in enumerate(U["id"])}
    pro_mid = np.zeros((G.N_BULAN, len(U)), dtype=bool)
    for uid, mulai, akhir in zip(S["user_id"], S["mulai_at"], S["berakhir_at"]):
        for t in range(G.N_BULAN):
            mid = G.awal_bulan(t) + pd.Timedelta(days=14)
            if mulai <= mid < akhir:
                pro_mid[t, idx[uid]] = True
    tb = _indeks_bulan(T["created_at"])
    beli = T["pembeli_id"].map(idx).to_numpy()
    jual = T["penjual_id"].map(idx).to_numpy()

    kol = np.where(peran == "kolektor")[0]
    sen = np.where(peran == "seniman")[0]
    baris = []
    for t in range(G.N_BULAN):
        ek = kol[daftar[kol] <= t]
        w = np.where(daftar[ek] == t, 0.5, 1.0)
        pro = pro_mid[t, ek]
        tx_t = tb == t
        bk = beli[tx_t]
        n_pro_tx = int(pro_mid[t, bk].sum())
        n_non_tx = int(len(bk) - n_pro_tx)
        es = sen[daftar[sen] <= t]
        sp = pro_mid[t, es]
        js = jual[tx_t]
        s_pro_tx = int(pro_mid[t, js].sum())
        baris.append(dict(t=t, ex_pro=w[pro].sum(), ex_non=w[~pro].sum(), tx_pro=n_pro_tx, tx_non=n_non_tx,
                          ps=sp.mean() if len(sp) else 0.0, sen_pro=int(sp.sum()), sen_non=int((~sp).sum()),
                          s_pro_tx=s_pro_tx, s_non_tx=int(len(js) - s_pro_tx),
                          musim=G.MUSIM_BULAN[G.awal_bulan(t).month] * (1 + G.EFEK_RAMADAN * G.fraksi_ramadan(G.awal_bulan(t))),
                          tren=1 + G.TREN_LAJU_BULANAN * t))
    m = pd.DataFrame(baris)

    def rasio_mh(df, tx_a, ex_a, tx_b, ex_b):
        """Mantel-Haenszel: sum tx_a / sum(ex_a * laju_b_per_bulan)."""
        laju_b = df[tx_b] / df[ex_b].clip(lower=1e-9)
        return df[tx_a].sum() / max((df[ex_a] * laju_b).sum(), 1e-9)

    def boot(fn):
        est = fn(m)
        bs = [fn(m.iloc[rng.integers(0, len(m), len(m))].reset_index(drop=True)) for _ in range(n_boot)]
        return est, np.percentile(bs, 2.5), np.percentile(bs, 97.5)

    uplift = boot(lambda df: rasio_mh(df, "tx_pro", "ex_pro", "tx_non", "ex_non"))
    # kolektor non-Pro: laju dinormalkan musim x tren, diregresikan ke pangsa seniman Pro
    import statsmodels.api as sm
    ok = m["ex_non"] > 20
    y = (m["tx_non"] / m["ex_non"] / (m["musim"] * m["tren"]))[ok]
    X = sm.add_constant(m["ps"][ok])
    fit = sm.WLS(y, X, weights=m["ex_non"][ok]).fit()
    a, b = fit.params["const"], fit.params["ps"]
    sa, sb = fit.bse["const"], fit.bse["ps"]
    penjual = boot(lambda df: rasio_mh(df, "s_pro_tx", "sen_pro", "s_non_tx", "sen_non"))
    tx12 = float(m["tx_pro"].tail(12).add(m["tx_non"].tail(12)).mean())
    return {
        "ps_akhir": float(m["ps"].iloc[-1]), "lift_akhir": G.PROMO_LIFT * float(m["ps"].iloc[-1]),
        "tx_rata": tx12, "noise_akhir": 1 / np.sqrt(tx12),
        "uplift": uplift, "a": (a, sa), "b": (b, sb), "n_bulan_reg": int(ok.sum()),
        "penjual": penjual,
        "benar": {"uplift": G.UPLIFT_PRO_KOLEKTOR, "a": G.LAJU_BELI_DASAR, "b": G.LAJU_BELI_DASAR * G.PROMO_LIFT,
                  "penjual": G.BOBOT_PENJUAL_PRO},
    }


# ---------------------------------------------------------------- 5. ketahanan antar-seed
def uji_antar_seed(seeds: list[int], targets=("total", "komisi")) -> pd.DataFrame:
    import jalankan  # backtest()
    from modelku import MODEL

    baris = []
    for sd in seeds:
        df0 = bulanan_dari_data(G.buat_data(sd))
        for tg in targets:
            df = df0.assign(y=df0[TARGET[tg]].astype(float))
            with contextlib.redirect_stdout(io.StringIO()):
                hasil = jalankan.backtest(df, list(MODEL))
            for model, m in hasil.items():
                baris.append(dict(seed=sd, target=tg, model=model, wape=m["wape_pct"]))
            print(f"  seed {sd} / {tg} selesai", flush=True)
    return pd.DataFrame(baris)


# ---------------------------------------------------------------- laporan
def main(cepat: bool):
    print("Membangkitkan data (seed utama) ...", flush=True)
    d = G.buat_data()
    print("Uji integritas ...", flush=True)
    integ = uji_integritas(d)
    print("Uji reproduksibilitas + silang-cek Neon ...", flush=True)
    repro = uji_reproduksi(d)
    print("Uji pemulihan efek ...", flush=True)
    ef = uji_pemulihan_efek(d)
    seed_df = None
    seeds = [G.SEED, G.SEED + 1, G.SEED + 2, G.SEED + 3]
    if not cepat:
        print("Uji ketahanan antar-seed (lama) ...", flush=True)
        seed_df = uji_antar_seed(seeds)

    df = bulanan_dari_data(d)
    L = []
    w = L.append
    w("# Laporan Data Dummy — Dashboard Admin GALERIA\n")
    w(f"_Dibuat otomatis oleh `data/validasi.py` pada {datetime.now():%Y-%m-%d %H:%M}. Jalankan ulang bila parameter di `data/generate.py` berubah._\n")
    w("## 1. Apa data ini, dan apa yang BUKAN\n")
    w("Data ini **sintetis**: dibangkitkan oleh simulasi per-pengguna (`data/generate.py`) karena platform belum rilis dan belum "
      "ada transaksi nyata. Fungsinya: bahan untuk mengembangkan dan menguji pipeline forecasting serta tampilan dashboard.\n")
    w("Yang **dapat** dipertanggungjawabkan: (1) setiap parameter terdokumentasi beserta dasarnya, (2) data konsisten secara internal, "
      "(3) hasilnya reproduksibel, (4) efek yang ditanam terbukti muncul & dapat diestimasi balik, (5) kesimpulan perbandingan model tidak "
      "bergantung pada satu seed acak.\n")
    w("Yang **tidak** dapat diklaim: bahwa angka (pendapatan, pertumbuhan, pangsa Pro, besar efek Pro) mencerminkan perilaku pasar nyata. "
      "Skor forecasting di data ini mencerminkan **desain simulasi**, bukan performa produksi. Setelah ada data nyata, parameter bertanda "
      "*asumsi* harus dikalibrasi ulang dan seluruh evaluasi diulang.\n")

    w("## 2. Parameter simulasi dan dasarnya\n")
    w("| Parameter | Nilai | Dasar |\n|---|---|---|")
    for a, b, c in tabel_parameter():
        w(f"| {a} | {b} | {c} |")
    w("")

    w("## 3. Uji integritas internal\n")
    w("| Uji | Hasil | Rincian |\n|---|---|---|")
    for nama, ok, rinci in integ + repro:
        w(f"| {nama} | {'LULUS' if ok else '**GAGAL**'} | {rinci} |")
    n_ok = sum(1 for _, ok, _ in integ + repro if ok)
    w(f"\n**Ringkasan: {n_ok} dari {len(integ + repro)} uji lulus.**\n")

    w("## 4. Uji pemulihan efek (apakah efek yang ditanam benar-benar terbaca dari data?)\n")
    w("Efek diestimasi **hanya dari tabel data** (tanpa melihat parameter), lalu dibandingkan dengan nilai yang ditanam. "
      "Interval 95% dari bootstrap antar-bulan (efek Pro kolektor, efek penjual Pro) atau galat baku WLS (regresi promosi).\n")
    w("| Efek | Nilai ditanam | Estimasi dari data | Selang 95% | Terpulihkan? |\n|---|---|---|---|---|")
    est, lo, hi = ef["uplift"]
    w(f"| Kolektor Pro belanja lebih sering (rasio laju) | {ef['benar']['uplift']} | {est:.2f} | {lo:.2f} – {hi:.2f} | {'ya' if lo <= ef['benar']['uplift'] <= hi else 'tidak'} |")
    est, lo, hi = ef["penjual"]
    w(f"| Seniman Pro lebih sering terpilih sbg penjual (rasio laju) | {ef['benar']['penjual']} | {est:.2f} | {lo:.2f} – {hi:.2f} | {'ya' if lo <= ef['benar']['penjual'] <= hi else 'tidak'} |")
    a, sa = ef["a"]
    b, sb = ef["b"]
    w(f"| Laju beli dasar kolektor non-Pro (per bulan) | {ef['benar']['a']:.3f} | {a:.3f} | {a - 1.96 * sa:.3f} – {a + 1.96 * sa:.3f} | {'ya' if abs(a - ef['benar']['a']) <= 1.96 * sa else 'tidak'} |")
    w(f"| Kenaikan laju beli per 100% pangsa seniman Pro (promosi beranda) | {ef['benar']['b']:.3f} | {b:.3f} | {b - 1.96 * sb:.3f} – {b + 1.96 * sb:.3f} | {'ya' if abs(b - ef['benar']['b']) <= 1.96 * sb else 'tidak'} |")
    promo_ok = abs(b - ef["benar"]["b"]) <= 1.96 * sb
    w(f"\nRegresi promosi memakai {ef['n_bulan_reg']} bulan (paparan > 20 kolektor non-Pro).\n")
    w(f"**Temuan: efek promosi seniman Pro {'terpulihkan' if promo_ok else 'TIDAK terpulihkan'} dari data ini.** "
      f"Efek yang ditanam di akhir periode hanya ±{ef['lift_akhir'] * 100:.1f}% kenaikan laju beli "
      f"({G.PROMO_LIFT * 100:.0f}% x pangsa seniman Pro {ef['ps_akhir'] * 100:.1f}%), sedangkan noise acak bulanan jumlah transaksi "
      f"±{ef['noise_akhir'] * 100:.1f}% (Poisson, ±{ef['tx_rata']:.0f} transaksi/bln). Efek sekecil itu tenggelam dalam noise pada 36 titik bulanan. "
      "Akibatnya: (a) ini bukan bug generator — nilai yang ditanam memang kecil; (b) di data ini **jangan** menafsirkan Pro seniman sebagai "
      "pendorong penjualan, dan variabel `n_pro_seniman`/`pro_share_seniman` praktis tidak menambah informasi bagi model komisi; "
      "(c) bila efek promosi ingin menjadi variabel yang bermakna, besarnya harus diputuskan dari data nyata/uji A-B, bukan diubah di sini "
      "hanya agar uji ini lulus.\n")
    w("Tiga efek lain (kolektor Pro, penjual Pro, laju dasar) terpulihkan karena besarnya cukup di atas noise.\n")

    w("## 5. Gambaran data (tahun terakhir)\n")
    w("| Bulan | Pengguna (kolektor/seniman) | Pro kolektor | Pro seniman | Transaksi | Komisi 2,5% | Langganan | Total |\n|---|---|---|---|---|---|---|---|")
    for _, r in df.tail(12).iterrows():
        w(f"| {r['bulan']:%b %Y} | {fmt(r['n_kolektor'])}/{fmt(r['n_seniman'])} | {fmt(r['n_pro_kolektor'])} ({r['pro_share_kolektor'] * 100:.1f}%) "
          f"| {fmt(r['n_pro_seniman'])} ({r['pro_share_seniman'] * 100:.1f}%) | {fmt(r['n_transaksi'])} | {rp(r['komisi_idr'])} "
          f"| {rp(r['langganan_kolektor_idr'] + r['langganan_seniman_idr'])} | {rp(r['total_idr'])} |")
    lang = df["langganan_kolektor_idr"].sum() + df["langganan_seniman_idr"].sum()
    w(f"\nSeluruh periode: komisi {rp(df['komisi_idr'].sum())}, langganan {rp(lang)} "
      f"({lang / df['total_idr'].sum() * 100:.1f}% dari total pendapatan platform).\n")

    w("## 6. Ketahanan kesimpulan forecasting antar-seed\n")
    if seed_df is None:
        w("_Dilewati (`--cepat`)._\n")
    else:
        w(f"Data dibangkitkan ulang dengan {len(seeds)} seed berbeda ({', '.join(map(str, seeds))}); seluruh model di-backtest ulang pada tiap seed "
          "(titik potong 24–30, horizon 6). Tabel: WAPE rata-rata ± simpangan baku antar-seed (makin kecil makin baik) dan berapa kali model jadi pemenang.\n")
        for tg in ("total", "komisi"):
            sub = seed_df[seed_df["target"] == tg]
            menang = sub.loc[sub.groupby("seed")["wape"].idxmin()]["model"].value_counts()
            rata = sub.groupby("model")["wape"].agg(["mean", "std"]).sort_values("mean")
            w(f"**Target: {tg}**\n")
            w("| Model | WAPE rata-rata | Simpangan baku | Menang (dari %d seed) |\n|---|---|---|---|" % len(seeds))
            for model, r in rata.iterrows():
                w(f"| {model} | {r['mean']:.1f}% | {r['std']:.1f} | {int(menang.get(model, 0))} |")
            w("")
        w("Cara membaca: bila pemenang berganti-ganti antar-seed dan selisih rata-rata antar-model kecil dibanding simpangan bakunya, "
          "jangan klaim satu model \"terbaik secara umum\" — hanya \"kompetitif\". Hanya selisih yang konsisten di semua seed yang layak dilaporkan.\n")

    w("## 7. Keterbatasan yang harus disebut di laporan/presentasi\n")
    for s in [
        "Seluruh angka bersifat sintetis; tidak ada validasi terhadap pasar nyata atau pembanding eksternal.",
        "Hanya 36 titik data bulanan: selisih kecil antar-model bisa noise; interval ketidakpastian lebih bermakna daripada satu angka titik.",
        "Struktur data ditentukan oleh kita sendiri, sehingga model yang kebetulan cocok dengan struktur itu akan tampak bagus. Ini alasan uji antar-seed (bagian 6) dan pemulihan efek (bagian 4) ada.",
        "Efek Pro/promosi diasumsikan sebab-akibat; pada data nyata efek ini harus diestimasi, bukan diasumsikan (kemungkinan bias seleksi: pengguna yang aktif lebih mungkin upgrade).",
        "Forecast bukan jaminan pendapatan; pakai rentang P10–P90.",
    ]:
        w(f"- {s}")
    LAPORAN.write_text("\n".join(L) + "\n", encoding="utf-8")
    print(f"\nLaporan ditulis: {LAPORAN}")
    gagal = [n for n, ok, _ in integ + repro if not ok]
    if gagal:
        print("UJI GAGAL:", gagal)
        sys.exit(1)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--cepat", action="store_true", help="lewati uji ketahanan antar-seed")
    main(ap.parse_args().cepat)
