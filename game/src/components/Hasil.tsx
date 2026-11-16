'use client';

import { useEffect, useRef, useState } from 'react';
import gsap from 'gsap';
import { useGSAP } from '@gsap/react';
import { peringkat, skorMaksimum } from '@/lib/game';
import { ledakKonfeti } from '@/lib/konfeti';
import { bacaPapan, simpanSkor, type Skor } from '@/lib/papanSkor';
import type { HasilMain } from './Main';
import Papan from './Papan';

gsap.registerPlugin(useGSAP);

/** Layar hasil: skor menghitung naik, gelar, konfeti, simpan nama ke papan skor. */
export default function Hasil({ hasil, onUlang }: { hasil: HasilMain; onUlang: () => void }) {
  const root = useRef<HTMLDivElement>(null);
  const angka = useRef<HTMLSpanElement>(null);
  const [nama, setNama] = useState('');
  const [papan, setPapan] = useState<Skor[]>([]);
  const [tersimpan, setTersimpan] = useState<number | undefined>(undefined);

  const benar = hasil.benarPelukis + hasil.benarAliran;
  const jumlahSoal = hasil.total * 2;
  const rank = peringkat(hasil.skor, hasil.total);
  const bagus = hasil.skor / Math.max(1, skorMaksimum(hasil.total)) >= 0.35;

  useEffect(() => {
    setPapan(bacaPapan());
  }, []);

  useGSAP(
    () => {
      const obj = { v: 0 };
      const tl = gsap.timeline({ defaults: { ease: 'power3.out' } });
      tl.from('.hasil-kartu', { y: 50, opacity: 0, duration: 0.7 })
        .from('.hasil-label', { y: 16, opacity: 0, duration: 0.4 }, 0.3)
        .to(obj, {
          v: hasil.skor,
          duration: 1.6,
          ease: 'power2.out',
          onUpdate: () => {
            if (angka.current) angka.current.textContent = String(Math.round(obj.v));
          },
        }, 0.5)
        .from('.gelar', { scale: 0.3, opacity: 0, rotate: -6, duration: 0.8, ease: 'back.out(2.4)' }, 1.9)
        .from('.gelar-desk, .rincian > *', { y: 16, opacity: 0, stagger: 0.1, duration: 0.5 }, 2.2)
        .from('.simpan-form, .papan-bagian', { y: 22, opacity: 0, stagger: 0.12, duration: 0.5 }, 2.5);
      if (bagus && root.current) {
        gsap.delayedCall(1.9, () => root.current && ledakKonfeti(root.current, 110));
      }
    },
    { scope: root },
  );

  const simpan = (e: React.FormEvent) => {
    e.preventDefault();
    if (tersimpan !== undefined) return;
    const waktu = Date.now();
    const baru: Skor = { nama: (nama.trim() || 'Pengunjung').slice(0, 14), skor: hasil.skor, benar, total: hasil.total, waktu };
    setPapan(simpanSkor(baru));
    setTersimpan(waktu);
    gsap.fromTo('.papan-bagian', { scale: 0.97 }, { scale: 1, duration: 0.5, ease: 'back.out(2.5)' });
  };

  return (
    <div ref={root} className="layar layar-hasil">
      <div className="hasil-kartu">
        <div className="hasil-kiri">
        <p className="hasil-label">Skor akhirmu</p>
        <div className="hasil-skor">
          <span ref={angka}>0</span>
        </div>
        <h2 className="gelar">{rank.gelar}</h2>
        <p className="gelar-desk">{rank.deskripsi}</p>
        <div className="rincian">
          <span>
            Pelukis tepat <b>{hasil.benarPelukis}</b>/{hasil.total}
          </span>
          <span>
            Aliran tepat <b>{hasil.benarAliran}</b>/{hasil.total}
          </span>
          <span>
            Total benar <b>{benar}</b>/{jumlahSoal}
          </span>
        </div>
        </div>

        <div className="hasil-kanan">

        {tersimpan === undefined ? (
          <form className="simpan-form" onSubmit={simpan}>
            <label htmlFor="nama" className="hasil-label">
              Namamu di papan skor
            </label>
            <div className="simpan-baris">
              <input id="nama" value={nama} onChange={(e) => setNama(e.target.value)} maxLength={14} placeholder="Nama kamu" autoComplete="off" />
              <button className="tombol tombol-simpan" type="submit">
                Simpan
              </button>
            </div>
          </form>
        ) : (
          <p className="simpan-ok">Skormu tersimpan!</p>
        )}

        <div className="papan-bagian">
          <h3>Papan Skor</h3>
          <Papan papan={papan} tandai={tersimpan} />
        </div>

        <button className="tombol tombol-ulang" onClick={onUlang}>
          Main Lagi
        </button>
        </div>
      </div>
    </div>
  );
}
