import React from 'react';
import {interpolate, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {C, FONT} from './theme';

/** Kartu judul besar di awal ("DAY 1 / BIKIN GALERI DARI NOL"), lalu menghilang. */
export const Title: React.FC<{badge: string; text: string; until?: number}> = ({
  badge,
  text,
  until = 40,
}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const opacity = interpolate(frame, [0, 6, until - 10, until], [0, 1, 1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  if (frame >= until) return null;
  const s = spring({frame, fps, config: {damping: 11, stiffness: 160}});
  const stroke = {
    WebkitTextStroke: '14px #14161c',
    paintOrder: 'stroke fill',
  } as React.CSSProperties;

  return (
    <div
      style={{
        position: 'absolute',
        left: 0,
        right: 0,
        top: 70,
        textAlign: 'center',
        opacity,
        transform: `scale(${0.8 + 0.2 * s})`,
        fontFamily: FONT,
        fontWeight: 900,
      }}
    >
      <div
        style={{
          display: 'inline-block',
          background: C.ink,
          color: C.yellow,
          fontSize: 110,
          padding: '4px 34px',
          borderRadius: 22,
          boxShadow: '0 8px 0 rgba(0,0,0,.35)',
        }}
      >
        {badge}
      </div>
      <div style={{color: '#fff', fontSize: 76, lineHeight: 1.05, marginTop: 22, padding: '0 40px', ...stroke}}>
        {text}
      </div>
    </div>
  );
};
