"""
Membuat suara per kalimat (edge-tts, bahasa Indonesia) dari src/script.ts.
Hasil: public/audio/lNN.mp3 dan src/audio-durations.json (durasi detik per kalimat).

Pakai:  python tools/buat_suara.py [suara] [rate]
        suara bawaan: id-ID-ArdiNeural (pria); alternatif id-ID-GadisNeural (wanita)
"""
import asyncio
import json
import re
import sys
from pathlib import Path

import edge_tts
from mutagen.mp3 import MP3

ROOT = Path(__file__).resolve().parent.parent
VOICE = sys.argv[1] if len(sys.argv) > 1 else "id-ID-ArdiNeural"
RATE = sys.argv[2] if len(sys.argv) > 2 else "+0%"

src = (ROOT / "src" / "script.ts").read_text(encoding="utf-8")
lines = [m.group(1) for m in re.finditer(r"/\* \d+ \*/ '(.*)',", src)]
assert lines, "tidak menemukan LINES di script.ts"

out_dir = ROOT / "public" / "audio"
out_dir.mkdir(parents=True, exist_ok=True)


async def main():
    durasi = []
    for i, raw in enumerate(lines):
        teks = raw.replace("**", "")
        path = out_dir / f"l{i:02d}.mp3"
        await edge_tts.Communicate(teks, VOICE, rate=RATE).save(str(path))
        d = MP3(str(path)).info.length
        durasi.append(round(d, 3))
        print(f"{i:02d} {d:5.2f}s  {teks}")
    (ROOT / "src" / "audio-durations.json").write_text(json.dumps(durasi), encoding="utf-8")
    print("selesai:", len(durasi), "berkas,", round(sum(durasi), 1), "detik total")


asyncio.run(main())
