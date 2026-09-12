"""Dataset PyTorch untuk memuat gambar WikiArt beserta labelnya dari CSV.

Tanggung jawab file ini:
- Membaca file split CSV (train / val / test) yang berkolom:
  ``filename, artist, genre, style, artist_name, genre_name, style_name``.
- Memetakan setiap baris ke path gambar absolut di dalam ``data.image_dir``
  (default ``C:/wikiart_sample``). File gambar ASLI tidak pernah dimodifikasi.
- Meng-encode kolom target (mis. ``style``) menjadi indeks kelas integer memakai
  mapping ``label -> idx`` yang KONSISTEN antar-split (dibangun dari train,
  dipakai ulang di val/test/embedding).
- Mengembalikan ``(image_tensor, label_int)`` setelah transform diterapkan.

Komponen utama:
- :class:`WikiArtDataset`  -- ``torch.utils.data.Dataset``.
- :func:`build_label_mapping` -- buat & cache mapping ``label -> idx``.
- :func:`make_weighted_sampler` -- ``WeightedRandomSampler`` inverse-frekuensi
  kelas untuk mitigasi imbalance parah (rasio s/d 307x di label ``style``).
- :func:`create_dataloaders` -- factory DataLoader train/val/test dari config.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Callable

import numpy as np
import pandas as pd
import torch
from PIL import Image
from torch.utils.data import DataLoader, Dataset, WeightedRandomSampler

from .utils import resolve_path


class WikiArtDataset(Dataset):
    """Dataset gambar WikiArt dari satu file split CSV.

    Args:
        csv_path: path file split CSV.
        image_dir: direktori berisi file ``.jpg``.
        label_column: nama kolom target (mis. ``"style"``).
        label_to_idx: mapping ``{label -> int}``. WAJIB sama untuk semua split.
        transform: callable augmentasi/normalisasi dari :mod:`src.transforms`.
        filename_column: nama kolom berisi nama file gambar.
    """

    def __init__(
        self,
        csv_path: str | Path,
        image_dir: str | Path,
        label_column: str,
        label_to_idx: dict[str, int],
        transform: Callable | None = None,
        filename_column: str = "filename",
    ) -> None:
        self.df: pd.DataFrame = pd.read_csv(resolve_path(csv_path))
        self.image_dir: Path = resolve_path(image_dir)
        self.label_column = label_column
        self.filename_column = filename_column
        self.label_to_idx = label_to_idx
        self.transform = transform

    def __len__(self) -> int:
        return len(self.df)

    def __getitem__(self, idx: int) -> tuple[Any, int]:
        """Kembalikan ``(image, label_idx)`` untuk baris ke-``idx``."""
        row = self.df.iloc[idx]
        img_path = self.image_dir / str(row[self.filename_column])
        image = Image.open(img_path).convert("RGB")
        if self.transform is not None:
            image = self.transform(image)
        # -1 utk baris berlabel di luar label_to_idx (mis. katalog penuh yang
        # memuat kelas yang dibuang saat training/split -- tetap perlu di-embed
        # utk Visual Search meski bukan bagian dari 11 kelas terlatih).
        label = self.label_to_idx.get(row[self.label_column], -1)
        return image, label

    @property
    def num_classes(self) -> int:
        return len(self.label_to_idx)


def build_label_mapping(cfg: dict) -> dict[str, int]:
    """Bangun mapping ``{label -> idx}`` dari split train, lalu cache ke disk.

    Mapping disimpan sebagai JSON di ``data.cache_dir`` supaya train, evaluate,
    dan embedding memakai indeks kelas yang sama persis.

    Returns:
        Dict ``label_to_idx`` terurut alfabetis.
    """
    label_col = cfg["data"]["label_column"]
    cache_path = resolve_path(cfg["data"]["cache_dir"]) / f"label_to_idx__{label_col}.json"

    if cache_path.exists():
        with open(cache_path, "r", encoding="utf-8") as f:
            return json.load(f)

    train_df = pd.read_csv(resolve_path(cfg["data"]["train_csv"]))
    labels = sorted(train_df[label_col].dropna().unique().tolist())
    label_to_idx = {label: i for i, label in enumerate(labels)}

    cache_path.parent.mkdir(parents=True, exist_ok=True)
    with open(cache_path, "w", encoding="utf-8") as f:
        json.dump(label_to_idx, f, ensure_ascii=False, indent=2)
    return label_to_idx


def make_weighted_sampler(dataset: "WikiArtDataset") -> WeightedRandomSampler:
    """Buat ``WeightedRandomSampler`` berbasis inverse frekuensi kelas.

    Mitigasi imbalance parah pada training set (lihat CLAUDE.md / Data Card).
    Bobot tiap sampel = 1 / jumlah_sampel_di_kelasnya, sehingga kelas minoritas
    lebih sering ter-sampling.
    """
    idx = dataset.df[dataset.label_column].map(dataset.label_to_idx).to_numpy()
    class_count = np.bincount(idx, minlength=dataset.num_classes)
    class_weight = 1.0 / np.clip(class_count, 1, None)
    sample_weight = class_weight[idx]
    return WeightedRandomSampler(
        weights=torch.as_tensor(sample_weight, dtype=torch.double),
        num_samples=len(sample_weight),
        replacement=True,
    )


def create_dataloaders(cfg: dict) -> dict[str, DataLoader]:
    """Factory: kembalikan ``{"train": ..., "val": ..., "test": ...}`` DataLoader.

    Seluruh parameter (batch_size, num_workers, path, label_column, transform)
    diambil dari ``cfg``. Split train memakai augmentasi + (opsional)
    ``WeightedRandomSampler``; val/test memakai transform deterministik.
    """
    # Import lokal untuk menghindari circular import.
    from .transforms import build_eval_transforms, build_train_transforms

    label_to_idx = build_label_mapping(cfg)
    d = cfg["data"]
    t = cfg["train"]

    def _dataset(csv_key: str, transform: Callable) -> WikiArtDataset:
        return WikiArtDataset(
            csv_path=d[csv_key],
            image_dir=d["image_dir"],
            label_column=d["label_column"],
            label_to_idx=label_to_idx,
            transform=transform,
            filename_column=d["filename_column"],
        )

    train_ds = _dataset("train_csv", build_train_transforms(cfg))
    eval_tf = build_eval_transforms(cfg)

    common = dict(
        batch_size=t["batch_size"],
        num_workers=t["num_workers"],
        pin_memory=True,
    )

    if t.get("use_weighted_sampler", False):
        # sampler & shuffle mutually exclusive -> shuffle=False.
        train_loader = DataLoader(
            train_ds, sampler=make_weighted_sampler(train_ds), drop_last=True, **common
        )
    else:
        train_loader = DataLoader(train_ds, shuffle=True, drop_last=True, **common)

    val_loader = DataLoader(_dataset("val_csv", eval_tf), shuffle=False, **common)
    test_loader = DataLoader(_dataset("test_csv", eval_tf), shuffle=False, **common)

    return {"train": train_loader, "val": val_loader, "test": test_loader}
