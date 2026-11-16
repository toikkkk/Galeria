import React from 'react';
import {AbsoluteFill, Easing, interpolate, useCurrentFrame, useVideoConfig} from 'remotion';
import {ThreeCanvas} from '@remotion/three';
import {useThree} from '@react-three/fiber';
import {World, Sign} from '../three/World';
import {Character} from '../three/Character';
import {Subtitle} from '../Subtitle';
import {Badge} from '../Badge';
import {Title} from '../Title';
import {makeLine} from '../lines';

type V3 = [number, number, number];

const Rig: React.FC<{pos: V3; look: V3}> = ({pos, look}) => {
  const camera = useThree((s) => s.camera);
  camera.position.set(...pos);
  camera.lookAt(...look);
  return null;
};

const lerp3 = (a: V3, b: V3, k: number): V3 => [
  a[0] + (b[0] - a[0]) * k,
  a[1] + (b[1] - a[1]) * k,
  a[2] + (b[2] - a[2]) * k,
];

// Adegan uji: judul -> bidikan jauh -> kamera mendekat ke wajah, subtitle kata per kata.
const LINES = [
  makeLine('Hari pertama.', 40, 78, 8),
  makeLine('Aku **seniman.**', 84, 150, 9),
];

export const TestScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {width, height} = useVideoConfig();

  const k = interpolate(frame, [66, 110], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.inOut(Easing.cubic),
  });

  const pos = lerp3([0, 2.1, 12], [0.2, 2.6, 3.8], k);
  const look = lerp3([0, 1.5, 0], [0, 2.5, 0], k);
  const talking = (frame >= 40 && frame < 78) || (frame >= 84 && frame < 150);

  return (
    <AbsoluteFill style={{background: '#c5d8e3'}}>
      <ThreeCanvas width={width} height={height} shadows camera={{fov: 40, position: pos}}>
        <Rig pos={pos} look={look} />
        <World />
        <Sign label="KARYA" value="1" position={[1.7, 0, 0.5]} rotY={-0.4} />
        <Character talking={talking} mood={frame >= 120 ? 'senang' : 'netral'} />
      </ThreeCanvas>

      {/* vignette halus untuk kesan sinematik */}
      <AbsoluteFill
        style={{
          pointerEvents: 'none',
          background:
            'radial-gradient(ellipse at center, rgba(0,0,0,0) 55%, rgba(20,22,28,0.30) 100%)',
        }}
      />

      <Title badge="DAY 1" text="BIKIN GALERI DARI NOL" until={40} />
      <Badge label="DAY 1" delay={36} />
      <Subtitle lines={LINES} />
    </AbsoluteFill>
  );
};
