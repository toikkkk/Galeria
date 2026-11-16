import { createContext, useCallback, useContext, useEffect, useId, useMemo, useRef, useState } from "react";
import {
  Area, AreaChart, Bar, BarChart, Brush, CartesianGrid, Cell, ComposedChart, Line, LabelList,
  Pie, PieChart, ReferenceLine, ResponsiveContainer, Tooltip, XAxis, YAxis,
} from "recharts";
import { ambilToken, hapusToken, onSesiHabis, tokenExp } from "./api.js";
import Login from "./Login.jsx";
import { Muat, Segmented, Tabel, Tabs, Tip, useApi } from "./components.jsx";
import { angka, bulanPanjang, bulanPendek, persen, rupiah, rupiahRingkas, rupiahSumbu } from "./format.js";

/** Benar bila halaman yang memuatnya sedang dibuka; dipakai agar animasi diulang tiap halaman dibuka. */
const AktifCtx = createContext(true);
function Replay({ children }) {
  const aktif = useContext(AktifCtx);
  const [k, setK] = useState(0);
  useEffect(() => { if (aktif) setK((x) => x + 1); }, [aktif]);
  return <div key={k} className="replay">{children}</div>;
}

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

const IKON = {
  rumah: <path d="M4 11l8-7 8 7v9a1 1 0 01-1 1h-4v-6H9v6H5a1 1 0 01-1-1z" />,
  grafik: <path d="M4 20V10M10 20V4M16 20v-7M22 20H2" />,
  pengguna: <path d="M16 20v-1.5a4 4 0 00-4-4H8a4 4 0 00-4 4V20M10 11a3.5 3.5 0 100-7 3.5 3.5 0 000 7zM20 20v-1.5a4 4 0 00-3-3.9M16 4.2a3.5 3.5 0 010 6.6" />,
  keluar: <path d="M9 21H5a1 1 0 01-1-1V4a1 1 0 011-1h4M16 17l5-5-5-5M21 12H9" />,
  dompet: <path d="M3 7a2 2 0 012-2h13v4M3 7v11a2 2 0 002 2h15a1 1 0 001-1V10a1 1 0 00-1-1H5a2 2 0 01-2-2zM17 14.5h.01" />,
  label: <path d="M3 12V4a1 1 0 011-1h8l9 9-9 9zM8 8h.01" />,
  bintang: <path d="M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1L3.2 9.5l6.1-.9z" />,
  panel: <path d="M4 5h16a1 1 0 011 1v12a1 1 0 01-1 1H4a1 1 0 01-1-1V6a1 1 0 011-1zM9 5v14M14 10l2 2-2 2" />,
  info: <path d="M12 21a9 9 0 100-18 9 9 0 000 18zM12 11v5M12 8h.01" />,
};

function Ikon({ nama, ukuran = 22 }) {
  return (
    <svg viewBox="0 0 24 24" width={ukuran} height={ukuran} fill="none" stroke="currentColor" strokeWidth="1.8"
      strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">{IKON[nama]}</svg>
  );
}

/** Grafik mini tanpa sumbu: memperlihatkan arah tren di dalam kartu angka. */
function Spark({ data, k, warna = "var(--series-1)" }) {
  const gid = useId().replace(/:/g, "");
  return (
    <div className="spark" aria-hidden="true">
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={data} margin={{ top: 3, right: 0, bottom: 0, left: 0 }}>
          <defs>
            <linearGradient id={gid} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor={warna} stopOpacity={0.35} />
              <stop offset="100%" stopColor={warna} stopOpacity={0} />
            </linearGradient>
          </defs>
          <Area type="monotone" dataKey={k} stroke={warna} strokeWidth={1.8} fill={`url(#${gid})`} animationDuration={900} dot={false} />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}

function Kpi({ hero, tone, ikon, label, value, sub, seri, kunci }) {
  return (
    <div className={`kpi${hero ? " kpi-hero" : ""}${tone ? ` t-${tone}` : ""}`}>
      <div className="kpi-atas">
        <span className="kpi-ikon"><Ikon nama={ikon} ukuran={18} /></span>
        <span className="label">{label}</span>
      </div>
      <div className="value">{value}</div>
      <div className="sub">{sub}</div>
      {seri && <Spark data={seri} k={kunci} warna={hero ? "#f0c86a" : "var(--tone)"} />}
    </div>
  );
}

/** Jendela di atas halaman (dipakai konfirmasi keluar & detail teknis). Esc / klik latar = tutup. */
function Modal({ judul, tutup, children, lebar = 460 }) {
  useEffect(() => {
    const k = (e) => { if (e.key === "Escape") tutup(); };
    window.addEventListener("keydown", k);
    return () => window.removeEventListener("keydown", k);
  }, [tutup]);
  return (
    <div className="modal-latar" onMouseDown={(e) => { if (e.target === e.currentTarget) tutup(); }}>
      <div className="modal" role="dialog" aria-modal="true" aria-label={judul} style={{ maxWidth: lebar }}>
        {children}
      </div>
    </div>
  );
}

/** Angka yang menghitung naik saat halamannya dibuka. */
function Angka({ n, fmt = (v) => String(Math.round(v)) }) {
  const aktif = useContext(AktifCtx);
  const [v, setV] = useState(0);
  useEffect(() => {
    if (!aktif) return undefined;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) { setV(n); return undefined; }
    let raf; const t0 = performance.now();
    const tik = (t) => {
      const p = Math.min(1, (t - t0) / 900);
      setV(n * (1 - Math.pow(1 - p, 3)));
      if (p < 1) raf = requestAnimationFrame(tik);
    };
    raf = requestAnimationFrame(tik);
    return () => cancelAnimationFrame(raf);
  }, [n, aktif]);
  return <>{fmt(v)}</>;
}

/** Satu cincin persentase: bagian berwarna = yang sudah Pro. */
function Cincin({ nama, pro, warna = "var(--series-1)" }) {
  const data = [{ v: pro.pro_share_pct }, { v: Math.max(0, 100 - pro.pro_share_pct) }];
  return (
    <div className="cincin">
      <div className="cincin-g" role="img" aria-label={`${persen(pro.pro_share_pct)} ${nama} sudah Pro`}>
        <Replay>
          <ResponsiveContainer width="100%" height="100%">
            <PieChart>
              <Pie data={data} dataKey="v" innerRadius="68%" outerRadius="91%" startAngle={90} endAngle={-270}
                stroke="none" cornerRadius={6} animationDuration={900} animationEasing="ease-out">
                <Cell fill={warna} />
                <Cell fill="var(--track)" />
              </Pie>
            </PieChart>
          </ResponsiveContainer>
        </Replay>
        <span className="cincin-p"><Angka n={pro.pro_share_pct} />%</span>
      </div>
      <b>{nama}</b>
      <small>{angka(pro.n_pro)} sudah Pro</small>
    </div>
  );
}

function PanelPro({ d }) {
  return (
    <section className="card pro-card" aria-labelledby="h-pro-ring">
      <h2 id="h-pro-ring">Pengguna Pro</h2>
      <div className="cincin-baris">
        <Cincin nama="Kolektor" pro={d.pro.kolektor} warna="var(--series-1)" />
        <Cincin nama="Seniman" pro={d.pro.seniman} warna="var(--series-2)" />
      </div>
      <ul className="pro-daftar">
        {Object.values(ROLE).map((r) => (
          <li key={r.paket}><span>{r.paket}</span><b>{rupiah(r.harga)}<small>/bln</small></b></li>
        ))}
      </ul>
    </section>
  );
}

/** Dari mana pendapatan periode ini berasal: donat + rincian. */
function Komposisi({ d }) {
  const bagian = [
    { nama: "Komisi karya", v: d.komisi_idr, warna: "var(--series-1)" },
    { nama: "Kolektor Pro", v: d.langganan_kolektor_idr, warna: "var(--series-2)" },
    { nama: "Seniman Pro", v: d.langganan_seniman_idr, warna: "var(--series-3)" },
  ];
  const total = bagian.reduce((a, b) => a + b.v, 0) || 1;
  return (
    <section className="card komposisi" aria-labelledby="h-komp">
      <div className="card-judul"><h2 id="h-komp">Asal pendapatan</h2><span className="meta">{d.periode_hari} hari</span></div>
      <div className="donat-baris">
        <div className="donat" role="img" aria-label="Porsi tiap sumber pendapatan">
          <Replay>
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie data={bagian} dataKey="v" innerRadius="66%" outerRadius="97%" paddingAngle={2} startAngle={90} endAngle={-270} stroke="none" animationDuration={900}>
                  {bagian.map((b) => <Cell key={b.nama} fill={b.warna} />)}
                </Pie>
              </PieChart>
            </ResponsiveContainer>
          </Replay>
          <span className="donat-isi"><small>Total</small><b>{rupiahRingkas(total)}</b></span>
        </div>
        <ul className="komp-daftar">
          {bagian.map((b) => (
            <li key={b.nama}>
              <i style={{ background: b.warna }} />
              <span>{b.nama}</span>
              <b>{rupiahRingkas(b.v)}</b>
              <small>{persen((b.v / total) * 100, 0)}</small>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}

function TipBulan({ active, payload }) {
  if (!active || !payload?.length) return null;
  const r = payload[0].payload;
  return (
    <Tip judul={bulanPanjang(r.bulan)} baris={[
      ["Komisi karya terjual", rupiah(r.komisi_idr)],
      ["Langganan kolektor", rupiah(r.langganan_kolektor_idr)],
      ["Langganan seniman", rupiah(r.langganan_seniman_idr)],
      ["Total", rupiah(r.total_idr)],
    ]} />
  );
}

/** Pendapatan 12 bulan terakhir, ditumpuk per sumber. */
function TrenPendapatan({ api }) {
  return (
    <section className="card grafik tren" aria-labelledby="h-tren">
      <div className="card-judul">
        <h2 id="h-tren">Pendapatan 12 bulan terakhir</h2>
        <div className="legend">
          <span><i style={{ background: "var(--series-1)" }} />Komisi</span>
          <span><i style={{ background: "var(--series-2)" }} />Kolektor</span>
          <span><i style={{ background: "var(--series-3)" }} />Seniman</span>
        </div>
      </div>
      <Muat api={api}>
        {(rows) => (
          <div className="chart" role="img" aria-label="Diagram batang pendapatan per bulan menurut sumber">
            <Replay>
              <ResponsiveContainer>
                <BarChart data={rows.map((r) => ({ ...r, label: bulanPendek(r.bulan) }))} margin={{ top: 8, right: 8, bottom: 0, left: 0 }}>
                  <CartesianGrid stroke="var(--grid)" vertical={false} />
                  <XAxis dataKey="label" tick={AXIS} tickLine={false} axisLine={{ stroke: "var(--grid)" }} interval="preserveStartEnd" minTickGap={14} />
                  <YAxis tick={AXIS} tickLine={false} axisLine={false} width={74} tickFormatter={rupiahSumbu} />
                  <Tooltip content={<TipBulan />} cursor={{ fill: "var(--grid)", opacity: 0.6 }} />
                  <Bar dataKey="komisi_idr" stackId="p" fill="var(--series-1)" maxBarSize={34} animationDuration={800} />
                  <Bar dataKey="langganan_kolektor_idr" stackId="p" fill="var(--series-2)" maxBarSize={34} animationDuration={800} />
                  <Bar dataKey="langganan_seniman_idr" stackId="p" fill="var(--series-3)" radius={[4, 4, 0, 0]} maxBarSize={34} animationDuration={800} />
                </BarChart>
              </ResponsiveContainer>
            </Replay>
          </div>
        )}
      </Muat>
    </section>
  );
}

/* ------------------------------------------------------------ ringkasan */
/** Gabungkan dua deret per-peran (kolektor, seniman) menjadi satu deret per bulan. */
function gabungPro(proK, proS) {
  if (proK.status !== "ok" || proS.status !== "ok") return null;
  const peta = new Map(proS.data.map((r) => [r.bulan, r.n_pro]));
  return proK.data.map((r) => ({ bulan: r.bulan, label: bulanPendek(r.bulan), kolektor: r.n_pro, seniman: peta.get(r.bulan) ?? 0, total: r.n_pro + (peta.get(r.bulan) ?? 0) }));
}

function Kpis({ d, pend, pro }) {
  const langganan = d.langganan_kolektor_idr + d.langganan_seniman_idr;
  const seri = pend.status === "ok" ? pend.data.map((r) => ({ ...r, langganan: r.langganan_kolektor_idr + r.langganan_seniman_idr })) : null;
  return (
    <div className="kpis">
      <Kpi hero ikon="dompet" label="Total pendapatan" value={rupiahRingkas(d.pendapatan_total_idr)} sub={<Delta v={d.perubahan_pct.total_idr} ket="" />} seri={seri} kunci="total_idr" />
      <Kpi tone="biru" ikon="label" label="Komisi karya terjual" value={rupiahRingkas(d.komisi_idr)} sub={<>{angka(d.n_transaksi)} karya terjual</>} seri={seri} kunci="komisi_idr" />
      <Kpi tone="teal" ikon="bintang" label="Langganan Pro" value={rupiahRingkas(langganan)}
        sub={<>Kolektor {rupiahRingkas(d.langganan_kolektor_idr)} · Seniman {rupiahRingkas(d.langganan_seniman_idr)}</>} seri={seri} kunci="langganan" />
      <Kpi tone="amber" ikon="pengguna" label="Pengguna Pro" value={<Angka n={d.pro.kolektor.n_pro + d.pro.seniman.n_pro} fmt={(v) => angka(Math.round(v))} />}
        sub={<>{angka(d.pro.kolektor.n_pro)} kolektor · {angka(d.pro.seniman.n_pro)} seniman</>} seri={pro} kunci="total" />
    </div>
  );
}

function TipPertumbuhan({ active, payload }) {
  if (!active || !payload?.length) return null;
  const r = payload[0].payload;
  return <Tip judul={bulanPanjang(r.bulan)} baris={[["Kolektor Pro", angka(r.kolektor)], ["Seniman Pro", angka(r.seniman)], ["Total Pro", angka(r.total)]]} />;
}

/** Jumlah pengguna Pro per bulan, kolektor + seniman ditumpuk. */
function PertumbuhanPro({ data }) {
  const awal = data?.[0]?.total, akhir = data?.[data.length - 1]?.total;
  return (
    <section className="card grafik" aria-labelledby="h-tumbuh">
      <div className="card-judul">
        <h2 id="h-tumbuh">Pertumbuhan pengguna Pro</h2>
        <div className="legend">
          <span><i style={{ background: "var(--series-1)" }} />Kolektor</span>
          <span><i style={{ background: "var(--series-2)" }} />Seniman</span>
          {data && <span className="meta">+{angka(akhir - awal)} dalam {data.length - 1} bulan</span>}
        </div>
      </div>
      {!data ? <div className="skeleton" aria-busy="true" /> : (
        <div className="chart" role="img" aria-label="Diagram area jumlah pengguna Pro per bulan">
          <Replay>
            <ResponsiveContainer>
              <AreaChart data={data} margin={{ top: 6, right: 8, bottom: 0, left: 0 }}>
                <CartesianGrid stroke="var(--grid)" vertical={false} />
                <XAxis dataKey="label" tick={AXIS} tickLine={false} axisLine={{ stroke: "var(--grid)" }} interval="preserveStartEnd" minTickGap={18} />
                <YAxis tick={AXIS} tickLine={false} axisLine={false} width={44} tickFormatter={angka} />
                <Tooltip content={<TipPertumbuhan />} cursor={{ stroke: "var(--text-muted)", strokeDasharray: "3 3" }} />
                <Area type="monotone" dataKey="kolektor" stackId="p" stroke="var(--series-1)" strokeWidth={2} fill="var(--series-1)" fillOpacity={0.9} animationDuration={900} />
                <Area type="monotone" dataKey="seniman" stackId="p" stroke="var(--series-2)" strokeWidth={2} fill="var(--series-2)" fillOpacity={0.85} animationDuration={900} />
              </AreaChart>
            </ResponsiveContainer>
          </Replay>
        </div>
      )}
    </section>
  );
}

function Ringkasan({ api, pend, pro }) {
  return (
    <Muat api={api}>
      {(d) => (
        <>
          <Kpis d={d} pend={pend} pro={pro} />
          <div className="baris baris-1">
            <TrenPendapatan api={pend} />
            <Komposisi d={d} />
          </div>
          <div className="baris baris-2">
            <PertumbuhanPro data={pro} />
            <PanelPro d={d} />
          </div>
        </>
      )}
    </Muat>
  );
}

/* ------------------------------------------------------------ zoom & skala waktu grafik */
/** Rentang tampil [a..b] pada n titik data; bisa diperbesar/diperkecil dengan tombol, roda mouse, atau slider di bawah grafik. */
function useZoom(n, awal = n) {
  const mulai = () => [Math.max(0, n - awal), Math.max(0, n - 1)];
  const [r, setR] = useState(mulai);
  useEffect(() => { setR(mulai()); }, [n]); // eslint-disable-line react-hooks/exhaustive-deps
  const zoom = (f, pusat = 0.5) => {
    const w = r[1] - r[0] + 1;
    const nw = Math.max(Math.min(4, n), Math.min(n, Math.round(w * f)));
    const a = Math.max(0, Math.min(n - nw, Math.round(r[0] + w * pusat - nw * pusat)));
    setR([a, a + nw - 1]);
  };
  return {
    a: r[0], b: r[1], n,
    dalam: () => zoom(0.6), luar: () => zoom(1 / 0.6), zoom,
    reset: () => setR([0, n - 1]),
    atur: (a, b) => { if (a != null && b != null) setR([a, b]); },
    diperbesar: r[0] > 0 || r[1] < n - 1,
    terlihat: r[1] - r[0] + 1,
  };
}

/** Roda mouse di atas grafik = zoom di sekitar posisi kursor. */
function useRodaZoom(z, aktif) {
  const ref = useRef(null);
  const zr = useRef(z);
  zr.current = z;
  useEffect(() => {
    const el = ref.current;
    if (!el || !aktif) return undefined;
    const h = (e) => {
      e.preventDefault();
      const rc = el.getBoundingClientRect();
      zr.current.zoom(e.deltaY < 0 ? 0.8 : 1.25, Math.min(1, Math.max(0, (e.clientX - rc.left) / rc.width)));
    };
    el.addEventListener("wheel", h, { passive: false });
    return () => el.removeEventListener("wheel", h);
  }, [aktif]);
  return ref;
}

const SKALA = [{ value: "bulan", label: "Bulanan" }, { value: "tahun", label: "Tahunan" }];

function KontrolGrafik({ skala, setSkala, z, tabel, setTabel }) {
  return (
    <div className="kontrol-grafik">
      <Segmented label="Skala waktu" value={skala} onChange={setSkala} options={SKALA} />
      {skala === "bulan" && !tabel && (
        <div className="zoom" role="group" aria-label="Perbesar atau perkecil grafik">
          <button onClick={z.luar} disabled={z.terlihat >= z.n} aria-label="Perkecil" title="Perkecil (lihat rentang lebih panjang)">−</button>
          <button onClick={z.dalam} disabled={z.terlihat <= 4} aria-label="Perbesar" title="Perbesar (lihat rentang lebih pendek)">+</button>
          <button onClick={z.reset} disabled={!z.diperbesar} className="reset" title="Tampilkan semua bulan">Semua</button>
        </div>
      )}
      <button className="link" onClick={() => setTabel(!tabel)}>{tabel ? "Lihat grafik" : "Lihat angka"}</button>
    </div>
  );
}

const BRUSH = { height: 22, travellerWidth: 10, stroke: "var(--gold)", fill: "var(--surface-2)" };

/** Rangkum perkiraan per tahun: yang sudah terjadi + yang diperkirakan. */
function seriTahunan(seri) {
  const m = new Map();
  for (const r of seri) {
    const t = r.iso.slice(0, 4);
    const o = m.get(t) || { label: t, tahun: t, aktual: 0, forecast: 0, p10: 0, p90: 0, nA: 0, nF: 0 };
    if (r.jenis === "aktual") { o.aktual += r.aktual; o.nA += 1; } else { o.forecast += r.forecast; o.p10 += r.p10; o.p90 += r.p90; o.nF += 1; }
    m.set(t, o);
  }
  return [...m.values()].map((o) => ({ ...o, bulanTercatat: o.nA + o.nF }));
}

function TipTahun({ active, payload }) {
  if (!active || !payload?.length) return null;
  const r = payload[0].payload;
  const baris = [];
  if (r.nA) baris.push([`Sebenarnya (${r.nA} bln)`, rupiah(r.aktual)]);
  if (r.nF) baris.push([`Perkiraan (${r.nF} bln)`, rupiah(r.forecast)]);
  baris.push(["Jumlah", rupiah(r.aktual + r.forecast)]);
  if (r.bulanTercatat < 12) baris.push(["Catatan", `baru ${r.bulanTercatat} dari 12 bulan`]);
  return <Tip judul={`Tahun ${r.tahun}`} baris={baris} />;
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

function GrafikForecast({ fc, seri, batas, info }) {
  const [tabel, setTabel] = useState(false);
  const [skala, setSkala] = useState("bulan");
  const z = useZoom(seri.length, 24);
  const tahunan = useMemo(() => seriTahunan(seri), [seri]);
  const roda = useRodaZoom(z, skala === "bulan" && !tabel);
  return (
    <section className="card grafik" aria-labelledby="h-fc">
      <div className="card-head">
        <h2 id="h-fc">Perkiraan {info.judul}</h2>
        <KontrolGrafik skala={skala} setSkala={setSkala} z={z} tabel={tabel} setTabel={setTabel} />
      </div>
      {tabel ? (
        <div className="gulir">
          {skala === "bulan" ? (
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
            <Tabel
              kolom={[
                { judul: "Tahun", sel: (r) => r.tahun },
                { judul: "Bulan tercatat", sel: (r) => `${r.bulanTercatat} dari 12` },
                { judul: "Sebenarnya", sel: (r) => (r.nA ? rupiah(r.aktual) : "–") },
                { judul: "Perkiraan", sel: (r) => (r.nF ? rupiah(r.forecast) : "–") },
                { judul: "Jumlah", sel: (r) => rupiah(r.aktual + r.forecast) },
              ]}
              baris={tahunan}
            />
          )}
        </div>
      ) : skala === "bulan" ? (
        <>
          <div className="legend">
            <span><i style={{ background: "var(--series-1)" }} />Sebenarnya</span>
            <span><i className="dash" />Perkiraan paling mungkin</span>
            <span><i className="band" />Kisaran kemungkinan</span>
            <span className="petunjuk">Gulirkan roda mouse atau geser slider di bawah untuk memperbesar</span>
          </div>
          <div className="chart" ref={roda} role="img"
            aria-label={`Grafik pendapatan ${info.judul} per bulan, bisa diperbesar dan diperkecil`}>
            <Replay><ResponsiveContainer>
              <ComposedChart data={seri} margin={{ top: 8, right: 12, bottom: 0, left: 0 }}>
                <CartesianGrid stroke="var(--grid)" vertical={false} />
                <XAxis dataKey="label" tick={AXIS} tickLine={false} axisLine={{ stroke: "var(--grid)" }} interval="preserveStartEnd" minTickGap={18} />
                <YAxis tick={AXIS} tickLine={false} axisLine={false} width={74} tickFormatter={rupiahSumbu} />
                <Tooltip content={<TipForecast />} cursor={{ stroke: "var(--text-muted)", strokeDasharray: "3 3" }} />
                <ReferenceLine x={batas} stroke="var(--text-muted)" strokeDasharray="2 4"
                  label={{ value: "Perkiraan →", position: "insideTopRight", fill: "var(--text-muted)", fontSize: 12 }} />
                <Area type="monotone" dataKey="base" stackId="band" stroke="none" fill="none" isAnimationActive={false} legendType="none" />
                <Area type="monotone" dataKey="band" stackId="band" stroke="none" fill="var(--band)" isAnimationActive={false} legendType="none" />
                <Line type="monotone" dataKey="aktual" stroke="var(--series-1)" strokeWidth={3} dot={z.terlihat <= 14}
                  activeDot={{ r: 6, stroke: "var(--surface-1)", strokeWidth: 2 }} animationDuration={1000} />
                <Line type="monotone" dataKey="forecast" stroke="var(--series-2)" strokeWidth={3} strokeDasharray="6 4" dot={false}
                  activeDot={{ r: 6, stroke: "var(--surface-1)", strokeWidth: 2 }} animationDuration={1000} />
                <Brush dataKey="label" {...BRUSH} startIndex={z.a} endIndex={z.b} onChange={(r) => z.atur(r.startIndex, r.endIndex)} />
              </ComposedChart>
            </ResponsiveContainer></Replay>
          </div>
        </>
      ) : (
        <>
          <div className="legend">
            <span><i style={{ background: "var(--series-1)" }} />Sebenarnya</span>
            <span><i className="band" />Perkiraan</span>
            <span className="petunjuk">Tahun yang belum penuh 12 bulan ditandai * (hanya bulan yang tercatat/diperkirakan)</span>
          </div>
          <div className="chart" role="img" aria-label={`Diagram batang pendapatan ${info.judul} per tahun`}>
            <Replay><ResponsiveContainer>
              <BarChart data={tahunan.map((t) => ({ ...t, label: t.bulanTercatat < 12 ? `${t.tahun}*` : t.tahun }))} margin={{ top: 8, right: 12, bottom: 0, left: 0 }}>
                <CartesianGrid stroke="var(--grid)" vertical={false} />
                <XAxis dataKey="label" tick={AXIS} tickLine={false} axisLine={{ stroke: "var(--grid)" }} />
                <YAxis tick={AXIS} tickLine={false} axisLine={false} width={74} tickFormatter={rupiahSumbu} />
                <Tooltip content={<TipTahun />} cursor={{ fill: "var(--grid)", opacity: 0.6 }} />
                <Bar dataKey="aktual" stackId="t" fill="var(--series-1)" maxBarSize={90} animationDuration={800} />
                <Bar dataKey="forecast" stackId="t" fill="var(--gold-soft)" stroke="var(--series-2)" strokeDasharray="4 3" radius={[6, 6, 0, 0]} maxBarSize={90} animationDuration={800} />
              </BarChart>
            </ResponsiveContainer></Replay>
          </div>
        </>
      )}
    </section>
  );
}

function Forecast() {
  const [target, setTarget] = useState("total");
  const api = useApi(`/forecast?target=${target}&bulan_aktual=36`);
  const [teknis, setTeknis] = useState(false);
  const tutup = useCallback(() => setTeknis(false), []);
  const info = TARGET.find((t) => t.value === target);
  return (
    <>
      <div className="bar-atas">
        <Segmented label="Sumber pendapatan" value={target} onChange={setTarget}
          options={TARGET.map((t) => ({ value: t.value, label: t.label }))} />
        <span className="bar-ket">{info.ket}</span>
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
          const lebar = fc.total_p90_idr - fc.total_p10_idr;
          const posisi = lebar > 0 ? Math.min(100, Math.max(0, ((fc.total_p50_idr - fc.total_p10_idr) / lebar) * 100)) : 50;
          return (
            <div className="fc-grid">
              <GrafikForecast fc={fc} seri={seri} batas={batas} info={info} />

              <aside className="fc-samping">
                <div className="card fc-utama">
                  <div className="s-l">Perkiraan {awalBln} – {akhirBln}</div>
                  <div className="besar">{rupiahRingkas(fc.total_p50_idr)}</div>
                  {naik != null && (
                    <span className={`lencana ${naik >= 0 ? "naik" : "turun"}`}>
                      {naik >= 0 ? "▲" : "▼"} {arah(naik)} {persen(Math.abs(naik), 0)} dari 6 bulan terakhir
                    </span>
                  )}
                </div>
                <div className="card fc-rentang">
                  <div className="s-l">Kisaran kemungkinan</div>
                  <div className="rentang" aria-hidden="true"><i style={{ left: `${posisi}%` }} /></div>
                  <div className="rentang-nilai">
                    <span><small>Terendah</small><b>{rupiahRingkas(fc.total_p10_idr)}</b></span>
                    <span><small>Tertinggi</small><b>{rupiahRingkas(fc.total_p90_idr)}</b></span>
                  </div>
                </div>
                <div className="card fc-bulan">
                  <div className="s-l">Perkiraan per bulan</div>
                  <ul>
                    {fc.forecast.map((f) => (
                      <li key={f.bulan}><span>{bulanPanjang(f.bulan)}</span><b>{rupiahRingkas(f.p50_idr)}</b></li>
                    ))}
                  </ul>
                </div>
                <div className="card fc-catatan">
                  <p>Garis putus-putus = perkiraan paling mungkin. Area berwarna = kisarannya. Bukan jaminan: dibuat dari pola bulan-bulan sebelumnya.</p>
                  <button className="link" onClick={() => setTeknis(true)}><Ikon nama="info" ukuran={15} /> Detail untuk tim data</button>
                </div>
              </aside>

              {teknis && (
                <Modal judul="Detail untuk tim data" tutup={tutup} lebar={720}>
                  <h3>Detail untuk tim data</h3>
                  <p className="desc">Berisi istilah teknis; tidak perlu dibaca untuk memahami dashboard.</p>
                  <ul className="istilah">
                    <li><b>Kemungkinan terendah / tertinggi</b> = batas P10 dan P90: hasil sebenarnya diperkirakan jatuh di antara keduanya dengan peluang sekitar 80%.</li>
                    <li><b>Paling mungkin</b> = median (P50).</li>
                    <li><b>Galat (WAPE)</b> = rata-rata selisih perkiraan dan kenyataan saat model diuji ulang pada data lama (backtest); makin kecil makin baik.</li>
                  </ul>
                  {bt && (
                    <p className="desc">Model yang dipakai: <b>{namaModel(fc.model_terpilih)}</b> (galat uji {persen(bt.wape_pct)}).</p>
                  )}
                  {fc.target === "total" && fc.jumlah_komponen_p50_idr != null && (
                    <p className="desc">
                      Total diramal langsung. Jumlah ramalan tiga komponennya ={" "}
                      <b>{rupiahRingkas(fc.jumlah_komponen_p50_idr)}</b>; selisih kecil wajar karena model tiap sumber dipilih terpisah.
                    </p>
                  )}
                  <div className="gulir" style={{ maxHeight: 260 }}>
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
                  </div>
                  <div className="modal-aksi"><button className="btn" onClick={tutup}>Tutup</button></div>
                </Modal>
              )}
            </div>
          );
        }}
      </Muat>
    </>
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
    <Tip judul={r.tahunan ? `Akhir ${r.tahun}${r.bulanTercatat < 12 ? ` (${r.bulanTercatat} bulan tercatat)` : ""}` : bulanPanjang(r.bulan)} baris={[
      ["Sudah Pro", angka(r.n_pro)],
      ["Belum upgrade", angka(r.n_non_pro)],
      ["Jumlah semua", angka(r.n_pro + r.n_non_pro)],
      ["Persen yang Pro", persen(r.pro_share_pct)],
      [r.tahunan ? "Baru upgrade sepanjang tahun" : "Baru upgrade bulan ini", angka(r.upgrade_baru)],
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

/** Rangkum per tahun: posisi akhir tahun (jumlah Pro saat itu) + total upgrade baru sepanjang tahun. */
function dataTahunan(data) {
  const m = new Map();
  for (const r of data) {
    const t = r.bulan.slice(0, 4);
    const o = m.get(t) || { tahun: t, upgrade_baru: 0, bulanTercatat: 0 };
    Object.assign(o, { n_pro: r.n_pro, n_non_pro: r.n_non_pro, pro_share_pct: r.pro_share_pct });
    o.upgrade_baru += r.upgrade_baru; o.bulanTercatat += 1;
    m.set(t, o);
  }
  return [...m.values()].map((o) => ({ ...o, tahunan: true, label: o.bulanTercatat < 12 ? `${o.tahun}*` : o.tahun }));
}

/** Dua batang berdampingan per periode (emas = sudah Pro, biru tua = belum upgrade); bisa diperbesar & diperkecil. */
function BatangGabungan({ data, info, skala, z, roda }) {
  const bulanan = skala === "bulan";
  const langkah = bulanan && z.terlihat > 12 ? 2 : 1;
  return (
    <>
      <div className="legend">
        <span><i style={{ background: "var(--series-1)" }} />Sudah Pro</span>
        <span><i style={{ background: "var(--netral)" }} />Belum upgrade</span>
        <span className="petunjuk">{bulanan ? "Gulirkan roda mouse atau geser slider di bawah untuk memperbesar" : "Angka = posisi akhir tahun; * = tahun belum penuh 12 bulan"}</span>
      </div>
      <div className="chart" ref={bulanan ? roda : undefined} role="img"
        aria-label={`Diagram batang jumlah ${info.sebutan} yang sudah Pro dan yang belum upgrade, per ${bulanan ? "bulan" : "tahun"}`}>
        <Replay key={skala}><ResponsiveContainer>
          <BarChart data={data} margin={{ top: 26, right: 8, bottom: 0, left: 0 }} barGap={3} barCategoryGap="14%">
            <CartesianGrid stroke="var(--grid)" vertical={false} />
            <XAxis dataKey="label" tick={AXIS} tickLine={false} axisLine={{ stroke: "var(--grid)" }} interval="preserveStartEnd" minTickGap={14} />
            <YAxis tick={AXIS} tickLine={false} axisLine={false} width={48} tickFormatter={angka} domain={[0, "auto"]} />
            <Tooltip content={<TipPro />} cursor={{ fill: "var(--grid)", opacity: 0.6 }} />
            <Bar dataKey="n_pro" fill="var(--series-1)" radius={[4, 4, 0, 0]} maxBarSize={bulanan ? 30 : 70} animationDuration={800}>
              <LabelList dataKey="n_pro" content={labelAngka(langkah)} />
            </Bar>
            <Bar dataKey="n_non_pro" fill="var(--netral)" radius={[4, 4, 0, 0]} maxBarSize={bulanan ? 30 : 70} animationDuration={800}>
              <LabelList dataKey="n_non_pro" content={labelAngka(langkah)} />
            </Bar>
            {bulanan && <Brush dataKey="label" {...BRUSH} startIndex={z.a} endIndex={z.b} onChange={(r) => z.atur(r.startIndex, r.endIndex)} />}
          </BarChart>
        </ResponsiveContainer></Replay>
      </div>
    </>
  );
}

function GrafikPro({ data, info }) {
  const [tabel, setTabel] = useState(false);
  const [skala, setSkala] = useState("bulan");
  const z = useZoom(data.length, 12);
  const tahunan = useMemo(() => dataTahunan(data), [data]);
  const roda = useRodaZoom(z, skala === "bulan" && !tabel);
  const bulanan = skala === "bulan";
  const seg = bulanan ? data.slice(z.a, z.b + 1) : tahunan;
  const a = seg[0], b = seg[seg.length - 1];
  const tumbuh = a.n_pro ? ((b.n_pro - a.n_pro) / a.n_pro) * 100 : null;
  const waktuB = bulanan ? bulanPanjang(b.bulan) : `akhir ${b.tahun}`;
  const banding = bulanan ? `${seg.length - 1} bulan lalu` : `akhir ${a.tahun}`;
  return (
    <section className="card grafik" aria-labelledby="h-pro">
      <div className="card-head">
        <div>
          <h2 id="h-pro">{info.label} Pro {bulanan ? "bulan demi bulan" : "tahun demi tahun"}</h2>
          <p className="desc">
            Ada <b>{angka(b.n_pro)} {info.sebutan} Pro</b> per {waktuB}
            {tumbuh != null && seg.length > 1 && <>, <b className={tumbuh >= 0 ? "delta-up" : "delta-down"}>{arah(tumbuh)} {persen(Math.abs(tumbuh), 0)}</b> dibanding {banding}</>}.
          </p>
        </div>
        <KontrolGrafik skala={skala} setSkala={setSkala} z={z} tabel={tabel} setTabel={setTabel} />
      </div>
      {tabel ? (
        <div className="gulir">
          <Tabel
            kolom={[
              { judul: bulanan ? "Bulan" : "Tahun", sel: (r) => (r.tahunan ? `${r.label}` : bulanPanjang(r.bulan)) },
              { judul: "Sudah Pro", sel: (r) => angka(r.n_pro) },
              { judul: "Belum upgrade", sel: (r) => angka(r.n_non_pro) },
              { judul: "Persen Pro", sel: (r) => persen(r.pro_share_pct) },
              { judul: "Baru upgrade", sel: (r) => angka(r.upgrade_baru) },
            ]}
            baris={bulanan ? data : tahunan}
          />
        </div>
      ) : (
        <BatangGabungan data={bulanan ? data : tahunan} info={info} skala={skala} z={z} roda={roda} />
      )}
    </section>
  );
}

const BULAN_RIWAYAT = 36;

function PanelRole({ role }) {
  const info = ROLE[role];
  const api = useApi(`/pro-vs-nonpro?role=${role}&bulan=${BULAN_RIWAYAT}`);
  const pend = useApi(`/pendapatan-bulanan?bulan=${BULAN_RIWAYAT}`);
  return (
    <Muat api={api}>
      {(rows) => {
        const data = rows.map((r) => ({ ...r, label: bulanPendek(r.bulan) }));
        const b = data[data.length - 1];
        const pendapatan = pend.status === "ok" ? pend.data[pend.data.length - 1][info.kolomPendapatan] : null;
        return (
          <div className="pro-grid">
            <aside className="pro-samping">
              <div className="paket">
                <div>
                  <div className="nama">{info.paket}</div>
                  <div className="harga">{rupiah(info.harga)} <small>per bulan</small></div>
                </div>
                <ul>{info.manfaat.map((m) => <li key={m}>{m}</li>)}</ul>
              </div>
              <div className="stats">
                <div><div className="s-l">Sudah Pro</div><div className="s-v">{angka(b.n_pro)}</div></div>
                <div><div className="s-l">Belum upgrade</div><div className="s-v">{angka(b.n_non_pro)}</div></div>
                <div><div className="s-l">Persen Pro</div><div className="s-v">{persen(b.pro_share_pct)}</div></div>
                <div><div className="s-l">Baru upgrade</div><div className="s-v">{angka(b.upgrade_baru)}</div></div>
                <div className="lebar"><div className="s-l">Pendapatan langganan bulan ini</div><div className="s-v">{pendapatan == null ? "–" : rupiahRingkas(pendapatan)}</div></div>
              </div>
            </aside>
            <GrafikPro data={data} info={info} />
          </div>
        );
      }}
    </Muat>
  );
}

function NaikKelas() {
  // ?role=seniman membuka tab Seniman langsung (berguna utk berbagi tautan / tangkapan layar)
  const awal = new URLSearchParams(window.location.search).get("role");
  const [role, setRole] = useState(awal in ROLE ? awal : "kolektor");
  return (
    <>
      <div className="bar-atas">
        <Segmented label="Jenis pengguna" value={role} onChange={setRole}
          options={Object.entries(ROLE).map(([value, r]) => ({ value, label: r.label }))} />
        <span className="bar-ket">Cokelat tua = sudah Pro, abu = belum upgrade. Dicatat tiap akhir bulan.</span>
      </div>
      <PanelRole key={role} role={role} />
    </>
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

const MENU = [
  { id: "ringkasan", label: "Dashboard", judul: "Ringkasan", ikon: "rumah" },
  { id: "perkiraan", label: "Perkiraan", judul: "Perkiraan pendapatan", ikon: "grafik" },
  { id: "pro", label: "Pengguna Pro", judul: "Siapa yang sudah naik kelas ke Pro?", ikon: "pengguna" },
];

/** Isi sidebar: angka kunci + grafik mini, supaya menu tidak terasa kosong. */
function SideSekilas({ api, pend }) {
  const d = api.status === "ok" ? api.data : null;
  if (!d) return <div className="side-sekilas" aria-busy="true" />;
  const seri = pend.status === "ok" ? pend.data : null;
  const p = d.perubahan_pct.total_idr;
  return (
    <div className="side-sekilas" aria-label={`Sekilas ${d.periode_hari} hari terakhir`}>
      <div className="ss-label">SEKILAS · {d.periode_hari} HARI</div>
      <div className="ss-besar">{rupiahRingkas(d.pendapatan_total_idr)}</div>
      {p != null && <div className={`ss-delta ${p >= 0 ? "naik" : "turun"}`}>{p >= 0 ? "▲" : "▼"} {persen(Math.abs(p))}</div>}
      {seri && <Spark data={seri} k="total_idr" warna="#f0c86a" />}
      <dl className="ss-daftar">
        <div><dt>Karya terjual</dt><dd>{angka(d.n_transaksi)}</dd></div>
        <div><dt>Pengguna Pro</dt><dd>{angka(d.pro.kolektor.n_pro + d.pro.seniman.n_pro)}</dd></div>
        <div><dt>Pro kolektor</dt><dd>{persen(d.pro.kolektor.pro_share_pct)}</dd></div>
        <div><dt>Pro seniman</dt><dd>{persen(d.pro.seniman.pro_share_pct)}</dd></div>
      </dl>
    </div>
  );
}

function Dashboard({ keluar }) {
  const ringkasan = useApi(`/ringkasan?periode=${PERIODE_HARI}`);
  const pend = useApi("/pendapatan-bulanan?bulan=12");
  const proK = useApi("/pro-vs-nonpro?role=kolektor&bulan=12");
  const proS = useApi("/pro-vs-nonpro?role=seniman&bulan=12");
  const pro = useMemo(() => gabungPro(proK, proS), [proK, proS]);
  const [aktif, setAktif] = useState(0);
  const [tanyaKeluar, setTanyaKeluar] = useState(false);
  const [kecil, setKecil] = useState(() => { try { return localStorage.getItem("galeria_side_kecil") === "1"; } catch { return false; } });
  useEffect(() => { try { localStorage.setItem("galeria_side_kecil", kecil ? "1" : "0"); } catch { /* abaikan */ } }, [kecil]);
  const batal = useCallback(() => setTanyaKeluar(false), []);
  // tiap halaman tetap terpasang; yang lain bergeser keluar sehingga terlihat saling menimpa saat berpindah
  const kelas = (i) => `view ${i === aktif ? "v-aktif" : i < aktif ? "v-sebelum" : "v-sesudah"}`;
  return (
    <div className={`shell${kecil ? " side-kecil" : ""}`}>
      <aside className="side">
        <div className="side-atas">
          <div className="side-logo">
            <h1 className="nama">GALERIA</h1>
            <span className="peran">ADMIN</span>
          </div>
          <button className="side-tombol" onClick={() => setKecil(!kecil)}
            aria-label={kecil ? "Perluas menu" : "Kecilkan menu"} aria-expanded={!kecil}
            title={kecil ? "Perluas menu" : "Kecilkan menu"}>
            <Ikon nama="panel" ukuran={18} />
          </button>
        </div>
        <div className="side-label">MENU</div>
        <nav className="side-nav" aria-label="Menu utama">
          {MENU.map((m, i) => (
            <button key={m.id} className={aktif === i ? "aktif" : ""} title={m.label} aria-label={m.label}
              aria-current={aktif === i ? "page" : undefined} onClick={() => setAktif(i)}>
              <Ikon nama={m.ikon} ukuran={18} /><span className="teks">{m.label}</span>
            </button>
          ))}
        </nav>
        <SideSekilas api={ringkasan} pend={pend} />
        <div className="side-kaki">
          <p className="side-catatan">Data contoh untuk demo. Bukan angka transaksi sungguhan.</p>
          <button className="side-keluar" title="Keluar" aria-label="Keluar" onClick={() => setTanyaKeluar(true)}>
            <Ikon nama="keluar" ukuran={18} /><span className="teks">Keluar</span>
          </button>
        </div>
      </aside>

      <div className="utama">
        <header className="topbar">
          <h2 className="topbar-judul">{MENU[aktif].judul}</h2>
          <span className="chip-periode">{PERIODE_HARI} hari terakhir</span>
          <div className="akun">
            <span className="avatar" aria-hidden="true">A</span>
            <div><b>Admin</b><small>Pengelola platform</small></div>
          </div>
        </header>
        <PeringatanSesi keluar={keluar} />

        <main className="stage">
          <section className={kelas(0)} aria-hidden={aktif !== 0}><AktifCtx.Provider value={aktif === 0}><Ringkasan api={ringkasan} pend={pend} pro={pro} /></AktifCtx.Provider></section>
          <section className={kelas(1)} aria-hidden={aktif !== 1}><AktifCtx.Provider value={aktif === 1}><Forecast /></AktifCtx.Provider></section>
          <section className={kelas(2)} aria-hidden={aktif !== 2}><AktifCtx.Provider value={aktif === 2}><NaikKelas /></AktifCtx.Provider></section>
        </main>
      </div>

      {tanyaKeluar && (
        <Modal judul="Konfirmasi keluar" tutup={batal} lebar={400}>
          <h3>Keluar dari dashboard?</h3>
          <p className="desc">Sesi login akan diakhiri dan kamu perlu masuk lagi untuk membuka dashboard.</p>
          <div className="modal-aksi">
            <button className="btn" autoFocus onClick={batal}>Batal</button>
            <button className="btn btn-bahaya" onClick={() => keluar()}>Ya, keluar</button>
          </div>
        </Modal>
      )}
    </div>
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
