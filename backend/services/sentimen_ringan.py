"""Analisis sentimen ulasan otomatis di server -- TF-IDF + regresi logistik, murni numpy (tanpa sklearn/PyTorch).

Bobot dilatih offline oleh ``ml-sentiment/scripts/latih_ringan.py`` -> ``ml-sentiment/models/sentimen_tfidf.json``
(dimuat sekali). Tokenisasi/pembobotan meniru ``TfidfVectorizer(ngram_range=(1, 2), sublinear_tf=True)``.

Ini model RINGAN pengganti sementara selama bobot IndoBERT belum ada di server; hasilnya diberi
``model_version`` sendiri (``tfidf-logreg-v1``), dan skornya di data dummy sintetis bukan performa produksi.
Kalau berkas bobot tidak ada, ``prediksi`` mengembalikan None (ulasan tetap tersimpan, status 'menunggu analisis').
"""

from __future__ import annotations

import json
import math
import os
import re
from functools import lru_cache
from pathlib import Path

import numpy as np

# Salinan di backend/artifacts ikut masuk image Docker (hanya backend/ yang disalin); yang di ml-sentiment/ adalah sumbernya.
_KANDIDAT = [
    Path(os.environ["SENTIMEN_MODEL_PATH"]) if os.environ.get("SENTIMEN_MODEL_PATH") else None,
    Path(__file__).resolve().parents[1] / "artifacts" / "sentimen_tfidf.json",
    Path(__file__).resolve().parents[2] / "ml-sentiment" / "models" / "sentimen_tfidf.json",
]
BERKAS = next((k for k in _KANDIDAT if k is not None and k.is_file()), _KANDIDAT[1])
_TOKEN = re.compile(r"(?u)\b\w\w+\b")  # sama dengan default sklearn


@lru_cache(maxsize=1)
def _muat() -> dict | None:
    if not BERKAS.is_file():
        return None
    d = json.loads(BERKAS.read_text(encoding="utf-8"))
    d["idf"] = np.asarray(d["idf"], dtype=np.float64)
    d["coef"] = np.asarray(d["coef"], dtype=np.float64)
    d["intercept"] = np.asarray(d["intercept"], dtype=np.float64)
    return d


def _fitur(teks: str, vocab: dict[str, int]) -> dict[int, int]:
    kata = _TOKEN.findall(teks.lower())
    hitung: dict[int, int] = {}
    for gram in kata + [f"{a} {b}" for a, b in zip(kata, kata[1:])]:
        i = vocab.get(gram)
        if i is not None:
            hitung[i] = hitung.get(i, 0) + 1
    return hitung


def prediksi(teks: str) -> dict | None:
    """-> {"label", "prob": {"negatif","netral","positif"}, "model_version"} atau None bila model tidak tersedia."""
    m = _muat()
    if m is None:
        return None
    hitung = _fitur(teks, m["vocab"])
    x = np.zeros(len(m["idf"]))
    for i, c in hitung.items():
        x[i] = (1.0 + math.log(c)) * m["idf"][i]
    norma = np.linalg.norm(x)
    if norma > 0:
        x /= norma
    logit = m["coef"] @ x + m["intercept"]
    e = np.exp(logit - logit.max())
    p = e / e.sum()
    kelas = m["kelas"]
    return {"label": kelas[int(p.argmax())], "prob": {k: float(v) for k, v in zip(kelas, p)}, "model_version": m["model_version"]}
