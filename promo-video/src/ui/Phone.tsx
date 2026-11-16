import React from 'react';
import {interpolate, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {C, FONT} from '../theme';
import {paintUrl} from '../art';

const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;
const art = (seed: number, w: number, h: number, extra: React.CSSProperties = {}): React.CSSProperties => ({
  width: w,
  height: h,
  borderRadius: 8,
  background: `url(${paintUrl(seed, w * 2, h * 2)}) center/cover`,
  ...extra,
});

/** Layar 1: kamera membidik lukisan, lalu jepret (kilatan). */
const ScreenFoto: React.FC = () => {
  const f = useCurrentFrame();
  const flash = interpolate(f, [34, 38, 52], [0, 0.9, 0], clamp);
  const press = interpolate(f, [32, 36, 42], [1, 0.82, 1], clamp);
  const b = (pos: React.CSSProperties): React.CSSProperties => ({
    position: 'absolute',
    width: 36,
    height: 36,
    ...pos,
  });
  const w = 5;
  return (
    <div style={{position: 'absolute', inset: 0, background: '#e9dcc3'}}>
      <div style={{position: 'absolute', left: 0, right: 0, bottom: 0, height: 120, background: '#b89a6a'}} />
      <div style={art(3, 200, 250, {position: 'absolute', left: '50%', top: 150, transform: 'translateX(-50%)', border: '8px solid #3b2a1c'})} />
      <div style={b({left: 40, top: 110, borderLeft: `${w}px solid ${C.ink}`, borderTop: `${w}px solid ${C.ink}`})} />
      <div style={b({right: 40, top: 110, borderRight: `${w}px solid ${C.ink}`, borderTop: `${w}px solid ${C.ink}`})} />
      <div style={b({left: 40, bottom: 190, borderLeft: `${w}px solid ${C.ink}`, borderBottom: `${w}px solid ${C.ink}`})} />
      <div style={b({right: 40, bottom: 190, borderRight: `${w}px solid ${C.ink}`, borderBottom: `${w}px solid ${C.ink}`})} />
      <div
        style={{
          position: 'absolute',
          left: '50%',
          bottom: 40,
          width: 84,
          height: 84,
          marginLeft: -42,
          borderRadius: 42,
          border: `7px solid ${C.ink}`,
          background: '#fff',
          transform: `scale(${press})`,
        }}
      />
      <div style={{position: 'absolute', inset: 0, background: '#fff', opacity: flash}} />
    </div>
  );
};

/** Layar 2: hasil karya serupa (tanpa angka). */
const ScreenHasil: React.FC = () => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  const seeds = [3, 0, 2, 4];
  return (
    <div style={{position: 'absolute', inset: 0, background: C.cream, fontFamily: FONT, color: C.ink, padding: '70px 22px 0'}}>
      <div style={{fontWeight: 900, fontSize: 28, marginBottom: 4}}>Karya serupa</div>
      <div style={{fontSize: 18, fontWeight: 800, color: '#6b6757', marginBottom: 18}}>di katalog GALERIA</div>
      <div style={{display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14}}>
        {seeds.map((sd, i) => {
          const s = spring({frame: f - i * 6, fps, config: {damping: 12, stiffness: 190}});
          return (
            <div key={i} style={{transform: `scale(${Math.max(0, s)})`}}>
              <div style={art(sd, 128, 150, i === 0 ? {border: `5px solid ${C.green}`, width: 128} : {border: `3px solid ${C.ink}`, width: 128})} />
              {i === 0 && (
                <div style={{marginTop: 4, fontWeight: 900, fontSize: 16, letterSpacing: 1.5, color: '#2f7a2b'}}>PALING MIRIP</div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
};

/** Layar 3-4: AR, lukisan di dinding; `ukuran` memunculkan garis dan label ukuran. */
const ScreenAr: React.FC<{ukuran: boolean}> = ({ukuran}) => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  const pop = spring({frame: f - 6, fps, config: {damping: 9, stiffness: 150}});
  const line = interpolate(f, [4, 22], [0, 1], clamp);
  return (
    <div style={{position: 'absolute', inset: 0, background: '#e4d5ba', overflow: 'hidden'}}>
      <div style={{position: 'absolute', left: 0, right: 0, bottom: 0, height: 150, background: '#b08f5e'}} />
      <div style={{position: 'absolute', left: 0, right: 0, bottom: 150, height: 6, background: '#8a6d42'}} />
      <div
        style={{
          ...art(1, 220, 160, {position: 'absolute', left: '50%', top: 190, border: '9px solid #3b2a1c'}),
          transform: `translateX(-50%) scale(${Math.max(0, pop)})`,
          boxShadow: '0 12px 22px rgba(0,0,0,.25)',
        }}
      />
      {ukuran && (
        <>
          <div style={{position: 'absolute', left: '50%', top: 380, width: 238 * line, marginLeft: -119 * line, borderTop: `4px dashed ${C.ink}`}} />
          <div style={{position: 'absolute', left: '50%', top: 188, marginLeft: 150, height: 178 * line, borderLeft: `4px dashed ${C.ink}`}} />
          <div
            style={{
              position: 'absolute',
              left: '50%',
              top: 392,
              transform: 'translateX(-50%)',
              background: C.yellow,
              border: `4px solid ${C.ink}`,
              borderRadius: 8,
              padding: '0 12px',
              fontFamily: FONT,
              fontWeight: 900,
              fontSize: 26,
              whiteSpace: 'nowrap',
              opacity: line,
            }}
          >
            80 × 60 cm
          </div>
        </>
      )}
      <div
        style={{
          position: 'absolute',
          left: 16,
          top: 64,
          background: C.ink,
          color: C.cream,
          fontFamily: FONT,
          fontWeight: 900,
          fontSize: 16,
          letterSpacing: 2,
          padding: '3px 10px',
          borderRadius: 6,
        }}
      >
        AR · ILUSTRASI
      </div>
    </div>
  );
};

/**
 * Ponsel yang naik dari bawah. `cuts` = frame lokal pergantian layar: [hasil, ar, ukuran].
 */
export const Phone: React.FC<{cuts: [number, number, number]}> = ({cuts}) => {
  const f = useCurrentFrame();
  const {fps, durationInFrames} = useVideoConfig();
  const s = spring({frame: f, fps, config: {damping: 14, stiffness: 110}});
  const out = interpolate(f, [durationInFrames - 10, durationInFrames], [1, 0], clamp);
  const tilt = (1 - s) * -8 + Math.sin(f / 40) * 0.8;

  let screen: React.ReactNode;
  let key = 0;
  if (f < cuts[0]) screen = <ScreenFoto />;
  else if (f < cuts[1]) {
    key = 1;
    screen = <ScreenHasil />;
  } else if (f < cuts[2]) {
    key = 2;
    screen = <ScreenAr ukuran={false} />;
  } else {
    key = 3;
    screen = <ScreenAr ukuran />;
  }
  const cutStart = [0, cuts[0], cuts[1], cuts[2]][key];
  const local = f - cutStart;

  return (
    <div
      style={{
        position: 'absolute',
        left: '50%',
        top: 150,
        width: 340,
        height: 690,
        marginLeft: -170,
        opacity: out,
        transform: `translateY(${(1 - s) * 900}px) rotate(${tilt}deg)`,
        background: '#0e0f13',
        border: `10px solid ${C.ink}`,
        borderRadius: 46,
        boxShadow: `0 14px 0 rgba(20,22,28,.45)`,
        overflow: 'hidden',
      }}
    >
      {/* sub-sequence manual: frame lokal layar = local */}
      <LocalFrame frame={local}>{screen}</LocalFrame>
      <div
        style={{
          position: 'absolute',
          left: '50%',
          top: 10,
          width: 90,
          height: 22,
          marginLeft: -45,
          borderRadius: 12,
          background: '#0e0f13',
        }}
      />
    </div>
  );
};

// menyuntikkan frame lokal ke anak-anak yang memakai useCurrentFrame lewat Sequence
import {Sequence} from 'remotion';
const LocalFrame: React.FC<{frame: number; children: React.ReactNode}> = ({frame, children}) => {
  const f = useCurrentFrame();
  return (
    <Sequence from={f - frame} layout="none">
      {children}
    </Sequence>
  );
};
