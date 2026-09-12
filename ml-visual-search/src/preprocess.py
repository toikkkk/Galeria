"""Preprocessing: "embed" gambar WikiArt ke kanvas persegi + resize, simpan ke disk.

Tanggung jawab file ini:
- Membaca setiap gambar di ``data.raw_dir`` (nama file dari ``data.metadata_csv``).
- Menerapkan :class:`src.transforms.SquarePad` -> gambar ditaruh di tengah kanvas
  PERSEGI, sisi kosong diisi padding kiri-kanan / atas-bawah. Seluruh komposisi
  lukisan terjaga, rasio aspek tidak terdistorsi (arahan dosen: "di-embed dulu").
- Me-resize hasil ke ``preprocess.out_size`` x ``preprocess.out_size``.
- Menyimpan sebagai JPEG ke ``data.processed_dir`` dengan NAMA FILE SAMA, sehingga
  ``train_split.csv`` / ``val_split.csv`` / ``test_split.csv`` yang lama tetap valid.

Dijalankan SEKALI sebelum training::

    python -m src.preprocess --config configs/config.yaml

Setelah ini, ``config.yaml`` memakai ``data.image_dir: data/processed`` dan
``image.pad_to_square: false`` (padding sudah "baked-in").
"""

from __future__ import annotations

import argparse

import pandas as pd
from PIL import Image

from .transforms import SquarePad
from .utils import get_logger, load_config, resolve_path


def process_one(
    src_path,
    dst_path,
    pad: SquarePad,
    out_size: int,
    jpeg_quality: int,
) -> None:
    """Embed 1 gambar ke kanvas persegi, resize, simpan sebagai JPEG."""
    with Image.open(src_path) as im:
        im = im.convert("RGB")
        im = pad(im)
        im = im.resize((out_size, out_size), Image.BICUBIC)
        im.save(dst_path, format="JPEG", quality=jpeg_quality)


def main(config_path: str) -> None:
    cfg = load_config(config_path)
    logger = get_logger("preprocess")
    p = cfg["preprocess"]

    raw_dir = resolve_path(cfg["data"]["raw_dir"])
    out_dir = resolve_path(cfg["data"]["processed_dir"])
    out_dir.mkdir(parents=True, exist_ok=True)

    meta = pd.read_csv(resolve_path(cfg["data"]["metadata_csv"]))
    files = meta[cfg["data"]["filename_column"]].tolist()
    pad = SquarePad(mode=p["pad_mode"], fill=p["pad_fill"])

    done, skipped, failed = 0, 0, 0
    for i, fname in enumerate(files, 1):
        dst = out_dir / fname
        if dst.exists() and not p["overwrite"]:
            skipped += 1
            continue
        try:
            process_one(raw_dir / fname, dst, pad, p["out_size"], p["jpeg_quality"])
            done += 1
        except Exception as e:  # noqa: BLE001 - laporkan & lanjut
            failed += 1
            logger.warning("Gagal proses %s: %s", fname, e)
        if i % 200 == 0:
            logger.info("... %d/%d", i, len(files))

    logger.info(
        "Selesai. diproses=%d, dilewati(sudah ada)=%d, gagal=%d -> %s",
        done, skipped, failed, out_dir,
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Preprocess (embed persegi) gambar WikiArt")
    parser.add_argument("--config", default="configs/config.yaml")
    args = parser.parse_args()
    main(args.config)
