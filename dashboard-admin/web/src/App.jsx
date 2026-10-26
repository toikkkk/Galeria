import { useCallback, useEffect, useState } from "react";
import {
  Bar, BarChart, CartesianGrid, ComposedChart, Line, LabelList,
  ReferenceLine, ResponsiveContainer, Tooltip, XAxis, YAxis,
} from "recharts";
import { ambilToken, hapusToken, onSesiHabis, tokenExp } from "./api.js";
import Login from "./Login.jsx";
import { Muat, Segmented, Tabel, Tabs, Tip, useApi } from "./components.jsx";
import { angka, bulanPanjang, bulanPendek, persen, rupiah, rupiahRingkas, rupiahSumbu } from "./format.js";

const AXIS = { fontSize: 12, fill: "var(--text-secondary)" };
const PERIODE_HARI = 30;
const arah = (v) => (v >= 0 ? "naik" : "turun");

/* istilah teknis -> hanya muncul di "Detail untuk tim data" */
const NAMA_MODEL = {
  arima: "ARIMA (univariat)",
  fts_multivariat: "Fuzzy Time Series (multivariat)",
  seasonal_naive_tren: "Seasonal naive + tren",
  ets_redaman: "ETS (tren teredam)",
  theta: "Theta",
  lightgbm: "LightGBM rekursif",
  chronos2_kalender: "Chronos-2 + kalender",
  chronos2_kovariat_pro: "Chronos-2 + kovariat Pro",
  chronos2_log_kalender: "Chronos-2 (log) + kalender",
  chronos2_log_kovariat_pro: "Chronos-2 (log) + kovariat Pro",
  ensemble_chronos_theta: "Ensemble Chronos-2 + Theta",
};
const namaModel = (m) => NAMA_MODEL[m] || m;

const TARGET = [
  { value: "total", label: "Semua pendapatan", judul: "seluruh pendapatan GALERIA",
    ket: "Komisi dari karya terjual + langganan Pro kolektor + langganan Pro seniman" },
  { value: "komisi", label: "Komisi karya terjual", judul: "komisi dari karya terjual",
    ket: "GALERIA mengambil 2,5% dari harga setiap karya yang terjual" },
  { value: "langganan_kolektor", label: "Langganan kolektor", judul: "langganan Pro kolektor",
    ket: "Rp50.000 per bulan — kolektor bisa memakai AR dan bergabung ke Komunitas" },
  { value: "langganan_seniman", label: "Langganan seniman", judul: "langganan Pro seniman",
    ket: "Rp150.000 per bulan — seniman bisa promosi karya, membuat event, dan membuat komunitas" },
];

function Delta({ v, ket = `dibanding ${PERIODE_HARI} hari sebelumnya` }) {
  if (v == null) return <span className="sub">–</span>;
  const naik = v >= 0;
  return (
    <span className={naik ? "delta-up" : "delta-down"}>
      {naik ? "▲" : "▼"} {arah(v)} {persen(Math.abs(v))} <span className="sub">{ket}</span>
    </span>
  );
}

function Kpi({ label, value, sub }) {
  return (
    <div className="card kpi">
      <div className="label">{label}</div>
      <div className="value">{value}</div>
      <div className="sub">{sub}</div>
    </div>
  );
}

/* ------------------------------------------------------------ ringkasan */
function Headline({ d }) {
  const p = d.perubahan_pct.total_idr;
  return (
    <div className="headline">
      <div className="h-kecil">Ringkasan {d.periode_hari} hari terakhir</div>
      <p>
        GALERIA memperoleh pendapatan <b>{rupiahRingkas(d.pendapatan_total_idr)}</b>
        {p != null && <>, <b className={p >= 0 ? "delta-up" : "delta-down"}>{arah(p)} {persen(Math.abs(p))}</b> dibanding {d.periode_hari} hari sebelumnya</>}.
      </p>
    </div>
  );
}

function Kpis({ d }) {
  const langganan = d.langganan_kolektor_idr + d.langganan_seniman_idr;
  return (
    <div className="kpis">
      <Kpi label="Total pendapatan" value={rupiahRingkas(d.pendapatan_total_idr)} sub={<Delta v={d.perubahan_pct.total_idr} />} />
      <Kpi label="Komisi dari karya terjual" value={rupiahRingkas(d.komisi_idr)}
        sub={<>{angka(d.n_transaksi)} karya terjual · <Delta v={d.perubahan_pct.komisi_idr} ket="" /></>} />
      <Kpi label="Pendapatan dari langganan Pro" value={rupiahRingkas(langganan)}
        sub={<>Kolektor {rupiahRingkas(d.langganan_kolektor_idr)} · Seniman {rupiahRingkas(d.langganan_seniman_idr)}</>} />
      <Kpi label="Pengguna yang sudah Pro" value={angka(d.pro.kolektor.n_pro + d.pro.seniman.n_pro)}
        sub={<>{angka(d.pro.kolektor.n_pro)} kolektor ({persen(d.pro.kolektor.pro_share_pct)}) · {angka(d.pro.seniman.n_pro)} seniman ({persen(d.pro.seniman.pro_share_pct)})</>} />
    </div>
  );
}

/* ------------------------------------------------------------ perkiraan */
function bangunSeri(fc) {
  const aktual = fc.aktual.map((a) => ({
    iso: a.bulan, label: bulanPendek(a.bulan), jenis: "aktual", aktual: a.nilai_idr,
  }));
  const akhir = aktual[aktual.length - 1];
  akhir.forecast = akhir.aktual; // sambungkan garis perkiraan ke titik aktual terakhir
  const depan = fc.forecast.map((f) => ({
    iso: f.bulan, label: bulanPendek(f.bulan), jenis: "forecast", forecast: f.p50_idr,
  }));
  return [...aktual, ...depan];
}

function TipForecast({ active, payload }) {
  if (!active || !payload?.length) return null;
  const r = payload[0].payload;
  const j = bulanPanjang(r.iso);
  if (r.jenis === "aktual") return <Tip judul={j} baris={[["Pendapatan sebenarnya", rupiah(r.aktual)]]} />;
  return <Tip judul={`${j} · perkiraan`} baris={[["Perkiraan", rupiah(r.forecast)]]} />;
}

const METODE_DIMINTA = ["arima", "fts_multivariat"];

const pTampil = (v, kpss = false) => {
  if (kpss && v <= 0.01) return "≤ 0,01";
  if (kpss && v >= 0.1) return "≥ 0,10";
  return v < 0.001 ? "< 0,001" : v.toFixed(3).replace(".", ",");
};

/* Langkah 1: cek data series sebelum memilih metode */
function DiagnosaDeret({ target }) {
  const api = useApi(`/diagnosa?target=${target}`);
  return (
    <details className="teknis" open>
      <summary>Langkah 1 — Cek data series sebelum memilih metode</summary>
      <Muat api={api}>
        {(d) => {
          if (!d.tersedia) return <p className="desc">Hasil pemeriksaan data belum tersedia.</p>;
          const h = d.hasil;
          const s = h.stasioneritas;
          return (
            <>
              <ul className="istilah">
                {h.ringkasan.map((b) => <li key={b}>{b}</li>)}
              </ul>
              <Tabel
                kolom={[
                  { judul: "Uji (p-value)", sel: (r) => r.uji },
                  { judul: "Level", sel: (r) => r.level },
                  { judul: "Selisih pertama", sel: (r) => r.selisih },
                ]}
                baris={[
                  { uji: "ADF (H0: ada akar unit)", level: pTampil(s.level.adf_p), selisih: pTampil(s.selisih_pertama.adf_p) },
                  { uji: "KPSS (H0: stasioner)", level: pTampil(s.level.kpss_p, true), selisih: pTampil(s.selisih_pertama.kpss_p, true) },
                ]}
              />
              <p className="desc" style={{ marginTop: 10 }}>
                Kesimpulan: data ditransformasi log, orde diferensiasi <b>d = {s.d_disarankan}</b>, ada tren naik, musiman {h.musiman.tingkat}.
                Karena hanya {h.kelengkapan.n_titik} bulan (3 siklus tahunan), uji musiman dan stasioneritas berdaya rendah; data ini sintetis.
              </p>
            </>
          );
        }}
      </Muat>
    </details>
  );
}

function Forecast() {
  const [target, setTarget] = useState("total");
  const api = useApi(`/forecast?target=${target}&bulan_aktual=18`);
  const [tabel, setTabel] = useState(false);
  const info = TARGET.find((t) => t.value === target);
  return (
    <section className="card" aria-labelledby="h-fc">
      <div className="card-head">
        <div>
          <h2 id="h-fc">Perkiraan pendapatan</h2>
          <p className="desc">{info.ket}</p>
        </div>
        <button className="link" onClick={() => setTabel(!tabel)}>{tabel ? "Lihat grafik" : "Lihat angka per bulan"}</button>
      </div>
      <div className="pilih">
        <span>Lihat perkiraan untuk:</span>
        <Segmented label="Sumber pendapatan" value={target} onChange={setTarget}
          options={TARGET.map((t) => ({ value: t.value, label: t.label }))} />
      </div>
      <DiagnosaDeret target={target} />
      <Muat api={api}>
        {(fc) => {
          if (!fc.tersedia)
            return <div className="state">Perkiraan belum tersedia. Hubungi tim data untuk menjalankan perhitungannya.</div>;
          const seri = bangunSeri(fc);
          const batas = seri.find((x) => x.jenis === "aktual" && x.forecast != null).label;
          const aktual6 = fc.aktual.slice(-6).reduce((a, b) => a + b.nilai_idr, 0);
          const naik = aktual6 ? ((fc.total_p50_idr - aktual6) / aktual6) * 100 : null;
          const bt = fc.backtest.find((b) => b.terpilih);
          const awalBln = bulanPanjang(fc.forecast[0].bulan);
          const akhirBln = bulanPanjang(fc.forecast[fc.forecast.length - 1].bulan);
          return (
            <>
              <p className="kalimat">
                Diperkirakan sekitar <b>{rupiahRingkas(fc.total_p50_idr)}</b> selama {awalBln} – {akhirBln}.
                {naik != null && <> Ini <b className={naik >= 0 ? "delta-up" : "delta-down"}>{arah(naik)} {persen(Math.abs(naik), 0)}</b> dibanding 6 bulan terakhir.</>}
              </p>
              <div className="stats">
                <div><div className="s-l">Perkiraan {fc.horizon_bulan} bulan</div><div className="s-v">{rupiahRingkas(fc.total_p50_idr)}</div></div>
                <div><div className="s-l">Metode terbaik</div><div className="s-v">{namaModel(fc.model_terpilih)}</div></div>
                {bt && bt.mape_pct != null && (
                  <div><div className="s-l">Galat uji (MAPE)</div><div className="s-v">{persen(bt.mape_pct)}</div></div>
                )}
              </div>

              {tabel ? (
                <Tabel
                  kolom={[
                    { judul: "Bulan", sel: (r) => bulanPanjang(r.iso) },
                    { judul: "Keterangan", sel: (r) => (r.jenis === "aktual" ? "Sebenarnya" : "Perkiraan") },
                    { judul: "Pendapatan", sel: (r) => rupiah(r.jenis === "aktual" ? r.aktual : r.forecast) },
                  ]}
                  baris={seri}
                />
              ) : (
                <>
                  <div className="legend">
                    <span><i style={{ background: "var(--series-1)" }} />Aktual</span>
                    <span><i style={{ background: "var(--series-2)" }} />Forecast ({namaModel(fc.model_terpilih)})</span>
                  </div>
                  <div className="chart" role="img"
                    aria-label={`Grafik pendapatan ${info.judul}: garis aktual 18 bulan terakhir dan garis forecast 6 bulan ke depan`}>
                    <ResponsiveContainer>
                      <ComposedChart data={seri} margin={{ top: 8, right: 12, bottom: 0, left: 0 }}>
                        <CartesianGrid stroke="var(--grid)" vertical={false} />
                        <XAxis dataKey="label" tick={AXIS} tickLine={false} axisLine={{ stroke: "var(--grid)" }} interval="preserveStartEnd" minTickGap={18} />
                        <YAxis tick={AXIS} tickLine={false} axisLine={false} width={74} tickFormatter={rupiahSumbu} />
                        <Tooltip content={<TipForecast />} cursor={{ stroke: "var(--text-muted)", strokeDasharray: "3 3" }} />
                        <ReferenceLine x={batas} stroke="var(--text-muted)" strokeDasharray="2 4"
                          label={{ value: "Forecast →", position: "insideTopRight", fill: "var(--text-muted)", fontSize: 12 }} />
                        <Line dataKey="aktual" stroke="var(--series-1)" strokeWidth={2.5} dot={false}
                          activeDot={{ r: 5, stroke: "var(--surface-1)", strokeWidth: 2 }} isAnimationActive={false} />
                        <Line dataKey="forecast" stroke="var(--series-2)" strokeWidth={2.5} strokeDasharray="6 4" dot={false}
                          activeDot={{ r: 5, stroke: "var(--surface-1)", strokeWidth: 2 }} isAnimationActive={false} />
                      </ComposedChart>
                    </ResponsiveContainer>
                  </div>
                  <p className="cap">
                    Forecast dibuat dari pola bulan-bulan sebelumnya dan bukan jaminan pendapatan.
                  </p>
                </>
              )}

              <h3 className="sub">Langkah 2 — Perbandingan metode ({fc.backtest.length} metode diuji)</h3>
              <Tabel
                kolom={[
                  { judul: "Metode", sel: (r) => namaModel(r.model) + (METODE_DIMINTA.includes(r.model) ? " ★" : "") + (r.terpilih ? " ✓ terbaik" : "") },
                  { judul: "MAPE", sel: (r) => (r.mape_pct == null ? "–" : persen(r.mape_pct)) },
                  { judul: "RMSE", sel: (r) => (r.rmse_idr == null ? "–" : rupiahRingkas(r.rmse_idr)) },
                ]}
                baris={fc.backtest.map((b) => ({ ...b, _pilih: b.terpilih }))}
              />
              <p className="cap">
                ★ = dua metode yang diminta untuk dibandingkan (ARIMA univariat dan Fuzzy Time Series multivariat); metode lain adalah pembanding.
                Metode terbaik dipilih dari MAPE terkecil di antara <b>semua</b> metode (RMSE sebagai pembanding) pada uji ulang bergulir: model dilatih pada data lama,
                meramal 6 bulan, lalu dibandingkan dengan kenyataan, diulang 7 kali. Pemenangnya dipilih per sumber pendapatan.
              </p>

              <details className="teknis">
                <summary>Detail untuk tim data</summary>
                <ul className="istilah">
                  <li><b>ARIMA (univariat)</b> = hanya memakai riwayat pendapatan itu sendiri; skala log; orde d dari uji ADF + KPSS; orde (p, q) 0–1 dari AICc.</li>
                  <li><b>Fuzzy Time Series (multivariat)</b> = dua faktor: pendapatan dan satu faktor pengaruh (jumlah transaksi, pengguna Pro, atau pengguna baru) yang dipilih otomatis dari korelasi pada data latih; dihitung pada selisih log.</li>
                  <li><b>MAPE</b> = rata-rata |aktual − forecast| ÷ aktual; <b>RMSE</b> = akar rata-rata kuadrat selisih (dalam Rupiah).</li>
                  <li>Bulan awal yang nilainya &lt; 5% median (bulan peluncuran) dibuang sebelum pemodelan.</li>
                </ul>
                {fc.target === "total" && fc.jumlah_komponen_p50_idr != null && (
                  <p className="desc">
                    Total diramal langsung. Jumlah ramalan tiga komponennya (komisi + 2 langganan, masing-masing dengan metode sendiri) ={" "}
                    <b>{rupiahRingkas(fc.jumlah_komponen_p50_idr)}</b>; selisih kecil wajar karena metode tiap sumber dipilih terpisah.
                  </p>
                )}
                <p className="desc">
                  Hanya 7 titik uji × 6 bulan dari data sintetis 36 bulan, sehingga selisih kecil antar-metode bisa saja kebetulan, dan skor
                  mencerminkan desain simulasi, bukan performa produksi. Metode meneruskan tren historis; bila pertumbuhan melambat, keduanya cenderung melebihkan.
                </p>
              </details>
            </>
          );
        }}
      </Muat>
    </section>
  );
}

/* ------------------------------------------------------------ naik kelas ke Pro */
const ROLE = {
  kolektor: {
    label: "Kolektor", sebutan: "kolektor", paket: "Pro Kolektor", harga: 50000,
    manfaat: ["Simulasi AR: lihat karya di ruanganmu sebelum membeli", "Gabung Komunitas seni"],
    kolomPendapatan: "langganan_kolektor_idr",
  },
  seniman: {
    label: "Seniman", sebutan: "seniman", paket: "Pro Seniman", harga: 150000,
    manfaat: ["Promosikan karya — tampil di halaman utama kolektor", "Buat event", "Buat komunitas"],
    kolomPendapatan: "langganan_seniman_idr",
  },
};

function TipPro({ active, payload }) {
  if (!active || !payload?.length) return null;
  const r = payload[0].payload;
  return (
    <Tip judul={bulanPanjang(r.bulan)} baris={[
      ["Sudah Pro", angka(r.n_pro)],
      ["Belum upgrade", angka(r.n_non_pro)],
      ["Jumlah semua", angka(r.n_pro + r.n_non_pro)],
      ["Persen yang Pro", persen(r.pro_share_pct)],
      ["Baru upgrade bulan ini", angka(r.upgrade_baru)],
    ]} />
  );
}

/** Angka jumlah di atas tiap batang; jarang-jarang bila batangnya banyak. */
function labelAngka(langkah) {
  return function Label({ x, y, width, index, value }) {
    if (index % langkah !== 0 || value == null) return null;
    return (
      <text x={x + width / 2} y={y - 6} textAnchor="middle" fontSize={10.5} fontWeight={600} fill="var(--text-primary)">
        {angka(value)}
      </text>
    );
  };
}

/** SATU grafik: dua batang berdampingan per bulan (emas = sudah Pro, biru = belum upgrade), jumlah tertulis di batang. */
function BatangGabungan({ data, info, langkah }) {
  return (
    <>
      <div className="legend">
        <span><i style={{ background: "var(--series-1)" }} />Sudah Pro</span>
        <span><i style={{ background: "var(--series-2)" }} />Belum upgrade</span>
      </div>
      <div className="chart" role="img"
        aria-label={`Diagram batang jumlah ${info.sebutan} yang sudah Pro dan yang belum upgrade, per bulan`}>
        <ResponsiveContainer>
          <BarChart data={data} margin={{ top: 26, right: 8, bottom: 0, left: 0 }} barGap={3} barCategoryGap="14%">
            <CartesianGrid stroke="var(--grid)" vertical={false} />
            <XAxis dataKey="label" tick={AXIS} tickLine={false} axisLine={{ stroke: "var(--grid)" }} interval="preserveStartEnd" minTickGap={14} />
            <YAxis tick={AXIS} tickLine={false} axisLine={false} width={48} tickFormatter={angka} domain={[0, "auto"]} />
            <Tooltip content={<TipPro />} cursor={{ fill: "var(--grid)", opacity: 0.6 }} />
            <Bar dataKey="n_pro" fill="var(--series-1)" radius={[4, 4, 0, 0]} maxBarSize={30} isAnimationActive={false}>
              <LabelList dataKey="n_pro" content={labelAngka(langkah)} />
            </Bar>
            <Bar dataKey="n_non_pro" fill="var(--series-2)" radius={[4, 4, 0, 0]} maxBarSize={30} isAnimationActive={false}>
              <LabelList dataKey="n_non_pro" content={labelAngka(langkah)} />
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      </div>
    </>
  );
}

function PanelRole({ role, n }) {
  const info = ROLE[role];
  const api = useApi(`/pro-vs-nonpro?role=${role}&bulan=${n}`);
  const pend = useApi(`/pendapatan-bulanan?bulan=${n}`);
  const [tabel, setTabel] = useState(false);
  return (
    <div role="tabpanel" id={`panel-${role}`} aria-labelledby={`tab-${role}`}>
      <div className="paket">
        <div>
          <div className="nama">{info.paket}</div>
          <div className="harga">{rupiah(info.harga)} <small>per bulan</small></div>
        </div>
        <ul>{info.manfaat.map((m) => <li key={m}>{m}</li>)}</ul>
      </div>
      <Muat api={api}>
        {(rows) => {
          const data = rows.map((r) => ({ ...r, label: bulanPendek(r.bulan) }));
          const a = data[0], b = data[data.length - 1];
          const tumbuh = a.n_pro ? ((b.n_pro - a.n_pro) / a.n_pro) * 100 : null;
          const pendapatan = pend.status === "ok" ? pend.data[pend.data.length - 1][info.kolomPendapatan] : null;
          const langkah = data.length > 12 ? 2 : 1;
          return (
            <>
              <p className="kalimat">
                Per {bulanPanjang(b.bulan)} ada <b>{angka(b.n_pro)} {info.sebutan} Pro</b>
                {tumbuh != null && <>, <b className={tumbuh >= 0 ? "delta-up" : "delta-down"}>{arah(tumbuh)} {persen(Math.abs(tumbuh), 0)}</b> dibanding {n} bulan lalu ({angka(a.n_pro)})</>}.
                {" "}Persentase {info.sebutan} yang sudah Pro {arah(b.pro_share_pct - a.pro_share_pct)} dari {persen(a.pro_share_pct)} menjadi {persen(b.pro_share_pct)}.
              </p>
              <div className="stats">
                <div><div className="s-l">Sudah Pro</div><div className="s-v">{angka(b.n_pro)}</div></div>
                <div><div className="s-l">Belum upgrade</div><div className="s-v">{angka(b.n_non_pro)}</div></div>
                <div><div className="s-l">Persen yang Pro</div><div className="s-v">{persen(b.pro_share_pct)}</div></div>
                <div><div className="s-l">Baru upgrade bulan ini</div><div className="s-v">{angka(b.upgrade_baru)}</div></div>
                <div><div className="s-l">Pendapatan langganan bulan ini</div><div className="s-v">{pendapatan == null ? "–" : rupiahRingkas(pendapatan)}</div></div>
              </div>

              <div className="card-head" style={{ marginBottom: 6 }}>
                <div>
                  <h3 className="judul-grafik">Sudah Naik Kelas atau Belum? {info.label} Bulan demi Bulan</h3>
                  <p className="cap" style={{ margin: 0 }}>
                    Emas = sudah Pro, biru = belum upgrade. Angka di atas batang = jumlah {info.sebutan} pada akhir bulan.
                  </p>
                </div>
                <button className="link" onClick={() => setTabel(!tabel)}>{tabel ? "Lihat grafik" : "Lihat angka per bulan"}</button>
              </div>

              {tabel ? (
                <Tabel
                  kolom={[
                    { judul: "Bulan", sel: (r) => bulanPanjang(r.bulan) },
                    { judul: "Sudah Pro", sel: (r) => angka(r.n_pro) },
                    { judul: "Belum upgrade", sel: (r) => angka(r.n_non_pro) },
                    { judul: "Persen Pro", sel: (r) => persen(r.pro_share_pct) },
                    { judul: "Baru upgrade", sel: (r) => angka(r.upgrade_baru) },
                  ]}
                  baris={data}
                />
              ) : (
                <>
                  <BatangGabungan data={data} info={info} langkah={langkah} />
                </>
              )}
            </>
          );
        }}
      </Muat>
    </div>
  );
}

function NaikKelas() {
  // ?role=seniman membuka tab Seniman langsung (berguna utk berbagi tautan / tangkapan layar)
  const awal = new URLSearchParams(window.location.search).get("role");
  const [role, setRole] = useState(awal in ROLE ? awal : "kolektor");
  const [n, setN] = useState(12);
  return (
    <section className="card" aria-labelledby="h-pro">
      <div className="card-head">
        <div>
          <h2 id="h-pro">Siapa yang Sudah Naik Kelas ke Pro?</h2>
          <p className="desc">Perbandingan pengguna yang sudah berlangganan Pro dengan yang belum, dicatat tiap akhir bulan.</p>
        </div>
        <Segmented label="Rentang waktu" value={n} onChange={setN}
          options={[{ value: 6, label: "6 bulan" }, { value: 12, label: "12 bulan" }, { value: 24, label: "24 bulan" }]} />
      </div>
      <Tabs label="Pilih jenis pengguna" value={role} onChange={setRole}
        tabs={Object.entries(ROLE).map(([value, r]) => ({ value, label: r.label }))} />
      <PanelRole key={role} role={role} n={n} />
    </section>
  );
}

/* ------------------------------------------------------------ keaktifan seniman */
const WARNA_CLUSTER = { "Aktif": "#B08A12", "Kurang Aktif": "#D9C37C", "Tidak Aktif": "#B7B0A4" };
const skorFmt = (v) => Number(v).toFixed(1).replace(".", ",");

function TipPeringkat({ active, payload, baris }) {
  if (!active || !payload?.length) return null;
  const r = payload[0].payload;
  return <Tip judul={r.nama} baris={baris(r)} />;
}

/* Bar chart horizontal biasa (bukan stacked) */
function BarPeringkat({ data, kunci, judul, format, warna, baris }) {
  const isi = data.map((d, i) => ({ ...d, nama: `${i + 1}. ${d.nama}`, nilai: d[kunci] }));
  return (
    <div className="chart" style={{ height: 380 }} role="img" aria-label={judul}>
      <ResponsiveContainer>
        <BarChart data={isi} layout="vertical" margin={{ top: 4, right: 64, bottom: 0, left: 8 }} barCategoryGap="22%">
          <CartesianGrid stroke="var(--grid)" horizontal={false} />
          <XAxis type="number" tick={AXIS} tickLine={false} axisLine={false} tickFormatter={format} />
          <YAxis type="category" dataKey="nama" tick={AXIS} tickLine={false} axisLine={false} width={150} />
          <Tooltip content={<TipPeringkat baris={baris} />} cursor={{ fill: "var(--surface-2)" }} />
          <Bar dataKey="nilai" fill={warna} radius={[0, 4, 4, 0]} maxBarSize={22} isAnimationActive={false}>
            <LabelList dataKey="nilai" position="right" formatter={format}
              style={{ fontSize: 12, fill: "var(--text-secondary)" }} />
          </Bar>
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}

function KeaktifanSeniman() {
  const api = useApi("/keaktifan-seniman");
  return (
    <section className="card" aria-labelledby="h-kt" style={{ marginTop: 16 }}>
      <div className="card-head">
        <div>
          <h2 id="h-kt">Keaktifan seniman</h2>
          <p className="desc">Seberapa aktif seniman menjual dalam 90 hari terakhir, dikelompokkan menjadi Aktif, Kurang Aktif, dan Tidak Aktif.</p>
        </div>
      </div>
      <Muat api={api}>
        {(d) => {
          if (!d.tersedia)
            return <div className="state">Data keaktifan belum tersedia. Hubungi tim data untuk menjalankan perhitungannya.</div>;
          const m = d.meta;
          return (
            <>
              <div className="cluster-baris">
                {d.cluster.map((c) => (
                  <div className="cluster-item" key={c.cluster}>
                    <div className="cluster-nama">
                      <i style={{ background: WARNA_CLUSTER[c.cluster] }} />
                      <b>{c.cluster}</b>
                      <span className="sub">{angka(c.ukuran)} seniman · {persen(c.persen)}</span>
                    </div>
                    <div className="cluster-bar"><span style={{ width: `${c.persen}%`, background: WARNA_CLUSTER[c.cluster] }} /></div>
                    <div className="sub">
                      Terakhir menjual sekitar {c.hari_sejak_jual_median} hari lalu (median) · {persen(c.pernah_jual_pct, 0)} pernah menjual · {persen(c.pro_pct, 0)} Pro
                    </div>
                  </div>
                ))}
              </div>

              <div className="grid2" style={{ marginTop: 20 }}>
                <div>
                  <h3 className="sub-judul">Top 10 seniman terbaik</h3>
                  <p className="desc">Berdasarkan omzet penjualan 12 bulan terakhir.</p>
                  <BarPeringkat data={d.top_terbaik} kunci="omzet_12b_idr" warna="var(--series-1)"
                    judul="Bar chart 10 seniman dengan omzet 12 bulan terakhir tertinggi" format={rupiahRingkas}
                    baris={(r) => [["Omzet 12 bulan", rupiah(r.omzet_12b_idr)], ["Karya terjual", angka(r.n_jual_12b)], ["Kelompok", r.cluster]]} />
                </div>
                <div>
                  <h3 className="sub-judul">Top 10 seniman paling aktif</h3>
                  <p className="desc">Berdasarkan skor keaktifan 0–100 (penjualan, omzet, dan kebaruan penjualan 90 hari terakhir).</p>
                  <BarPeringkat data={d.top_aktif} kunci="skor_keaktifan" warna="var(--series-2)"
                    judul="Bar chart 10 seniman dengan skor keaktifan tertinggi" format={skorFmt}
                    baris={(r) => [["Skor keaktifan", skorFmt(r.skor_keaktifan)], ["Terjual 90 hari", angka(r.n_jual_90d)], ["Terakhir menjual", `${r.hari_sejak_jual} hari lalu`]]} />
                </div>
              </div>

              <details className="teknis">
                <summary>Detail untuk tim data</summary>
                <ul className="istilah">
                  <li><b>Skor keaktifan</b> = 50% peringkat jumlah penjualan 90 hari + 30% peringkat omzet 90 hari + 20% kebaruan penjualan terakhir (peringkat-persentil, 0–100).</li>
                  <li><b>Pengelompokan</b>: {m.algoritma}. HDBSCAN menemukan <b>{m.k_ditemukan} kelompok kecil</b> (perilaku penjualan bersifat kontinu, jumlahnya tidak bisa dipaksa menjadi tiga),
                    lalu digabung hierarkis (Ward) menjadi tiga tingkat menurut rata-rata skor. K-Means tidak dipakai.</li>
                  <li><b>Silhouette</b> (ruang fitur asli): kelompok HDBSCAN {String(m.silhouette_ruang_fitur).replace(".", ",")}; tiga tingkat akhir <b>{String(m.silhouette_tiga_tingkat).replace(".", ",")}</b>.
                    Nilai tiga tingkat di bawah 0,5: pemisahan antar-tingkat <b>lemah</b>; batas antar-kelompok lebih berupa kesepakatan bisnis daripada celah alami di data.</li>
                  <li>Stabilitas (ARI, subsampel 80%): {String(m.stabilitas_ari_rata2).replace(".", ",")} ± {String(m.stabilitas_ari_sd).replace(".", ",")}; noise HDBSCAN {String(m.noise_pct).replace(".", ",")}% (ditetapkan ke kelompok terdekat).</li>
                  <li>Seniman yang belum pernah menjual dinilai dari umur akunnya, sehingga akun baru yang belum menjual cenderung masuk "Kurang Aktif" dan akun lama tanpa penjualan masuk "Tidak Aktif".</li>
                </ul>
                <p className="desc">{m.catatan}</p>
              </details>
            </>
          );
        }}
      </Muat>
    </section>
  );
}

/* ------------------------------------------------------------ halaman */
function PeringatanSesi({ keluar }) {
  const [sisa, setSisa] = useState(null); // menit tersisa, hanya diisi saat <= 5
  useEffect(() => {
    const cek = () => {
      const exp = tokenExp();
      if (!exp) return;
      const ms = exp - Date.now();
      if (ms <= 0) return keluar("Sesi berakhir, silakan login lagi.");
      setSisa(ms <= 5 * 60000 ? Math.ceil(ms / 60000) : null);
    };
    cek();
    const t = setInterval(cek, 15000);
    return () => clearInterval(t);
  }, [keluar]);
  if (sisa == null) return null;
  return <div className="sesi-habis" role="status">Sesi berakhir sekitar {sisa} menit lagi. Simpan pekerjaanmu, lalu login ulang.</div>;
}

function Dashboard({ keluar }) {
  const ringkasan = useApi(`/ringkasan?periode=${PERIODE_HARI}`);
  return (
    <main className="wrap">
      <PeringatanSesi keluar={keluar} />
      <header className="top">
        <div>
          <div className="wordmark">
            <h1 className="nama">GALERIA</h1>
            <span className="peran">ADMIN</span>
          </div>
          <p className="tagline">Pantau pendapatan GALERIA dan perkembangan pengguna Pro</p>
        </div>
        <button className="link" onClick={() => keluar()}>Keluar</button>
      </header>

      <Muat api={ringkasan}>
        {(d) => (
          <>
            <Headline d={d} />
            <Kpis d={d} />
          </>
        )}
      </Muat>

      <div className="grid2" style={{ marginTop: 16 }}>
        <Forecast />
        <NaikKelas />
      </div>

      <KeaktifanSeniman />
    </main>
  );
}

export default function App() {
  const [masuk, setMasuk] = useState(() => !!ambilToken());
  const [pesan, setPesan] = useState("");
  useEffect(() => {
    onSesiHabis(() => { setPesan("Sesi berakhir, silakan login lagi."); setMasuk(false); });
  }, []);
  const keluar = useCallback((alasan = "") => { hapusToken(); setPesan(alasan); setMasuk(false); }, []);
  return masuk
    ? <Dashboard keluar={keluar} />
    : <Login pesan={pesan} onSukses={() => { setPesan(""); setMasuk(true); }} />;
}
