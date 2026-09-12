"""Business logic Visual Search: muat model sekali saat startup, layani inferensi.

Tanggung jawab file ini:
- Muat ``model.onnx`` (ONNXRuntime, bukan PyTorch -- server tidak perlu
  training stack penuh) + index katalog (``catalog_embeddings.npz``) SEKALI
  saat aplikasi start (lihat ``main.py`` -- jangan reload per-request).
- Preprocessing gambar upload -> tensor (SquarePad + resize 224 + normalize
  ImageNet) IDENTIK dengan ``ml-visual-search/src/transforms.py``. Kalau
  preprocessing di sini beda sedikit saja dari training, hasil model bisa
  meleset -- pastikan konstanta (mean/std/ukuran) disalin dari
  ``ml-visual-search/configs/config.yaml``, jangan ditebak ulang.
- Cari nearest-neighbor ke katalog + hitung ``confidence_verdict`` (logic yang
  sama seperti ``ml-visual-search/src/embedding.py``, supaya jawaban ke user
  konsisten dengan yang sudah divalidasi di notebook demo).

Artefak yang dikonsumsi (hasil dari ``ml-visual-search/``):
    ../ml-visual-search/export/model.onnx
    ../ml-visual-search/data/cache/catalog_embeddings.npz
    ../ml-visual-search/data/cache/label_to_idx__style_name.json
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

# Samakan persis dengan ml-visual-search/configs/config.yaml [image]
IMAGE_SIZE = 224
IMAGENET_MEAN = (0.485, 0.456, 0.406)
IMAGENET_STD = (0.229, 0.224, 0.225)


class VisualSearchService:
    """Singleton-ish service: 1 instance dibuat saat startup, dipakai semua request."""

    def __init__(
        self,
        model_path: str | Path,
        catalog_path: str | Path,
        label_map_path: str | Path,
    ) -> None:
        self.model_path = Path(model_path)
        self.catalog_path = Path(catalog_path)
        self.label_map_path = Path(label_map_path)
        self._session = None       # onnxruntime.InferenceSession, di-set di load()
        self._cat_emb: np.ndarray | None = None
        self._cat_filenames: np.ndarray | None = None
        self._idx_to_label: dict[int, str] | None = None

    def load(self) -> None:
        """Panggil sekali di FastAPI startup event."""
        # TODO:
        #   import onnxruntime as ort, json
        #   self._session = ort.InferenceSession(str(self.model_path),
        #                                        providers=["CPUExecutionProvider"])
        #   cat = np.load(self.catalog_path)
        #   self._cat_emb, self._cat_filenames = cat["embeddings"], cat["filenames"]
        #   label_to_idx = json.loads(self.label_map_path.read_text())
        #   self._idx_to_label = {v: k for k, v in label_to_idx.items()}
        raise NotImplementedError

    def _preprocess(self, image: Image.Image) -> np.ndarray:
        """Ganti versi ``build_capture_simulation_transform``/``eval_tf`` (PyTorch)
        jadi numpy murni (server tidak load torch). SquarePad -> resize -> normalize.
        """
        # TODO: port logic SquarePad dari ml-visual-search/src/transforms.py ke numpy/PIL saja.
        raise NotImplementedError

    def search(self, image: Image.Image, top_k: int = 5):
        """Prediksi style + cari ke katalog. Return dict siap dipetakan ke
        ``schemas.visual_search.VisualSearchResponse``.
        """
        # TODO:
        #   x = self._preprocess(image)
        #   embedding = self._session.run(None, {"image": x})[0]
        #   sims = embedding @ self._cat_emb.T
        #   idx = np.argsort(-sims[0])[:top_k]
        #   ... confidence_verdict(sims[0][idx]) -> verdict ...
        raise NotImplementedError
