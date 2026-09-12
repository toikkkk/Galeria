"""Definisi model: backbone pretrained (configurable) + classifier head.

Tanggung jawab file ini:
- :class:`GaleriaArtNet` -- ``nn.Module`` yang membungkus **backbone pretrained
  ImageNet** (nama dari ``cfg["model"]["name"]``) + classifier head. Dua jalur:
    * ``forward(x)``          -> logits klasifikasi (train / evaluate).
    * ``forward_features(x)`` -> embedding vektor (fitur sebelum head) untuk
      Visual Search & basis Digital Art Identity.
- :func:`build_model` -- factory dari config, mengatur mode training backbone.
- :func:`save_checkpoint` / :func:`load_checkpoint`.

Backbone yang didukung (``model.name``):
    resnet50, resnet101,
    convnext_tiny, convnext_small, convnext_base,
    efficientnet_v2_s, swin_v2_t, vit_b_16
Semua di-strip classifier-nya lalu diganti head sendiri; ``embedding_dim``
terdeteksi otomatis (nilai di config hanya informatif).

Catatan: CLAUDE.md menetapkan ResNet50 sebagai baseline yang disengaja. Backbone
lain untuk eksperimen/pembanding -- update CLAUDE.md bila salah satunya dipilih
sebagai model final.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import torch
import torch.nn as nn
from torchvision import models

from .utils import resolve_path

# name -> (constructor, nama enum weights di torchvision.models, attribut classifier)
_BACKBONES: dict[str, tuple[Any, str, str]] = {
    "resnet50": (models.resnet50, "ResNet50_Weights", "fc"),
    "resnet101": (models.resnet101, "ResNet101_Weights", "fc"),
    "convnext_tiny": (models.convnext_tiny, "ConvNeXt_Tiny_Weights", "classifier"),
    "convnext_small": (models.convnext_small, "ConvNeXt_Small_Weights", "classifier"),
    "convnext_base": (models.convnext_base, "ConvNeXt_Base_Weights", "classifier"),
    "efficientnet_v2_s": (models.efficientnet_v2_s, "EfficientNet_V2_S_Weights", "classifier"),
    "swin_v2_t": (models.swin_v2_t, "Swin_V2_T_Weights", "head"),
    "vit_b_16": (models.vit_b_16, "ViT_B_16_Weights", "heads"),
}


def _strip_classifier(model: nn.Module, attr: str) -> int:
    """Netralkan layer klasifikasi terakhir; kembalikan dimensi fitur (in_features)."""
    head = getattr(model, attr)
    if isinstance(head, nn.Linear):
        feat_dim = head.in_features
        setattr(model, attr, nn.Identity())
        return feat_dim
    if isinstance(head, nn.Sequential):
        lin_idx = max(i for i, mod in enumerate(head) if isinstance(mod, nn.Linear))
        feat_dim = head[lin_idx].in_features
        head[lin_idx] = nn.Identity()
        return feat_dim
    raise ValueError(f"tidak tahu cara strip head bertipe {type(head).__name__}")


class GaleriaArtNet(nn.Module):
    """Backbone pretrained + classifier head, dengan akses ke embedding."""

    def __init__(self, num_classes: int, cfg: dict) -> None:
        super().__init__()
        m = cfg["model"]
        name = m["name"].lower()
        if name not in _BACKBONES:
            raise ValueError(
                f"backbone '{name}' tidak dikenal. Pilihan: {list(_BACKBONES)}"
            )
        ctor, weights_enum, head_attr = _BACKBONES[name]

        weights = None
        if m.get("pretrained", True):
            weights = getattr(models, weights_enum).DEFAULT
        backbone = ctor(weights=weights)

        self.arch = name
        self.embedding_dim: int = _strip_classifier(backbone, head_attr)
        self.backbone = backbone
        self.classifier = nn.Sequential(
            nn.Dropout(p=m["dropout"]),
            nn.Linear(self.embedding_dim, num_classes),
        )
        self._configure_trainable(m)

    def _configure_trainable(self, m: dict) -> None:
        """Atur layer yang trainable sesuai ``m["train_mode"]``.

        - ``finetune_all``     : semua parameter dilatih.
        - ``freeze_backbone``  : hanya classifier head.
        - ``finetune_partial`` : ResNet -> N block terakhir (``unfreeze_last_n_blocks``);
          backbone lain -> fraksi parameter terdalam (``unfreeze_frac``, default 0.3).
        """
        mode = m["train_mode"]
        if mode == "finetune_all":
            return

        for p in self.backbone.parameters():
            p.requires_grad = False
        if mode == "freeze_backbone":
            return

        # finetune_partial
        if hasattr(self.backbone, "layer4"):  # ResNet family
            blocks = [
                self.backbone.layer4,
                self.backbone.layer3,
                self.backbone.layer2,
                self.backbone.layer1,
            ]
            for block in blocks[: int(m.get("unfreeze_last_n_blocks", 1))]:
                for p in block.parameters():
                    p.requires_grad = True
        else:  # generik: buka fraksi parameter terdalam
            params = list(self.backbone.parameters())
            frac = float(m.get("unfreeze_frac", 0.3))
            cut = int(len(params) * (1.0 - frac))
            for p in params[cut:]:
                p.requires_grad = True

    def forward_features(self, x: torch.Tensor) -> torch.Tensor:
        """Embedding sebelum classifier, shape ``(B, embedding_dim)``."""
        return self.backbone(x)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """Logits klasifikasi, shape ``(B, num_classes)``."""
        return self.classifier(self.backbone(x))


def build_model(cfg: dict, num_classes: int) -> GaleriaArtNet:
    """Factory: bangun :class:`GaleriaArtNet` dari config."""
    return GaleriaArtNet(num_classes=num_classes, cfg=cfg)


def save_checkpoint(model: nn.Module, path: str | Path, **metadata: Any) -> None:
    """Simpan ``state_dict`` model + metadata ke file ``.pth``."""
    ckpt_path = resolve_path(path)
    ckpt_path.parent.mkdir(parents=True, exist_ok=True)
    torch.save({"model_state": model.state_dict(), **metadata}, ckpt_path)


def load_checkpoint(
    model: nn.Module, path: str | Path, map_location: str = "cpu"
) -> dict[str, Any]:
    """Muat bobot ke ``model`` (in-place) dan kembalikan seluruh isi checkpoint."""
    ckpt = torch.load(resolve_path(path), map_location=map_location, weights_only=False)
    model.load_state_dict(ckpt["model_state"])
    return ckpt
