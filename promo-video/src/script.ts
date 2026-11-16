import AUDIO_DETIK from './audio-durations.json';

/**
 * Naskah + garis waktu. Satu baris = satu kalimat = satu berkas suara = satu subtitle.
 * Kata di antara **...** diwarnai kuning. Durasi sementara DIPERKIRAKAN dari jumlah kata;
 * setelah suara dibuat, ganti dengan durasi audio sebenarnya (DURASI_AUDIO).
 */
export const LINES: string[] = [
  /* 0 */ 'Hari pertama.',
  /* 1 */ 'Aku **seniman.**',
  /* 2 */ 'Lukisanku **banyak.**',
  /* 3 */ 'Tapi nggak punya **tempat jualan.**',
  /* 4 */ 'Cari event? Nggak tahu di mana.',
  /* 5 */ 'Bikin komunitas? **Belum ada.**',
  /* 6 */ 'Info lelang? Apalagi.',
  /* 7 */ 'Sampai ketemu **GALERIA.**',
  /* 8 */ 'Unggah satu karya.',
  /* 9 */ 'Dicek otomatis: ada **duplikat**? Atau **kemungkinan buatan AI**?',
  /* 10 */ 'Lolos? Dapat **sertifikat digital keaslian.**',
  /* 11 */ 'Tapi ini bukan buat ngecek lukisan palsu secara fisik, ya.',
  /* 12 */ 'Event, komunitas, lelang.',
  /* 13 */ 'Semuanya di **satu aplikasi.**',
  /* 14 */ 'Tapi sebagus apa pun karyanya, masih kurang **satu hal.**',
  /* 15 */ 'Orang yang mau **memilikinya.**',
  /* 16 */ 'Kenalin, **kolektor.**',
  /* 17 */ 'Dia juga punya **masalah.**',
  /* 18 */ 'Naksir lukisan, tapi nggak tahu **muat nggak** di kamar.',
  /* 19 */ 'Tinggal **foto.**',
  /* 20 */ 'Visual Search carikan karya yang **mirip.**',
  /* 21 */ 'Lalu coba pasang lewat **AR.**',
  /* 22 */ 'Ukurannya **pas** sama aslinya.',
  /* 23 */ 'Hari pertama. Karya satu.',
  /* 24 */ 'Besok? Kita lihat.',
  /* 25 */ 'GALERIA. Temukan, lihat, miliki.',
];

/** Nyalakan setelah berkas public/audio/lNN.mp3 dibuat. */
export const PAKAI_AUDIO = true;
/** Ekstensi berkas suara di public/audio: 'mp3' (edge-tts / MiniMax) atau 'wav' (Voicebox). */
export const EKSTENSI_AUDIO: 'mp3' | 'wav' = 'mp3';

/** Durasi audio per kalimat (frame @30fps). null = pakai perkiraan. Diisi setelah suara dibuat. */
// edge-tts menyisakan ±0,25 dtk hening di ujung tiap berkas; dipangkas supaya tempo tidak lambat.
export const DURASI_AUDIO: (number | null)[] | null = (AUDIO_DETIK as number[]).map((d) =>
  Math.max(20, Math.ceil((d - 0.25) * 30)),
);

const FRAME_PER_KATA = 11;
const MIN_FRAME = 26;
const JEDA = 9;
export const LEAD = 46; // judul "DAY 1" di awal
export const TAIL = 80; // layar penutup setelah kalimat terakhir

export type Timed = {text: string; from: number; to: number; words: number};

export const TIMED: Timed[] = (() => {
  let t = LEAD;
  return LINES.map((text, i) => {
    const words = text.replace(/\*\*/g, '').split(/\s+/).filter(Boolean).length;
    const est = Math.max(MIN_FRAME, words * FRAME_PER_KATA + 10);
    const dur = DURASI_AUDIO?.[i] ?? est;
    const from = t;
    const to = from + dur;
    t = to + JEDA;
    return {text, from, to, words};
  });
})();

export const TOTAL = TIMED[TIMED.length - 1].to + TAIL;
