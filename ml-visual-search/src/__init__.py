"""GALERIA — modul modeling computer vision (Visual Search encoder).

Alur: preprocess -> train -> evaluate -> embedding -> export.

Modul:
    utils        Loader config YAML, seed, logger, resolusi path.
    preprocess   "Embed" gambar ke kanvas persegi + resize, tulis ke data/processed/.
    dataset      Dataset PyTorch: load gambar WikiArt + label dari CSV.
    transforms   Augmentasi train vs transform deterministik val/test + SquarePad.
    model        ResNet50 fine-tuned + akses embedding penultimate.
    train        Training loop (entry point: python -m src.train).
    evaluate     Evaluasi model: accuracy, F1, confusion matrix, retrieval@k.
    embedding    Ekstraksi embedding katalog + FAISS index (basis Visual Search).
    export       Checkpoint .pth -> TorchScript / ONNX untuk backend/.
"""

__version__ = "0.1.0"
