import React, {useMemo} from 'react';
import * as THREE from 'three';
import {useLoader} from '@react-three/fiber';
import {GLTFLoader} from 'three/examples/jsm/loaders/GLTFLoader.js';
import {clone as skeletonClone} from 'three/examples/jsm/utils/SkeletonUtils.js';
import {staticFile, useCurrentFrame, useVideoConfig} from 'remotion';

type V3 = [number, number, number];

/** Model GLB statis (aset Kenney, CC0) di public/models/<kit>/<nama>.glb. */
export const Model: React.FC<{
  kit: 'plat' | 'sub' | 'town' | 'char' | 'mini';
  name: string;
  position?: V3;
  rotY?: number;
  scale?: number | V3;
}> = ({kit, name, position = [0, 0, 0], rotY = 0, scale = 1}) => {
  const gltf = useLoader(GLTFLoader, staticFile(`models/${kit}/${name}.glb`));
  const obj = useMemo(() => {
    const c = gltf.scene.clone(true);
    c.traverse((o) => {
      if ((o as THREE.Mesh).isMesh) {
        o.castShadow = true;
        o.receiveShadow = true;
      }
    });
    return c;
  }, [gltf]);
  return <primitive object={obj} position={position} rotation={[0, rotY, 0]} scale={scale} />;
};

export type Anim =
  | 'idle'
  | 'walk'
  | 'sprint'
  | 'emote-yes'
  | 'emote-no'
  | 'interact-right'
  | 'interact-left'
  | 'holding-right'
  | 'pick-up'
  | 'sit'
  | 'static';

/**
 * Karakter blocky Kenney (CC0) dengan animasi sungguhan.
 * Tingginya dinormalisasi ke `height` supaya mudah diatur; menghadap +z.
 */
export const KChar: React.FC<{
  skin: string; // 'char': huruf a..r; 'mini': male-a..f / female-a..f
  kit?: 'char' | 'mini';
  anim?: Anim;
  height?: number;
  position?: V3;
  rotY?: number;
  speed?: number;
  offset?: number;
}> = ({skin, kit = 'mini', anim = 'idle', height = 3, position = [0, 0, 0], rotY = 0, speed = 1, offset = 0}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const gltf = useLoader(GLTFLoader, staticFile(`models/${kit}/character-${skin}.glb`));

  const rig = useMemo(() => {
    const scene = skeletonClone(gltf.scene) as THREE.Group;
    scene.traverse((o) => {
      if ((o as THREE.Mesh).isMesh) {
        o.castShadow = true;
        o.receiveShadow = true;
        o.frustumCulled = false;
      }
    });
    const box = new THREE.Box3().setFromObject(scene);
    const h = Math.max(0.0001, box.max.y - box.min.y);
    return {scene, mixer: new THREE.AnimationMixer(scene), k: height / h, minY: box.min.y};
  }, [gltf, height]);

  const clip = gltf.animations.find((a) => a.name === anim) ?? gltf.animations.find((a) => a.name === 'idle');
  if (clip) {
    rig.mixer.stopAllAction();
    const action = rig.mixer.clipAction(clip);
    action.play();
    rig.mixer.setTime(((frame / fps) * speed + offset) % Math.max(0.01, clip.duration));
  }

  return (
    <group position={position} rotation={[0, rotY, 0]}>
      <primitive object={rig.scene} scale={rig.k} position={[0, -rig.minY * rig.k, 0]} />
    </group>
  );
};
