import {mixPose, P0, Pose} from './three/Hero';

const mk = (o: Partial<Pose>): Pose => ({...P0, ...o});

/** Pustaka pose. Nama bebas, dipakai di urutan gerak per kalimat di bawah. */
export const POSES = {
  neutral: mk({}),
  happy: mk({smile: 0.9, brow: 0.4, lid: 0.15}),
  lookL: mk({hy: -0.55, brow: 0.2}),
  lookR: mk({hy: 0.5, brow: 0.2}),
  self: mk({fxR: 0.9, abR: -0.25, elR: 1.9, smile: 0.35, hz: -0.06}), // tangan ke dada: "aku"
  wave: mk({abR: 2.05, elR: 0.7, oscEl: 0.55, smile: 0.9, brow: 0.5, hz: -0.08, lid: 0.1}),
  presentR: mk({fxR: 0.9, abR: 1.05, elR: 0.25, smile: 0.5, hy: 0.35, brow: 0.3}),
  shrugSad: mk({abL: 0.9, abR: 0.9, fxL: 0.2, fxR: 0.2, elL: 1.0, elR: 1.0, hz: 0.14, brow: 0.5, browTilt: 0.45, smile: -0.7, hx: 0.08}),
  salute: mk({fxR: 1.85, abR: 0.25, elR: 1.95, hy: 0.4, brow: 0.3, lid: 0.35}), // tangan di atas mata (mencari)
  think: mk({fxR: 1.2, abR: -0.2, elR: 2.3, fxL: 0.9, elL: 1.8, hz: 0.12, brow: 0.7, lid: 0.4, hy: -0.2}),
  sigh: mk({hx: 0.3, lean: 0.08, abL: 0.35, abR: 0.35, elL: 0.5, elR: 0.5, lid: 0.55, smile: -0.4}),
  surprised: mk({brow: 1, lid: 0, fxL: 0.4, fxR: 0.4, elL: 0.9, elR: 0.9, smile: 0.2, hop: 0.06, lean: -0.05}),
  cheer: mk({abL: 2.6, abR: 2.6, elL: 0.3, elR: 0.3, smile: 1, brow: 0.8, hop: 0.12, lid: 0.1}),
  hold: mk({fxL: 1.3, fxR: 1.3, abL: 0.1, abR: 0.1, elL: 0.45, elR: 0.45, smile: 0.4}),
  idea: mk({fxR: 2.45, abR: 0.2, elR: 0.5, brow: 0.9, smile: 0.4, hz: -0.1}),
  thumbs: mk({fxR: 1.1, abR: 0.1, elR: 1.95, smile: 0.95, brow: 0.4, hz: -0.06}),
  no: mk({fxL: 1.0, fxR: 1.0, abL: 0.5, abR: 0.5, elL: 0.5, elR: 0.5, oscHead: 0.28, lid: 0.35, smile: -0.2}),
  presentBoth: mk({abL: 1.15, abR: 1.15, fxL: 0.5, fxR: 0.5, elL: 0.4, elR: 0.4, smile: 0.9, brow: 0.4}),
  hips: mk({abL: 0.7, abR: 0.7, fxL: -0.2, fxR: -0.2, elL: 1.8, elR: 1.8, hy: 0.2, smile: 0.2, lid: 0.3}),
  lookFar: mk({fxR: 1.9, abR: 0.2, elR: 2.0, hy: 0.7, brow: 0.5, lid: 0.3}),
  measure: mk({abL: 1.5, abR: 1.5, fxL: 0.6, fxR: 0.6, elL: 0.3, elR: 0.3, hz: 0.1, brow: 0.3, browTilt: 0.3, smile: -0.2}),
  measure2: mk({abL: 0.6, abR: 0.6, fxL: 0.9, fxR: 0.9, elL: 0.6, elR: 0.6, hz: -0.08, brow: 0.5, browTilt: 0.2}),
  phone: mk({fxL: 1.25, fxR: 1.25, abL: -0.1, abR: -0.1, elL: 1.4, elR: 1.4, hx: 0.25, phone: 1, lid: 0.3}),
  phoneL: mk({fxL: 1.4, fxR: 1.4, abL: -0.05, abR: -0.05, elL: 1.35, elR: 1.35, hy: -0.55, hx: 0.1, phone: 1, brow: 0.4}),
  phoneR: mk({fxL: 1.4, fxR: 1.4, abL: -0.05, abR: -0.05, elL: 1.35, elR: 1.35, hy: 0.55, hx: 0.1, phone: 1, brow: 0.4}),
  phoneUp: mk({fxL: 1.7, fxR: 1.7, abL: 0, abR: 0, elL: 1.2, elR: 1.2, hx: -0.1, phone: 1, smile: 0.6, brow: 0.5}),
} satisfies Record<string, Pose>;

export type PoseName = keyof typeof POSES;
type Beat = [number, PoseName]; // [bagian kalimat 0..1, nama pose]

// Urutan gerak SENIMAN per kalimat (indeks sama dengan LINES di script.ts).
export const SEQ_S: Beat[][] = [
  /* 0 Hari pertama. */ [[0, 'lookL'], [0.5, 'lookR'], [1, 'neutral']],
  /* 1 Aku seniman. */ [[0, 'neutral'], [0.25, 'wave'], [0.7, 'wave'], [1, 'self']],
  /* 2 Lukisanku banyak. */ [[0, 'self'], [0.35, 'presentR'], [1, 'presentR']],
  /* 3 nggak punya tempat jualan */ [[0, 'neutral'], [0.35, 'shrugSad'], [1, 'shrugSad']],
  /* 4 Cari event? */ [[0, 'salute'], [0.5, 'salute'], [0.62, 'shrugSad'], [1, 'shrugSad']],
  /* 5 komunitas belum ada */ [[0, 'think'], [0.5, 'think'], [0.65, 'shrugSad'], [1, 'shrugSad']],
  /* 6 Info lelang? Apalagi. */ [[0, 'shrugSad'], [0.4, 'sigh'], [1, 'sigh']],
  /* 7 Sampai ketemu GALERIA */ [[0, 'sigh'], [0.4, 'surprised'], [0.7, 'cheer'], [1, 'cheer']],
  /* 8 Unggah satu karya */ [[0, 'cheer'], [0.3, 'hold'], [0.7, 'presentR'], [1, 'presentR']],
  /* 9 Dicek otomatis */ [[0, 'neutral'], [0.3, 'think'], [0.6, 'think'], [0.82, 'idea'], [1, 'idea']],
  /* 10 Lolos? sertifikat */ [[0, 'idea'], [0.3, 'thumbs'], [1, 'thumbs']],
  /* 11 bukan cek palsu fisik */ [[0, 'neutral'], [0.2, 'no'], [0.85, 'no'], [1, 'neutral']],
  /* 12 Event, komunitas, lelang */ [[0, 'neutral'], [0.2, 'idea'], [0.4, 'neutral'], [0.55, 'idea'], [0.75, 'neutral'], [1, 'cheer']],
  /* 13 satu aplikasi */ [[0, 'cheer'], [0.3, 'presentBoth'], [1, 'presentBoth']],
  /* 14 masih kurang satu hal */ [[0, 'presentBoth'], [0.3, 'hips'], [0.7, 'hips'], [0.85, 'idea'], [1, 'idea']],
  /* 15 orang yang mau memilikinya */ [[0, 'idea'], [0.3, 'lookFar'], [1, 'lookFar']],
  /* 16 Kenalin, kolektor */ [[0, 'neutral'], [0.35, 'presentR'], [1, 'presentR']],
  /* 17 punya masalah */ [[0, 'presentR'], [0.3, 'lookR'], [1, 'lookR']],
  /* 18 */ [[0, 'lookR'], [1, 'lookR']],
  /* 19 */ [[0, 'lookR'], [1, 'lookR']],
  /* 20 */ [[0, 'lookR'], [0.6, 'happy'], [1, 'happy']],
  /* 21 */ [[0, 'happy'], [1, 'lookR']],
  /* 22 */ [[0, 'lookR'], [0.5, 'thumbs'], [1, 'thumbs']],
  /* 23 Hari pertama. Karya satu. */ [[0, 'neutral'], [0.2, 'wave'], [1, 'wave']],
  /* 24 Besok? Kita lihat. */ [[0, 'wave'], [0.45, 'presentBoth'], [1, 'happy']],
  /* 25 */ [[0, 'cheer'], [1, 'cheer']],
];

// Urutan gerak KOLEKTOR (hanya tampil dari kalimat 16).
export const SEQ_K: Beat[][] = [
  ...Array.from({length: 16}, () => [[0, 'neutral']] as Beat[]),
  /* 16 */ [[0, 'neutral'], [0.7, 'neutral'], [0.9, 'wave'], [1, 'wave']],
  /* 17 */ [[0, 'wave'], [0.3, 'shrugSad'], [1, 'shrugSad']],
  /* 18 muat nggak di kamar */ [[0, 'shrugSad'], [0.2, 'measure'], [0.5, 'measure2'], [0.7, 'measure'], [1, 'shrugSad']],
  /* 19 Tinggal foto */ [[0, 'neutral'], [0.3, 'phone'], [1, 'phone']],
  /* 20 Visual Search */ [[0, 'phone'], [0.5, 'phone'], [0.8, 'phoneUp'], [1, 'phoneUp']],
  /* 21 pasang lewat AR */ [[0, 'phoneUp'], [0.3, 'phoneL'], [0.6, 'phoneR'], [1, 'phoneUp']],
  /* 22 pas sama aslinya */ [[0, 'phoneUp'], [0.35, 'cheer'], [1, 'cheer']],
  /* 23 */ [[0, 'cheer'], [0.3, 'wave'], [1, 'wave']],
  /* 24 */ [[0, 'wave'], [0.5, 'happy'], [1, 'happy']],
  /* 25 */ [[0, 'happy'], [1, 'wave']],
];

const smooth = (x: number) => {
  const t = Math.min(1, Math.max(0, x));
  return t * t * (3 - 2 * t);
};

const beatPose = (beats: Beat[], frac: number): Pose => {
  let i = 0;
  for (let j = 0; j < beats.length; j++) if (frac >= beats[j][0]) i = j;
  const cur = POSES[beats[i][1]];
  if (i === beats.length - 1) return cur;
  const next = POSES[beats[i + 1][1]];
  const span = Math.max(0.0001, beats[i + 1][0] - beats[i][0]);
  return mixPose(cur, next, smooth((frac - beats[i][0]) / span));
};

/** Pose pada kalimat `idx` di bagian `frac` (0..1); 12% pertama dicampur dari pose akhir kalimat sebelumnya. */
export const poseAt = (seq: Beat[][], idx: number, frac: number): Pose => {
  const p = beatPose(seq[idx], frac);
  const blend = 0.14;
  if (idx > 0 && frac < blend) {
    const prev = beatPose(seq[idx - 1], 1);
    return mixPose(prev, p, smooth(frac / blend));
  }
  return p;
};
