"""Definisi arsitektur PyTorch untuk Art-to-Art dan Art-to-AI.

Kelas di file ini adalah REPLIKA PERSIS dari sel notebook tempat model
aslinya dilatih -- supaya checkpoint ``.pth`` (``state_dict()`` saja, bukan
model utuh) bisa dimuat ulang dengan benar di ``src/export.py``. Kalau kelas
di sini menyimpang sedikit saja dari notebook (urutan layer, nama atribut),
``load_state_dict`` akan gagal atau -- lebih berbahaya -- berhasil tapi
memuat bobot ke posisi yang salah.

JANGAN ubah kelas ini tanpa mengubah juga notebook aslinya, atau sebaliknya.
"""

from __future__ import annotations

import torch
import torch.nn as nn
import torch.nn.functional as F
from torchvision import models


class SiameseConvNeXt(nn.Module):
    """Art-to-Art -- replika dari ``notebooks/Similarity image Art to Art/model_devArt.ipynb``.

    Backbone ConvNeXt-Tiny, classifier bawaan diganti proyeksi ke embedding
    ``embedding_dim`` (512), dilatih pakai Contrastive Loss (margin=2.0) di
    atas jarak Euclidean. ``forward_once`` (dipakai di inferensi 1-gambar,
    lihat :func:`export_art_to_art`) SUDAH mem-L2-normalize output -- jangan
    normalize dua kali di caller.
    """

    def __init__(self, embedding_dim: int = 512) -> None:
        super().__init__()
        self.backbone = models.convnext_tiny(weights=None)
        in_features = self.backbone.classifier[2].in_features
        self.backbone.classifier[2] = nn.Sequential(
            nn.Linear(in_features, 1024),
            nn.BatchNorm1d(1024),
            nn.ReLU(),
            nn.Dropout(0.3),
            nn.Linear(1024, embedding_dim),
        )

    def forward_once(self, x: torch.Tensor) -> torch.Tensor:
        embedding = self.backbone(x)
        embedding = F.normalize(embedding, p=2, dim=1)
        return embedding

    def forward(self, input1: torch.Tensor, input2: torch.Tensor) -> tuple[torch.Tensor, torch.Tensor]:
        """Dipakai HANYA saat training (pasangan gambar). Export/inferensi backend
        pakai :meth:`forward_once` (1 gambar -> 1 embedding), lihat ``export.py``.
        """
        return self.forward_once(input1), self.forward_once(input2)


def build_siamese_art_to_art(embedding_dim: int = 512) -> SiameseConvNeXt:
    return SiameseConvNeXt(embedding_dim=embedding_dim)


def build_ai_detector() -> nn.Module:
    """Art-to-AI -- replika dari ``notebooks/similarity image AI/model_devAI.ipynb``
    (``build_convnext_binary_classifier``). ConvNeXt-Tiny + classifier[2]
    diganti ``Linear(in_features, 1)`` -- 1 logit, ``sigmoid(logit)`` =
    probabilitas AI-generated (label training: 0=REAL, 1=AI).

    ``forward`` mengembalikan LOGIT MENTAH (belum di-sigmoid) -- persis
    seperti notebook, supaya kompatibel dgn ``BCEWithLogitsLoss`` kalau nanti
    perlu re-training. Sigmoid diterapkan di wrapper export (lihat
    ``export.py::AiDetectorWrapper``), bukan di sini.
    """
    model = models.convnext_tiny(weights=None)
    in_features = model.classifier[2].in_features
    model.classifier[2] = nn.Linear(in_features, 1)
    return model
