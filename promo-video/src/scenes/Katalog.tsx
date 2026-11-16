import React from 'react';
import {AbsoluteFill, useVideoConfig} from 'remotion';
import {ThreeCanvas} from '@remotion/three';
import {useThree} from '@react-three/fiber';
import {KChar, Model} from '../three/Model';

const Cam: React.FC = () => {
  const camera = useThree((s) => s.camera);
  camera.position.set(0, 4.5, 20);
  camera.lookAt(0, 1.6, -2);
  return null;
};

type Item = {kit: 'plat' | 'sub' | 'town'; name: string};

const ITEMS: Item[] = [
  ...'abcdefghijklmnopqrstu'.split('').slice(0, 21).map((c) => ({kit: 'sub' as const, name: `building-type-${c}`})),
  {kit: 'sub', name: 'tree-large'},
  {kit: 'sub', name: 'tree-small'},
  {kit: 'sub', name: 'planter'},
  {kit: 'sub', name: 'path-long'},
  {kit: 'plat', name: 'tree'},
  {kit: 'plat', name: 'tree-pine'},
  {kit: 'plat', name: 'flowers'},
  {kit: 'plat', name: 'grass'},
  {kit: 'plat', name: 'rocks'},
  {kit: 'plat', name: 'mushrooms'},
  {kit: 'plat', name: 'fence-low-straight'},
  {kit: 'plat', name: 'sign'},
  {kit: 'town', name: 'fountain-round'},
  {kit: 'town', name: 'lantern'},
  {kit: 'town', name: 'stall'},
  {kit: 'town', name: 'stall-red'},
  {kit: 'town', name: 'cart'},
  {kit: 'town', name: 'banner-red'},
  {kit: 'town', name: 'tree'},
  {kit: 'town', name: 'windmill'},
];

// pratinjau katalog model: grid 8 kolom, nama berkas ditulis di layar
const NAMES = ['male-a','male-b','male-c','male-d','male-e','male-f','female-a','female-b','female-c','female-d','female-e','female-f'];
export const Katalog: React.FC = () => {
  const {width, height} = useVideoConfig();
  return (
    <AbsoluteFill style={{background: '#cfe0e8'}}>
      <ThreeCanvas width={width} height={height} camera={{fov: 40, position: [0, 4.5, 20]}}>
        <Cam />
        <ambientLight intensity={1.6} />
        <directionalLight position={[5, 10, 8]} intensity={1.6} />
        {NAMES.map((n, i) => (
          <KChar key={n} skin={n} kit="mini" height={3} position={[(i % 6) * 3.6 - 9, 0, i < 6 ? 0 : -6]} />
        ))}
      </ThreeCanvas>
      <div style={{position: 'absolute', inset: 0, fontFamily: 'sans-serif', fontSize: 16, fontWeight: 800}}>
        {NAMES.map((n, i) => (
          <div key={n} style={{position: 'absolute', left: width / 2 + ((i % 6) * 3.6 - 9) * 42 - 40, top: i < 6 ? 560 : 420, width: 80, textAlign: 'center', background: 'rgba(255,255,255,.75)'}}>{n}</div>
        ))}
      </div>
    </AbsoluteFill>
  );
};
