import React from 'react';
import {spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {C, FONT} from './theme';

/** Lencana kecil di pojok kiri atas ("DAY 1"), muncul setelah `delay` frame lalu tetap tampil. */
export const Badge: React.FC<{label: string; delay?: number}> = ({label, delay = 0}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  if (frame < delay) return null;
  const s = spring({frame: frame - delay, fps, config: {damping: 12}});
  return (
    <div
      style={{
        position: 'absolute',
        left: 36,
        top: 96,
        transform: `scale(${s})`,
        transformOrigin: 'left top',
        background: C.ink,
        color: C.yellow,
        fontFamily: FONT,
        fontWeight: 900,
        fontSize: 44,
        padding: '6px 20px',
        borderRadius: 14,
        boxShadow: '0 4px 0 rgba(0,0,0,.35)',
      }}
    >
      {label}
    </div>
  );
};
