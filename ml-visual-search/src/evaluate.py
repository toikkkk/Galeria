"""Evaluasi model terlatih pada split test.

Tanggung jawab file ini:
- Memuat checkpoint (``--checkpoint``) beserta ``label_to_idx`` dari metadata-nya.
- Inferensi pada test set (transform deterministik).
- Metrik: accuracy, top-3 accuracy, macro-F1, weighted-F1, dan
  precision/recall/F1 per kelas (scikit-learn ``classification_report``).
- Confusion matrix (baris dinormalisasi) -> ``output.confusion_matrix_path``.
- Ringkasan metrik (JSON) -> ``output.metrics_report_path``.

Cara menjalankan (dari folder ml/)::

    python -m src.evaluate --config configs/config.yaml --checkpoint checkpoints/best.pth
"""

from __future__ import annotations

import argparse
import json

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
)

from .dataset import build_label_mapping, create_dataloaders
from .model import build_model, load_checkpoint
from .utils import get_device, get_logger, load_config, resolve_path, set_seed


@torch.no_grad()
def run_inference(
    model: nn.Module,
    loader: torch.utils.data.DataLoader,
    device: torch.device,
    tta: bool = False,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Inferensi seluruh loader.

    Args:
        tta: bila True, rata-ratakan softmax dari citra asli + horizontal-flip.

    Returns:
        ``(y_true, y_pred, y_prob)`` -- y_prob shape ``(N, num_classes)``.
    """
    model.eval()
    y_true, y_pred, y_prob = [], [], []
    for images, labels in loader:
        images = images.to(device, non_blocking=True)
        probs = F.softmax(model(images), dim=1)
        if tta:
            probs = (probs + F.softmax(model(torch.flip(images, dims=[3])), dim=1)) / 2
        probs = probs.cpu().numpy()
        y_prob.append(probs)
        y_pred.extend(probs.argmax(1).tolist())
        y_true.extend(labels.tolist())
    return np.array(y_true), np.array(y_pred), np.concatenate(y_prob, axis=0)


def _top_k_accuracy(y_true: np.ndarray, y_prob: np.ndarray, k: int) -> float:
    topk = np.argsort(-y_prob, axis=1)[:, :k]
    return float(np.mean([t in row for t, row in zip(y_true, topk)]))


def compute_metrics(
    y_true: np.ndarray,
    y_pred: np.ndarray,
    y_prob: np.ndarray,
    idx_to_label: dict[int, str],
    subset_min_support: int = 8,
) -> dict:
    """accuracy, top-3 accuracy, macro/weighted-F1, report per kelas.

    ``macro_f1_subset``: macro-F1 hanya atas kelas dengan >= ``subset_min_support``
    sampel test (buang kelas 1-sampel yang variansinya menyesatkan).
    """
    labels = list(range(len(idx_to_label)))
    names = [idx_to_label[i] for i in labels]

    support = np.bincount(y_true, minlength=len(labels))
    subset = [i for i in labels if support[i] >= subset_min_support]

    onehot = np.zeros_like(y_prob)
    onehot[np.arange(len(y_true)), y_true] = 1.0

    return {
        "n_test": int(len(y_true)),
        "accuracy": float(accuracy_score(y_true, y_pred)),
        "mse": float(((y_prob - onehot) ** 2).sum(axis=1).mean()),  # Brier score
        "top3_accuracy": _top_k_accuracy(y_true, y_prob, k=3),
        "macro_f1": float(f1_score(y_true, y_pred, average="macro", zero_division=0)),
        "weighted_f1": float(f1_score(y_true, y_pred, average="weighted", zero_division=0)),
        "macro_f1_subset": float(
            f1_score(y_true, y_pred, labels=subset, average="macro", zero_division=0)
        ),
        "subset_classes": [idx_to_label[i] for i in subset],
        "subset_min_support": subset_min_support,
        "per_class": classification_report(
            y_true, y_pred, labels=labels, target_names=names,
            output_dict=True, zero_division=0,
        ),
    }


def plot_confusion_matrix(
    y_true: np.ndarray,
    y_pred: np.ndarray,
    idx_to_label: dict[int, str],
    save_path,
) -> np.ndarray:
    """Confusion matrix ternormalisasi per baris -> PNG. Return matrix mentah."""
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    labels = list(range(len(idx_to_label)))
    names = [idx_to_label[i] for i in labels]
    cm = confusion_matrix(y_true, y_pred, labels=labels)
    cm_norm = cm / cm.sum(axis=1, keepdims=True).clip(min=1)

    fig, ax = plt.subplots(figsize=(9, 8))
    try:
        import seaborn as sns

        sns.heatmap(
            cm_norm, annot=True, fmt=".2f", cmap="Blues",
            xticklabels=names, yticklabels=names, ax=ax, cbar=True,
        )
    except ImportError:
        im = ax.imshow(cm_norm, cmap="Blues")
        ax.set_xticks(labels, names, rotation=90)
        ax.set_yticks(labels, names)
        fig.colorbar(im, ax=ax)

    ax.set_xlabel("Prediksi")
    ax.set_ylabel("Aktual")
    ax.set_title("Confusion matrix (ternormalisasi per baris)")
    fig.tight_layout()
    resolve_path(save_path).parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(save_path, dpi=110)
    plt.close(fig)
    return cm


def main(config_path: str, checkpoint_path: str) -> None:
    cfg = load_config(config_path)
    set_seed(cfg["seed"])
    logger = get_logger("evaluate", cfg["output"]["log_file"])
    device = get_device(cfg["device"])

    label_to_idx = build_label_mapping(cfg)
    idx_to_label = {v: k for k, v in label_to_idx.items()}

    model = build_model(cfg, num_classes=len(label_to_idx)).to(device)
    ckpt = load_checkpoint(model, checkpoint_path, map_location=str(device))
    logger.info(
        "Checkpoint: %s (epoch=%s, %s=%s)",
        checkpoint_path, ckpt.get("epoch", "?"),
        ckpt.get("monitor", "?"), ckpt.get("monitor_value", "?"),
    )

    ev = cfg.get("eval", {})
    loaders = create_dataloaders(cfg)
    y_true, y_pred, y_prob = run_inference(
        model, loaders["test"], device, tta=ev.get("tta", False)
    )

    metrics = compute_metrics(
        y_true, y_pred, y_prob, idx_to_label,
        subset_min_support=ev.get("subset_min_support", 8),
    )
    metrics["tta"] = ev.get("tta", False)
    cm = plot_confusion_matrix(
        y_true, y_pred, idx_to_label, cfg["output"]["confusion_matrix_path"]
    )
    metrics["confusion_matrix"] = cm.tolist()
    metrics["confusion_matrix_labels"] = [idx_to_label[i] for i in range(len(idx_to_label))]
    metrics["checkpoint"] = {
        "path": checkpoint_path,
        "epoch": ckpt.get("epoch"),
        "monitor": ckpt.get("monitor"),
        "monitor_value": ckpt.get("monitor_value"),
    }
    metrics["catatan"] = (
        "Subset WikiArt 1 dari 72 shard, tidak representatif (dominan Van Gogh/"
        "Roerich/Monet), imbalance ~54x. Angka ini indikatif, jangan di-overclaim."
    )

    out = resolve_path(cfg["output"]["metrics_report_path"])
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(metrics, indent=2, ensure_ascii=False), encoding="utf-8")

    logger.info(
        "TEST (n=%d, tta=%s): acc %.3f | top3 %.3f | macro-F1 %.3f "
        "| macro-F1[support>=%d, %d kelas] %.3f | weighted-F1 %.3f",
        metrics["n_test"], metrics["tta"], metrics["accuracy"], metrics["top3_accuracy"],
        metrics["macro_f1"], metrics["subset_min_support"], len(metrics["subset_classes"]),
        metrics["macro_f1_subset"], metrics["weighted_f1"],
    )
    logger.info("Report -> %s | Confusion matrix -> %s",
                cfg["output"]["metrics_report_path"], cfg["output"]["confusion_matrix_path"])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Evaluasi model GALERIA (test set)")
    parser.add_argument("--config", default="configs/config.yaml")
    parser.add_argument("--checkpoint", default="checkpoints/best.pth")
    args = parser.parse_args()
    main(args.config, args.checkpoint)
