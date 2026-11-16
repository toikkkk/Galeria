export type Word = {t: string; at: number; key: boolean};
export type Line = {words: Word[]; from: number; to: number};

/**
 * Membuat satu baris subtitle kata-per-kata.
 * Kata di antara **...** diwarnai kuning (kata kunci).
 * `from`/`to` dalam frame; `step` = jarak antar kata (frame).
 * Nanti `from`/`to`/`step` diambil dari durasi berkas suara tiap kalimat.
 */
export const makeLine = (text: string, from: number, to: number, step = 7): Line => {
  let on = false;
  const words = text
    .split(/\s+/)
    .filter(Boolean)
    .map((raw, i) => {
      if (raw.startsWith('**')) on = true;
      const key = on;
      if (raw.endsWith('**')) on = false;
      return {t: raw.replace(/\*\*/g, ''), at: from + i * step, key};
    });
  return {words, from, to};
};
