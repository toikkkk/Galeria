import React, {useLayoutEffect, useMemo, useRef} from 'react';
import * as THREE from 'three';
import {spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {paintTexture} from '../art';

/** Gedung galeri low-poly yang "tumbuh" dari tanah saat frame `appearAt`. */
export const Gallery: React.FC<{appearAt: number; position?: [number, number, number]}> = ({
  appearAt,
  position = [0, 0, -6],
}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const ref = useRef<THREE.Group>(null);

  useLayoutEffect(() => {
    ref.current?.traverse((o) => {
      if ((o as THREE.Mesh).isMesh) {
        o.castShadow = true;
        o.receiveShadow = true;
      }
    });
  });

  const tex = useMemo(() => [1, 3, 4].map((s) => paintTexture(s)), []);
  const signTex = useMemo(() => {
    const c = document.createElement('canvas');
    c.width = 512;
    c.height = 128;
    const g = c.getContext('2d')!;
    g.fillStyle = '#14161c';
    g.fillRect(0, 0, 512, 128);
    g.fillStyle = '#fbf3e4';
    g.textAlign = 'center';
    g.textBaseline = 'middle';
    g.font = '900 84px sans-serif';
    g.fillText('GALERIA', 256, 70);
    const t = new THREE.CanvasTexture(c);
    t.colorSpace = THREE.SRGBColorSpace;
    return t;
  }, []);

  if (frame < appearAt) return null;
  const s = Math.max(
    0.001,
    spring({frame: frame - appearAt, fps, config: {damping: 9, stiffness: 80, mass: 0.9}}),
  );

  const frameBox = (x: number, y: number, w: number, h: number, i: number) => (
    <group position={[x, y, 1.52]}>
      <mesh position={[0, 0, -0.02]}>
        <boxGeometry args={[w + 0.18, h + 0.18, 0.06]} />
        <meshStandardMaterial color="#3b2a1c" roughness={1} />
      </mesh>
      <mesh position={[0, 0, 0.02]}>
        <planeGeometry args={[w, h]} />
        <meshStandardMaterial map={tex[i]} roughness={1} />
      </mesh>
    </group>
  );

  return (
    <group position={position} scale={[1, s, 1]}>
      <group ref={ref}>
        {/* badan gedung */}
        <mesh position={[0, 1.7, 0]}>
          <boxGeometry args={[7, 3.4, 3]} />
          <meshStandardMaterial color="#efe3cf" roughness={1} />
        </mesh>
        {/* atap */}
        <mesh position={[0, 3.6, 0]}>
          <boxGeometry args={[7.6, 0.4, 3.6]} />
          <meshStandardMaterial color="#b5553d" roughness={1} />
        </mesh>
        {/* pintu */}
        <mesh position={[0, 1.0, 1.52]}>
          <boxGeometry args={[1.2, 2.0, 0.08]} />
          <meshStandardMaterial color="#5a3a24" roughness={1} />
        </mesh>
        {/* papan nama */}
        <mesh position={[0, 2.55, 1.53]}>
          <planeGeometry args={[2.6, 0.65]} />
          <meshStandardMaterial map={signTex} roughness={1} />
        </mesh>
        {/* lukisan di dinding */}
        {frameBox(-2.3, 1.9, 1.3, 1.6, 0)}
        {frameBox(2.3, 1.9, 1.3, 1.6, 1)}
      </group>
    </group>
  );
};
