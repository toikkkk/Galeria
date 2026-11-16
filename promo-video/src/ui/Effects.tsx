import React from 'react';
import {AbsoluteFill, interpolate, random, useCurrentFrame, useVideoConfig} from 'remotion';
import {C, FONT} from '../theme';

const COLORS = [C.yellow, '#ff7a59', '#5ec2a5', '#8e7cf0', '#ffffff', '#f08fb0'];

/** Konfeti jatuh dari atas (2D). Dipakai di dalam <Sequence> agar frame lokal mulai dari 0. */
export const Confetti: React.FC<{count?: number; seed?: string}> = ({count = 38, seed = 'c'}) => {
  const f = useCurrentFrame();
  const {durationInFrames} = useVideoConfig();
  const fade = interpolate(f, [durationInFrames - 14, durationInFrames], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  return (
    <AbsoluteFill style={{pointerEvents: 'none', opacity: fade, overflow: 'hidden'}}>
      {Array.from({length: count}, (_, i) => {
        const x0 = random(`${seed}x${i}`) * 720;
        const drift = (random(`${seed}d${i}`) - 0.5) * 220;
        const delay = random(`${seed}t${i}`) * 10;
        const speed = 11 + random(`${seed}s${i}`) * 9;
        const ff = Math.max(0, f - delay);
        const y = -40 + ff * speed + (ff * ff) * 0.18;
        const x = x0 + drift * (ff / 40) + Math.sin(ff / 5 + i) * 18;
        const size = 14 + random(`${seed}z${i}`) * 14;
        return (
          <div
            key={i}
            style={{
              position: 'absolute',
              left: x,
              top: y,
              width: size,
              height: size * 0.55,
              background: COLORS[i % COLORS.length],
              borderRadius: 3,
              transform: `rotate(${ff * (6 + (i % 5) * 3)}deg)`,
            }}
          />
        );
      })}
    </AbsoluteFill>
  );
};

/** Sapuan transisi (krem + ink) yang melintas layar dengan label opsional. */
export const Wipe: React.FC<{label?: string}> = ({label}) => {
  const f = useCurrentFrame();
  const {durationInFrames} = useVideoConfig();
  const p = interpolate(f, [0, durationInFrames], [0, 1], {extrapolateRight: 'clamp'});
  const x = interpolate(p, [0, 1], [-130, 130]);
  return (
    <AbsoluteFill style={{pointerEvents: 'none', overflow: 'hidden'}}>
      <div
        style={{
          position: 'absolute',
          top: '-10%',
          bottom: '-10%',
          width: '120%',
          left: `${x}%`,
          transform: 'skewX(-12deg)',
          background: C.ink,
        }}
      />
      <div
        style={{
          position: 'absolute',
          top: '-10%',
          bottom: '-10%',
          width: '100%',
          left: `${x - 12}%`,
          transform: 'skewX(-12deg)',
          background: C.cream,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        {label && (
          <div
            style={{
              transform: 'skewX(12deg)',
              fontFamily: FONT,
              fontWeight: 900,
              fontSize: 96,
              color: C.ink,
              letterSpacing: 4,
            }}
          >
            {label}
          </div>
        )}
      </div>
    </AbsoluteFill>
  );
};
