'use client';

import { useRef } from 'react';
import gsap from 'gsap';
import { useGSAP } from '@gsap/react';
import { LUKISAN } from '@/data/lukisan';
import { RONDE, WAKTU_JAWAB } from '@/lib/game';

gsap.registerPlugin(useGSAP);

/** Layar judul (attract mode): deretan lukisan bergulir, judul muncul huruf demi huruf, tombol berdenyut. */
export default function Judul({ onMulai, admin, onHapusPapan }: { onMulai: () => void; admin: boolean; onHapusPapan: () => void }) {
  const root = useRef<HTMLDivElement>(null);

  useGSAP(
    () => {
      const kurangGerak = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

      // lukisan di latar bergulir terus (dua baris berlawanan arah)
      if (!kurangGerak) {
        gsap.to('.baris-a', { xPercent: -50, duration: 70, ease: 'none', repeat: -1 });
        gsap.fromTo('.baris-b', { xPercent: -50 }, { xPercent: 0, duration: 85, ease: 'none', repeat: -1 });
      }

      const tl = gsap.timeline({ defaults: { ease: 'power3.out' } });
      tl.from('.latar-gulir', { opacity: 0, duration: 1.2 }, 0)
        .from('.logo-judul', { scale: 0.3, rotate: -40, opacity: 0, duration: 1, ease: 'back.out(1.8)' }, 0.1)
        .from('.huruf', { yPercent: 110, opacity: 0, rotateX: -80, stagger: 0.035, duration: 0.8 }, 0.35)
        .from('.sub-judul', { y: 24, opacity: 0, duration: 0.7 }, 0.95)
        .from('.info-judul > *', { y: 20, opacity: 0, stagger: 0.12, duration: 0.6 }, 1.15)
        .from('.tombol-mulai', { scale: 0.6, opacity: 0, duration: 0.7, ease: 'back.out(2.2)' }, 1.35);

      if (!kurangGerak) {
        gsap.to('.logo-judul', { y: -8, duration: 2.4, ease: 'sine.inOut', yoyo: true, repeat: -1 });
        gsap.to('.tombol-mulai', { scale: 1.045, duration: 0.9, ease: 'sine.inOut', yoyo: true, repeat: -1, delay: 2.2 });
        gsap.to('.kilau', { xPercent: 260, duration: 2.2, ease: 'power1.inOut', repeat: -1, repeatDelay: 1.4, delay: 2.6 });
      }
    },
    { scope: root },
  );

  const huruf = (teks: string) =>
    teks.split('').map((h, i) => (
      <span key={i} className="huruf-kotak">
        <span className="huruf">{h === ' ' ? ' ' : h}</span>
      </span>
    ));

  // dua baris gambar, masing-masing digandakan supaya gulirannya mulus tanpa celah
  const baris = (arr: typeof LUKISAN) => [...arr, ...arr, ...arr, ...arr];

  return (
    <div ref={root} className="layar layar-judul">
      <div className="latar-gulir" aria-hidden="true">
        <div className="baris baris-a">
          {baris(LUKISAN).map((l, i) => (
            <img key={`a${i}`} src={`/lukisan/${l.berkas}`} alt="" draggable={false} />
          ))}
        </div>
        <div className="baris baris-b">
          {baris([...LUKISAN].reverse()).map((l, i) => (
            <img key={`b${i}`} src={`/lukisan/${l.berkas}`} alt="" draggable={false} />
          ))}
        </div>
        <div className="latar-selubung" />
      </div>

      <div className="kartu-judul">
        <img className="logo-judul" src="/brand/galeria_logo.png" alt="Logo GALERIA" />
        <p className="label-kecil"><i aria-hidden="true" />GALERIA PRESENTS<i aria-hidden="true" /></p>
        <h1 className="judul-besar" aria-label="Tebak Lukisan">
          <span className="baris-judul">{huruf('TEBAK')}</span>
          <span className="baris-judul">{huruf('LUKISAN')}</span>
        </h1>
        <p className="sub-judul">Kenali pelukis dan aliran dari sebuah mahakarya.</p>
        <ul className="info-judul">
          <li><b>{Math.min(RONDE, LUKISAN.length)}</b> lukisan</li>
          <li><b>2</b> pertanyaan tiap lukisan</li>
          <li><b>{WAKTU_JAWAB}</b> detik tiap jawaban</li>
        </ul>
        <button className="tombol tombol-mulai" onClick={onMulai}>
          <span>Mulai Main</span>
          <i className="kilau" aria-hidden="true" />
        </button>
        {admin && (
          <button className="tombol-admin" onClick={onHapusPapan}>
            Hapus papan skor (admin)
          </button>
        )}
      </div>
    </div>
  );
}
