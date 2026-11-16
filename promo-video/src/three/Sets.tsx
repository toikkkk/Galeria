import React, {useMemo} from 'react';
import * as THREE from 'three';
import {useLoader} from '@react-three/fiber';
import {GLTFLoader} from 'three/examples/jsm/loaders/GLTFLoader.js';
import {random, spring, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import {Model, KChar} from './Model';
import {Atmosphere, groundColor} from './Atmosphere';
import {Sign} from './World';
import {paintTexture} from '../art';

type V3 = [number, number, number];
const S = 2.6; // skala aset kit supaya sepadan dengan karakter setinggi 3 unit

/** Mengulang satu model sepanjang garis (pagar, hedge, jalan setapak). */
const ModelRow: React.FC<{
  kit: 'plat' | 'sub' | 'town';
  name: string;
  from: V3;
  to: V3;
  scale?: number;
  gap?: number;
}> = ({kit, name, from, to, scale = S, gap = 0}) => {
  const g = useLoader(GLTFLoader, staticFile(`models/${kit}/${name}.glb`));
  const w = useMemo(() => {
    const b = new THREE.Box3().setFromObject(g.scene);
    return Math.max(0.2, (b.max.x - b.min.x) * scale) + gap;
  }, [g, scale, gap]);
  const dx = to[0] - from[0];
  const dz = to[2] - from[2];
  const n = Math.max(1, Math.round(Math.hypot(dx, dz) / w));
  const rot = -Math.atan2(dz, dx);
  return (
    <>
      {Array.from({length: n + 1}, (_, i) => (
        <Model
          key={i}
          kit={kit}
          name={name}
          scale={scale}
          rotY={rot}
          position={[from[0] + (dx * i) / n, from[1], from[2] + (dz * i) / n]}
        />
      ))}
    </>
  );
};

const Ground: React.FC<{color: THREE.Color | string}> = ({color}) => (
  <mesh rotation={[-Math.PI / 2, 0, 0]} receiveShadow>
    <planeGeometry args={[260, 260]} />
    <meshStandardMaterial color={color} roughness={1} />
  </mesh>
);

const Hills: React.FC<{tone?: [string, string]}> = ({tone = ['#a0b351', '#b3c062']}) => (
  <>
    {[
      [-34, -60, 30, 10],
      [10, -74, 42, 15],
      [52, -52, 26, 9],
    ].map(([x, z, r, h], i) => (
      <mesh key={i} position={[x, 0, z]} scale={[r, h, r]}>
        <sphereGeometry args={[1, 8, 6]} />
        <meshStandardMaterial color={tone[i % 2]} flatShading roughness={1} />
      </mesh>
    ))}
  </>
);

/** Titik acak, menghindari zona karakter dan jalur kamera utama. */
const scatter = (n: number, seed: string, xr: [number, number], zr: [number, number], avoid?: (x: number, z: number) => boolean) => {
  const out: {x: number; z: number; s: number; r: number}[] = [];
  let i = 0;
  while (out.length < n && i < n * 6) {
    const x = xr[0] + random(`${seed}x${i}`) * (xr[1] - xr[0]);
    const z = zr[0] + random(`${seed}z${i}`) * (zr[1] - zr[0]);
    if (!avoid || !avoid(x, z)) out.push({x, z, s: 0.75 + random(`${seed}s${i}`) * 0.6, r: random(`${seed}r${i}`) * 6.28});
    i++;
  }
  return out;
};
const nearChars = (x: number, z: number) => Math.abs(x) < 4.2 && z > -3 && z < 6;

/** Kanvas-kanvas lukisan bersandar (milik seniman). */
export const Canvases: React.FC<{position?: V3}> = ({position = [3.2, 0, -1]}) => {
  const tex = useMemo(() => [0, 1, 2, 3, 4].map((s) => paintTexture(s)), []);
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  const pop = (i: number) => Math.max(0.001, spring({frame: f - i * 3, fps, config: {damping: 11, stiffness: 150}}));
  const cfg: {x: number; z: number; r: number; w: number; h: number}[] = [
    {x: 0, z: 0, r: 0.15, w: 1.5, h: 1.9},
    {x: 1.4, z: -0.4, r: -0.3, w: 1.7, h: 1.3},
    {x: -1.3, z: -0.5, r: 0.4, w: 1.3, h: 1.7},
    {x: 0.6, z: -1.2, r: 0.0, w: 1.9, h: 1.5},
    {x: -0.4, z: 0.9, r: -0.2, w: 1.2, h: 1.5},
  ];
  return (
    <group position={position}>
      {cfg.map((c, i) => (
        <group key={i} position={[c.x, 0, c.z]} rotation={[-0.14, c.r, 0]} scale={pop(i)}>
          <mesh position={[0, c.h / 2, 0]} castShadow>
            <boxGeometry args={[c.w + 0.16, c.h + 0.16, 0.08]} />
            <meshStandardMaterial color="#3b2a1c" roughness={1} />
          </mesh>
          <mesh position={[0, c.h / 2, 0.05]}>
            <planeGeometry args={[c.w, c.h]} />
            <meshStandardMaterial map={tex[i]} roughness={1} />
          </mesh>
        </group>
      ))}
    </group>
  );
};

/** LOKASI 1: padang rumput (seniman belum punya apa-apa). */
export const MeadowSet: React.FC<{tod: number; showCanvases: boolean}> = ({tod, showCanvases}) => {
  const trees = useMemo(() => scatter(20, 'mt', [-34, 34], [-46, -5], (x, z) => Math.abs(x) < 6 && z > -12), []);
  const pines = useMemo(() => scatter(9, 'mp', [-34, 34], [-46, -8], (x, z) => Math.abs(x) < 8), []);
  const flowers = useMemo(() => scatter(110, 'mf', [-26, 26], [-26, 12], nearChars), []);
  const grass = useMemo(() => scatter(420, 'mg', [-28, 28], [-30, 14], (x, z) => Math.abs(x) < 1.4 && z > -1.5 && z < 1.5), []);
  const rocks = useMemo(() => scatter(10, 'mr', [-22, 22], [-24, 4], nearChars), []);
  const shrooms = useMemo(() => scatter(8, 'mm', [-14, 14], [-14, 6], nearChars), []);
  return (
    <>
      <Atmosphere tod={tod} />
      <Ground color={groundColor(tod)} />
      <Hills />
      {trees.map((p, i) => (
        <Model key={`t${i}`} kit="plat" name="tree" position={[p.x, 0, p.z]} scale={S * p.s * 1.2} rotY={p.r} />
      ))}
      {pines.map((p, i) => (
        <Model key={`p${i}`} kit="plat" name="tree-pine" position={[p.x, 0, p.z]} scale={S * p.s * 1.2} rotY={p.r} />
      ))}
      {flowers.map((p, i) => (
        <Model key={`f${i}`} kit="plat" name={i % 3 ? 'flowers' : 'flowers-tall'} position={[p.x, 0, p.z]} scale={S * p.s * 0.5} rotY={p.r} />
      ))}
      {grass.map((p, i) => (
        <Model key={`g${i}`} kit="plat" name="grass" position={[p.x, 0, p.z]} scale={S * p.s * 0.45} rotY={p.r} />
      ))}
      {rocks.map((p, i) => (
        <Model key={`r${i}`} kit="plat" name={i % 2 ? 'rocks' : 'stones'} position={[p.x, 0, p.z]} scale={S * p.s * 1.1} rotY={p.r} />
      ))}
      {shrooms.map((p, i) => (
        <Model key={`m${i}`} kit="plat" name="mushrooms" position={[p.x, 0, p.z]} scale={S * p.s * 0.6} rotY={p.r} />
      ))}
      <ModelRow kit="plat" name="fence-low-straight" from={[-30, 0, -14]} to={[30, 0, -14]} />
      <Sign label="KARYA" value="1" position={[-2.6, 0, -0.8]} rotY={0.35} />
      {showCanvases && <Canvases position={[3.4, 0, -0.8]} />}
    </>
  );
};

/** Gedung galeri: rumah dari kit, dengan papan nama dan lukisan di dinding depan. */
export const GalleryHouse: React.FC<{appearAt: number; position?: V3}> = ({appearAt, position = [0, 0, -9]}) => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  const tex = useMemo(() => [1, 3].map((s) => paintTexture(s)), []);
  const sign = useMemo(() => {
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
  if (f < appearAt) return null;
  const s = Math.max(0.001, spring({frame: f - appearAt, fps, config: {damping: 9, stiffness: 80, mass: 0.9}}));
  return (
    <group position={position} scale={[1, s, 1]}>
      <Model kit="sub" name="building-type-d" scale={4.6} />
      {/* papan nama dan lukisan menempel di depan bangunan */}
      <mesh position={[0, 4.6, 3.3]}>
        <planeGeometry args={[4.4, 1.1]} />
        <meshStandardMaterial map={sign} roughness={1} />
      </mesh>
      {[
        [-3.4, 2.4, tex[0]],
        [3.4, 2.4, tex[1]],
      ].map(([x, y, t], i) => (
        <group key={i} position={[x as number, y as number, 3.3]}>
          <mesh position={[0, 0, -0.03]}>
            <boxGeometry args={[1.9, 2.3, 0.08]} />
            <meshStandardMaterial color="#3b2a1c" roughness={1} />
          </mesh>
          <mesh position={[0, 0, 0.02]}>
            <planeGeometry args={[1.65, 2.05]} />
            <meshStandardMaterial map={t as THREE.Texture} roughness={1} />
          </mesh>
        </group>
      ))}
    </group>
  );
};

/** LOKASI 2: alun-alun kota (galeri sudah berdiri, ramai). */
export const PlazaSet: React.FC<{tod: number; crowd: boolean; galleryAt: number}> = ({tod, crowd, galleryAt}) => {
  const trees = useMemo(() => scatter(12, 'pt', [-36, 36], [-34, -14], (x) => Math.abs(x) < 8), []);
  const lamps: V3[] = [
    [-6, 0, -1],
    [6, 0, -1],
    [-9, 0, -6],
    [9, 0, -6],
  ];
  return (
    <>
      <Atmosphere tod={tod} fogNear={30} fogFar={95} />
      <Ground color={groundColor(tod, ['#bfb8a2', '#cfc7ae', '#d9c49c'])} />
      <Hills tone={['#9fb257', '#aebb62']} />
      <GalleryHouse appearAt={galleryAt} position={[0, 0, -9]} />
      <Model kit="town" name="fountain-round" position={[9.5, 0, -2.5]} scale={S * 1.3} />
      <Model kit="town" name="stall-red" position={[-10.5, 0, -3.5]} scale={S} rotY={0.5} />
      <Model kit="town" name="stall-green" position={[-14.5, 0, -6]} scale={S} rotY={0.3} />
      <Model kit="town" name="cart" position={[13.5, 0, -7]} scale={S} rotY={-0.6} />
      <Model kit="town" name="banner-red" position={[-4.2, 0, -7.2]} scale={S} />
      <Model kit="town" name="banner-green" position={[4.2, 0, -7.2]} scale={S} />
      {lamps.map((p, i) => (
        <Model key={i} kit="town" name="lantern" position={p} scale={S * 1.1} />
      ))}
      {trees.map((p, i) => (
        <Model key={i} kit="town" name={i % 2 ? 'tree' : 'tree-high-round'} position={[p.x, 0, p.z]} scale={S * p.s * 1.1} rotY={p.r} />
      ))}
      <ModelRow kit="town" name="hedge" from={[-26, 0, -12]} to={[-8, 0, -12]} scale={S} />
      <ModelRow kit="town" name="hedge" from={[8, 0, -12]} to={[26, 0, -12]} scale={S} />
      {crowd && (
        <>
          <KChar skin="male-a" anim="emote-yes" position={[-6.5, 0, 1.5]} rotY={0.5} offset={0.2} />
          <KChar skin="female-a" anim="idle" position={[-8.5, 0, -1.5]} rotY={0.8} offset={0.6} />
          <KChar skin="male-e" anim="interact-right" position={[6.5, 0, 2]} rotY={-0.5} offset={0.1} />
          <KChar skin="female-e" anim="idle" position={[8, 0, -0.5]} rotY={-0.8} offset={0.9} />
          <KChar skin="male-b" anim="emote-yes" position={[0.5, 0, -4.5]} rotY={0} offset={0.4} />
        </>
      )}
    </>
  );
};

/** LOKASI 3: jalan permukiman (sisi kolektor), senja keemasan. */
export const StreetSet: React.FC<{tod: number}> = ({tod}) => {
  const types = ['a', 'b', 'e', 'g', 'k', 'n', 'q'];
  const xs = [-26, -17, -8.5, 0.5, 9, 17.5, 26];
  const trees = useMemo(() => scatter(10, 'st', [-30, 30], [-8, 8], (x, z) => Math.abs(x) < 7 || z > -2), []);
  return (
    <>
      <Atmosphere tod={tod} fogNear={26} fogFar={90} />
      <Ground color={groundColor(tod, ['#a9b06c', '#b5b878', '#c3b26a'])} />
      {/* jalan aspal dan trotoar */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.02, 4]} receiveShadow>
        <planeGeometry args={[120, 7]} />
        <meshStandardMaterial color={new THREE.Color('#7a7a78')} roughness={1} />
      </mesh>
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.03, -2.6]} receiveShadow>
        <planeGeometry args={[120, 3.6]} />
        <meshStandardMaterial color={new THREE.Color('#cfc9bb')} roughness={1} />
      </mesh>
      {xs.map((x, i) => (
        <Model key={i} kit="sub" name={`building-type-${types[i]}`} position={[x, 0, -10.5]} scale={4.4} rotY={0} />
      ))}
      <ModelRow kit="sub" name="fence" from={[-32, 0, -4.6]} to={[32, 0, -4.6]} scale={S * 0.9} />
      {trees.map((p, i) => (
        <Model key={i} kit="sub" name={i % 3 ? 'tree-large' : 'tree-small'} position={[p.x, 0, p.z - 1]} scale={S * p.s * 1.2} rotY={p.r} />
      ))}
      <Hills tone={['#b0a85a', '#bdb066']} />
    </>
  );
};
