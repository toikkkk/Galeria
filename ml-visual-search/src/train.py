"""Training loop GALERIA — klasifikasi style WikiArt (pretext task Visual Search).

Tanggung jawab file ini:
- Membaca ``configs/config.yaml`` (via :func:`src.utils.load_config`).
- Menyiapkan seed, device, logger, DataLoader
  (:func:`src.dataset.create_dataloaders`), model
  (:func:`src.model.build_model`), loss (CrossEntropy + label smoothing),
  optimizer (AdamW/Adam/SGD), scheduler (cosine/step), mixed precision (AMP).
- Loop epoch: :func:`train_one_epoch` + :func:`validate`, mencatat metrik
  (loss, accuracy, macro-F1) ke log & ``outputs/history.json``.
- Early stopping + simpan best checkpoint ke ``checkpoints/best.pth`` sesuai
  ``checkpoint.monitor``; selalu simpan ``checkpoints/last.pth``.
- Menyimpan kurva loss/metrik ke ``outputs/training_history.png``.

Cara menjalankan (dari folder ml/)::

    python -m src.train --config configs/config.yaml
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from sklearn.metrics import accuracy_score, f1_score
from tqdm import tqdm

from .dataset import build_label_mapping, create_dataloaders
from .model import build_model, save_checkpoint
from .utils import get_device, get_logger, load_config, resolve_path, set_seed


# --------------------------------------------------------------------------- #
# Builders
# --------------------------------------------------------------------------- #
def build_optimizer(cfg: dict, model: nn.Module) -> torch.optim.Optimizer:
    """Optimizer sesuai config, HANYA untuk parameter ``requires_grad``.

    Differential LR: parameter ``classifier`` (head) pakai ``learning_rate``,
    parameter backbone pakai ``learning_rate * backbone_lr_mult`` (default 1.0).
    """
    t = cfg["train"]
    lr = t["learning_rate"]
    mult = t.get("backbone_lr_mult", 1.0)

    head, backbone = [], []
    for name_, p in model.named_parameters():
        if not p.requires_grad:
            continue
        (head if name_.startswith("classifier") else backbone).append(p)

    groups = [{"params": head, "lr": lr}]
    if backbone:
        groups.append({"params": backbone, "lr": lr * mult})

    name = t["optimizer"].lower()
    wd = t["weight_decay"]
    if name == "adamw":
        return torch.optim.AdamW(groups, lr=lr, weight_decay=wd)
    if name == "adam":
        return torch.optim.Adam(groups, lr=lr, weight_decay=wd)
    if name == "sgd":
        return torch.optim.SGD(groups, lr=lr, momentum=0.9, weight_decay=wd)
    raise ValueError(f"optimizer tidak dikenal: {t['optimizer']}")


def build_scheduler(cfg: dict, optimizer: torch.optim.Optimizer):
    """LR scheduler sesuai ``cfg['train']['scheduler']`` (cosine / step / none)."""
    t = cfg["train"]
    kind = str(t.get("scheduler", "none")).lower()
    if kind == "cosine":
        return torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=t["epochs"])
    if kind == "step":
        return torch.optim.lr_scheduler.StepLR(
            optimizer, step_size=t["step_size"], gamma=t["gamma"]
        )
    return None


def make_scaler(device_type: str, enabled: bool):
    """GradScaler yang kompatibel torch < 2.4 (torch.cuda.amp) & >= 2.4 (torch.amp)."""
    if hasattr(torch.amp, "GradScaler"):
        return torch.amp.GradScaler(device_type, enabled=enabled)
    return torch.cuda.amp.GradScaler(enabled=enabled)  # torch < 2.4


# --------------------------------------------------------------------------- #
# Loop satu epoch
# --------------------------------------------------------------------------- #
def _metrics(
    y_true: list[int], y_pred: list[int], y_prob: "np.ndarray | None" = None
) -> dict[str, float]:
    """accuracy, macro-F1, dan (bila y_prob diberi) ``mse`` = Brier score

    ``mse`` = rata-rata ||softmax(prob) - one_hot(label)||^2 -- error kuadrat
    prediksi terhadap target; turun tiap epoch = bukti gradient descent bekerja.
    """
    out = {
        "accuracy": float(accuracy_score(y_true, y_pred)),
        "macro_f1": float(f1_score(y_true, y_pred, average="macro", zero_division=0)),
    }
    if y_prob is not None and len(y_prob):
        yp = np.asarray(y_prob, dtype=np.float64)
        onehot = np.zeros_like(yp)
        onehot[np.arange(len(y_true)), np.asarray(y_true)] = 1.0
        out["mse"] = float(((yp - onehot) ** 2).sum(axis=1).mean())
    return out


def train_one_epoch(
    model: nn.Module,
    loader: torch.utils.data.DataLoader,
    criterion: nn.Module,
    optimizer: torch.optim.Optimizer,
    device: torch.device,
    scaler,
    grad_clip_norm: float | None = None,
    step_losses: "list[float] | None" = None,
) -> dict[str, float]:
    """Satu epoch training. Return ``{loss, mse, accuracy, macro_f1}``.

    Bila ``step_losses`` (list) diberikan, loss tiap batch di-append ke situ
    (untuk plot loss-per-step -> visualisasi gradient descent).
    """
    model.train()
    use_amp = scaler.is_enabled()
    total_loss, n = 0.0, 0
    y_true: list[int] = []
    y_pred: list[int] = []
    y_prob: list = []

    for images, labels in tqdm(loader, desc="train", leave=False):
        images = images.to(device, non_blocking=True)
        labels = labels.to(device, non_blocking=True)

        optimizer.zero_grad(set_to_none=True)
        with torch.autocast(device_type=device.type, enabled=use_amp):
            logits = model(images)
            loss = criterion(logits, labels)

        scaler.scale(loss).backward()
        if grad_clip_norm:
            scaler.unscale_(optimizer)
            nn.utils.clip_grad_norm_(
                (p for p in model.parameters() if p.requires_grad), grad_clip_norm
            )
        scaler.step(optimizer)
        scaler.update()

        bs = labels.size(0)
        total_loss += loss.item() * bs
        n += bs
        if step_losses is not None:
            step_losses.append(loss.item())
        y_true.extend(labels.tolist())
        y_pred.extend(logits.argmax(1).tolist())
        y_prob.extend(F.softmax(logits.float(), dim=1).detach().cpu().numpy())

    return {"loss": total_loss / max(n, 1), **_metrics(y_true, y_pred, np.asarray(y_prob))}


@torch.no_grad()
def validate(
    model: nn.Module,
    loader: torch.utils.data.DataLoader,
    criterion: nn.Module,
    device: torch.device,
) -> dict[str, float]:
    """Evaluasi split val. Return ``{loss, mse, accuracy, macro_f1}``."""
    model.eval()
    total_loss, n = 0.0, 0
    y_true: list[int] = []
    y_pred: list[int] = []
    y_prob: list = []

    for images, labels in tqdm(loader, desc="val", leave=False):
        images = images.to(device, non_blocking=True)
        labels = labels.to(device, non_blocking=True)
        logits = model(images)
        loss = criterion(logits, labels)

        bs = labels.size(0)
        total_loss += loss.item() * bs
        n += bs
        y_true.extend(labels.tolist())
        y_pred.extend(logits.argmax(1).tolist())
        y_prob.extend(F.softmax(logits.float(), dim=1).cpu().numpy())

    return {"loss": total_loss / max(n, 1), **_metrics(y_true, y_pred, np.asarray(y_prob))}


# --------------------------------------------------------------------------- #
# Plot
# --------------------------------------------------------------------------- #
def plot_history(
    history: dict[str, list[float]],
    save_path: Path,
    step_losses: "list[float] | None" = None,
) -> None:
    """Learning curve: loss (train/val), MSE/Brier (train/val), macro-F1 (train/val).

    Bila ``step_losses`` diberi, panel ke-4 = loss per training step (bukti
    gradient descent).
    """
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    epochs = range(1, len(history["train_loss"]) + 1)
    has_step = bool(step_losses)
    ncols = 4 if has_step else 3
    fig, axes = plt.subplots(1, ncols, figsize=(4.2 * ncols, 4.2))

    axes[0].plot(epochs, history["train_loss"], "o-", ms=3, label="train")
    axes[0].plot(epochs, history["val_loss"], "s-", ms=3, label="val")
    axes[0].set_title("Loss (CrossEntropy)")
    axes[0].set_xlabel("epoch"); axes[0].legend()

    if "train_mse" in history:
        axes[1].plot(epochs, history["train_mse"], "o-", ms=3, label="train")
        axes[1].plot(epochs, history["val_mse"], "s-", ms=3, label="val")
    axes[1].set_title("MSE (Brier score) — turun = gradient descent")
    axes[1].set_xlabel("epoch"); axes[1].legend()

    axes[2].plot(epochs, history["train_macro_f1"], "o-", ms=3, label="train")
    axes[2].plot(epochs, history["val_macro_f1"], "s-", ms=3, label="val")
    axes[2].set_title("macro-F1 (gap = overfitting)")
    axes[2].set_xlabel("epoch"); axes[2].set_ylim(0, 1); axes[2].legend()

    if has_step:
        axes[3].plot(step_losses, lw=0.5, alpha=0.4, color="tab:gray")
        k = max(1, len(step_losses) // 50)
        if len(step_losses) > k:
            import numpy as _np

            ma = _np.convolve(step_losses, _np.ones(k) / k, mode="valid")
            axes[3].plot(range(k - 1, len(step_losses)), ma, lw=2, color="tab:red")
        axes[3].set_title(f"Loss per step (moving avg {k})")
        axes[3].set_xlabel("training step (batch)")

    fig.tight_layout()
    save_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(save_path, dpi=110)
    plt.close(fig)


# --------------------------------------------------------------------------- #
# Main
# --------------------------------------------------------------------------- #
def main(config_path: str) -> None:
    cfg = load_config(config_path)
    set_seed(cfg["seed"])
    logger = get_logger("train", cfg["output"]["log_file"])
    device = get_device(cfg["device"])
    logger.info("Device: %s", device)

    label_to_idx = build_label_mapping(cfg)
    num_classes = len(label_to_idx)
    logger.info("Kelas (%s): %d", cfg["data"]["label_column"], num_classes)

    loaders = create_dataloaders(cfg)
    logger.info(
        "Batch: train=%d val=%d (batch_size=%d)",
        len(loaders["train"]), len(loaders["val"]), cfg["train"]["batch_size"],
    )

    model = build_model(cfg, num_classes=num_classes).to(device)
    n_train = sum(p.numel() for p in model.parameters() if p.requires_grad)
    n_total = sum(p.numel() for p in model.parameters())
    logger.info("Parameter trainable: %.2fM / %.2fM", n_train / 1e6, n_total / 1e6)

    criterion = nn.CrossEntropyLoss(label_smoothing=cfg["train"]["label_smoothing"])
    optimizer = build_optimizer(cfg, model)
    scheduler = build_scheduler(cfg, optimizer)
    use_amp = bool(cfg["train"]["mixed_precision"]) and device.type == "cuda"
    scaler = make_scaler(device.type, use_amp)

    if cfg["checkpoint"].get("resume_from"):
        from .model import load_checkpoint

        ck = load_checkpoint(model, cfg["checkpoint"]["resume_from"], map_location=str(device))
        logger.info("Resume dari %s (epoch %s)", cfg["checkpoint"]["resume_from"], ck.get("epoch"))

    monitor = cfg["checkpoint"]["monitor"]              # mis. "val_macro_f1"
    monitor_key = monitor.removeprefix("val_")          # -> "macro_f1"
    grad_clip = cfg["train"].get("grad_clip_norm") or None
    patience = cfg["train"]["early_stopping_patience"]

    ckpt_dir = resolve_path(cfg["checkpoint"]["dir"])
    history: dict[str, list[float]] = {
        k: [] for k in
        ["train_loss", "val_loss", "train_mse", "val_mse",
         "train_accuracy", "val_accuracy", "train_macro_f1", "val_macro_f1", "lr"]
    }
    step_losses: list[float] = []
    best_metric = -math.inf
    epochs_no_improve = 0

    for epoch in range(1, cfg["train"]["epochs"] + 1):
        tr = train_one_epoch(
            model, loaders["train"], criterion, optimizer, device, scaler, grad_clip,
            step_losses=step_losses,
        )
        va = validate(model, loaders["val"], criterion, device)
        lr_now = optimizer.param_groups[0]["lr"]
        if scheduler is not None:
            scheduler.step()

        for k in ("loss", "mse", "accuracy", "macro_f1"):
            history[f"train_{k}"].append(tr.get(k, float("nan")))
            history[f"val_{k}"].append(va.get(k, float("nan")))
        history["lr"].append(lr_now)

        logger.info(
            "epoch %2d/%d | lr %.2e | train loss %.4f mse %.4f acc %.3f f1 %.3f "
            "| val loss %.4f mse %.4f acc %.3f f1 %.3f",
            epoch, cfg["train"]["epochs"], lr_now,
            tr["loss"], tr.get("mse", float("nan")), tr["accuracy"], tr["macro_f1"],
            va["loss"], va.get("mse", float("nan")), va["accuracy"], va["macro_f1"],
        )

        current = va[monitor_key]
        if current > best_metric:
            best_metric = current
            epochs_no_improve = 0
            save_checkpoint(
                model, ckpt_dir / "best.pth",
                epoch=epoch, monitor=monitor, monitor_value=current,
                val_metrics=va, label_to_idx=label_to_idx, config=cfg,
            )
            logger.info("  -> best (%s=%.4f) disimpan ke checkpoints/best.pth", monitor, current)
        else:
            epochs_no_improve += 1
            if epochs_no_improve >= patience:
                logger.info("Early stopping di epoch %d (tidak membaik %d epoch).", epoch, patience)
                break

    save_checkpoint(
        model, ckpt_dir / "last.pth",
        epoch=epoch, val_metrics=va, label_to_idx=label_to_idx, config=cfg,
    )
    hist_path = resolve_path(cfg["output"]["history_json_path"])
    hist_path.parent.mkdir(parents=True, exist_ok=True)
    hist_path.write_text(
        json.dumps({**history, "step_losses": step_losses}, indent=2), encoding="utf-8"
    )
    plot_history(history, resolve_path(cfg["output"]["history_plot_path"]), step_losses)
    logger.info("Selesai. best %s = %.4f | history -> %s",
                monitor, best_metric, cfg["output"]["history_plot_path"])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Training model GALERIA (style classification)")
    parser.add_argument("--config", default="configs/config.yaml", help="path config.yaml")
    args = parser.parse_args()
    main(args.config)
