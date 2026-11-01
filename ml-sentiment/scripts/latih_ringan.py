"""Latih model sentimen RINGAN (TF-IDF + regresi logistik) dan ekspor bobotnya ke JSON.

Dipakai backend untuk menganalisis ulasan baru SECARA OTOMATIS saat dikirim (tanpa PyTorch di server).
Ini bukan pengganti IndoBERT: IndoBERT (``src/train.py``) tetap model utama untuk laporan; model ringan ini
dipakai selama bobot IndoBERT belum ada di server. Hasilnya diberi ``model_version = tfidf-logreg-v1``
supaya terlihat jelas model mana yang menghasilkan labelnya.

Konfigurasi SAMA dengan baseline di ``src/train.py`` (ngram 1-2, min_df=2, sublinear_tf, C=5).
Model akhir dilatih di train+val; test tetap hanya untuk metrik.

    python scripts/latih_ringan.py
"""
import json
from pathlib import Path

import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, f1_score

ROOT = Path(__file__).resolve().parents[1]
KELAS = ["negatif", "netral", "positif"]  # urutan SAMA dengan src/train.py
KELUAR = ROOT / "models" / "sentimen_tfidf.json"
# salinan untuk backend (image Docker hanya berisi backend/)
SALINAN = ROOT.parent / "backend" / "artifacts" / "sentimen_tfidf.json"


df = pd.read_csv(ROOT / "data" / "ulasan_dummy.csv")
df["y"] = df.sentimen.map({k: i for i, k in enumerate(KELAS)})
tr, va, te = (df[df.split == s] for s in ("train", "val", "test"))

# metrik jujur: latih di train, ukur di test
vec = TfidfVectorizer(ngram_range=(1, 2), min_df=2, sublinear_tf=True, lowercase=True)
lr = LogisticRegression(max_iter=2000, C=5.0, random_state=42).fit(vec.fit_transform(tr.teks), tr.y)
pred = lr.predict(vec.transform(te.teks))
akurasi, f1 = accuracy_score(te.y, pred), f1_score(te.y, pred, average="macro")
print(f"test: akurasi {akurasi:.4f}  macro-F1 {f1:.4f}  (n={len(te)})")

# model yang diekspor: train+val
tv = pd.concat([tr, va])
vec = TfidfVectorizer(ngram_range=(1, 2), min_df=2, sublinear_tf=True, lowercase=True)
lr = LogisticRegression(max_iter=2000, C=5.0, random_state=42).fit(vec.fit_transform(tv.teks), tv.y)

vocab = {k: int(v) for k, v in vec.vocabulary_.items()}
KELUAR.write_text(json.dumps({
    "model_version": "tfidf-logreg-v1",
    "kelas": KELAS,
    "vocab": vocab,
    "idf": [round(float(x), 6) for x in vec.idf_],
    "coef": [[round(float(x), 6) for x in baris] for baris in lr.coef_],
    "intercept": [round(float(x), 6) for x in lr.intercept_],
    "metrik_test": {"akurasi": round(akurasi, 4), "macro_f1": round(f1, 4), "n": int(len(te)),
                    "catatan": "data dummy sintetis -- bukan performa produksi"},
}, ensure_ascii=False), encoding="utf-8")
SALINAN.parent.mkdir(parents=True, exist_ok=True)
SALINAN.write_bytes(KELUAR.read_bytes())
print(f"Tersimpan: {KELUAR} dan {SALINAN} ({len(vocab)} fitur, {KELUAR.stat().st_size/1024:.0f} KB)")
