'use client';

import type { Skor } from '@/lib/papanSkor';

/** Daftar papan skor. `tandai` = waktu entri yang baru disimpan (disorot). */
export default function Papan({ papan, tandai, maks = 5 }: { papan: Skor[]; tandai?: number; maks?: number }) {
  const tampil = papan.slice(0, maks);
  if (tampil.length === 0) {
    return <p className="papan-kosong">Belum ada skor. Jadilah yang pertama!</p>;
  }
  return (
    <ol className="papan">
      {tampil.map((s, i) => (
        <li key={`${s.waktu}-${i}`} className={s.waktu === tandai ? 'papan-baru' : ''}>
          <span className="papan-no">{i + 1}</span>
          <span className="papan-nama">{s.nama}</span>
          <span className="papan-benar">
            {s.benar}/{s.total * 2}
          </span>
          <b className="papan-skor">{s.skor}</b>
        </li>
      ))}
    </ol>
  );
}
