"""Latih klasifikasi sentimen ulasan (negatif / netral / positif) dengan IndoBERT + baseline pembanding.

Alur: baca ``data/ulasan_dummy.csv`` (split train/val/test sudah tetap di CSV) ->
  (1) baseline TF-IDF + regresi logistik, (2) fine-tune IndoBERT (``indobenchmark/indobert-base-p1``).
Epoch terbaik dipilih dari macro-F1 VALIDASI; TEST dipakai SEKALI di akhir.
Keluaran: ``models/metrics.json``, ``models/indobert_sentimen/`` (bobot, di-gitignore),
``data/hasil/sentimen_ulasan.csv`` (prediksi semua 500 ulasan, dipakai ``scripts/muat_neon.py``).

    python src/train.py [--epochs 6] [--batch 16] [--max-len 64] [--lr 3e-5]
"""
from __future__ import annotations

import argparse
import json
import random
import time
from pathlib import Path

import numpy as np
import pandas as pd
import torch
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, confusion_matrix, f1_score
from torch.utils.data import DataLoader, TensorDataset
from transformers import AutoModelForSequenceClassification, AutoTokenizer, get_linear_schedule_with_warmup

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data" / "ulasan_dummy.csv"
HASIL = ROOT / "data" / "hasil" / "sentimen_ulasan.csv"
MODELS = ROOT / "models"
MODEL_NAME = "indobenchmark/indobert-base-p1"
MODEL_VERSION = "indobert-v1"
LABELS = ["negatif", "netral", "positif"]
L2I = {l: i for i, l in enumerate(LABELS)}
SEED = 42


def seed_all(seed: int) -> None:
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)


def metrik(y_true, y_pred) -> dict:
    return {
        "akurasi": round(float(accuracy_score(y_true, y_pred)), 4),
        "macro_f1": round(float(f1_score(y_true, y_pred, average="macro")), 4),
        "f1_per_kelas": {l: round(float(f), 4) for l, f in zip(LABELS, f1_score(y_true, y_pred, average=None, labels=[0, 1, 2]))},
        "confusion_matrix": confusion_matrix(y_true, y_pred, labels=[0, 1, 2]).tolist(),
    }


def bootstrap_ci(y_true, y_pred, n=1000, seed=0) -> list[float]:
    """Selang 95% macro-F1 (bootstrap atas baris test) -- test hanya 75 baris, jadi selangnya lebar."""
    rng = np.random.default_rng(seed)
    y_true, y_pred = np.asarray(y_true), np.asarray(y_pred)
    skor = []
    for _ in range(n):
        i = rng.integers(0, len(y_true), len(y_true))
        skor.append(f1_score(y_true[i], y_pred[i], average="macro"))
    return [round(float(np.percentile(skor, 2.5)), 4), round(float(np.percentile(skor, 97.5)), 4)]


def enkode(tok, teks: list[str], max_len: int):
    e = tok(teks, padding="max_length", truncation=True, max_length=max_len, return_tensors="pt")
    return e["input_ids"], e["attention_mask"]


@torch.no_grad()
def prediksi_proba(model, ids, mask, batch: int = 64) -> np.ndarray:
    model.eval()
    keluar = []
    for i in range(0, len(ids), batch):
        logits = model(input_ids=ids[i:i + batch], attention_mask=mask[i:i + batch]).logits
        keluar.append(torch.softmax(logits, dim=-1).cpu().numpy())
    return np.concatenate(keluar)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--epochs", type=int, default=6)
    ap.add_argument("--batch", type=int, default=16)
    ap.add_argument("--max-len", type=int, default=64)
    ap.add_argument("--lr", type=float, default=3e-5)
    a = ap.parse_args()
    seed_all(SEED)

    df = pd.read_csv(DATA)
    df["y"] = df["sentimen"].map(L2I)
    tr, va, te = (df[df.split == s].reset_index(drop=True) for s in ("train", "val", "test"))
    print(f"train {len(tr)} | val {len(va)} | test {len(te)}")
    hasil: dict = {"model_version": MODEL_VERSION, "model": MODEL_NAME, "n": {"train": len(tr), "val": len(va), "test": len(te)},
                   "hiperparameter": vars(a) | {"seed": SEED}}

    # ---------------------------------------------------------------- baseline
    vec = TfidfVectorizer(ngram_range=(1, 2), min_df=2, sublinear_tf=True, lowercase=True)
    Xtr = vec.fit_transform(tr.teks)
    lr = LogisticRegression(max_iter=2000, C=5.0, random_state=SEED).fit(Xtr, tr.y)
    b_val, b_te = lr.predict(vec.transform(va.teks)), lr.predict(vec.transform(te.teks))
    hasil["baseline_tfidf_logreg"] = {"val": metrik(va.y, b_val), "test": metrik(te.y, b_te),
                                      "test_macro_f1_ci95": bootstrap_ci(te.y, b_te)}
    print("baseline  val macro-F1", hasil["baseline_tfidf_logreg"]["val"]["macro_f1"],
          "| test", hasil["baseline_tfidf_logreg"]["test"]["macro_f1"])

    # ---------------------------------------------------------------- IndoBERT
    torch.set_num_threads(max(1, torch.get_num_threads()))
    tok = AutoTokenizer.from_pretrained(MODEL_NAME)
    model = AutoModelForSequenceClassification.from_pretrained(MODEL_NAME, num_labels=3)
    ids_tr, m_tr = enkode(tok, tr.teks.tolist(), a.max_len)
    ids_va, m_va = enkode(tok, va.teks.tolist(), a.max_len)
    ids_te, m_te = enkode(tok, te.teks.tolist(), a.max_len)
    loader = DataLoader(TensorDataset(ids_tr, m_tr, torch.tensor(tr.y.values)), batch_size=a.batch, shuffle=True,
                        generator=torch.Generator().manual_seed(SEED))
    opt = torch.optim.AdamW(model.parameters(), lr=a.lr, weight_decay=0.01)
    total = len(loader) * a.epochs
    sched = get_linear_schedule_with_warmup(opt, int(0.1 * total), total)

    terbaik, state_terbaik, riwayat = -1.0, None, []
    for ep in range(1, a.epochs + 1):
        model.train()
        t0, loss_sum = time.time(), 0.0
        for ids, mask, y in loader:
            opt.zero_grad()
            out = model(input_ids=ids, attention_mask=mask, labels=y)
            out.loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
            opt.step()
            sched.step()
            loss_sum += out.loss.item() * len(y)
        p_val = prediksi_proba(model, ids_va, m_va).argmax(1)
        f1 = f1_score(va.y, p_val, average="macro")
        riwayat.append({"epoch": ep, "loss_train": round(loss_sum / len(tr), 4), "val_macro_f1": round(float(f1), 4),
                        "detik": round(time.time() - t0, 1)})
        print(riwayat[-1], flush=True)
        if f1 > terbaik:
            terbaik, state_terbaik = f1, {k: v.detach().clone() for k, v in model.state_dict().items()}
    model.load_state_dict(state_terbaik)
    hasil["riwayat_epoch"] = riwayat
    hasil["epoch_terbaik"] = int(np.argmax([r["val_macro_f1"] for r in riwayat]) + 1)

    p_va = prediksi_proba(model, ids_va, m_va).argmax(1)
    p_te = prediksi_proba(model, ids_te, m_te).argmax(1)
    hasil["indobert"] = {"val": metrik(va.y, p_va), "test": metrik(te.y, p_te), "test_macro_f1_ci95": bootstrap_ci(te.y, p_te)}
    print("IndoBERT  val macro-F1", hasil["indobert"]["val"]["macro_f1"], "| test", hasil["indobert"]["test"]["macro_f1"])

    # ---------------------------------------------------------------- simpan
    MODELS.mkdir(exist_ok=True)
    model.save_pretrained(MODELS / "indobert_sentimen")
    tok.save_pretrained(MODELS / "indobert_sentimen")
    (MODELS / "metrics.json").write_text(json.dumps(hasil, ensure_ascii=False, indent=2), encoding="utf-8")

    ids_all, m_all = enkode(tok, df.teks.tolist(), a.max_len)
    proba = prediksi_proba(model, ids_all, m_all)
    out = df[["ulasan_id", "transaksi_id", "karya_id", "kolektor_id", "seniman_id", "teks", "rating", "sentimen", "split", "created_at"]].copy()
    out["sentimen_prediksi"] = [LABELS[i] for i in proba.argmax(1)]
    for i, l in enumerate(LABELS):
        out[f"prob_{l}"] = proba[:, i].round(4)
    out["model_version"] = MODEL_VERSION
    HASIL.parent.mkdir(parents=True, exist_ok=True)
    out.to_csv(HASIL, index=False, encoding="utf-8")
    print(f"selesai -> {MODELS / 'metrics.json'} , {HASIL}")


if __name__ == "__main__":
    main()
