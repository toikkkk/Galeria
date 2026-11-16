'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import gsap from 'gsap';
import { useGSAP } from '@gsap/react';
import type { Lukisan } from '@/data/lukisan';
import { WAKTU_JAWAB, hitungPoin, opsiAliran, opsiPelukis } from '@/lib/game';
import { ledakKonfeti } from '@/lib/konfeti';

gsap.registerPlugin(useGSAP);

type Fase = 'lihat' | 'pelukis' | 'aliran' | 'ungkap';
export type HasilMain = { skor: number; benarPelukis: number; benarAliran: number; total: number };

const HURUF = ['A', 'B', 'C', 'D', 'E', 'F'];

/** Layar permainan: lihat lukisan -> tebak pelukis -> tebak aliran -> ungkap, diulang tiap lukisan. */
export default function Main({ ronde, onSelesai }: { ronde: Lukisan[]; onSelesai: (h: HasilMain) => void }) {
  const root = useRef<HTMLDivElement>(null);
  const timer = useRef<gsap.core.Tween | null>(null);
  const terkunci = useRef(false);
  const tampilSkor = useRef({ v: 0 });
  const angkaSkor = useRef<HTMLSpanElement>(null);
  const angkaWaktu = useRef<HTMLSpanElement>(null);

  const [i, setI] = useState(0);
  const [fase, setFase] = useState<Fase>('lihat');
  const [skor, setSkor] = useState(0);
  const [benarP, setBenarP] = useState(0);
  const [benarA, setBenarA] = useState(0);
  const [poinP, setPoinP] = useState<number | null>(null);
  const [poinA, setPoinA] = useState<number | null>(null);
  const [dipilih, setDipilih] = useState<string | null>(null);
  const [popTeks, setPopTeks] = useState('');
  const [rasio, setRasio] = useState(0.75); // lebar/tinggi lukisan, dibaca saat gambar termuat (hanya untuk tampilan)

  const lk = ronde[i];
  const opsiP = useMemo(() => opsiPelukis(lk), [lk]);
  const opsiA = useMemo(() => opsiAliran(lk), [lk]);
  const bertanya = fase === 'pelukis' || fase === 'aliran';
  const kunci = fase === 'pelukis' ? lk.pelukis : lk.aliran;
  const opsi = fase === 'pelukis' ? opsiP : opsiA;
  const terakhir = i === ronde.length - 1;

  // masuk layar
  useGSAP(
    () => {
      gsap.from(root.current, { opacity: 0, duration: 0.5 });
    },
    { scope: root },
  );

  // angka skor menghitung naik
  useEffect(() => {
    const el = angkaSkor.current;
    if (!el) return;
    const tw = gsap.to(tampilSkor.current, {
      v: skor,
      duration: 0.7,
      ease: 'power2.out',
      onUpdate: () => {
        el.textContent = String(Math.round(tampilSkor.current.v));
      },
    });
    return () => {
      tw.kill();
    };
  }, [skor]);

  // gerak lambat pada lukisan selama masih lukisan yang sama (ken burns)
  useGSAP(
    () => {
      gsap.fromTo('.lukisan-img', { scale: 1 }, { scale: 1.05, duration: 14, ease: 'sine.inOut', yoyo: true, repeat: -1 });
    },
    { scope: root, dependencies: [i], revertOnUpdate: true },
  );

  // lampu sorot menyala setiap ganti lukisan, lalu bergoyang sangat halus
  useGSAP(
    () => {
      gsap.fromTo('.sorot', { opacity: 0 }, { opacity: 1, duration: 1.4, ease: 'power2.out' });
      gsap.fromTo('.sorot-kerucut', { rotate: -0.8 }, { rotate: 0.8, duration: 6, ease: 'sine.inOut', yoyo: true, repeat: -1, transformOrigin: '50% 0%' });
    },
    { scope: root, dependencies: [i], revertOnUpdate: true },
  );

  // fase 1: lukisan terungkap dari tengah
  useGSAP(
    () => {
      if (fase !== 'lihat') return;
      terkunci.current = false;
      const tl = gsap.timeline({ onComplete: () => setFase('pelukis') });
      tl.fromTo('.bingkai', { clipPath: 'inset(50% 50% 50% 50%)', scale: 1.12 }, { clipPath: 'inset(0% 0% 0% 0%)', scale: 1, duration: 1.3, ease: 'power4.out' })
        .from('.nomor-ronde', { y: -20, opacity: 0, duration: 0.5, ease: 'power3.out' }, 0.1)
        .from('.plakat', { y: 24, opacity: 0, duration: 0.6, ease: 'power3.out' }, 0.8)
        .from('.petunjuk', { y: 16, opacity: 0, duration: 0.5, ease: 'power3.out' }, 0.7)
        .to({}, { duration: 0.9 });
    },
    { scope: root, dependencies: [i, fase], revertOnUpdate: true },
  );

  // fase 2 dan 3: pertanyaan, pilihan masuk berurutan, waktu berjalan
  const { contextSafe } = useGSAP(
    () => {
      if (!bertanya) return;
      terkunci.current = false;
      gsap.from('.pertanyaan', { y: 28, opacity: 0, duration: 0.5, ease: 'power3.out' });
      gsap.from('.opsi', { y: 44, opacity: 0, scale: 0.92, stagger: 0.09, duration: 0.55, ease: 'back.out(1.7)', delay: 0.15, clearProps: 'transform,opacity' });
      gsap.set('.timer-bar', { scaleX: 1 });
      if (angkaWaktu.current) angkaWaktu.current.textContent = String(WAKTU_JAWAB);
      timer.current = gsap.to('.timer-bar', {
        scaleX: 0,
        duration: WAKTU_JAWAB,
        ease: 'none',
        delay: 0.7,
        onUpdate: () => {
          if (angkaWaktu.current && timer.current) {
            angkaWaktu.current.textContent = String(Math.max(0, Math.ceil(WAKTU_JAWAB * (1 - timer.current.progress()))));
          }
        },
        onComplete: () => jawab(''),
      });
      return () => {
        timer.current?.kill();
      };
    },
    { scope: root, dependencies: [i, fase], revertOnUpdate: true },
  );

  // fase 4: kartu ungkapan
  useGSAP(
    () => {
      if (fase !== 'ungkap') return;
      gsap.from('.kartu-ungkap > *', { y: 26, opacity: 0, stagger: 0.09, duration: 0.6, ease: 'power3.out' });
      gsap.from('.lencana-poin', { scale: 0.4, opacity: 0, stagger: 0.12, duration: 0.6, ease: 'back.out(2.4)', delay: 0.2 });
      gsap.from('.plakat-karya dd', { clipPath: 'inset(0 100% 0 0)', duration: 0.8, ease: 'power2.out' });
      if (poinP !== null && poinA !== null && poinP > 0 && poinA > 0 && root.current) ledakKonfeti(root.current, 55);
    },
    { scope: root, dependencies: [fase], revertOnUpdate: true },
  );

  // label museum terisi saat pelukis / aliran terjawab (tulisan "tersingkap" dari kiri ke kanan)
  useGSAP(
    () => {
      if (poinP !== null) gsap.fromTo('.plakat-pelukis dd', { clipPath: 'inset(0 100% 0 0)' }, { clipPath: 'inset(0 0% 0 0)', duration: 0.8, ease: 'power2.out' });
    },
    { scope: root, dependencies: [poinP] },
  );
  useGSAP(
    () => {
      if (poinA !== null) gsap.fromTo('.plakat-aliran dd', { clipPath: 'inset(0 100% 0 0)' }, { clipPath: 'inset(0 0% 0 0)', duration: 0.8, ease: 'power2.out' });
    },
    { scope: root, dependencies: [poinA] },
  );

  const jawab = contextSafe((pilihan: string) => {
    if (terkunci.current) return;
    terkunci.current = true;
    const sisa = timer.current ? 1 - timer.current.progress() : 0;
    timer.current?.kill();
    const benar = pilihan === kunci;
    const poin = hitungPoin(benar, benar ? sisa : 0);

    setDipilih(pilihan);
    setSkor((s) => s + poin);
    if (fase === 'pelukis') {
      setPoinP(poin);
      if (benar) setBenarP((n) => n + 1);
    } else {
      setPoinA(poin);
      if (benar) setBenarA((n) => n + 1);
    }
    setPopTeks(benar ? `+${poin}` : pilihan === '' ? 'Waktu habis' : 'Kurang tepat');

    const els = Array.from(root.current?.querySelectorAll<HTMLButtonElement>('.opsi') ?? []);
    const iBenar = opsi.indexOf(kunci);
    const iPil = opsi.indexOf(pilihan);
    if (benar && els[iBenar]) {
      gsap.fromTo(els[iBenar], { scale: 1 }, { scale: 1.05, duration: 0.16, yoyo: true, repeat: 3, ease: 'power1.inOut' });
    } else {
      if (els[iPil]) gsap.fromTo(els[iPil], { x: 0 }, { x: 12, duration: 0.06, repeat: 7, yoyo: true, ease: 'none', clearProps: 'x' });
      if (els[iBenar]) gsap.fromTo(els[iBenar], { scale: 1 }, { scale: 1.04, duration: 0.28, yoyo: true, repeat: 1, ease: 'power1.inOut', delay: 0.3 });
    }
    const pop = root.current?.querySelector('.poin-pop');
    if (pop) {
      gsap.killTweensOf(pop);
      gsap.fromTo(pop, { opacity: 0, y: 14, scale: 0.6 }, { opacity: 1, y: 0, scale: 1, duration: 0.5, ease: 'back.out(2.2)' });
      gsap.to(pop, { opacity: 0, duration: 0.3, delay: 1.0 });
    }
    gsap.to('.timer-track', { opacity: 0.35, duration: 0.3 });
    gsap.to('.waktu', { opacity: 0, duration: 0.2 });

    gsap.delayedCall(1.45, () => {
      setDipilih(null);
      setFase(fase === 'pelukis' ? 'aliran' : 'ungkap');
    });
  });

  const lanjut = () => {
    if (terakhir) {
      onSelesai({ skor, benarPelukis: benarP, benarAliran: benarA, total: ronde.length });
      return;
    }
    setI(i + 1);
    setFase('lihat');
    setPoinP(null);
    setPoinA(null);
    setDipilih(null);
  };

  const tandaP = poinP === null ? '' : poinP > 0 ? 'ya' : 'tidak';
  const tandaA = poinA === null ? '' : poinA > 0 ? 'ya' : 'tidak';

  return (
    <div ref={root} className="layar layar-main">
      {/* dinding galeri: lampu sorot dan lantai */}
      <div className="dinding" aria-hidden="true">
        <div className="sorot">
          <div className="sorot-kerucut" />
          <div className="sorot-kolam" />
        </div>
        <div className="lantai" />
      </div>

      <header className="bilah-atas">
        <span className="nomor-ronde">
          <span className="progres" aria-hidden="true">
            {ronde.map((r, k) => (
              <i key={r.id} className={k < i ? 'selesai' : k === i ? 'aktif' : ''} />
            ))}
          </span>
          Lukisan <b>{i + 1}</b> dari {ronde.length}
        </span>
        <span className="skor-papan">
          Skor <b ref={angkaSkor}>0</b>
        </span>
      </header>

      <div className="area-main">
        <figure className="sisi-lukisan">
          <div className="bingkai-luar">
            <div className="bingkai">
              <img
                key={lk.id}
                className="lukisan-img"
                style={{ ['--r' as string]: rasio }}
                src={`/lukisan/${lk.berkas}`}
                alt="Lukisan yang harus ditebak"
                draggable={false}
                onLoad={(e) => setRasio(e.currentTarget.naturalWidth / Math.max(1, e.currentTarget.naturalHeight))}
              />
            </div>
          </div>

          <aside className="plakat" aria-label="Label lukisan">
            <dl>
              <div className={`plakat-baris plakat-pelukis ${tandaP} ${fase === 'pelukis' ? 'giliran' : ''}`}>
                <dt>Pelukis</dt>
                <dd>{poinP !== null ? lk.pelukis : <span className="tanya">— ? —</span>}</dd>
              </div>
              <div className={`plakat-baris plakat-aliran ${tandaA} ${fase === 'aliran' ? 'giliran' : ''}`}>
                <dt>Aliran</dt>
                <dd>{poinA !== null ? lk.aliran : <span className="tanya">— ? —</span>}</dd>
              </div>
              <div className="plakat-baris plakat-karya">
                <dt>Karya</dt>
                <dd>{fase === 'ungkap' ? `${lk.judul}, ${lk.tahun}` : <span className="tanya">— ? —</span>}</dd>
              </div>
            </dl>
          </aside>
          {fase === 'lihat' && <figcaption className="petunjuk">Perhatikan baik-baik lukisan ini…</figcaption>}
        </figure>

        <section className="panel" aria-live="polite">
          {bertanya && (
            <>
              <div className="panel-kepala">
                <p className="langkah">
                  <span className={fase === 'pelukis' ? 'langkah-aktif' : ''}>1 · Pelukis</span>
                  <span className={fase === 'aliran' ? 'langkah-aktif' : ''}>2 · Aliran</span>
                </p>
                <span className="waktu" aria-label="Sisa waktu">
                  <b ref={angkaWaktu}>{WAKTU_JAWAB}</b>
                  <small>dtk</small>
                </span>
              </div>
              <h2 className="pertanyaan">{fase === 'pelukis' ? 'Siapa pelukisnya?' : 'Aliran seni apa ini?'}</h2>
              <div className="timer-track" aria-hidden="true">
                <div className="timer-bar" />
              </div>
              <div className="opsi-grid" role="group" aria-label="Pilihan jawaban">
                {opsi.map((o, idx) => {
                  const sudah = dipilih !== null;
                  const cls = [
                    'opsi',
                    sudah && o === kunci ? 'kunci' : '',
                    sudah && o === dipilih && o === kunci ? 'benar' : '',
                    sudah && o === dipilih && o !== kunci ? 'salah' : '',
                  ]
                    .filter(Boolean)
                    .join(' ');
                  return (
                    <button key={o} className={cls} disabled={sudah} onClick={() => jawab(o)}>
                      <span className="opsi-huruf">{HURUF[idx]}</span>
                      <span className="opsi-teks">{o}</span>
                    </button>
                  );
                })}
              </div>
              <div className="poin-pop" aria-hidden="true">
                {popTeks}
              </div>
            </>
          )}

          {fase === 'lihat' && (
            <div className="menunggu" aria-hidden="true">
              <span /> <span /> <span />
            </div>
          )}

          {fase === 'ungkap' && (
            <div className="kartu-ungkap">
              <p className="langkah">
                <span className="langkah-aktif">Jawabanmu</span>
              </p>
              <div className="baris-hasil">
                <span className={`lencana-poin ${poinP ? 'ya' : 'tidak'}`}>{poinP ? `Pelukis benar +${poinP}` : 'Pelukis kurang tepat'}</span>
                <span className={`lencana-poin ${poinA ? 'ya' : 'tidak'}`}>{poinA ? `Aliran benar +${poinA}` : 'Aliran kurang tepat'}</span>
              </div>
              <h2 className="nama-pelukis">{lk.pelukis}</h2>
              <p className="aliran-karya">{lk.aliran}</p>
              <p className="fakta">{lk.fakta}</p>
              <button className="tombol tombol-lanjut" onClick={lanjut}>
                {terakhir ? 'Lihat Hasil' : 'Lukisan Berikutnya'}
              </button>
            </div>
          )}
        </section>
      </div>
    </div>
  );
}
