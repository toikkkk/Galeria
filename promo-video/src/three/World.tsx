import React, {useLayoutEffect, useMemo, useRef} from 'react';
import * as THREE from 'three';
import {random} from 'remotion';

/** Menyalakan bayangan untuk semua mesh di dalam sebuah group. */
const useShadows = (ref: React.RefObject<THREE.Object3D | null>, cast = true, receive = true) => {
  useLayoutEffect(() => {
    ref.current?.traverse((o) => {
      if ((o as THREE.Mesh).isMesh) {
        o.castShadow = cast;
        o.receiveShadow = receive;
      }
    });
  });
};

const GRASS = ['#6f8f2f', '#86a23a', '#5c7d28', '#a3b552'];
const FLOWER = ['#f2d24a', '#b78be0', '#f08fb0', '#ffffff', '#f2a24a'];

/** Rumput: ribuan kerucut kecil lewat satu InstancedMesh (murah), warna bervariasi. */
const Grass: React.FC<{count: number}> = ({count}) => {
  const ref = useRef<THREE.InstancedMesh>(null);
  useLayoutEffect(() => {
    const m = ref.current;
    if (!m) return;
    const d = new THREE.Object3D();
    const col = new THREE.Color();
    for (let i = 0; i < count; i++) {
      d.position.set((random(`gx${i}`) - 0.5) * 50, 0.13, (random(`gz${i}`) - 0.5) * 60 - 14);
      d.scale.setScalar(0.6 + random(`gs${i}`) * 1.0);
      d.rotation.y = random(`gr${i}`) * 6;
      d.updateMatrix();
      m.setMatrixAt(i, d.matrix);
      m.setColorAt(i, col.set(GRASS[Math.floor(random(`gc${i}`) * GRASS.length)]));
    }
    m.instanceMatrix.needsUpdate = true;
    if (m.instanceColor) m.instanceColor.needsUpdate = true;
  }, [count]);
  return (
    <instancedMesh ref={ref} args={[undefined, undefined, count]}>
      <coneGeometry args={[0.032, 0.2, 4]} />
      <meshStandardMaterial flatShading roughness={1} />
    </instancedMesh>
  );
};

/** Bunga kecil warna-warni yang menyebar di padang. */
const Flowers: React.FC<{count: number}> = ({count}) => {
  const ref = useRef<THREE.InstancedMesh>(null);
  useLayoutEffect(() => {
    const m = ref.current;
    if (!m) return;
    const d = new THREE.Object3D();
    const col = new THREE.Color();
    for (let i = 0; i < count; i++) {
      d.position.set((random(`fx${i}`) - 0.5) * 36, 0.1, (random(`fz${i}`) - 0.5) * 40 - 8);
      d.scale.setScalar(0.7 + random(`fs${i}`) * 0.8);
      d.updateMatrix();
      m.setMatrixAt(i, d.matrix);
      m.setColorAt(i, col.set(FLOWER[Math.floor(random(`fc${i}`) * FLOWER.length)]));
    }
    m.instanceMatrix.needsUpdate = true;
    if (m.instanceColor) m.instanceColor.needsUpdate = true;
  }, [count]);
  return (
    <instancedMesh ref={ref} args={[undefined, undefined, count]}>
      <icosahedronGeometry args={[0.07, 0]} />
      <meshStandardMaterial flatShading roughness={1} />
    </instancedMesh>
  );
};

const Tree: React.FC<{x: number; z: number; s: number}> = ({x, z, s}) => (
  <group position={[x, 0, z]} scale={s}>
    <mesh position={[0, 0.55, 0]}>
      <cylinderGeometry args={[0.12, 0.17, 1.1, 6]} />
      <meshStandardMaterial color="#6b4a2c" flatShading roughness={1} />
    </mesh>
    <mesh position={[0, 1.7, 0]}>
      <icosahedronGeometry args={[0.95, 0]} />
      <meshStandardMaterial color="#5f9a3e" flatShading roughness={1} />
    </mesh>
  </group>
);

const Cloud: React.FC<{x: number; y: number; z: number; s: number; tone?: string}> = ({
  x,
  y,
  z,
  s,
  tone = '#e7e9e6',
}) => (
  <group position={[x, y, z]} scale={s}>
    {[
      [0, 0, 0, 1.8],
      [1.8, -0.3, 0.2, 1.3],
      [-1.7, -0.35, 0, 1.2],
    ].map(([cx, cy, cz, r], i) => (
      <mesh key={i} position={[cx, cy, cz]}>
        <icosahedronGeometry args={[r, 1]} />
        <meshStandardMaterial color={tone} emissive={tone} emissiveIntensity={0.35} flatShading roughness={1} />
      </mesh>
    ))}
  </group>
);

/** Papan kayu dengan tulisan (tekstur dari canvas). */
export const Sign: React.FC<{
  label: string;
  value: string;
  position: [number, number, number];
  rotY?: number;
}> = ({label, value, position, rotY = 0}) => {
  const ref = useRef<THREE.Group>(null);
  useShadows(ref);
  const tex = useMemo(() => {
    const c = document.createElement('canvas');
    c.width = 512;
    c.height = 320;
    const g = c.getContext('2d')!;
    g.fillStyle = '#b98a55';
    g.fillRect(0, 0, 512, 320);
    g.strokeStyle = '#8a6035';
    g.lineWidth = 14;
    g.strokeRect(7, 7, 498, 306);
    g.fillStyle = '#3a2a1a';
    g.textAlign = 'center';
    g.font = '700 54px sans-serif';
    g.fillText(label, 256, 105);
    g.font = '900 150px sans-serif';
    g.fillText(value, 256, 250);
    const t = new THREE.CanvasTexture(c);
    t.colorSpace = THREE.SRGBColorSpace;
    return t;
  }, [label, value]);

  return (
    <group ref={ref} position={position} rotation={[0, rotY, 0]}>
      <mesh position={[0, 0.6, 0]}>
        <boxGeometry args={[0.12, 1.2, 0.12]} />
        <meshStandardMaterial color="#6b4a2c" roughness={1} />
      </mesh>
      <mesh position={[0, 1.4, 0]}>
        <boxGeometry args={[1.5, 0.95, 0.1]} />
        <meshStandardMaterial map={tex} roughness={1} />
      </mesh>
    </group>
  );
};

const mixStops = (stops: string[], t: number): THREE.Color => {
  const n = stops.length - 1;
  const x = Math.min(Math.max(t, 0), 1) * n;
  const i = Math.min(Math.floor(x), n - 1);
  return new THREE.Color(stops[i]).lerp(new THREE.Color(stops[i + 1]), x - i);
};
const numStops = (stops: number[], t: number): number => {
  const n = stops.length - 1;
  const x = Math.min(Math.max(t, 0), 1) * n;
  const i = Math.min(Math.floor(x), n - 1);
  return stops[i] + (stops[i + 1] - stops[i]) * (x - i);
};

/**
 * Padang rumput low-poly: tanah, bukit, pohon, batu, pagar, awan, bunga, bayangan, kabut.
 * `tod` (0..1) = suasana waktu: 0 pagi mendung, 0.5 cerah, 1 senja keemasan.
 */
export const World: React.FC<{tod?: number}> = ({tod = 0.5}) => {
  const sky = mixStops(['#aebbc4', '#c5d8e3', '#f2c58f'], tod);
  const fog = mixStops(['#cfd3c4', '#dfe3cc', '#f1d2a8'], tod);
  const sun = mixStops(['#e8eef2', '#fff1d6', '#ffb870'], tod);
  const sunI = numStops([1.6, 2.3, 2.6], tod);
  const hemiI = numStops([0.9, 1.05, 0.85], tod);
  const ground = mixStops(['#9aa458', '#a9b455', '#b9ae52'], tod);
  const props = useRef<THREE.Group>(null);
  useShadows(props);

  const trees = useMemo(
    () =>
      Array.from({length: 24}, (_, i) => {
        const side = random(`ts${i}`) > 0.5 ? 1 : -1;
        return {
          x: side * (3.8 + random(`tx${i}`) * 16),
          z: -random(`tz${i}`) * 28 - 2,
          s: 0.8 + random(`tsc${i}`) * 0.9,
        };
      }),
    [],
  );
  const rocks = useMemo(
    () =>
      Array.from({length: 14}, (_, i) => ({
        x: (random(`rx${i}`) - 0.5) * 30,
        z: -random(`rz${i}`) * 22 - 1,
        s: 0.35 + random(`rs${i}`) * 0.5,
      })),
    [],
  );
  const posts = useMemo(() => Array.from({length: 27}, (_, i) => -20 + i * 1.5), []);

  return (
    <group>
      <color attach="background" args={[sky]} />
      <fog attach="fog" args={[fog, 22, 78]} />

      {/* cahaya: langit/tanah lembut + matahari hangat yang membuat bayangan */}
      <hemisphereLight args={['#e6eef4', '#8f9c4a', hemiI]} />
      <ambientLight intensity={0.2} />
      <directionalLight
        position={[-7, 11, 8]}
        intensity={sunI}
        color={sun}
        castShadow
        shadow-mapSize-width={2048}
        shadow-mapSize-height={2048}
        shadow-camera-left={-14}
        shadow-camera-right={14}
        shadow-camera-top={14}
        shadow-camera-bottom={-14}
        shadow-camera-near={1}
        shadow-camera-far={45}
        shadow-bias={-0.0004}
      />

      {/* tanah (menerima bayangan) */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} receiveShadow>
        <planeGeometry args={[220, 220]} />
        <meshStandardMaterial color={ground} roughness={1} />
      </mesh>

      {/* bukit di kejauhan */}
      {[
        [-30, -48, 26, 9],
        [8, -62, 36, 13],
        [46, -42, 22, 8],
      ].map(([x, z, r, h], i) => (
        <mesh key={i} position={[x, 0, z]} scale={[r, h, r]}>
          <sphereGeometry args={[1, 8, 6]} />
          <meshStandardMaterial color={i % 2 ? '#a0b351' : '#b3c062'} flatShading roughness={1} />
        </mesh>
      ))}

      <Grass count={9000} />
      <Flowers count={420} />

      <group ref={props}>
        {trees.map((t, i) => (
          <Tree key={i} {...t} />
        ))}

        {rocks.map((r, i) => (
          <mesh key={i} position={[r.x, r.s * 0.4, r.z]} scale={[r.s, r.s * 0.7, r.s]}>
            <dodecahedronGeometry args={[1, 0]} />
            <meshStandardMaterial color="#a3a397" flatShading roughness={1} />
          </mesh>
        ))}

        {/* pagar di belakang */}
        <group position={[0, 0, -13]}>
          {posts.map((x, i) => (
            <mesh key={i} position={[x, 0.4, 0]}>
              <boxGeometry args={[0.1, 0.8, 0.1]} />
              <meshStandardMaterial color="#7a5232" roughness={1} />
            </mesh>
          ))}
          <mesh position={[0, 0.6, 0]}>
            <boxGeometry args={[42, 0.05, 0.05]} />
            <meshStandardMaterial color="#d9d2c0" roughness={1} />
          </mesh>
        </group>
      </group>

      <Cloud x={-12} y={15} z={-40} s={1.4} tone="#d7dadb" />
      <Cloud x={14} y={18} z={-48} s={1.8} tone="#dfe2e1" />
      <Cloud x={2} y={13} z={-34} s={1} tone="#e9ebe9" />
    </group>
  );
};
