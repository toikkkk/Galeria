"""
Mengukur durasi rekaman suara (public/audio/l00..l22) lalu menulis src/audio-durations.json,
supaya garis waktu video mengikuti rekamanmu.

Pakai:  python tools/ukur_audio.py
Format berkas yang diterima: .mp3 .wav .m4a  (nama: l00, l01, ... l22 + ekstensi)
"""
import json
import sys
import wave
from pathlib import Path

from mutagen import File as MFile

ROOT = Path(__file__).resolve().parent.parent
AUDIO = ROOT / "public" / "audio"
JUMLAH = 26


def durasi(path: Path) -> float:
    if path.suffix.lower() == ".wav":
        with wave.open(str(path), "rb") as w:
            return w.getnframes() / w.getframerate()
    f = MFile(str(path))
    return float(f.info.length)


hasil = []
hilang = []
for i in range(JUMLAH):
    ada = [p for p in AUDIO.glob(f"l{i:02d}.*") if p.suffix.lower() in (".mp3", ".wav", ".m4a")]
    if not ada:
        hilang.append(f"l{i:02d}")
        hasil.append(None)
        continue
    d = durasi(ada[0])
    hasil.append(round(d, 3))
    print(f"l{i:02d}  {d:5.2f}s  ({ada[0].name})")

if hilang:
    print("\nBELUM ADA:", ", ".join(hilang))
    sys.exit(1)

(ROOT / "src" / "audio-durations.json").write_text(json.dumps(hasil), encoding="utf-8")
print("\nselesai:", round(sum(hasil), 1), "detik total. Sekarang render ulang videonya.")
