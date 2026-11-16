import React from 'react';
import * as THREE from 'three';

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

/** Warna tanah mengikuti suasana waktu (0 pagi mendung, 0.5 cerah, 1 senja). */
export const groundColor = (tod: number, stops = ['#9aa458', '#a9b455', '#b9ae52']): THREE.Color => mixStops(stops, tod);

/** Langit, kabut, dan cahaya (matahari + bayangan) untuk satu lokasi. Lokasi selalu berpusat di (0,0,0). */
export const Atmosphere: React.FC<{tod: number; fogNear?: number; fogFar?: number}> = ({tod, fogNear = 26, fogFar = 90}) => {
  const sky = mixStops(['#aebbc4', '#bcd6e8', '#f2c58f'], tod);
  const fog = mixStops(['#cfd3c4', '#dfe6d0', '#f1d2a8'], tod);
  const sun = mixStops(['#e8eef2', '#fff1d6', '#ffb870'], tod);
  const sunI = numStops([1.7, 2.4, 2.7], tod);
  const hemiI = numStops([0.95, 1.1, 0.9], tod);
  return (
    <>
      <color attach="background" args={[sky]} />
      <fog attach="fog" args={[fog, fogNear, fogFar]} />
      <hemisphereLight args={['#e6eef4', '#8f9c4a', hemiI]} />
      <ambientLight intensity={0.25} />
      <directionalLight
        position={[-9, 14, 10]}
        intensity={sunI}
        color={sun}
        castShadow
        shadow-mapSize-width={2048}
        shadow-mapSize-height={2048}
        shadow-camera-left={-22}
        shadow-camera-right={22}
        shadow-camera-top={22}
        shadow-camera-bottom={-22}
        shadow-camera-near={1}
        shadow-camera-far={60}
        shadow-bias={-0.0004}
      />
    </>
  );
};
