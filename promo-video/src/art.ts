import * as THREE from 'three';
import {random} from 'remotion';

const PALS = [
  ['#1f3a5f', '#f2c14e', '#e4572e', '#f6f1e9'],
  ['#2d6a4f', '#f4d35e', '#ee964b', '#faf0ca'],
  ['#5b2a86', '#ffb703', '#fb8500', '#e9d8fd'],
  ['#0b3954', '#bfd7ea', '#ff6663', '#e0ff4f'],
  ['#3d405b', '#e07a5f', '#f2cc8f', '#81b29a'],
];

/** Lukisan abstrak prosedural (ilustrasi), deterministik per seed. */
export const paintCanvas = (seed: number, w = 256, h = 320): HTMLCanvasElement => {
  const c = document.createElement('canvas');
  c.width = w;
  c.height = h;
  const g = c.getContext('2d')!;
  const p = PALS[seed % PALS.length];
  const grad = g.createLinearGradient(0, 0, 0, h);
  grad.addColorStop(0, p[0]);
  grad.addColorStop(1, p[3]);
  g.fillStyle = grad;
  g.fillRect(0, 0, w, h);
  for (let i = 0; i < 6; i++) {
    g.globalAlpha = 0.9;
    g.fillStyle = p[1 + (i % 3)];
    const x = random(`px${seed}-${i}`) * w;
    const y = random(`py${seed}-${i}`) * h;
    const r = (0.12 + random(`pr${seed}-${i}`) * 0.25) * Math.min(w, h);
    g.beginPath();
    if (i % 2) {
      g.arc(x, y, r, 0, Math.PI * 2);
    } else {
      g.rect(x - r, y - r * 0.6, r * 2, r * 1.2);
    }
    g.fill();
  }
  g.globalAlpha = 1;
  return c;
};

const cache = new Map<string, string>();
export const paintUrl = (seed: number, w = 256, h = 320): string => {
  const key = `${seed}-${w}-${h}`;
  let v = cache.get(key);
  if (!v) {
    v = paintCanvas(seed, w, h).toDataURL('image/png');
    cache.set(key, v);
  }
  return v;
};

export const paintTexture = (seed: number): THREE.CanvasTexture => {
  const t = new THREE.CanvasTexture(paintCanvas(seed));
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
};
