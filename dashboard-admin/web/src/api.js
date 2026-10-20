const BASE = import.meta.env.VITE_API_BASE || "http://localhost:8000";
const KUNCI_TOKEN = "galeria_admin_token";

/* Tanpa "Ingat saya": sessionStorage (hilang saat tab ditutup). Dengan: localStorage.
   Storage bisa melempar error (mode privat) -> semua akses dibungkus. */
const dari = (st, fn) => { try { return fn(window[st]); } catch { return null; } };
export const ambilToken = () =>
  dari("sessionStorage", (s) => s.getItem(KUNCI_TOKEN)) || dari("localStorage", (s) => s.getItem(KUNCI_TOKEN));
const simpanToken = (t, ingat) => {
  hapusToken();
  dari(ingat ? "localStorage" : "sessionStorage", (s) => s.setItem(KUNCI_TOKEN, t));
};
export const hapusToken = () => {
  dari("sessionStorage", (s) => s.removeItem(KUNCI_TOKEN));
  dari("localStorage", (s) => s.removeItem(KUNCI_TOKEN));
};

/** Detik epoch kedaluwarsa token (dibaca dari payload JWT; hanya utk tampilan, server tetap yang memvalidasi). */
export function tokenExp() {
  try {
    const p = ambilToken().split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    return JSON.parse(atob(p)).exp * 1000;
  } catch { return null; }
}

/** Dipanggil App saat sesi habis (401) supaya kembali ke halaman login. */
let saatSesiHabis = () => {};
export const onSesiHabis = (fn) => { saatSesiHabis = fn; };

export async function login(email, password, ingat = false) {
  let res;
  try {
    res = await fetch(`${BASE}/api/admin/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password, ingat }),
    });
  } catch {
    throw new Error("Server tidak terjangkau. Pastikan backend sedang berjalan.");
  }
  if (!res.ok) {
    const detail = (await res.json().catch(() => ({}))).detail;
    throw new Error(typeof detail === "string" ? detail : `Login gagal (${res.status})`);
  }
  simpanToken((await res.json()).access_token, ingat);
}

export async function getJson(path) {
  const token = ambilToken();
  const res = await fetch(`${BASE}/api/admin${path}`, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });
  if (res.status === 401) {
    hapusToken();
    saatSesiHabis();
    throw new Error("Sesi berakhir, silakan login lagi");
  }
  if (!res.ok) throw new Error(`Gagal memuat (${res.status})`);
  return res.json();
}
