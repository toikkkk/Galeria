"""Utilitas bersama lintas-modul GALERIA CV.

Tanggung jawab file ini:
- Memuat file konfigurasi YAML (``configs/config.yaml``) menjadi dict Python.
- Menyelesaikan path relatif terhadap root project (folder ``galeria-cv/``),
  sehingga tidak ada path absolut yang di-hardcode di dalam script.
- Menyediakan helper reproducibility (``set_seed``).
- Membuat logger sederhana yang menulis ke stdout sekaligus ke file log.

Semua script (train / evaluate / embedding) mengambil konfigurasi lewat modul
ini. Tidak ada hyperparameter atau path yang boleh di-hardcode di tempat lain.
"""

from __future__ import annotations

import logging
import os
import random
from pathlib import Path
from typing import Any

import yaml

# Root project = folder galeria-cv/ (satu tingkat di atas src/).
PROJECT_ROOT: Path = Path(__file__).resolve().parent.parent


def load_config(path: str | os.PathLike = "configs/config.yaml") -> dict[str, Any]:
    """Baca file YAML konfigurasi dan kembalikan sebagai dict.

    Args:
        path: lokasi file config. Path relatif diselesaikan terhadap
            :data:`PROJECT_ROOT`.

    Returns:
        Dict berisi seluruh isi ``config.yaml``.
    """
    cfg_path = Path(path)
    if not cfg_path.is_absolute():
        cfg_path = PROJECT_ROOT / cfg_path
    with open(cfg_path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def resolve_path(path: str | os.PathLike) -> Path:
    """Ubah path dari config menjadi absolut.

    Path yang sudah absolut (mis. ``C:/wikiart_sample``) dikembalikan apa adanya;
    path relatif digabung dengan :data:`PROJECT_ROOT`.
    """
    p = Path(path)
    return p if p.is_absolute() else (PROJECT_ROOT / p)


def set_seed(seed: int = 42) -> None:
    """Set seed global (random, numpy, torch) demi hasil yang reproducible."""
    random.seed(seed)
    os.environ["PYTHONHASHSEED"] = str(seed)
    try:
        import numpy as np

        np.random.seed(seed)
    except ImportError:  # numpy belum terpasang
        pass
    try:
        import torch

        torch.manual_seed(seed)
        torch.cuda.manual_seed_all(seed)
    except ImportError:  # torch belum terpasang
        pass


def get_logger(name: str, log_file: str | os.PathLike | None = None) -> logging.Logger:
    """Buat (atau ambil) logger yang menulis ke console dan opsional ke file.

    Args:
        name: nama logger.
        log_file: path file log. Bila diberikan, direktori induknya dibuat
            otomatis. Path relatif diselesaikan terhadap :data:`PROJECT_ROOT`.
    """
    logger = logging.getLogger(name)
    if logger.handlers:  # sudah dikonfigurasi sebelumnya
        return logger

    logger.setLevel(logging.INFO)
    fmt = logging.Formatter("%(asctime)s | %(levelname)-7s | %(name)s | %(message)s")

    stream = logging.StreamHandler()
    stream.setFormatter(fmt)
    logger.addHandler(stream)

    if log_file is not None:
        log_path = resolve_path(log_file)
        log_path.parent.mkdir(parents=True, exist_ok=True)
        file_handler = logging.FileHandler(log_path, encoding="utf-8")
        file_handler.setFormatter(fmt)
        logger.addHandler(file_handler)

    return logger


def get_device(preferred: str = "cuda") -> "Any":
    """Kembalikan ``torch.device`` sesuai preferensi, fallback ke CPU bila perlu."""
    import torch

    if preferred == "cuda" and torch.cuda.is_available():
        return torch.device("cuda")
    return torch.device("cpu")
