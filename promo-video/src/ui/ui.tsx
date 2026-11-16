import React from 'react';
import {interpolate, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {C, FONT} from '../theme';

export const BORDER = `4px solid ${C.ink}`;

/** Kartu info bergaya neobrutalist (krem, bingkai tebal, bayangan keras). Animasi masuk + keluar otomatis. */
export const Card: React.FC<{
  label?: string;
  children?: React.ReactNode;
  top?: number;
  width?: number;
  bg?: string;
  tilt?: number;
}> = ({label, children, top = 196, width = 600, bg = C.cream, tilt = 0}) => {
  const f = useCurrentFrame();
  const {fps, durationInFrames} = useVideoConfig();
  const s = spring({frame: f, fps, config: {damping: 12, stiffness: 170}});
  const out = interpolate(f, [durationInFrames - 8, durationInFrames], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  return (
    <div
      style={{
        position: 'absolute',
        left: '50%',
        top,
        width,
        transform: `translateX(-50%) translateY(${(1 - s) * -40}px) scale(${0.85 + 0.15 * s}) rotate(${tilt}deg)`,
        opacity: Math.min(1, s * 1.5) * out,
        background: bg,
        border: BORDER,
        borderRadius: 22,
        boxShadow: `0 8px 0 ${C.ink}`,
        padding: '18px 24px 20px',
        fontFamily: FONT,
        color: C.ink,
      }}
    >
      {label && (
        <div style={{fontSize: 20, fontWeight: 900, letterSpacing: 3, color: C.red, marginBottom: 10}}>
          {label}
        </div>
      )}
      {children}
    </div>
  );
};

const TONES = {
  red: {bg: '#f8c9c4', fg: '#c2342b'},
  green: {bg: '#cdebc3', fg: '#2f7a2b'},
  none: {bg: 'transparent', fg: C.ink},
};

/** Satu baris "kunci : nilai" yang muncul pada frame lokal `at`. */
export const Row: React.FC<{
  k: string;
  v?: React.ReactNode;
  tone?: 'red' | 'green' | 'none';
  at?: number;
}> = ({k, v, tone = 'none', at = 0}) => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  if (f < at) return null;
  const s = spring({frame: f - at, fps, config: {damping: 14, stiffness: 220}});
  const t = TONES[tone];
  return (
    <div
      style={{
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        fontSize: 34,
        fontWeight: 800,
        padding: '9px 0',
        borderBottom: '2px solid rgba(20,22,28,.12)',
        opacity: Math.min(1, s * 1.6),
        transform: `translateX(${(1 - s) * 30}px)`,
      }}
    >
      <span>{k}</span>
      {v !== undefined && (
        <span
          style={{
            background: t.bg,
            color: t.fg,
            padding: tone === 'none' ? 0 : '2px 16px',
            borderRadius: 10,
            fontWeight: 900,
          }}
        >
          {v}
        </span>
      )}
    </div>
  );
};

export const Check: React.FC<{size?: number; color?: string}> = ({size = 30, color = '#2f7a2b'}) => (
  <svg width={size} height={size} viewBox="0 0 24 24" style={{display: 'block'}}>
    <path d="M4 12.5l5 5L20 6.5" fill="none" stroke={color} strokeWidth={4} strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

export const Cross: React.FC<{size?: number; color?: string}> = ({size = 30, color = '#c2342b'}) => (
  <svg width={size} height={size} viewBox="0 0 24 24" style={{display: 'block'}}>
    <path d="M5 5l14 14M19 5L5 19" fill="none" stroke={color} strokeWidth={4} strokeLinecap="round" />
  </svg>
);

export const Chip: React.FC<{children: React.ReactNode; bg?: string; color?: string}> = ({
  children,
  bg = C.cream,
  color = C.ink,
}) => (
  <span
    style={{
      display: 'inline-block',
      background: bg,
      color,
      border: BORDER,
      borderRadius: 10,
      padding: '2px 14px',
      fontFamily: FONT,
      fontWeight: 900,
      fontSize: 24,
      letterSpacing: 2,
      margin: '0 6px',
    }}
  >
    {children}
  </span>
);
