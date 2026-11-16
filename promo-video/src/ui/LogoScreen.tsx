import React from 'react';
import {AbsoluteFill, Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import {C, FONT} from '../theme';
import {paintUrl} from '../art';
import {BORDER, Chip} from './ui';

const TILES = [
  {seed: 0, from: [-380, -520], to: [-232, -330], rot: -9},
  {seed: 1, from: [380, -560], to: [232, -300], rot: 8},
  {seed: 3, from: [-380, 560], to: [-224, 330], rot: 7},
  {seed: 4, from: [380, 540], to: [236, 306], rot: -8},
];

/**
 * Layar logo GALERIA. `final` = layar penutup (tetap tampil, ada chip + catatan kaki);
 * selain itu = perkenalan logo (menghilang di akhir sequence).
 */
export const LogoScreen: React.FC<{final?: boolean}> = ({final = false}) => {
  const f = useCurrentFrame();
  const {fps, durationInFrames} = useVideoConfig();

  const fadeIn = interpolate(f, [0, 8], [0, 1], {extrapolateRight: 'clamp'});
  const fadeOut = final ? 1 : interpolate(f, [durationInFrames - 14, durationInFrames], [1, 0], {extrapolateLeft: 'clamp'});
  const mark = spring({frame: f - 10, fps, config: {damping: 9, stiffness: 140}});
  const word = spring({frame: f - 16, fps, config: {damping: 13, stiffness: 160}});
  const sub = spring({frame: f - 26, fps, config: {damping: 14, stiffness: 160}});
  const chips = spring({frame: f - 34, fps, config: {damping: 14, stiffness: 160}});

  return (
    <AbsoluteFill style={{opacity: fadeIn * fadeOut, background: '#101218', fontFamily: FONT}}>
      {TILES.map((t, i) => {
        const s = spring({frame: f - i * 4, fps, config: {damping: 13, stiffness: 120}});
        const x = t.from[0] + (t.to[0] - t.from[0]) * s;
        const y = t.from[1] + (t.to[1] - t.from[1]) * s;
        return (
          <div
            key={i}
            style={{
              position: 'absolute',
              left: '50%',
              top: '50%',
              width: 210,
              height: 150,
              marginLeft: -105,
              marginTop: -75,
              transform: `translate(${x}px, ${y}px) rotate(${t.rot * s}deg)`,
              border: `5px solid ${C.cream}`,
              borderRadius: 10,
              background: `url(${paintUrl(t.seed, 420, 300)}) center/cover`,
              boxShadow: '0 10px 24px rgba(0,0,0,.5)',
            }}
          />
        );
      })}

      <div style={{position: 'absolute', left: 0, right: 0, top: '50%', transform: 'translateY(-58%)', textAlign: 'center'}}>
        <div
          style={{
            display: 'inline-flex',
            alignItems: 'center',
            justifyContent: 'center',
            width: 210,
            height: 210,
            borderRadius: 46,
            background: C.cream,
            transform: `scale(${Math.max(0, mark)}) rotate(${(1 - Math.min(1, mark)) * -14}deg)`,
            boxShadow: '0 10px 0 rgba(0,0,0,.45)',
          }}
        >
          {/* logo asli GALERIA (mobile/assets/images/logo/galeria_logo.png) */}
          <Img src={staticFile('galeria_logo.png')} style={{width: 186, height: 186, objectFit: 'contain'}} />
        </div>
        <div
          style={{
            color: C.cream,
            fontSize: 112,
            fontWeight: 900,
            letterSpacing: 6,
            marginTop: 18,
            opacity: Math.min(1, word * 1.4),
            transform: `translateY(${(1 - word) * 24}px)`,
          }}
        >
          GALERIA
        </div>
        {final && (
          <>
            <div
              style={{
                color: 'rgba(251,243,228,.75)',
                fontSize: 30,
                fontWeight: 800,
                letterSpacing: 3,
                opacity: Math.min(1, sub * 1.4),
              }}
            >
              Temukan, lihat, miliki.
            </div>
            <div style={{marginTop: 26, opacity: Math.min(1, chips * 1.4), transform: `translateY(${(1 - chips) * 16}px)`}}>
              <Chip>ANDROID</Chip>
              <Chip>SENIMAN & KOLEKTOR</Chip>
            </div>
          </>
        )}
      </div>

      {final && (
        <div
          style={{
            position: 'absolute',
            left: 44,
            right: 44,
            bottom: 58,
            textAlign: 'center',
            color: 'rgba(251,243,228,.62)',
            fontSize: 20,
            fontWeight: 800,
            lineHeight: 1.3,
            opacity: Math.min(1, chips * 1.4),
          }}
        >
          Sertifikat digital keaslian memeriksa duplikasi unggahan digital dan memperkirakan kemungkinan karya buatan AI; bukan keaslian fisik karya.
          Hasil deteksi AI berupa perkiraan, bukan kepastian. Tampilan di video adalah ilustrasi.
        </div>
      )}
    </AbsoluteFill>
  );
};

export {BORDER};
