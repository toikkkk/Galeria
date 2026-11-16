/** Papan skor disimpan di browser perangkat pameran (localStorage). Tidak ada server. */
export type Skor = { nama: string; skor: number; benar: number; total: number; waktu: number };

const KUNCI = 'galeria_tebak_lukisan_papan_skor_v1';
const MAKS = 50;

export function bacaPapan(): Skor[] {
  try {
    const mentah = window.localStorage.getItem(KUNCI);
    if (!mentah) return [];
    const data = JSON.parse(mentah) as Skor[];
    return Array.isArray(data) ? data : [];
  } catch {
    return [];
  }
}

export function simpanSkor(s: Skor): Skor[] {
  const papan = [...bacaPapan(), s].sort((a, b) => b.skor - a.skor || a.waktu - b.waktu).slice(0, MAKS);
  try {
    window.localStorage.setItem(KUNCI, JSON.stringify(papan));
  } catch {
    /* mode privat / penyimpanan penuh: papan hanya hidup selama sesi */
  }
  return papan;
}

export function hapusPapan(): void {
  try {
    window.localStorage.removeItem(KUNCI);
  } catch {
    /* abaikan */
  }
}
