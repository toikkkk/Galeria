import { useCallback, useEffect, useState } from "react";
import {
  Area, Bar, BarChart, CartesianGrid, ComposedChart, Line, LabelList,
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
  akhir.forecast = akhir.aktual; // sambungkan garis putus-putus ke titik terakhir
  akhir.base = akhir.aktual;
  akhir.band = 0;
  const depan = fc.forecast.map((f) => ({
    iso: f.bulan, label: bulanPendek(f.bulan), jenis: "forecast", forecast: f.p50_idr,
    p10: f.p10_idr, p90: f.p90_idr, base: f.p10_idr, band: f.p90_idr - f.p10_idr,
  }));
  return [...aktual, ...depan];
}

function TipForecast({ active, payload }) {
  if (!active || !payload?.length) return null;
  const r = payload[0].payload;
  const j = bulanPanjang(r.iso);
  if (r.jenis === "aktual") return <Tip judul={j} baris={[["Pendapatan sebenarnya", rupiah(r.aktual)]]} />;
  return (
    <Tip judul={`${j} · perkiraan`} baris={[
      ["Paling mungkin", rupiah(r.forecast)],
      ["Kemungkinan terendah", rupiah(r.p10)],
      ["Kemungkinan tertinggi", rupiah(r.p90)],
    ]} />
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
      <Muat api={api}>
        {(fc) => {
          if (!fc.tersedia)
            return <div className="state">Perkiraan belum tersedia. Hubungi tim data untuk menjalankan perhitungannya.</div>;
          const seri = bangunSeri(fc);
          const batas = seri.find((s) => s.jenis === "aktual" && s.forecast != null).label;
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
                <div><div className="s-l">Perkiraan paling mungkin</div><div className="s-v">{rupiahRingkas(fc.total_p50_idr)}</div></div>
                <div><div className="s-l">Kemungkinan terendah</div><div className="s-v">{rupiahRingkas(fc.total_p10_idr)}</div></div>
                <div><div className="s-l">Kemungkinan tertinggi</div><div className="s-v">{rupiahRingkas(fc.total_p90_idr)}</div></div>
              </div>

              {tabel ? (
                <Tabel
                  kolom={[
                    { judul: "Bulan", sel: (r) => bulanPanjang(r.iso) },
                    { judul: "Keterangan", sel: (r) => (r.jenis === "aktual" ? "Sebenarnya" : "Perkiraan") },
                    { judul: "Pendapatan", sel: (r) => rupiah(r.jenis === "aktual" ? r.aktual : r.forecast) },
                    { judul: "Terendah", sel: (r) => (r.p10 != null ? rupiah(r.p10) : "–") },
                    { judul: "Tertinggi", sel: (r) => (r.p90 != null ? rupiah(r.p90) : "–") },
                  ]}
                  baris={seri}
                />
              ) : (
                <>
                  <div className="legend">
                    <span><i style={{ background: "var(--series-1)" }} />Pendapatan sebenarnya</span>
                    <span><i className="dash" />Perkiraan paling mungkin</span>
                    <span><i className="band" />Kisaran kemungkinan</span>
                  </div>
                  <div className="chart" role="img"
                    aria-label={`Grafik pendapatan ${info.judul}: 18 bulan terakhir dan perkiraan 6 bulan ke depan`}>
                    <ResponsiveContainer>
                      <ComposedChart data={seri} margin={{ top: 8, right: 12, bottom: 0, left: 0 }}>
                        <CartesianGrid stroke="var(--grid)" vertical={false} />
                        <XAxis dataKey="label" tick={AXIS} tickLine={false} axisLine={{ stroke: "var(--grid)" }} interval="preserveStartEnd" minTickGap={18} />
                        <YAxis tick={AXIS} tickLine={false} axisLine={false} width={74} tickFormatter={rupiahSumbu} />
                        <Tooltip content={<TipForecast />} cursor={{ stroke: "var(--text-muted)", strokeDasharray: "3 3" }} />
                        <ReferenceLine x={batas} stroke="var(--text-muted)" strokeDasharray="2 4"
                          label={{ value: "Perkiraan →", position: "insideTopRight", fill: "var(--text-muted)", fontSize: 12 }} />
                        <Area dataKey="base" stackId="band" stroke="none" fill="none" isAnimationActive={false} legendType="none" />
                        <Area dataKey="band" stackId="band" stroke="none" fill="var(--band)" isAnimationActive={false} legendType="none" />
                        <Line dataKey="aktual" stroke="var(--series-1)" strokeWidth={2.5} dot={false}
                          activeDot={{ r: 5, stroke: "var(--surface-1)", strokeWidth: 2 }} isAnimationActive={false} />
                        <Line dataKey="forecast" stroke="var(--series-1)" strokeWidth={2.5} strokeDasharray="6 4" dot={false}
                          activeDot={{ r: 5, stroke: "var(--surface-1)", strokeWidth: 2 }} isAnimationActive={false} />
                      </ComposedChart>
                    </ResponsiveContainer>
                  </div>
                  <p className="cap">
                    Garis putus-putus adalah perkiraan yang paling mungkin. Area krem menunjukkan kisarannya: hasil sebenarnya bisa lebih
                    rendah atau lebih tinggi. Perkiraan dibuat dari pola bulan-bulan sebelumnya dan bukan jaminan.
                  </p>
                </>
              )}

              <details className="teknis">
                <summary>Detail untuk tim data</summary>
                <p className="desc">
                  Bagian ini berisi istilah teknis dan tidak perlu dibaca untuk memahami dashboard.
                </p>
                <ul className="istilah">
                  <li><b>Kemungkinan terendah / tertinggi</b> = batas P10 dan P90: hasil sebenarnya diperkirakan jatuh di antara keduanya dengan peluang sekitar 80%.</li>
                  <li><b>Paling mungkin</b> = median (P50).</li>
                  <li><b>Galat (WAPE)</b> = rata-rata selisih antara perkiraan dan kenyataan saat model diuji ulang pada data lama (backtest); makin kecil makin baik.</li>
                </ul>
                {bt && (
                  <p className="desc">Model yang dipakai untuk tampilan ini: <b>{namaModel(fc.model_terpilih)}</b> (galat uji {persen(bt.wape_pct)}).</p>
                )}
                {fc.target === "total" && fc.jumlah_komponen_p50_idr != null && (
                  <p className="desc">
                    Total diramal langsung. Jumlah ramalan tiga komponennya (komisi + 2 langganan, masing-masing dengan model sendiri) ={" "}
                    <b>{rupiahRingkas(fc.jumlah_komponen_p50_idr)}</b>; selisih kecil wajar karena model tiap sumber dipilih terpisah.
                  </p>
                )}
                <Tabel
                  kolom={[
                    { judul: "Model", sel: (r) => namaModel(r.model) + (r.terpilih ? " ✓" : "") },
                    { judul: "WAPE", sel: (r) => persen(r.wape_pct) },
                    { judul: "sMAPE", sel: (r) => persen(r.smape_pct) },
                    { judul: "MASE", sel: (r) => r.mase.toFixed(2).replace(".", ",") },
                    { judul: "Cakupan P10–P90", sel: (r) => (r.cakupan_p80 == null ? "–" : persen(r.cakupan_p80 * 100, 0)) },
                  ]}
                  baris={fc.backtest.map((b) => ({ ...b, _pilih: b.terpilih }))}
                />
                <p className="desc" style={{ marginTop: 10 }}>
                  Dokumentasi data: <code>dashboard-admin/data/LAPORAN_DATA.md</code>
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
