import React, {useLayoutEffect, useRef} from 'react';
import * as THREE from 'three';
import {useCurrentFrame, useVideoConfig} from 'remotion';
import {C} from '../theme';

export type Mood = 'netral' | 'senang';
export type Pose = 'idle' | 'wave' | 'shrug' | 'cheer' | 'point';

export type Palette = {skin: string; skinDark: string; hair: string; suit: string; shirt: string; beret?: string};

export const SENIMAN: Palette = {
  skin: C.skin,
  skinDark: C.skinDark,
  hair: '#1c1512',
  suit: C.suit,
  shirt: C.shirt,
};
export const KOLEKTOR: Palette = {
  skin: '#e0b48f',
  skinDark: '#c79a74',
  hair: '#4a2c1a',
  suit: '#1f6f74',
  shirt: '#f4ead5',
  beret: '#d6453d',
};

/**
 * Karakter low-poly blocky dari bentuk dasar (tanpa model 3D luar).
 * Menghadap +z (ke kamera). Tinggi total ~3 unit.
 * `walk` = siklus jalan; `pose` = gerak tangan.
 */
export const Character: React.FC<{
  talking?: boolean;
  mood?: Mood;
  pose?: Pose;
  walk?: boolean;
  palette?: Palette;
  position?: [number, number, number];
  rotY?: number;
}> = ({talking = false, mood = 'netral', pose = 'idle', walk = false, palette = SENIMAN, position = [0, 0, 0], rotY = 0}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const t = frame / fps;

  const root = useRef<THREE.Group>(null);
  useLayoutEffect(() => {
    root.current?.traverse((o) => {
      if ((o as THREE.Mesh).isMesh) {
        o.castShadow = true;
        o.receiveShadow = true;
      }
    });
  });

  const stride = walk ? Math.sin(t * 10) : 0;
  const bob = walk ? Math.abs(Math.sin(t * 10)) * 0.09 : Math.sin(t * 2.2) * 0.015;
  const sway = walk ? 0 : Math.sin(t * 1.4) * 0.04;
  const blink = frame % 96 < 4;
  const talk = talking ? Math.abs(Math.sin(t * 13)) : 0;
  const happy = mood === 'senang';

  const mat = (color: string) => <meshStandardMaterial color={color} roughness={1} />;

  // sudut lengan (rotasi z; positif = ke arah luar badan untuk sisi +1)
  const armZ = (side: 1 | -1): number => {
    switch (pose) {
      case 'wave':
        return side === 1 ? 2.5 + Math.sin(t * 11) * 0.28 : 0.06 + sway;
      case 'shrug':
        return side * (0.95 + Math.sin(t * 5) * 0.05);
      case 'cheer':
        return side * (2.7 + Math.sin(t * 9) * 0.18);
      case 'point':
        return side === 1 ? 1.45 : 0.06 + sway;
      default:
        return side * (0.06 + sway);
    }
  };

  const arm = (side: 1 | -1) => (
    <group
      position={[side * 0.55, 1.95, 0]}
      rotation={[walk ? -side * stride * 0.7 : 0, 0, armZ(side)]}
    >
      <mesh position={[0, -0.47, 0]}>
        <boxGeometry args={[0.22, 0.95, 0.26]} />
        {mat(palette.suit)}
      </mesh>
      <mesh position={[0, -1.02, 0]}>
        <sphereGeometry args={[0.11, 10, 8]} />
        {mat(palette.skin)}
      </mesh>
    </group>
  );

  const leg = (side: 1 | -1) => (
    <group position={[side * 0.18, 1.0, 0]} rotation={[side * stride * 0.6, 0, 0]}>
      <mesh position={[0, -0.5, 0]}>
        <boxGeometry args={[0.28, 1.0, 0.3]} />
        {mat(palette.suit)}
      </mesh>
      <mesh position={[0, -0.93, 0.08]}>
        <boxGeometry args={[0.32, 0.14, 0.46]} />
        {mat('#e6e3dc')}
      </mesh>
    </group>
  );

  const eye = (side: 1 | -1) =>
    happy ? (
      <mesh position={[side * 0.17, 0.05, 0.43]}>
        <torusGeometry args={[0.06, 0.014, 6, 12, Math.PI]} />
        {mat('#111')}
      </mesh>
    ) : (
      <mesh position={[side * 0.17, 0.06, 0.43]} scale={[1, blink ? 0.15 : 1, 1]}>
        <sphereGeometry args={[0.055, 10, 8]} />
        <meshStandardMaterial color="#111" roughness={0.6} />
      </mesh>
    );

  const brow = (side: 1 | -1) => (
    <mesh position={[side * 0.17, happy ? 0.18 : 0.15, 0.45]} rotation={[0, 0, -side * (happy ? 0.0 : 0.1)]}>
      <boxGeometry args={[0.19, 0.05, 0.04]} />
      {mat(palette.hair)}
    </mesh>
  );

  return (
    <group ref={root} position={position} rotation={[0, rotY, 0]}>
      <group position={[0, bob, 0]}>
        {leg(1)}
        {leg(-1)}

        {/* badan: jas, kemeja, dasi, kancing */}
        <mesh position={[0, 1.5, 0]}>
          <boxGeometry args={[0.84, 1.05, 0.42]} />
          {mat(palette.suit)}
        </mesh>
        <mesh position={[0, 1.52, 0.215]}>
          <boxGeometry args={[0.3, 0.8, 0.02]} />
          {mat(palette.shirt)}
        </mesh>
        <mesh position={[0, 1.64, 0.232]}>
          <boxGeometry args={[0.1, 0.5, 0.02]} />
          {mat(palette.beret ? '#8a2a24' : '#0c0d11')}
        </mesh>
        <mesh position={[0.2, 1.2, 0.22]}>
          <sphereGeometry args={[0.035, 8, 6]} />
          {mat('#7a5a2a')}
        </mesh>
        {[-1, 1].map((s) => (
          <mesh key={s} position={[s * 0.2, 1.8, 0.222]}>
            <boxGeometry args={[0.018, 0.7, 0.012]} />
            {mat('#f3f1ea')}
          </mesh>
        ))}

        {arm(1)}
        {arm(-1)}

        {/* kepala */}
        <group position={[0, 2.5, 0]} rotation={[0, 0, sway * 0.5]}>
          <mesh scale={[1, 1.06, 1]}>
            <sphereGeometry args={[0.46, 22, 16]} />
            {mat(palette.skin)}
          </mesh>
          {[-1, 1].map((s) => (
            <group key={s}>
              <mesh position={[s * 0.45, -0.02, 0]}>
                <sphereGeometry args={[0.085, 8, 6]} />
                {mat(palette.skinDark)}
              </mesh>
              <mesh position={[s * 0.49, -0.04, 0.03]}>
                <sphereGeometry args={[0.045, 8, 6]} />
                {mat('#f3f1ea')}
              </mesh>
            </group>
          ))}
          <mesh position={[0, 0.07, -0.05]} rotation={[-0.5, 0, 0]}>
            <sphereGeometry args={[0.49, 22, 12, 0, Math.PI * 2, 0, Math.PI * 0.5]} />
            {mat(palette.hair)}
          </mesh>
          {palette.beret && (
            <group position={[0.06, 0.4, -0.02]} rotation={[0, 0, -0.18]}>
              <mesh scale={[1, 0.32, 1]}>
                <sphereGeometry args={[0.46, 18, 10]} />
                {mat(palette.beret)}
              </mesh>
              <mesh position={[0, 0.17, 0]}>
                <cylinderGeometry args={[0.03, 0.03, 0.08, 6]} />
                {mat(palette.beret)}
              </mesh>
            </group>
          )}
          {eye(1)}
          {eye(-1)}
          {brow(1)}
          {brow(-1)}
          <mesh position={[0, -0.04, 0.46]}>
            <sphereGeometry args={[0.048, 8, 6]} />
            {mat(palette.skinDark)}
          </mesh>
          {happy ? (
            <mesh position={[0, -0.13, 0.435]} rotation={[0, 0, Math.PI]}>
              <torusGeometry args={[0.07, 0.014, 6, 12, Math.PI]} />
              {mat('#5a2a2a')}
            </mesh>
          ) : (
            <mesh position={[0, -0.19, 0.435]}>
              <boxGeometry args={[0.13, 0.03 + 0.09 * talk, 0.03]} />
              {mat('#5a2a2a')}
            </mesh>
          )}
        </group>
      </group>
    </group>
  );
};
