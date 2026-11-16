import React from 'react';
import {interpolate, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {C, FONT} from '../theme';
import {paintUrl} from '../art';
import {BORDER, Card, Check, Chip, Cross, Row} from './ui';

const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;

const thumb = (seed: number, w: number, h: number, extra: React.CSSProperties = {}): React.CSSProperties => ({
  width: w,
  height: h,
  objectFit: 'cover',
  border: BORDER,
  borderRadius: 10,
  background: `url(${paintUrl(seed, w * 2, h * 2)}) center/cover`,
  ...extra,
});

/** Adegan 3-6: daftar kebutuhan seniman yang "kosong". */
export const NeedsCard: React.FC<{at: number[]}> = ({at}) => (
  <Card label="KEBUTUHAN SENIMAN">
    <Row k="Tempat jualan" v="0" tone="red" at={at[0]} />
    <Row k="Event" v="???" tone="red" at={at[1]} />
    <Row k="Komunitas" v="0" tone="red" at={at[2]} />
    <Row k="Lelang" v="???" tone="red" at={at[3]} />
  </Card>
);

/** Unggah karya dengan progress. */
export const UploadCard: React.FC = () => {
  const f = useCurrentFrame();
  const p = interpolate(f, [8, 44], [0, 100], clamp);
  const done = p >= 100;
  return (
    <Card label="UNGGAH KARYA">
      <div style={{display: 'flex', gap: 20, alignItems: 'center'}}>
        <div style={thumb(2, 100, 126)} />
        <div style={{flex: 1}}>
          <div style={{fontSize: 30, fontWeight: 900, marginBottom: 10}}>Lukisan baru</div>
          <div style={{height: 20, border: BORDER, borderRadius: 10, overflow: 'hidden', background: '#fff'}}>
            <div style={{width: `${p}%`, height: '100%', background: C.green}} />
          </div>
          <div style={{marginTop: 8, display: 'flex', alignItems: 'center', gap: 8, fontSize: 26, fontWeight: 900}}>
            {done ? (
              <>
                <Check size={26} /> TERUNGGAH
              </>
            ) : (
              `${Math.round(p)}%`
            )}
          </div>
        </div>
      </div>
    </Card>
  );
};

/** Sertifikat digital keaslian (ilustrasi). */
export const CertCard: React.FC = () => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  const s = spring({frame: f - 26, fps, config: {damping: 8, stiffness: 200}});
  return (
    <Card label="SERTIFIKAT DIGITAL KEASLIAN" bg="#f8e7b9">
      <Row k="Karya" v="Terdaftar" tone="green" at={10} />
      <Row k="Duplikat" v="Tidak ada" tone="green" at={16} />
      <Row k="Tanda tangan" v="Digital" tone="green" at={22} />
      {f >= 26 && (
        <div
          style={{
            position: 'absolute',
            right: 16,
            bottom: -30,
            transform: `rotate(-10deg) scale(${s})`,
            border: `5px solid #2f7a2b`,
            color: '#2f7a2b',
            background: 'rgba(251,243,228,.95)',
            borderRadius: 12,
            padding: '2px 14px',
            fontWeight: 900,
            fontSize: 30,
            letterSpacing: 3,
          }}
        >
          TERDAFTAR
        </div>
      )}
    </Card>
  );
};

const IconRow: React.FC<{ok: boolean; text: string; at: number}> = ({ok, text, at}) => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  if (f < at) return null;
  const s = spring({frame: f - at, fps, config: {damping: 14, stiffness: 220}});
  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 14,
        fontSize: 32,
        fontWeight: 800,
        padding: '9px 0',
        opacity: Math.min(1, s * 1.6),
        transform: `translateX(${(1 - s) * 30}px)`,
      }}
    >
      {ok ? <Check /> : <Cross />}
      <span style={{textDecoration: ok ? 'none' : 'line-through', textDecorationThickness: 3}}>{text}</span>
    </div>
  );
};

/** Batasan sertifikat: bukan cek keaslian fisik; yang dicek duplikasi unggahan digital dan perkiraan buatan AI. */
export const DisclaimerCard: React.FC<{at: number[]}> = ({at}) => (
  <Card label="YANG DICEK SISTEM" bg="#fde4df">
    <IconRow ok={false} text="Keaslian fisik lukisan" at={at[0]} />
    <IconRow ok text="Duplikat unggahan digital" at={at[1]} />
    <IconRow ok text="Perkiraan buatan AI" at={at[2]} />
  </Card>
);

/** Hasil pengecekan otomatis saat unggah: duplikat dan perkiraan buatan AI (ilustrasi hasil lolos). */
export const CekOtomatisCard: React.FC = () => (
  <Card label="CEK OTOMATIS SAAT UNGGAH" bg="#e4f1d7">
    <Row k="Duplikat" v="Tidak ada" tone="green" at={8} />
    <Row k="Dibuat AI?" v="Kemungkinan kecil" tone="green" at={26} />
  </Card>
);

/** Event, komunitas, lelang dalam satu aplikasi. */
export const FeatureCard: React.FC<{at: number[]}> = ({at}) => (
  <Card label="DI SATU APLIKASI" bg="#cfe9f7">
    <Row k="Event" v={<Check />} at={at[0]} />
    <Row k="Komunitas" v={<Check />} at={at[1]} />
    <Row k="Lelang" v={<Check />} at={at[2]} />
  </Card>
);

/** Kamar kosong: "cukup nggak?" */
export const RoomCard: React.FC = () => {
  const f = useCurrentFrame();
  const bob = Math.sin(f / 6) * 4;
  return (
    <Card label="KAMAR KAMU">
      <div
        style={{
          height: 190,
          background: '#e9dcc3',
          border: BORDER,
          borderRadius: 12,
          position: 'relative',
          overflow: 'hidden',
        }}
      >
        <div
          style={{
            position: 'absolute',
            left: '50%',
            top: '50%',
            width: 170,
            height: 120,
            transform: `translate(-50%, calc(-50% + ${bob}px))`,
            border: `4px dashed ${C.ink}`,
            borderRadius: 6,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: 80,
            fontWeight: 900,
          }}
        >
          ?
        </div>
        <div style={{position: 'absolute', left: 0, right: 0, bottom: 0, height: 26, background: '#b89a6a'}} />
      </div>
      <div style={{fontSize: 34, fontWeight: 900, marginTop: 12}}>Cukup nggak, ya?</div>
    </Card>
  );
};

/** Visual Search: bidik lukisan dengan bingkai pemindai. */
export const SearchCard: React.FC = () => {
  const f = useCurrentFrame();
  const scan = ((f % 46) / 46) * 100;
  const corner = (pos: React.CSSProperties): React.CSSProperties => ({
    position: 'absolute',
    width: 38,
    height: 38,
    ...pos,
  });
  const w = 6;
  return (
    <Card label="VISUAL SEARCH">
      <div style={{position: 'relative', height: 250, borderRadius: 12, overflow: 'hidden', background: '#e9dcc3', border: BORDER}}>
        <div style={{...thumb(3, 210, 190, {position: 'absolute', left: '50%', top: '50%', transform: 'translate(-50%,-50%)'})}} />
        <div style={corner({left: 18, top: 18, borderLeft: `${w}px solid ${C.ink}`, borderTop: `${w}px solid ${C.ink}`})} />
        <div style={corner({right: 18, top: 18, borderRight: `${w}px solid ${C.ink}`, borderTop: `${w}px solid ${C.ink}`})} />
        <div style={corner({left: 18, bottom: 18, borderLeft: `${w}px solid ${C.ink}`, borderBottom: `${w}px solid ${C.ink}`})} />
        <div style={corner({right: 18, bottom: 18, borderRight: `${w}px solid ${C.ink}`, borderBottom: `${w}px solid ${C.ink}`})} />
        <div
          style={{
            position: 'absolute',
            left: 18,
            right: 18,
            top: `${scan}%`,
            height: 4,
            background: C.green,
            boxShadow: `0 0 14px ${C.green}`,
          }}
        />
      </div>
      <div style={{fontSize: 30, fontWeight: 900, marginTop: 12}}>Foto lukisan yang kamu suka</div>
    </Card>
  );
};

/** Hasil Visual Search: karya serupa di katalog (tanpa angka palsu). */
export const ResultCard: React.FC = () => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  const seeds = [3, 0, 2];
  return (
    <Card label="KARYA SERUPA DI KATALOG" bg="#d9f0d0">
      <div style={{display: 'flex', gap: 14, justifyContent: 'center'}}>
        {seeds.map((sd, i) => {
          const s = spring({frame: f - (8 + i * 6), fps, config: {damping: 12, stiffness: 200}});
          return (
            <div key={i} style={{textAlign: 'center', transform: `scale(${Math.max(0, s)})`}}>
              <div style={thumb(sd, 160, 200, i === 0 ? {border: `6px solid ${C.green}`} : {})} />
              {i === 0 && (
                <div style={{fontWeight: 900, fontSize: 20, letterSpacing: 2, marginTop: 6, color: '#2f7a2b'}}>
                  PALING MIRIP
                </div>
              )}
            </div>
          );
        })}
      </div>
    </Card>
  );
};

/** AR: lukisan di dinding dengan label ukuran (ilustrasi). */
export const ArCard: React.FC = () => {
  const f = useCurrentFrame();
  const pulse = 1 + Math.sin(f / 7) * 0.02;
  return (
    <Card label="AR · ILUSTRASI">
      <div
        style={{
          position: 'relative',
          height: 260,
          background: '#e9dcc3',
          border: BORDER,
          borderRadius: 12,
          overflow: 'hidden',
        }}
      >
        <div style={{position: 'absolute', left: 0, right: 0, bottom: 0, height: 34, background: '#b89a6a'}} />
        <div
          style={{
            ...thumb(1, 210, 150, {position: 'absolute', left: '50%', top: 38, transform: `translateX(-50%) scale(${pulse})`}),
            border: `8px solid #3b2a1c`,
          }}
        />
        {/* garis ukuran */}
        <div style={{position: 'absolute', left: '50%', top: 212, width: 230, height: 0, borderTop: `3px dashed ${C.ink}`, transform: 'translateX(-50%)'}} />
        <div
          style={{
            position: 'absolute',
            left: '50%',
            top: 196,
            transform: 'translateX(-50%)',
            background: C.yellow,
            border: BORDER,
            borderRadius: 8,
            padding: '0 12px',
            fontFamily: FONT,
            fontWeight: 900,
            fontSize: 26,
          }}
        >
          80 × 60 cm
        </div>
      </div>
    </Card>
  );
};

/** Penutup bercanda: hitungan hari pertama. */
export const CounterCard: React.FC<{at: number[]}> = ({at}) => (
  <Card label="GALERIA · HARI 1">
    <Row k="Karya" v="1" tone="green" at={at[0]} />
    <Row k="Kolektor" v="nunggu kamu" tone="red" at={at[1]} />
  </Card>
);

/** Peralihan seniman -> kolektor: apa yang masih kurang. */
export const BridgeCard: React.FC<{at: number[]}> = ({at}) => (
  <Card label="HARI 1 · SUDAH ADA" bg="#f8e7b9" tilt={-1.5}>
    <Row k="Karya" v={<Check />} at={at[0]} />
    <Row k="Galeri" v={<Check />} at={at[1]} />
    <Row k="Pembeli" v="???" tone="red" at={at[2]} />
  </Card>
);

/** Label perkenalan kolektor. */
export const NameTag: React.FC = () => (
  <Card label="KENALIN" width={470} tilt={3} bg="#cfe9f7">
    <div style={{fontSize: 60, fontWeight: 900, letterSpacing: 2, textAlign: 'center'}}>KOLEKTOR</div>
    <div style={{fontSize: 24, fontWeight: 800, textAlign: 'center', color: '#4a5560'}}>pencari karya</div>
  </Card>
);

/** Masalah kolektor (cermin kartu kebutuhan seniman). */
export const ProblemCard: React.FC<{at: number[]}> = ({at}) => (
  <Card label="MASALAH KOLEKTOR" tilt={-1.2}>
    <Row k="Karya yang dicari" v="???" tone="red" at={at[0]} />
    <Row k="Cocok di ruangan" v="???" tone="red" at={at[1]} />
  </Card>
);

export {Chip};
