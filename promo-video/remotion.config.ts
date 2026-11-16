import {Config} from '@remotion/cli/config';

Config.setVideoImageFormat('jpeg');
// adegan 3D (three.js) butuh WebGL di Chromium tanpa kepala
Config.setChromiumOpenGlRenderer('angle');
Config.setOverwriteOutput(true);
