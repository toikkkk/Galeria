const nf = (d) => new Intl.NumberFormat("id-ID", { maximumFractionDigits: d });

export const rupiah = (v) => "Rp" + nf(0).format(Math.round(v));

/** Untuk teks & kartu (mudah dibaca awam): Rp232,4 juta / Rp1,69 miliar / Rp3,29 triliun */
export function rupiahRingkas(v) {
  const a = Math.abs(v);
  if (a >= 1e12) return "Rp" + nf(2).format(v / 1e12) + " triliun";
  if (a >= 1e9) return "Rp" + nf(2).format(v / 1e9) + " miliar";
  if (a >= 1e6) return "Rp" + nf(1).format(v / 1e6) + " juta";
  return rupiah(v);
}

/** Untuk sumbu grafik (ruang sempit): Rp200 jt / Rp1,5 M */
export function rupiahSumbu(v) {
  const a = Math.abs(v);
  if (a >= 1e9) return "Rp" + nf(1).format(v / 1e9) + " M";
  if (a >= 1e6) return "Rp" + nf(0).format(v / 1e6) + " jt";
  return rupiah(v);
}

export const angka = (v) => nf(0).format(v);
export const persen = (v, d = 1) => (v == null ? "–" : nf(d).format(v) + "%");

export function bulanPendek(iso) {
  const d = new Date(iso + "T00:00:00Z");
  return new Intl.DateTimeFormat("id-ID", { month: "short", year: "2-digit", timeZone: "UTC" }).format(d);
}
export function bulanPanjang(iso) {
  const d = new Date(iso + "T00:00:00Z");
  return new Intl.DateTimeFormat("id-ID", { month: "long", year: "numeric", timeZone: "UTC" }).format(d);
}
