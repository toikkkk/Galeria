import { useCallback, useEffect, useState } from "react";
import { getJson } from "./api.js";

/** Muat data dari API dgn loading / error + coba lagi. */
export function useApi(path) {
  const [state, setState] = useState({ status: "loading", data: null, error: null });
  const muat = useCallback(() => {
    setState((s) => ({ ...s, status: "loading" }));
    getJson(path)
      .then((data) => setState({ status: "ok", data, error: null }))
      .catch((e) => setState({ status: "error", data: null, error: e.message }));
  }, [path]);
  useEffect(() => { muat(); }, [muat]);
  return { ...state, muat };
}

export function Segmented({ value, onChange, options, label }) {
  return (
    <div className="seg" role="group" aria-label={label}>
      {options.map((o) => (
        <button key={o.value} aria-pressed={o.value === value} onClick={() => onChange(o.value)}>
          {o.label}
        </button>
      ))}
    </div>
  );
}

/** Tab sungguhan (bukan tombol segmen): isi panel di bawahnya berganti mengikuti tab terpilih. */
export function Tabs({ value, onChange, tabs, label }) {
  return (
    <div className="tabs" role="tablist" aria-label={label}>
      {tabs.map((t) => (
        <button key={t.value} role="tab" className="tab" id={`tab-${t.value}`}
          aria-selected={t.value === value} aria-controls={`panel-${t.value}`}
          onClick={() => onChange(t.value)}>
          {t.label}
        </button>
      ))}
    </div>
  );
}

export function Muat({ api, children }) {
  if (api.status === "loading") return <div className="skeleton" aria-busy="true" />;
  if (api.status === "error")
    return (
      <div className="state" role="alert">
        <div>Data tidak bisa dimuat: {api.error}</div>
        <button className="link" onClick={api.muat}>Coba lagi</button>
      </div>
    );
  return children(api.data);
}

export function Tip({ judul, baris }) {
  return (
    <div className="tip">
      <b>{judul}</b>
      {baris.map((b) => (
        <div className="row" key={b[0]}>
          <span>{b[0]}</span>
          <span>{b[1]}</span>
        </div>
      ))}
    </div>
  );
}

export function Tabel({ kolom, baris }) {
  return (
    <div className="tbl-wrap">
      <table>
        <thead>
          <tr>{kolom.map((k) => <th key={k.judul}>{k.judul}</th>)}</tr>
        </thead>
        <tbody>
          {baris.map((r, i) => (
            <tr key={i} className={r._pilih ? "pilih" : ""}>
              {kolom.map((k) => <td key={k.judul}>{k.sel(r)}</td>)}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
