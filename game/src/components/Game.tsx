'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import type { Lukisan } from '@/data/lukisan';
import { IDLE_RESET_MS, pilihLukisan } from '@/lib/game';
import { hapusPapan } from '@/lib/papanSkor';
import Hasil from './Hasil';
import Judul from './Judul';
import Main, { type HasilMain } from './Main';

type Layar = 'judul' | 'main' | 'hasil';

/** Pengatur layar: judul -> main -> hasil. Kembali ke judul otomatis bila tak disentuh (mode pameran). */
export default function Game() {
  const [layar, setLayar] = useState<Layar>('judul');
  const [ronde, setRonde] = useState<Lukisan[]>([]);
  const [hasil, setHasil] = useState<HasilMain | null>(null);
  const [admin, setAdmin] = useState(false);
  const [penuh, setPenuh] = useState(false);
  const terakhirSentuh = useRef(Date.now());

  useEffect(() => {
    setAdmin(new URLSearchParams(window.location.search).get('admin') === '1');
  }, []);

  // lacak sentuhan; bila diam terlalu lama dan bukan di layar judul -> kembali ke judul
  useEffect(() => {
    const tandai = () => {
      terakhirSentuh.current = Date.now();
    };
    window.addEventListener('pointerdown', tandai);
    window.addEventListener('keydown', tandai);
    const cek = window.setInterval(() => {
      if (Date.now() - terakhirSentuh.current > IDLE_RESET_MS) {
        setLayar((l) => (l === 'judul' ? l : 'judul'));
      }
    }, 2000);
    return () => {
      window.removeEventListener('pointerdown', tandai);
      window.removeEventListener('keydown', tandai);
      window.clearInterval(cek);
    };
  }, []);

  useEffect(() => {
    const onFs = () => setPenuh(!!document.fullscreenElement);
    document.addEventListener('fullscreenchange', onFs);
    return () => document.removeEventListener('fullscreenchange', onFs);
  }, []);

  const mulai = useCallback(() => {
    terakhirSentuh.current = Date.now();
    setRonde(pilihLukisan());
    setHasil(null);
    setLayar('main');
  }, []);

  const selesai = useCallback((h: HasilMain) => {
    terakhirSentuh.current = Date.now();
    setHasil(h);
    setLayar('hasil');
  }, []);

  const layarPenuh = () => {
    if (document.fullscreenElement) void document.exitFullscreen();
    else void document.documentElement.requestFullscreen?.();
  };

  return (
    <main className="stage">
      {layar === 'judul' && <Judul onMulai={mulai} admin={admin} onHapusPapan={() => { hapusPapan(); window.alert('Papan skor dihapus.'); }} />}
      {layar === 'main' && ronde.length > 0 && <Main key={ronde.map((r) => r.id).join('|')} ronde={ronde} onSelesai={selesai} />}
      {layar === 'hasil' && hasil && <Hasil hasil={hasil} onUlang={mulai} />}

      <button className="tombol-fs" onClick={layarPenuh} aria-label={penuh ? 'Keluar layar penuh' : 'Layar penuh'} title="Layar penuh">
        {penuh ? '⤡' : '⤢'}
      </button>
    </main>
  );
}
