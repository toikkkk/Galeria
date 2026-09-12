"""Ekstraksi embedding dari model terlatih + evaluasi kualitas retrieval.

Dipakai oleh dua fitur AI GALERIA:
- **Visual Search** -- pencarian karya mirip lewat cosine similarity antar
  embedding gambar.
- **Digital Art Identity** -- "sidik jari" (fingerprint) vektor untuk tiap karya.

Tanggung jawab file ini:
- Memuat model + checkpoint terlatih, set ke ``eval`` mode.
- Mengiterasi katalog gambar (``embedding.source_csv``) memakai transform
  deterministik (:func:`src.transforms.build_eval_transforms`).
- Mengambil embedding penultimate (:meth:`GaleriaArtNet.forward_features`),
  opsional L2-normalize.
- Menyimpan matriks embedding + daftar ``filename`` / label ke
  ``embedding.output_path`` (format ``.npz``).
- Pencarian tetangga terdekat (cosine similarity) -- brute-force numpy, cukup
  cepat untuk katalog puluhan ribu gambar (tidak butuh FAISS di skala ini).
- :func:`evaluate_retrieval` -- Recall@k / Precision@k / mAP@k, metrik sukses
  SEBENARNYA untuk Visual Search (bukan akurasi klasifikasi style).

Catatan scope (CLAUDE.md):
- Digital Art Identity juga memakai perceptual hashing (pHash) untuk deteksi
  cepat. pHash bersifat algoritmik (bukan training) dan diimplementasikan di
  sisi backend platform, bukan di repo ini.
- Digital Art Identity mendeteksi duplikasi UPLOAD DIGITAL di platform, BUKAN
  pemalsuan fisik karya seni. Jangan overclaim.

Cara menjalankan::

    python -m src.embedding --config configs/config.yaml \
        --checkpoint checkpoints/best.pth
"""

from __future__ import annotations

import argparse

import numpy as np
import torch
import torch.nn.functional as F
from tqdm import tqdm

from .dataset import WikiArtDataset, build_label_mapping
from .model import build_model, load_checkpoint
from .transforms import build_eval_transforms
from .utils import get_device, get_logger, load_config, resolve_path, set_seed


@torch.no_grad()
def extract_embeddings(
    model: torch.nn.Module,
    loader: torch.utils.data.DataLoader,
    device: torch.device,
    l2_normalize: bool = True,
    desc: str = "embed",
) -> tuple[np.ndarray, np.ndarray]:
    """Ekstrak embedding untuk seluruh gambar di ``loader``.

    Returns:
        ``(embeddings, labels)`` -- ``embeddings`` shape ``(N, embedding_dim)``,
        ``labels`` shape ``(N,)`` (-1 untuk baris tanpa label yang dikenal).
    """
    model.eval()
    embs, labels = [], []
    for images, lbl in tqdm(loader, desc=desc, leave=False):
        images = images.to(device, non_blocking=True)
        feat = model.forward_features(images)
        if l2_normalize:
            feat = F.normalize(feat, dim=1)
        embs.append(feat.cpu().numpy())
        labels.append(lbl.numpy() if torch.is_tensor(lbl) else np.asarray(lbl))
    return np.concatenate(embs, axis=0), np.concatenate(labels, axis=0)


def save_embedding_index(
    embeddings: np.ndarray,
    filenames: list[str],
    labels: np.ndarray,
    output_path: str,
) -> None:
    """Simpan index embedding ke file ``.npz``."""
    out = resolve_path(output_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(
        out, embeddings=embeddings, filenames=np.array(filenames), labels=labels
    )


def nearest_neighbors(
    query: np.ndarray,
    gallery: np.ndarray,
    top_k: int = 10,
) -> tuple[np.ndarray, np.ndarray]:
    """Cari ``top_k`` tetangga tergampang mirip di ``gallery`` (cosine similarity).

    Asumsi ``query``/``gallery`` sudah L2-normalized -> cosine similarity =
    dot product. Brute-force (cukup cepat sampai puluhan ribu gambar).

    Args:
        query: ``(D,)`` (1 query) atau ``(Q, D)`` (banyak query sekaligus).

    Returns:
        ``(indices, scores)`` shape ``(Q, top_k)``, terurut menurun.
    """
    q = query if query.ndim == 2 else query[None, :]
    sims = q @ gallery.T
    idx = np.argsort(-sims, axis=1)[:, :top_k]
    scores = np.take_along_axis(sims, idx, axis=1)
    return idx, scores


def confidence_verdict(
    scores: np.ndarray,
    sure_threshold: float = 0.85,
    maybe_threshold: float = 0.6,
    min_gap: float = 0.05,
) -> str:
    """Putuskan seberapa yakin hasil #1 retrieval itu "karya yang sama".

    Kenapa perlu ini: similarity TINGGI tidak selalu berarti "karya yang sama"
    -- lukisan BEDA oleh pelukis yang sama/gaya serupa juga bisa skor tinggi
    (0.7-0.9), tumpang tindih dengan skor "karya sama, foto kurang ideal".
    Satu ambang batas mutlak saja gampang overclaim. Di sini dipakai DUA
    syarat sekaligus: skor #1 harus tinggi **DAN** menonjol jelas dari #2
    (``min_gap``) -- kalau #2..#5 rapat ke #1, itu tanda beberapa kandidat
    mirip, bukan satu jawaban pasti.

    Args:
        scores: similarity #1..#k utk SATU query, terurut menurun (mis.
            ``scores[0]`` dari :func:`nearest_neighbors`).

    Returns:
        ``"confirmed"``  -- #1 kemungkinan besar karya yang sama (skor tinggi
            + menonjol jelas dari kandidat lain).
        ``"ambiguous"``  -- ada kandidat yang mirip tapi tidak ada yang jelas
            menonjol -- JANGAN klaim satu jawaban pasti ke user.
        ``"not_found"``  -- kemungkinan besar karya ini tidak ada di katalog.
    """
    top1 = float(scores[0])
    gap = top1 - float(scores[1]) if len(scores) > 1 else top1
    if top1 >= sure_threshold and gap >= min_gap:
        return "confirmed"
    if top1 >= maybe_threshold:
        return "ambiguous"
    return "not_found"


def evaluate_retrieval(
    query_emb: np.ndarray,
    query_labels: np.ndarray,
    gallery_emb: np.ndarray,
    gallery_labels: np.ndarray,
    ks: tuple[int, ...] = (1, 5, 10),
    exclude_self: bool = False,
) -> dict:
    """Recall@k, Precision@k, mAP@k -- "relevan" = gallery berlabel sama query.

    Ini metrik sukses SEBENARNYA untuk Visual Search (bukan akurasi
    klasifikasi style, yang cuma pretext task).

    Args:
        exclude_self: True kalau ``query_emb is gallery_emb`` (evaluasi
            leave-one-out) -- diagonal similarity dibuat -inf supaya query
            tidak menemukan dirinya sendiri.

    Returns:
        dict ``{"recall@K":..., "precision@K":..., "map@K":...}`` per K di ``ks``.
    """
    sims = query_emb @ gallery_emb.T  # (Q, G)
    if exclude_self:
        n = min(sims.shape)
        idx = np.arange(n)
        sims[idx, idx] = -np.inf

    max_k = max(ks)
    order = np.argsort(-sims, axis=1)[:, :max_k]
    hit = gallery_labels[order] == query_labels[:, None]  # (Q, max_k) bool

    out: dict[str, float] = {}
    for k in ks:
        hk = hit[:, :k]
        out[f"recall@{k}"] = float(hk.any(axis=1).mean())
        out[f"precision@{k}"] = float(hk.mean())
        ranks = np.arange(1, k + 1)
        prec_at_i = np.cumsum(hk, axis=1) / ranks
        denom = np.clip(hk.sum(axis=1), 1, None)
        ap_per_query = (prec_at_i * hk).sum(axis=1) / denom
        out[f"map@{k}"] = float(ap_per_query.mean())
    return out


def chance_recall_at_k(labels: np.ndarray, k: int) -> float:
    """Perkiraan Recall@k kalau menebak acak (baseline pembanding).

    Kelas yang besar porsinya di ``labels`` lebih gampang "kena" walau asal
    tebak -- baseline ini dirata-rata berbobot frekuensi kelas si query.
    """
    _, counts = np.unique(labels, return_counts=True)
    p = counts / len(labels)
    return float(np.average(1 - (1 - p) ** k, weights=counts))


def main(config_path: str, checkpoint_path: str) -> None:
    cfg = load_config(config_path)
    set_seed(cfg["seed"])
    logger = get_logger("embedding", cfg["output"]["log_file"])
    device = get_device(cfg["device"])
    emb_cfg = cfg["embedding"]

    label_to_idx = build_label_mapping(cfg)
    model = build_model(cfg, num_classes=len(label_to_idx)).to(device)
    load_checkpoint(model, checkpoint_path, map_location=str(device))
    logger.info("Model + checkpoint siap untuk ekstraksi embedding.")

    dataset = WikiArtDataset(
        csv_path=emb_cfg["source_csv"],
        image_dir=cfg["data"]["image_dir"],
        label_column=cfg["data"]["label_column"],
        label_to_idx=label_to_idx,
        transform=build_eval_transforms(cfg),
        filename_column=cfg["data"]["filename_column"],
    )
    loader = torch.utils.data.DataLoader(
        dataset, batch_size=emb_cfg["batch_size"], shuffle=False,
        num_workers=cfg["train"]["num_workers"], pin_memory=True,
    )
    embeddings, labels = extract_embeddings(
        model, loader, device, l2_normalize=emb_cfg["l2_normalize"]
    )
    save_embedding_index(
        embeddings,
        dataset.df[cfg["data"]["filename_column"]].tolist(),
        labels,
        emb_cfg["output_path"],
    )
    logger.info(
        "Embedding %d gambar (dim=%d) -> %s",
        embeddings.shape[0], embeddings.shape[1], emb_cfg["output_path"],
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Ekstraksi embedding GALERIA CV")
    parser.add_argument("--config", default="configs/config.yaml")
    parser.add_argument("--checkpoint", default="checkpoints/best.pth")
    args = parser.parse_args()
    main(args.config, args.checkpoint)
