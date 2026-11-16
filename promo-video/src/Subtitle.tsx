import React from 'react';
import {spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {C, FONT} from './theme';
import type {Line} from './lines';

/** Subtitle kata-per-kata: tiap kata muncul (pop) tepat saat diucapkan, kata kunci kuning. */
export const Subtitle: React.FC<{lines: Line[]; bottom?: number}> = ({lines, bottom = 250}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const line = lines.find((l) => frame >= l.from && frame < l.to);
  if (!line) return null;

  return (
    <div
      style={{
        position: 'absolute',
        left: 40,
        right: 40,
        bottom,
        textAlign: 'center',
      }}
    >
      {line.words
        .filter((w) => frame >= w.at)
        .map((w, i) => {
          const p = spring({frame: frame - w.at, fps, config: {damping: 14, stiffness: 220}});
          return (
            <span
              key={i}
              style={{
                display: 'inline-block',
                margin: '0 8px',
                transform: `scale(${0.7 + 0.3 * p}) translateY(${(1 - p) * 14}px)`,
                opacity: Math.min(1, p * 1.4),
                color: w.key ? C.yellow : '#ffffff',
                WebkitTextStroke: '12px #14161c',
                paintOrder: 'stroke fill',
                fontFamily: FONT,
                fontWeight: 900,
                fontSize: 68,
                lineHeight: 1.15,
              }}
            >
              {w.t}
            </span>
          );
        })}
    </div>
  );
};
