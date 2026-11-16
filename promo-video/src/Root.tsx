import React from 'react';
import {Composition} from 'remotion';
import {TestScene} from './scenes/TestScene';
import {Promo} from './scenes/Promo';
import {Katalog} from './scenes/Katalog';
import {TOTAL} from './script';

// 9:16, 30 fps.
export const Root: React.FC = () => {
  return (
    <>
      <Composition id="Promo" component={Promo} durationInFrames={TOTAL} fps={30} width={720} height={1280} />
      <Composition id="Katalog" component={Katalog} durationInFrames={30} fps={30} width={1280} height={720} />
      <Composition id="Uji" component={TestScene} durationInFrames={150} fps={30} width={720} height={1280} />
    </>
  );
};
