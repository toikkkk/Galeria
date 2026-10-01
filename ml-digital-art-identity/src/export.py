"""Export checkpoint .pth (Art-to-Art & Art-to-AI) ke ONNX siap-pakai ``backend/``.

Pola PERSIS mengikuti ``ml-visual-search/src/export.py`` -- dynamic batch
axis, verifikasi selisih PyTorch vs ONNX, opset dari config. Beda dari situ:
ada DUA model independen di sini (arsitektur beda, preprocessing beda), jadi
dua fungsi export terpisah, bukan satu ``main()`` yang dipakai bersama.

Jalankan (dari folder ``ml-digital-art-identity/``, venv dgn torch+torchvision
+onnx terpasang)::

    python -m src.export --config configs/config.yaml
"""

from __future__ import annotations

import argparse
from pathlib import Path

import torch
import torch.nn as nn
import yaml

from .models import SiameseConvNeXt, build_ai_detector, build_siamese_art_to_art

BASE_DIR = Path(__file__).resolve().parent.parent


def _resolve(path: str) -> Path:
    p = Path(path)
    return p if p.is_absolute() else BASE_DIR / p


def _max_abs_diff(a, b) -> float:
    a = a.detach().numpy() if torch.is_tensor(a) else a
    b = b.detach().numpy() if torch.is_tensor(b) else b
    return float(abs(a - b).max())


def _export_onnx(model: nn.Module, example: torch.Tensor, out_path: Path, opset: int) -> float | None:
    model.eval()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    torch.onnx.export(
        model,
        example,
        str(out_path),
        opset_version=opset,
        input_names=["image"],
        output_names=["output"],
        dynamic_axes={"image": {0: "batch"}, "output": {0: "batch"}},
        dynamo=False,  # exporter TorchScript-based -- lebih stabil, lihat catatan ml-visual-search/src/export.py
    )
    try:
        import onnxruntime as ort
    except ImportError:
        return None
    sess = ort.InferenceSession(str(out_path), providers=["CPUExecutionProvider"])
    with torch.no_grad():
        y_ref = model(example)
    y_onnx = sess.run(["output"], {"image": example.numpy()})[0]
    return _max_abs_diff(y_ref, y_onnx)


class _ForwardOnceWrapper(nn.Module):
    """Bungkus ``SiameseConvNeXt`` supaya graf ONNX cuma expose ``forward_once``
    (1 gambar -> 1 embedding 512-d, sudah L2-normalized) -- backend butuh
    inferensi 1 gambar per request (bandingkan ke katalog di DB via pgvector),
    bukan pasangan gambar seperti saat training Siamese.
    """

    def __init__(self, net: SiameseConvNeXt) -> None:
        super().__init__()
        self.net = net

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.net.forward_once(x)


class _SigmoidWrapper(nn.Module):
    """Bungkus classifier Art-to-AI supaya graf ONNX langsung mengeluarkan
    PROBABILITAS (sigmoid sudah diterapkan), bukan logit mentah -- backend
    tinggal baca angka 0..1 tanpa risiko lupa/salah menerapkan sigmoid sendiri.
    """

    def __init__(self, net: nn.Module) -> None:
        super().__init__()
        self.net = net

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        logit = self.net(x)
        return torch.sigmoid(logit)


def export_art_to_art(cfg: dict) -> None:
    c = cfg["art_to_art"]
    net = build_siamese_art_to_art(embedding_dim=c["embedding_dim"])
    ckpt_path = _resolve(c["checkpoint"])
    state_dict = torch.load(str(ckpt_path), map_location="cpu")
    net.load_state_dict(state_dict)
    net.eval()

    model = _ForwardOnceWrapper(net)
    model.eval()

    size = c["image"]["size"]
    example = torch.randn(1, 3, size, size)
    out_path = _resolve(c["export"]["onnx_path"])
    diff = _export_onnx(model, example, out_path, c["export"]["onnx_opset"])

    print(f"[art_to_art] checkpoint={ckpt_path}")
    print(f"[art_to_art] ONNX -> {out_path} (selisih maks vs PyTorch: {diff})")
    if diff is not None and diff > 1e-4:
        print("[art_to_art] PERINGATAN: selisih ekspor > 1e-4 -- cek ulang sebelum dipakai backend/.")


def export_art_to_ai(cfg: dict) -> None:
    c = cfg["art_to_ai"]
    net = build_ai_detector()
    ckpt_path = _resolve(c["checkpoint"])
    state_dict = torch.load(str(ckpt_path), map_location="cpu")
    net.load_state_dict(state_dict)
    net.eval()

    model = _SigmoidWrapper(net)
    model.eval()

    size = c["image"]["size"]
    example = torch.randn(1, 3, size, size)
    out_path = _resolve(c["export"]["onnx_path"])
    diff = _export_onnx(model, example, out_path, c["export"]["onnx_opset"])

    print(f"[art_to_ai] checkpoint={ckpt_path}")
    print(f"[art_to_ai] ONNX -> {out_path} (selisih maks vs PyTorch: {diff})")
    if diff is not None and diff > 1e-4:
        print("[art_to_ai] PERINGATAN: selisih ekspor > 1e-4 -- cek ulang sebelum dipakai backend/.")


def main(config_path: str) -> None:
    with open(_resolve(config_path), "r", encoding="utf-8") as f:
        cfg = yaml.safe_load(f)
    export_art_to_art(cfg)
    export_art_to_ai(cfg)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Export Art-to-Art & Art-to-AI ke ONNX")
    parser.add_argument("--config", default="configs/config.yaml")
    args = parser.parse_args()
    main(args.config)
