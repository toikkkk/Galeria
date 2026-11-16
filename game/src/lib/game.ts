import { LUKISAN, ALIRAN_PENGECOH, PELUKIS_PENGECOH, type Lukisan } from '@/data/lukisan';

/** Pengaturan permainan (ubah di sini). */
export const RONDE = 5; // jumlah lukisan per permainan (maks. sebanyak data)
export const WAKTU_JAWAB = 15; // detik per pertanyaan
export const POIN_BENAR = 100;
export const BONUS_CEPAT = 50; // bonus maksimum (sisa waktu penuh)
export const JUMLAH_PILIHAN = 4;
export const IDLE_RESET_MS = 60_000; // layar judul/hasil kembali ke awal bila tak disentuh

export function acak<T>(arr: readonly T[]): T[] {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

/** Pilihan jawaban: 1 benar + pengecoh dari semua nama yang ada (tanpa duplikat), lalu diacak. */
export function buatPilihan(benar: string, semuaBenar: readonly string[], pengecoh: readonly string[], n = JUMLAH_PILIHAN): string[] {
  const kolam = [...new Set([...semuaBenar, ...pengecoh])].filter((x) => x !== benar);
  const salah = acak(kolam).slice(0, Math.max(0, n - 1));
  return acak([benar, ...salah]);
}

export function pilihLukisan(): Lukisan[] {
  return acak(LUKISAN).slice(0, Math.min(RONDE, LUKISAN.length));
}

export const opsiPelukis = (l: Lukisan) =>
  buatPilihan(l.pelukis, LUKISAN.map((x) => x.pelukis), PELUKIS_PENGECOH);
export const opsiAliran = (l: Lukisan) =>
  buatPilihan(l.aliran, LUKISAN.map((x) => x.aliran), ALIRAN_PENGECOH);

/** Poin satu jawaban: 0 bila salah, selain itu dasar + bonus menurut sisa waktu (0..1). */
export function hitungPoin(benar: boolean, sisaWaktu01: number): number {
  if (!benar) return 0;
  return POIN_BENAR + Math.round(BONUS_CEPAT * Math.min(1, Math.max(0, sisaWaktu01)));
}

export const skorMaksimum = (jumlahRonde: number) => jumlahRonde * 2 * (POIN_BENAR + BONUS_CEPAT);

export function peringkat(skor: number, jumlahRonde: number): { gelar: string; deskripsi: string } {
  const p = skor / Math.max(1, skorMaksimum(jumlahRonde));
  if (p >= 0.85) return { gelar: 'Maestro GALERIA', deskripsi: 'Matamu setajam kurator museum.' };
  if (p >= 0.6) return { gelar: 'Kurator Muda', deskripsi: 'Kamu paham betul seluk-beluk seni rupa.' };
  if (p >= 0.35) return { gelar: 'Penikmat Seni', deskripsi: 'Bagus! Sedikit lagi jadi ahli.' };
  return { gelar: 'Calon Kolektor', deskripsi: 'Setiap kolektor hebat bermula dari rasa ingin tahu.' };
}
