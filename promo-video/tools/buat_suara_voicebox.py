"""
Membuat suara per kalimat lewat Voicebox lokal (http://127.0.0.1:17493), mesin Chatterbox multilingual.
Voicebox belum mendukung bahasa Indonesia; dipakai bahasa 'ms' (Melayu) dengan suara referensi berlogat
Indonesia (public/audio_ref/ref.mp3) supaya pelafalan mendekati Indonesia.

Pakai:  python tools/buat_suara_voicebox.py
Hasil:  public/audio/lNN.mp3 (WAV dari Voicebox disimpan apa adanya dengan ekstensi .wav), src/audio-durations.json
"""
import json
import re
import sys
import time
import wave
from pathlib import Path

import requests
from mutagen import File as MFile

BASE = "http://127.0.0.1:17493"
ROOT = Path(__file__).resolve().parent.parent
REF = ROOT / "public" / "audio_ref" / "ref.mp3"
OUT = ROOT / "public" / "audio"
LANG = "ms"
ENGINE = "chatterbox"

src = (ROOT / "src" / "script.ts").read_text(encoding="utf-8")
lines = [m.group(1) for m in re.finditer(r"/\* \d+ \*/ '(.*)',", src)]
assert lines, "LINES tidak ditemukan"


def bersih(t: str) -> str:
    t = t.replace("**", "")
    # ejaan yang membantu pelafalan
    t = t.replace("GALERIA", "Galeria").replace("AR.", "A R.")
    return t


def profil() -> str:
    for p in requests.get(f"{BASE}/profiles", timeout=20).json():
        if p["name"] == "GALERIA Ref":
            return p["id"]
    r = requests.post(
        f"{BASE}/profiles",
        json={"name": "GALERIA Ref", "language": LANG, "voice_type": "cloned", "default_engine": ENGINE},
        timeout=30,
    )
    r.raise_for_status()
    pid = r.json()["id"]
    with open(REF, "rb") as fh:
        rs = requests.post(
            f"{BASE}/profiles/{pid}/samples",
            files={"file": ("ref.mp3", fh, "audio/mpeg")},
            data={"reference_text": "Langsung dapat sertifikat digital keaslian. Cuma memastikan karya ini nggak didaftarkan dua kali."},
            timeout=120,
        )
        rs.raise_for_status()
    return pid


def generate(pid: str, teks: str) -> str:
    r = requests.post(
        f"{BASE}/generate",
        json={"profile_id": pid, "text": teks, "language": LANG, "engine": ENGINE, "normalize": True},
        timeout=60,
    )
    r.raise_for_status()
    gid = r.json()["id"]
    for _ in range(600):
        st = requests.get(f"{BASE}/generate/{gid}/status", timeout=30)
        body = st.text
        if '"completed"' in body or '"status": "completed"' in body or "completed" in body.lower():
            return gid
        if "failed" in body.lower():
            raise RuntimeError(body[:300])
        time.sleep(3)
    raise TimeoutError(gid)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    pid = profil()
    durasi = []
    for i, raw in enumerate(lines):
        teks = bersih(raw)
        gid = generate(pid, teks)
        audio = requests.get(f"{BASE}/audio/{gid}", timeout=120)
        audio.raise_for_status()
        tmp = OUT / f"l{i:02d}.wav"
        tmp.write_bytes(audio.content)
        with wave.open(str(tmp), "rb") as w:
            d = w.getnframes() / w.getframerate()
        durasi.append(round(d, 3))
        print(f"{i:02d} {d:5.2f}s  {teks}", flush=True)
    (ROOT / "src" / "audio-durations.json").write_text(json.dumps(durasi), encoding="utf-8")
    print("selesai", round(sum(durasi), 1), "detik")


if __name__ == "__main__":
    sys.exit(main())
