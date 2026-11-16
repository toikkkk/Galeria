import React, {useLayoutEffect, useMemo, useRef} from 'react';
import * as THREE from 'three';
import {RoundedBoxGeometry} from 'three/examples/jsm/geometries/RoundedBoxGeometry.js';

type V3 = [number, number, number];

/** Parameter pose (semua angka, supaya bisa dicampur/diinterpolasi). Sudut dalam radian. */
export type Pose = {
  // lengan kiri (L, x<0) dan kanan (R, x>0): fx = angkat ke depan, ab = buka ke samping, el = tekuk siku
  fxL: number; abL: number; elL: number;
  fxR: number; abR: number; elR: number;
  // kepala
  hx: number; hy: number; hz: number; // angguk (+ = menunduk), tengok, miring
  // badan
  lean: number; twist: number; hop: number;
  // wajah
  brow: number; browTilt: number; // angkat alis, kemiringan (+ = sedih/cemas, - = marah)
  lid: number; // 0 terbuka, 1 tertutup
  smile: number; // -1 cemberut .. +1 senyum lebar
  // osilasi (dikalikan sin waktu)
  oscEl: number; // goyang siku (melambai/tepuk)
  oscHead: number; // geleng kepala
  phone: number; // 0..1 ponsel di tangan
};

export const P0: Pose = {
  fxL: 0, abL: 0.08, elL: 0.12, fxR: 0, abR: 0.08, elR: 0.12,
  hx: 0, hy: 0, hz: 0, lean: 0, twist: 0, hop: 0,
  brow: 0, browTilt: 0, lid: 0.25, smile: 0, oscEl: 0, oscHead: 0, phone: 0,
};

export const mixPose = (a: Pose, b: Pose, k: number): Pose => {
  const o = {} as Pose;
  (Object.keys(a) as (keyof Pose)[]).forEach((key) => {
    o[key] = a[key] + (b[key] - a[key]) * k;
  });
  return o;
};

export type Palette = {
  skin: string; skinDark: string; hair: string; suit: string; shirt: string; tie: string; hairStyle: 'quiff' | 'buns';
};
export const PAL_SENIMAN: Palette = {
  skin: '#e9b78c', skinDark: '#cf9a70', hair: '#2a211d', suit: '#17181f', shirt: '#e8e2d4', tie: '#0f1013', hairStyle: 'quiff',
};
export const PAL_KOLEKTOR: Palette = {
  skin: '#d9a07a', skinDark: '#bd8460', hair: '#6a3a22', suit: '#1f6f74', shirt: '#f3ead6', tie: '#d6453d', hairStyle: 'buns',
};

const rbCache = new Map<string, RoundedBoxGeometry>();
const rbGeo = (w: number, h: number, d: number, r: number) => {
  const key = `${w}|${h}|${d}|${r}`;
  let g = rbCache.get(key);
  if (!g) {
    g = new RoundedBoxGeometry(w, h, d, 4, r);
    rbCache.set(key, g);
  }
  return g;
};

/** Kotak membulat (tepi dibulatkan) supaya tidak terlihat patah. */
const RBox: React.FC<{size: V3; r?: number; color: string; position?: V3; rotation?: V3}> = ({
  size, r = 0.08, color, position = [0, 0, 0], rotation = [0, 0, 0],
}) => (
  <mesh geometry={rbGeo(size[0], size[1], size[2], Math.min(r, Math.min(...size) / 2 - 0.001))} position={position} rotation={rotation}>
    <meshStandardMaterial color={color} roughness={0.85} />
  </mesh>
);

const Ball: React.FC<{r: number; color: string; position?: V3; scale?: V3}> = ({r, color, position = [0, 0, 0], scale = [1, 1, 1]}) => (
  <mesh position={position} scale={scale}>
    <sphereGeometry args={[r, 28, 20]} />
    <meshStandardMaterial color={color} roughness={0.85} />
  </mesh>
);

const Cord: React.FC<{side: 1 | -1}> = ({side}) => {
  const geo = useMemo(() => {
    const pts = [
      new THREE.Vector3(side * 0.6, 2.55, 0.02),
      new THREE.Vector3(side * 0.5, 2.15, 0.12),
      new THREE.Vector3(side * 0.34, 1.95, 0.3),
      new THREE.Vector3(side * 0.28, 1.4, 0.37),
      new THREE.Vector3(side * 0.3, 0.98, 0.38),
    ];
    return new THREE.TubeGeometry(new THREE.CatmullRomCurve3(pts), 24, 0.012, 6, false);
  }, [side]);
  return (
    <mesh geometry={geo}>
      <meshStandardMaterial color="#f4f2ec" roughness={0.7} />
    </mesh>
  );
};

const Leg: React.FC<{side: 1 | -1; hip: number; knee: number; pal: Palette}> = ({side, hip, knee, pal}) => (
  <group position={[side * 0.2, 1.1, 0]} rotation={[hip, 0, 0]}>
    <RBox size={[0.3, 0.56, 0.32]} r={0.1} color={pal.suit} position={[0, -0.26, 0]} />
    <group position={[0, -0.54, 0]} rotation={[knee, 0, 0]}>
      <RBox size={[0.27, 0.52, 0.29]} r={0.09} color={pal.suit} position={[0, -0.24, 0]} />
      <RBox size={[0.32, 0.15, 0.5]} r={0.07} color="#ecebe6" position={[0, -0.55, 0.08]} />
    </group>
  </group>
);

const Arm: React.FC<{side: 1 | -1; fx: number; ab: number; el: number; osc: number; pal: Palette}> = ({side, fx, ab, el, osc, pal}) => (
  <group position={[side * 0.6, 2.0, 0]} rotation={[-fx, 0, side * ab, 'ZXY']}>
    <RBox size={[0.25, 0.56, 0.27]} r={0.1} color={pal.suit} position={[0, -0.26, 0]} />
    <group position={[0, -0.52, 0]} rotation={[-(el + osc), 0, 0]}>
      <RBox size={[0.23, 0.52, 0.25]} r={0.09} color={pal.suit} position={[0, -0.24, 0]} />
      <Ball r={0.12} color={pal.skin} position={[0, -0.56, 0]} />
    </group>
  </group>
);

/**
 * Karakter buatan sendiri: kepala bulat telur, badan jas, sendi siku dan lutut, wajah berekspresi.
 * Menghadap +z. Tinggi ±3.3 unit. `walk` = fase langkah (radian) atau null saat diam.
 */
export const Hero: React.FC<{
  pose: Pose;
  time: number; // detik (untuk napas, kedip, osilasi)
  talk?: number; // 0..1 bukaan mulut
  walk?: number | null;
  pal?: Palette;
  position?: V3;
  rotY?: number;
  phone?: boolean;
}> = ({pose, time, talk = 0, walk = null, pal = PAL_SENIMAN, position = [0, 0, 0], rotY = 0}) => {
  const root = useRef<THREE.Group>(null);
  useLayoutEffect(() => {
    root.current?.traverse((o) => {
      if ((o as THREE.Mesh).isMesh) {
        o.castShadow = true;
        o.receiveShadow = true;
      }
    });
  });

  const w = walk ?? 0;
  const walking = walk !== null;
  const swing = walking ? Math.sin(w) : 0;
  const breathe = Math.sin(time * 2.1) * 0.012;
  const bob = (walking ? Math.abs(Math.sin(w)) * 0.1 : breathe) + pose.hop;
  const blink = Math.sin(time * 1.3 + 0.7) > 0.985 || (time * 30) % 110 < 3;
  const lid = Math.min(1, blink ? 1 : pose.lid);
  const osc = Math.sin(time * 11) * pose.oscEl;
  const headShake = Math.sin(time * 8.5) * pose.oscHead;
  const mouthOpen = talk * Math.max(0, Math.sin(time * 9.5)) * 0.8;
  const smile = pose.smile;

  // lengan saat berjalan mengayun berlawanan dengan kaki
  const wfx = walking ? swing * 0.7 : 0;

  return (
    <group ref={root} position={position} rotation={[0, rotY, 0]}>
      <group position={[0, bob, 0]} rotation={[pose.lean, pose.twist, 0]}>
        {/* kaki */}
        <Leg side={1} hip={walking ? swing * 0.65 : 0} knee={walking ? Math.max(0, -swing) * 0.9 : 0.03} pal={pal} />
        <Leg side={-1} hip={walking ? -swing * 0.65 : 0} knee={walking ? Math.max(0, swing) * 0.9 : 0.03} pal={pal} />

        {/* badan: jas membulat, kemeja, dasi/kerah */}
        <RBox size={[0.96, 1.12, 0.5]} r={0.16} color={pal.suit} position={[0, 1.52, 0]} />
        <RBox size={[0.34, 0.86, 0.04]} r={0.015} color={pal.shirt} position={[0, 1.58, 0.255]} />
        {/* dasi/kerah berbentuk V */}
        <RBox size={[0.1, 0.5, 0.03]} r={0.012} color={pal.tie} position={[0, 1.62, 0.28]} />
        <RBox size={[0.07, 0.4, 0.03]} r={0.01} color={pal.suit} position={[-0.15, 1.82, 0.28]} rotation={[0, 0, 0.7]} />
        <RBox size={[0.07, 0.4, 0.03]} r={0.01} color={pal.suit} position={[0.15, 1.82, 0.28]} rotation={[0, 0, -0.7]} />
        <Ball r={0.035} color="#7a5a2a" position={[0.34, 1.25, 0.26]} />

        <Cord side={1} />
        <Cord side={-1} />

        <Arm side={-1} fx={pose.fxL + wfx} ab={pose.abL} el={pose.elL} osc={osc} pal={pal} />
        <Arm side={1} fx={pose.fxR - wfx} ab={pose.abR} el={pose.elR} osc={osc} pal={pal} />

        {/* ponsel di tangan (kolektor) */}
        {pose.phone > 0.05 && (
          <group position={[0.1, 1.85, 0.62]} rotation={[-0.4, 0, 0]} scale={pose.phone}>
            <RBox size={[0.32, 0.56, 0.05]} r={0.04} color="#15161b" />
            <RBox size={[0.27, 0.5, 0.01]} r={0.02} color="#9ec9e8" position={[0, 0, 0.03]} />
          </group>
        )}

        {/* leher + kepala */}
        <mesh position={[0, 2.1, 0]}>
          <cylinderGeometry args={[0.15, 0.17, 0.2, 14]} />
          <meshStandardMaterial color={pal.skinDark} roughness={0.9} />
        </mesh>
        <group position={[0, 2.62, 0]} rotation={[pose.hx, pose.hy + headShake, pose.hz]}>
          <Ball r={0.56} color={pal.skin} scale={[1, 1.1, 0.98]} />
          {/* telinga + earbud */}
          {[-1, 1].map((s) => (
            <group key={s}>
              <Ball r={0.1} color={pal.skinDark} position={[s * 0.55, -0.03, 0]} scale={[0.6, 1, 0.9]} />
              <Ball r={0.05} color="#f6f4ee" position={[s * 0.6, -0.05, 0.04]} />
            </group>
          ))}
          {/* rambut */}
          <mesh position={[0, 0.1, -0.06]} rotation={[-0.5, 0, 0]} scale={[1, 1.05, 1]}>
            <sphereGeometry args={[0.59, 28, 16, 0, Math.PI * 2, 0, Math.PI * 0.52]} />
            <meshStandardMaterial color={pal.hair} roughness={0.9} />
          </mesh>
          {pal.hairStyle === 'quiff' ? (
            <RBox size={[0.7, 0.16, 0.32]} r={0.07} color={pal.hair} position={[0.06, 0.58, 0.18]} rotation={[0.35, 0, -0.15]} />
          ) : (
            <>
              <Ball r={0.2} color={pal.hair} position={[-0.38, 0.55, -0.05]} />
              <Ball r={0.2} color={pal.hair} position={[0.38, 0.55, -0.05]} />
              <RBox size={[0.9, 0.16, 0.24]} r={0.07} color={pal.hair} position={[0, 0.36, 0.38]} rotation={[0.5, 0, 0]} />
            </>
          )}
          {/* wajah */}
          {[-1, 1].map((s) => (
            <group key={s}>
              {/* mata (kelopak setengah menutup lewat scale y) */}
              <mesh position={[s * 0.21, 0.05, 0.5]} scale={[1, Math.max(0.06, 1 - lid), 0.5]}>
                <sphereGeometry args={[0.062, 14, 10]} />
                <meshStandardMaterial color="#0e0e10" roughness={0.5} />
              </mesh>
              {/* alis */}
              <RBox
                size={[0.2, 0.034, 0.03]}
                r={0.014}
                color={pal.hair}
                position={[s * 0.21, 0.16 + pose.brow * 0.07, 0.52]}
                rotation={[0, 0, -s * pose.browTilt]}
              />
            </group>
          ))}
          {/* hidung */}
          <Ball r={0.045} color={pal.skinDark} position={[0, -0.06, 0.55]} scale={[1, 0.9, 1]} />
          {/* mulut: senyum/cemberut lewat busur, terbuka saat bicara */}
          {mouthOpen > 0.2 ? (
            <mesh position={[0, -0.2, 0.52]} scale={[1.2, 0.25 + mouthOpen * 0.8, 0.5]}>
              <sphereGeometry args={[0.06, 14, 10]} />
              <meshStandardMaterial color="#4d2222" roughness={0.6} />
            </mesh>
          ) : Math.abs(smile) > 0.12 ? (
            <mesh position={[0, -0.2 + (smile > 0 ? 0.045 : -0.02), 0.525]} rotation={[0, 0, smile > 0 ? Math.PI : 0]} scale={[1, Math.abs(smile), 1]}>
              <torusGeometry args={[0.09, 0.013, 6, 16, Math.PI]} />
              <meshStandardMaterial color="#5a2a2a" roughness={0.7} />
            </mesh>
          ) : (
            <RBox size={[0.13, 0.022, 0.02]} r={0.01} color="#5a2a2a" position={[0, -0.2, 0.53]} />
          )}
        </group>
      </group>
      {/* bayangan lembut di tanah */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.015, 0]}>
        <circleGeometry args={[0.8, 24]} />
        <meshBasicMaterial color="#000" transparent opacity={0.16} />
      </mesh>
    </group>
  );
};
