"""Export model terlatih ke format siap-pakai untuk ``backend/``.

Tanggung jawab file ini:
- Memuat checkpoint terbaik (``export.checkpoint``) ke arsitektur
  :class:`src.model.GaleriaArtNet`.
- Membungkus model agar ``forward`` menghasilkan **embedding** ternormalisasi
  L2 (encoder untuk Visual Search), bukan logits klasifikasi -- lihat
  ``export.output``. Normalisasi dibakukan di dalam graf yang diekspor supaya
  ``backend/`` tidak perlu mereplikasi logikanya.
- Meng-export ke:
    * TorchScript (``export.torchscript_path``) -- untuk PyTorch runtime di server.
    * ONNX (``export.onnx_path``) -- portable; bisa dilanjut ke TFLite / Core ML
      bila nanti butuh inferensi on-device.
- Verifikasi ringan: bandingkan output PyTorch vs TorchScript/ONNX pada batch
  dummy + 1 gambar asli, pastikan selisihnya kecil (< 1e-4).

CATATAN: model TIDAK jalan di HP. Artefak ini dikonsumsi ``backend/`` (FastAPI)
yang melayani endpoint Visual Search + pencarian nearest-neighbor.

Jalankan (setelah training)::

    python -m src.export --config configs/config.yaml
"""

from __future__ import annotations

import argparse

import torch
import torch.nn as nn
import torch.nn.functional as F

from .dataset import build_label_mapping
from .model import build_model, load_checkpoint
from .utils import get_logger, load_config, resolve_path


class EmbeddingWrapper(nn.Module):
    """Bungkus model agar ``forward`` mengembalikan embedding (opsional L2-normalize)."""

    def __init__(self, net: nn.Module, l2_normalize: bool = True) -> None:
        super().__init__()
        self.net = net
        self.l2_normalize = l2_normalize

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        feat = self.net.forward_features(x)
        if self.l2_normalize:
            feat = F.normalize(feat, dim=1)
        return feat


class EmbeddingAndStyleWrapper(nn.Module):
    """Bungkus model agar ``forward`` mengembalikan DUA output sekaligus dari
    SATU forward pass backbone: ``(embedding, style_probs)``.

    Backend butuh dua-duanya bersamaan (Visual Search similarity + field
    ``style_predictions`` di response) -- menyatukan ke satu graf lebih murah
    drpd inferensi terpisah 2x. Classifier dijalankan di atas fitur backbone
    MENTAH (sebelum L2-normalize), sama seperti saat training (lihat
    ``GaleriaArtNet.forward``) -- normalisasi HANYA memengaruhi output
    embedding, bukan input classifier.
    """

    def __init__(self, net: nn.Module, l2_normalize: bool = True) -> None:
        super().__init__()
        self.net = net
        self.l2_normalize = l2_normalize

    def forward(self, x: torch.Tensor) -> tuple[torch.Tensor, torch.Tensor]:
        raw_feat = self.net.forward_features(x)
        probs = F.softmax(self.net.classifier(raw_feat), dim=1)
        emb = F.normalize(raw_feat, dim=1) if self.l2_normalize else raw_feat
        return emb, probs


def _max_abs_diff(a, b) -> float:
    """Selisih absolut maksimum antara dua output model -- terima tensor
    tunggal ATAU tuple/list tensor sejajar (mis. ``(embedding, style_probs)``),
    supaya verifikasi export tetap jalan baik utk wrapper 1-output maupun
    2-output tanpa cabang kode terpisah di pemanggil.
    """
    if isinstance(a, (tuple, list)):
        return max(_max_abs_diff(x, y) for x, y in zip(a, b))
    a = a.detach().numpy() if torch.is_tensor(a) else a
    b = b.detach().numpy() if torch.is_tensor(b) else b
    return float(abs(a - b).max())


def export_torchscript(model: nn.Module, example: torch.Tensor, path: str) -> float:
    """Trace model ke TorchScript, simpan, kembalikan selisih maks vs PyTorch asli."""
    model.eval()
    ts = torch.jit.trace(model, example, check_trace=True)
    out_path = resolve_path(path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    ts.save(str(out_path))

    with torch.no_grad():
        y_ref = model(example)
        y_ts = ts(example)
    return _max_abs_diff(y_ref, y_ts)


def export_onnx(
    model: nn.Module,
    example: torch.Tensor,
    path: str,
    opset: int,
    output_names: list[str] | None = None,
) -> "float | None":
    """Export model ke ONNX (dynamic batch axis).

    ``output_names`` default ``["embedding"]`` (1 output) -- isi 2 nama
    (mis. ``["embedding", "style_probs"]``) utk model yang forward-nya
    mengembalikan tuple 2 tensor (lihat :class:`EmbeddingAndStyleWrapper`).

    Return selisih maks vs PyTorch (via onnxruntime) kalau library tersedia,
    ``None`` kalau ``onnxruntime`` tidak terpasang (export tetap jalan).
    """
    output_names = output_names or ["embedding"]
    out_path = resolve_path(path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    model.eval()
    dynamic_axes = {"image": {0: "batch"}}
    dynamic_axes.update({name: {0: "batch"} for name in output_names})
    # dynamo=False -> exporter TorchScript-based (lama), lebih stabil untuk CNN
    # feedforward biasa dan tidak butuh `onnxscript`. Exporter baru (dynamo=True)
    # juga sempat crash di konsol Windows (cp1252) gara-gara print emoji internal.
    torch.onnx.export(
        model,
        example,
        str(out_path),
        opset_version=opset,
        input_names=["image"],
        output_names=output_names,
        dynamic_axes=dynamic_axes,
        dynamo=False,
    )

    try:
        import onnxruntime as ort
    except ImportError:
        return None

    sess = ort.InferenceSession(str(out_path), providers=["CPUExecutionProvider"])
    with torch.no_grad():
        y_ref = model(example)
    y_onnx = sess.run(output_names, {"image": example.numpy()})
    if len(output_names) == 1:
        return _max_abs_diff(y_ref, y_onnx[0])
    return _max_abs_diff(y_ref, tuple(y_onnx))


def main(config_path: str) -> None:
    cfg = load_config(config_path)
    logger = get_logger("export")
    ex = cfg["export"]

    label_to_idx = build_label_mapping(cfg)
    net = build_model(cfg, num_classes=len(label_to_idx))
    ck = load_checkpoint(net, ex["checkpoint"], map_location="cpu")
    net.eval()
    logger.info(
        "Checkpoint %s dimuat (epoch=%s, %s=%s)",
        ex["checkpoint"], ck.get("epoch"), ck.get("monitor"), ck.get("monitor_value"),
    )

    output_names = ["embedding"]
    if ex["output"] == "embedding":
        model = EmbeddingWrapper(net, l2_normalize=cfg["embedding"]["l2_normalize"])
    elif ex["output"] == "embedding_and_style":
        model = EmbeddingAndStyleWrapper(net, l2_normalize=cfg["embedding"]["l2_normalize"])
        output_names = ["embedding", "style_probs"]
    else:
        model = net
    model.eval()

    size = cfg["image"]["size"]
    example = torch.randn(1, 3, size, size)

    diff_ts = export_torchscript(model, example, ex["torchscript_path"])
    logger.info("TorchScript -> %s (selisih maks vs PyTorch: %.2e)", ex["torchscript_path"], diff_ts)

    diff_onnx = export_onnx(model, example, ex["onnx_path"], ex["onnx_opset"], output_names)
    if diff_onnx is None:
        logger.info("ONNX -> %s (onnxruntime tidak ada, verifikasi dilewati)", ex["onnx_path"])
    else:
        logger.info("ONNX -> %s (selisih maks vs PyTorch: %.2e)", ex["onnx_path"], diff_onnx)

    if diff_ts > 1e-4 or (diff_onnx is not None and diff_onnx > 1e-4):
        logger.warning("Selisih ekspor > 1e-4 -- cek ulang sebelum dipakai backend/.")
    else:
        logger.info("Verifikasi OK -- artefak siap dipakai backend/.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Export model GALERIA ke TorchScript/ONNX")
    parser.add_argument("--config", default="configs/config.yaml")
    args = parser.parse_args()
    main(args.config)
