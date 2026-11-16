import React from 'react';
import * as THREE from 'three';
import {AbsoluteFill, Audio, Easing, interpolate, Sequence, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import {ThreeCanvas} from '@remotion/three';
import {useThree} from '@react-three/fiber';
import {Anim} from '../three/Model';
import {Hero, PAL_KOLEKTOR, PAL_SENIMAN} from '../three/Hero';
import {SEQ_K, SEQ_S, poseAt} from '../anim';
import {MeadowSet, PlazaSet, StreetSet} from '../three/Sets';
import {Subtitle} from '../Subtitle';
import {Badge} from '../Badge';
import {Title} from '../Title';
import {makeLine} from '../lines';
import {EKSTENSI_AUDIO, LEAD, PAKAI_AUDIO, TIMED, TOTAL} from '../script';
import {
  ArCard,
  BridgeCard,
  CertCard,
  CekOtomatisCard,
  CounterCard,
  DisclaimerCard,
  FeatureCard,
  NameTag,
  NeedsCard,
  ProblemCard,
  RoomCard,
  UploadCard,
} from '../ui/Overlays';
import {LogoScreen} from '../ui/LogoScreen';
import {Phone} from '../ui/Phone';
import {Confetti, Wipe} from '../ui/Effects';

void ArCard; // dipakai sebelumnya; kini diganti layar ponsel

type V3 = [number, number, number];
type Sub = {p: [V3, V3]; l: [V3, V3]; roll?: [number, number]; fov?: [number, number]};

const sub = (p1: V3, p2: V3, l1: V3, l2: V3 = l1, roll: [number, number] = [0, 0], fov: [number, number] = [40, 40]): Sub => ({
  p: [p1, p2],
  l: [l1, l2],
  roll,
  fov,
});
const H: V3 = [0, 2.2, 0]; // titik pandang umum (dada/kepala karakter)

// Bidikan kamera per kalimat; kalimat panjang dipecah jadi 2 potongan. Kamera selalu bergerak.
const SHOTS: Sub[][] = [
  /* 0 */ [sub([-3, 2.4, 14], [1, 2.1, 10.5], [0, 1.6, 0], [0, 1.8, 0], [-0.03, 0.02])],
  /* 1 */ [sub([-1.4, 2.7, 5.8], [0.4, 2.8, 4.0], [0, 2.5, 0], [0, 2.6, 0], [-0.05, 0], [44, 36])],
  /* 2 */ [sub([5.5, 1.6, 6], [1.2, 1.9, 6.8], [3.4, 1.4, -0.8], [3.2, 1.6, -0.8], [0.05, -0.02])],
  /* 3 */ [sub([0, 6, 16], [0, 3.2, 12.5], [0, 1, 0], [0, 1.6, 0], [0, 0.03])],
  /* 4 */ [
    sub([-6, 2, 9], [-3, 2.2, 7.5], [0, 1.8, 0], [0, 2, 0], [0.06, 0.03]),
    sub([4.5, 2.4, 8], [2.5, 2.4, 6], [0, 2.1, 0], [0, 2.2, 0], [-0.05, -0.02]),
  ],
  /* 5 */ [
    sub([0, 2.6, 5.2], [0, 2.7, 4.2], [0, 2.5, 0], [0, 2.6, 0], [0, 0], [42, 34]),
    sub([0, 0.9, 6.5], [0, 1.3, 5.2], [0, 2.4, 0], [0, 2.6, 0], [0.06, 0.02]),
  ],
  /* 6 */ [sub([0, 2.4, 5], [0, 4.8, 15], [0, 2.2, 0], [0, 1.6, 0])],
  /* 7 */ [sub([3.5, 1.4, 10], [-3.5, 4.5, 14], [0, 2, -2], [0, 2.4, -2], [0.04, -0.04])],
  /* 8 */ [sub([8, 3, 14], [2, 3.4, 11], [0, 3.6, -7], [0, 3.2, -4], [0.05, 0])],
  /* 9 */ [sub([-2.5, 2.4, 7.5], [1.8, 2.6, 5.6], H, H, [-0.04, 0.02])],
  /* 10 */ [sub([0.6, 2.7, 4.8], [-0.2, 2.7, 3.9], [0, 2.6, 0], [0, 2.6, 0], [0.02, 0], [42, 34])],
  /* 11 */ [
    sub([-0.8, 2.7, 4.2], [0.8, 2.7, 4.0], [0, 2.6, 0], [0, 2.6, 0]),
    sub([3, 1.5, 7.5], [0, 2.0, 6], [0, 2.2, 0], [0, 2.4, 0], [0.07, 0.02]),
  ],
  /* 12 */ [
    sub([-10, 2.2, 9], [-6, 2.4, 10.5], [-1, 2, 0], [0, 2, 0], [-0.05, -0.02]),
    sub([10, 3, 10], [5.5, 3, 11.5], [0, 2, 0], [0, 2, 0], [0.05, 0.02]),
  ],
  /* 13 */ [sub([0, 2, 10], [0, 7, 17], [0, 1.6, -3], [0, 2.2, -3])],
  /* 14 */ [
    sub([0, 2.6, 15], [0, 3, 11.5], [0, 2, -2], [0, 2.2, 0], [0, 0.02]),
    sub([-4.5, 1.6, 8], [-2, 2.1, 7], [0, 2.2, 0], [0, 2.3, 0], [-0.06, 0.02]),
  ],
  /* 15 */ [sub([0, 2.6, 6], [0, 2.7, 4.6], [0, 2.5, 0], [0, 2.6, 0], [0, 0], [42, 34])],
  /* 16 */ [sub([0, 2.5, 12], [0, 2.7, 9.5], [0, 2, 0], [0.2, 2.1, 0], [0.05, 0.02])],
  /* 17 */ [sub([4, 2.6, 6.5], [2.6, 2.7, 4.8], [1.8, 2.5, 0], [1.8, 2.6, 0], [0.05, 0], [42, 34])],
  /* 18 */ [
    sub([-0.5, 3, 9.5], [1.5, 2.8, 7], [1.2, 2.4, 0], [1.8, 2.4, 0], [-0.04, 0.02]),
    sub([2.4, 2.7, 5], [1.8, 2.7, 4.2], [1.8, 2.6, 0], [1.8, 2.7, 0], [0, 0], [40, 34]),
  ],
  /* 19 */ [sub([5, 2.4, 8.5], [2.4, 2.4, 8.5], [1.8, 2.4, 0], [1.8, 2.4, 0], [0.04, 0])],
  /* 20 */ [sub([-1.2, 2.4, 9], [1.2, 2.4, 8], [1.8, 2.4, 0], [1.8, 2.4, 0], [-0.04, 0])],
  /* 21 */ [sub([1.8, 1.2, 7.5], [1.8, 2.6, 7.5], [1.8, 2.4, 0], [1.8, 2.4, 0])],
  /* 22 */ [sub([6, 2, 7.5], [2.8, 2.6, 8.5], [1.8, 2.4, 0], [1.8, 2.4, 0], [0.05, 0])],
  /* 23 */ [sub([0, 2.6, 13], [0, 2.8, 9.5], [0, 2.2, 0], [0, 2.3, 0], [0, 0.02])],
  /* 24 */ [sub([-1.5, 2.4, 8.5], [0.5, 2.6, 6.5], [0, 2.3, 0], [0, 2.4, 0], [-0.03, 0.02])],
  /* 25 */ [sub([0, 3, 16], [0, 6, 24], [0, 2, -3], [0, 2.4, -3])],
];

type SetName = 'meadow' | 'plaza' | 'street';
const setOf = (i: number): SetName => (i <= 7 ? 'meadow' : i <= 13 ? 'plaza' : i <= 22 ? 'street' : 'plaza');

// animasi karakter per kalimat (nama klip Kenney Blocky Characters)
const SANIM: Anim[] = [
  'idle', 'interact-right', 'idle', 'emote-no', 'emote-no', 'idle', 'emote-no', 'idle',
  'interact-right', 'emote-yes', 'idle', 'idle', 'emote-yes', 'emote-yes',
  'idle', 'idle', 'interact-right', 'idle', 'idle', 'idle', 'idle', 'idle',
  'idle', 'emote-yes', 'interact-right', 'idle',
];
const KANIM: Anim[] = [
  'idle', 'idle', 'idle', 'idle', 'idle', 'idle', 'idle', 'idle',
  'idle', 'idle', 'idle', 'idle', 'idle', 'idle',
  'idle', 'idle', 'idle', 'emote-no', 'emote-no', 'interact-right', 'emote-yes', 'idle',
  'emote-yes', 'emote-yes', 'interact-right', 'idle',
];

const lerp3 = (a: V3, b: V3, k: number): V3 => [
  a[0] + (b[0] - a[0]) * k,
  a[1] + (b[1] - a[1]) * k,
  a[2] + (b[2] - a[2]) * k,
];

const Rig: React.FC<{pos: V3; look: V3; roll: number; fov: number}> = ({pos, look, roll, fov}) => {
  const camera = useThree((s) => s.camera) as THREE.PerspectiveCamera;
  camera.position.set(...pos);
  camera.lookAt(...look);
  camera.rotateZ(roll);
  if (camera.fov !== fov) {
    camera.fov = fov;
    camera.updateProjectionMatrix();
  }
  return null;
};

const SUB_LINES = TIMED.slice(0, -1).map((t) => {
  const step = Math.max(3, Math.floor((t.to - t.from - 6) / Math.max(1, t.words)));
  return makeLine(t.text, t.from, t.to + 4, step);
});

const A = (i: number) => TIMED[i].from - 6; // awal tampil kartu
const B = (i: number) => TIMED[i].to + 12; // akhir tampil kartu
const seq = (from: number, to: number, node: React.ReactNode, key: string) => (
  <Sequence key={key} from={from} durationInFrames={Math.max(1, to - from)} layout="none">
    {node}
  </Sequence>
);
const at = (a: number, ...idx: number[]) => idx.map((i) => Math.max(0, TIMED[i].from - a));

const WALK_END = 54; // seniman berjalan masuk selama judul
const clampOpts = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;
const ease = Easing.inOut(Easing.quad);

export const Promo: React.FC = () => {
  const frame = useCurrentFrame();
  const {width, height} = useVideoConfig();

  // kalimat aktif
  let idx = 0;
  for (let i = 0; i < TIMED.length; i++) if (frame >= TIMED[i].from - 6) idx = i;
  const segStart = idx === 0 ? 0 : TIMED[idx].from - 6;
  const segEnd = idx + 1 < TIMED.length ? TIMED[idx + 1].from - 6 : TOTAL;
  const frac = interpolate(frame, [segStart, segEnd], [0, 1], clampOpts);

  // kamera: bergerak terus; kalimat panjang dipotong (cut) jadi dua sudut
  const subs = SHOTS[idx];
  const n = subs.length;
  const si = Math.min(n - 1, Math.floor(frac * n));
  const local = ease(Math.min(1, Math.max(0, frac * n - si)));
  const sh = subs[si];
  const look = lerp3(sh.l[0], sh.l[1], local);
  const pos0 = lerp3(sh.p[0], sh.p[1], local);
  // sedikit menjauh dari titik pandang supaya karakter tidak memenuhi layar
  const pos: V3 = [
    look[0] + (pos0[0] - look[0]) * 1.22,
    look[1] + (pos0[1] - look[1]) * 1.22,
    look[2] + (pos0[2] - look[2]) * 1.22,
  ];
  const roll = (sh.roll?.[0] ?? 0) + ((sh.roll?.[1] ?? 0) - (sh.roll?.[0] ?? 0)) * local;
  const fov = (sh.fov?.[0] ?? 40) + ((sh.fov?.[1] ?? 40) - (sh.fov?.[0] ?? 40)) * local;

  const loc = setOf(idx);
  const kFrom = TIMED[16].from - 12;
  const kEnd = kFrom + 46;

  // suasana waktu per lokasi
  const tod =
    loc === 'meadow'
      ? interpolate(frame, [0, TIMED[6].to, TIMED[7].to], [0, 0, 0.55], clampOpts)
      : loc === 'plaza' && idx < 14
        ? 0.55
        : loc === 'street'
          ? interpolate(frame, [A(14), TIMED[16].from + 60], [0.8, 1], clampOpts)
          : 0.9;

  const logoFrom = A(7);
  const logoTo = TIMED[7].to + 3;
  const galleryAt = TIMED[8].from - 6 - 14; // gedung "tumbuh" begitu lokasi berganti ke alun-alun
  void galleryAt;
  const phoneA = A(19);
  const phoneB = B(22);

  // posisi dan gerak karakter
  const sWalk = frame < WALK_END;
  let sPos: V3 = [0, 0, 0];
  let sRot = 0;
  let sAnim: Anim = SANIM[idx];
  if (loc === 'meadow') {
    const x = interpolate(frame, [0, WALK_END], [-8, 0], clampOpts);
    sPos = [x, 0, 0];
    sRot = sWalk ? Math.PI / 2 : interpolate(frame, [WALK_END, WALK_END + 12], [Math.PI / 2, 0], clampOpts);
    if (sWalk) sAnim = 'walk';
  } else if (loc === 'plaza') {
    sPos = idx >= 23 ? [-1.7, 0, 0] : [0, 0, 1];
  } else {
    const slide = interpolate(frame, [TIMED[16].from + 4, TIMED[16].from + 30], [0, -1.8], {...clampOpts, easing: Easing.inOut(Easing.cubic)});
    sPos = [slide, 0, 0];
  }

  let kPos: V3 = [1.8, 0, 0];
  let kRot = 0.1;
  let kAnim: Anim = KANIM[idx];
  let kShow = false;
  if (loc === 'street' && frame >= kFrom) {
    kShow = true;
    const walking = frame < kEnd;
    const x = interpolate(frame, [kFrom, kEnd], [9, 1.8], {...clampOpts, easing: Easing.out(Easing.quad)});
    kPos = [x, 0, 0];
    kRot = walking ? -Math.PI / 2 : interpolate(frame, [kEnd, kEnd + 12], [-Math.PI / 2, 0.1], clampOpts);
    if (walking) kAnim = 'walk';
  } else if (loc === 'plaza' && idx >= 23) {
    kShow = true;
    kPos = [1.7, 0, 0];
  }

  const time = frame / 30;
  const sTalk = TIMED.some((t, i) => frame >= t.from && frame < t.to && (i <= 16 || i >= 23));
  const kTalk = TIMED.some((t, i) => frame >= t.from && frame < t.to && i >= 17 && i <= 22);
  const sWalking = loc === 'meadow' && frame < WALK_END;
  const kWalkingNow = kShow && loc === 'street' && frame >= kFrom && frame < kEnd;
  const sPose = poseAt(SEQ_S, idx, frac);
  const kPose = poseAt(SEQ_K, idx, frac);

  return (
    <AbsoluteFill style={{background: '#c5d8e3'}}>
      <AbsoluteFill style={{filter: 'contrast(1.07) saturate(1.14) brightness(1.02)'}}>
      <ThreeCanvas width={width} height={height} shadows camera={{fov: 40, position: pos}}>
        <Rig pos={pos} look={look} roll={roll} fov={fov} />
        {loc === 'meadow' && <MeadowSet tod={tod} showCanvases={idx >= 2} />}
        {loc === 'plaza' && <PlazaSet tod={tod} crowd={idx === 12 || idx === 13 || idx >= 23} galleryAt={idx >= 23 ? 0 : TIMED[8].from - 6} />}
        {loc === 'street' && <StreetSet tod={tod} />}
        <Hero pose={sPose} time={time} talk={sTalk ? 1 : 0} walk={sWalking ? frame * 0.36 : null} pal={PAL_SENIMAN} position={sPos} rotY={sRot} />
        {kShow && <Hero pose={kPose} time={time} talk={kTalk ? 1 : 0} walk={kWalkingNow ? frame * 0.36 : null} pal={PAL_KOLEKTOR} position={kPos} rotY={kRot} />}
      </ThreeCanvas>
      </AbsoluteFill>

      <AbsoluteFill
        style={{
          pointerEvents: 'none',
          background: 'radial-gradient(ellipse at center, rgba(0,0,0,0) 55%, rgba(20,22,28,0.30) 100%)',
        }}
      />

      {/* kartu info dan efek */}
      {seq(A(3), B(6), <NeedsCard at={at(A(3), 3, 4, 5, 6)} />, 'needs')}
      {seq(logoFrom, logoTo, <LogoScreen />, 'logo')}
      {seq(TIMED[8].from - 6, TIMED[8].from + 56, <Confetti seed="g" />, 'conf-g')}
      {seq(A(8), B(8), <UploadCard />, 'upload')}
      {seq(A(9), B(9), <CekOtomatisCard />, 'cek')}
      {seq(A(10), B(10), <CertCard />, 'cert')}
      {seq(A(10) + 26, A(10) + 80, <Confetti count={26} seed="s" />, 'conf-s')}
      {seq(A(11), B(11), <DisclaimerCard at={[6, 26, 46]} />, 'disc')}
      {seq(A(12), B(13), <FeatureCard at={[8, 16, 24]} />, 'feat')}

      {/* peralihan seniman -> kolektor (ganti lokasi) */}
      {seq(A(14) - 8, A(14) + 12, <Wipe label="SISI LAIN" />, 'wipe')}
      {seq(A(14) + 14, B(15), <BridgeCard at={[4, 14, 26]} />, 'bridge')}
      {seq(A(16) + 4, B(16), <NameTag />, 'tag')}
      {seq(A(17), B(17), <ProblemCard at={[8, 22]} />, 'problem')}

      {seq(A(18), B(18), <RoomCard />, 'room')}
      {seq(phoneA, phoneB, <Phone cuts={[TIMED[20].from - phoneA, TIMED[21].from - phoneA, TIMED[22].from - phoneA]} />, 'phone')}
      {seq(A(23) - 6, A(23) + 12, <Wipe label="HARI 1" />, 'wipe2')}
      {seq(A(23), B(24), <CounterCard at={at(A(23), 23, 24)} />, 'counter')}
      {seq(A(25), TOTAL, <LogoScreen final />, 'final')}
      {seq(A(25) + 4, A(25) + 62, <Confetti seed="e" />, 'conf-e')}

      <Title badge="DAY 1" text="BIKIN GALERI DARI NOL" until={LEAD - 4} />
      <Badge label="DAY 1" delay={LEAD - 10} />
      <Subtitle lines={SUB_LINES} />

      {PAKAI_AUDIO &&
        TIMED.map((t, i) => (
          <Sequence key={`a${i}`} from={t.from} layout="none">
            <Audio src={staticFile(`audio/l${String(i).padStart(2, '0')}.${EKSTENSI_AUDIO}`)} />
          </Sequence>
        ))}
    </AbsoluteFill>
  );
};
