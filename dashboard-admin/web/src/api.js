const BASE = import.meta.env.VITE_API_BASE || "http://localhost:8000";
const KEY = import.meta.env.VITE_ADMIN_KEY || "";

export async function getJson(path) {
  const res = await fetch(`${BASE}/api/admin${path}`, {
    headers: KEY ? { "X-Admin-Key": KEY } : {},
  });
  if (!res.ok) throw new Error(`Gagal memuat (${res.status})`);
  return res.json();
}
