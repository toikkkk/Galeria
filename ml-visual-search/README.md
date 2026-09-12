# ml/ — Modeling Computer Vision GALERIA

Bagian **modeling** dari monorepo GALERIA (lihat [../README.md](../README.md)).
Melatih encoder gambar untuk fitur **Visual Search** dan menghasilkan artefak
yang dikonsumsi `backend/`.

Model: **ResNet50** (pretrained ImageNet) di-*fine-tune* untuk klasifikasi
`style` WikiArt (12 kelas) sebagai *pretext task*. Setelah training, classifier
head dibuang; output penultimate layer (2048-d) dipakai sebagai **embedding**
untuk pencarian kemiripan. Embedding yang sama nanti di-*reuse* sebagai basis
Digital Art Identity (bagian anggota lain).

> **AR Simulation tidak ada di sini** — itu SDK ARCore/ARKit, bukan deep learning,
> tidak butuh training (lihat CLAUDE.md).

---

## Struktur folder

```
ml/
├── data/
│   ├── raw/            # WikiArt asli — copy dari C:\wikiart_sample (jpg + metadata.csv + split csv)
│   ├── processed/      # hasil `src.preprocess`: gambar sudah di-embed persegi + resize 256
│   └── cache/          # label_to_idx.json, catalog_embeddings.npz, catalog.faiss
├── notebooks/
│   ├── 00_scrape_wikiart.ipynb       # unduh shard WikiArt tambahan -> data/raw/ (butuh huggingface_hub)
│   ├── eda_wikiart.ipynb             # EDA + cleaning + stratified split + handle imbalance + augmentasi
│   ├── 01_train.ipynb                # setup + tuning (Optuna) + training + evaluasi (logic dari src/)
│   └── 02_embedding_retrieval.ipynb  # embedding + retrieval@k + instance-retrieval + export
├── src/
│   ├── utils.py        # loader config.yaml, seed, logger, resolusi path
│   ├── preprocess.py   # "embed" gambar ke kanvas persegi + resize -> data/processed/
│   ├── dataset.py      # Dataset custom: load gambar + label dari CSV split
│   ├── transforms.py   # augmentasi train vs transform deterministik + SquarePad
│   ├── model.py        # ResNet50 fine-tuned + akses embedding
│   ├── train.py        # training loop
│   ├── evaluate.py     # evaluasi (accuracy, F1, confusion matrix, retrieval@k)
│   ├── embedding.py    # ekstraksi embedding katalog + FAISS index
│   └── export.py       # checkpoint .pth -> TorchScript / ONNX untuk backend/
├── configs/config.yaml # SEMUA hyperparameter & path (jangan hardcode di script)
├── checkpoints/         # model .pth hasil training
├── outputs/             # log, plot, laporan evaluasi
├── export/              # model.torchscript / model.onnx
├── requirements.txt
└── README.md
```

> **Status:** `preprocess.py`, `train.py`, `evaluate.py` sudah fungsional.
> `embedding.py` / `export.py` masih *skeleton* — struktur & alur ada, logic inti
> ditandai `TODO` / `raise NotImplementedError`.

---

## 1. Instalasi

```bash
cd ml
python -m venv .venv
.venv\Scripts\Activate.ps1        # Windows PowerShell
# source .venv/bin/activate       # Linux/macOS
pip install -r requirements.txt
pip install -e .                  # agar `import src...` jalan dari notebooks/
```

Untuk build PyTorch spesifik (CUDA / CPU-only), ikuti <https://pytorch.org> dulu.

---

## 2. Siapkan data (sekali)

Dataset **tidak** masuk git (±500 MB + lisensi non-komersial). Ambil dari Google
Drive tim, lalu:

```bash
# 1. copy WikiArt asli ke data/raw/
#    isi: wikiart_00000.jpg ... + metadata.csv + train_split.csv/val_split.csv/test_split.csv
#    (kalau split csv hilang: jalankan ulang sel split di notebooks/eda_wikiart.ipynb — deterministik)

# 2. embed persegi + resize -> data/processed/
python -m src.preprocess --config configs/config.yaml
```

`preprocess` membaca `data/raw`, menaruh tiap lukisan di tengah kanvas persegi
(padding kiri-kanan / atas-bawah), resize ke 256×256, simpan ke `data/processed`
dengan nama file sama → split CSV lama tetap valid.

---

## 3. Konfigurasi

Semua di [`configs/config.yaml`](configs/config.yaml). Yang sering diubah:

| Bagian | Kunci | Keterangan |
|---|---|---|
| `data` | `image_dir` | `data/processed` (default, sesudah preprocess) atau `data/raw` |
| `data` | `label_column` | target: `style` / `genre` / `artist` |
| `image` | `pad_to_square` | `false` bila pakai `data/processed`; `true` bila padding on-the-fly dari `data/raw` |
| `preprocess` | `out_size`, `pad_mode` | ukuran & jenis border hasil preprocess |
| `model` | `train_mode` | `freeze_backbone` / `finetune_partial` / `finetune_all` |
| `train` | `epochs`, `batch_size`, `learning_rate`, `use_weighted_sampler` | hyperparameter utama |
| `export` | `checkpoint`, `onnx_path` | sumber & tujuan export |

Path relatif diselesaikan terhadap folder `ml/`.

---

## 4. Alur menjalankan

Jalankan sebagai **module** dari folder `ml/`.

| # | Perintah | Hasil |
|---|---|---|
| 1 | `python -m src.preprocess` | `data/processed/*.jpg` (gambar seragam, sudah di-embed) |
| 2 | `python -m src.train` | `checkpoints/best.pth`, `outputs/train.log`, `outputs/training_history.png` |
| 3 | `python -m src.evaluate --checkpoint checkpoints/best.pth` | `outputs/metrics_report.json`, `outputs/confusion_matrix.png` |
| 4 | `python -m src.embedding --checkpoint checkpoints/best.pth` | `data/cache/catalog_embeddings.npz` + `catalog.faiss` |
| 5 | `python -m src.export` | `export/model.torchscript`, `export/model.onnx` (untuk `backend/`) — output = embedding ternormalisasi L2 |

---

## 5. Dataset

- Subset **WikiArt** (`huggan/wikiart`), 1.132 `.jpg` dari shard pertama
  (`train-00000-of-00072.parquet`) — **bukan** random sample, didominasi
  Van Gogh / Roerich / Monet (representativeness terbatas, di Data Card).
- Split stratified 70/15/15: **train 787 / val 169 / test 169** (1.125 gambar
  setelah 4 kelas `style` <6 sampel di-exclude). Target `style` = **12 kelas**;
  jumlah kelas dibaca otomatis dari `train_split.csv`.
- EDA + split: [`notebooks/eda_wikiart.ipynb`](notebooks/eda_wikiart.ipynb).

---

## 6. Kesesuaian dengan CLAUDE.md

- **Fine-tuning:** `model.train_mode: finetune_partial` + `unfreeze_last_n_blocks: 1`
  → hanya `layer4` + `fc` yang dilatih.
- **Embed ke kanvas persegi (arahan dosen):** dikerjakan sekali di depan via
  `src.preprocess` (hasil di `data/processed/`). Seluruh komposisi lukisan
  terjaga, rasio aspek tak terdistorsi (EDA: rasio 0.35–3.28). `transforms.SquarePad`
  juga tersedia untuk mode on-the-fly (`image.pad_to_square: true` + `image_dir: data/raw`).
- **Augmentasi train:** `Resize(256) → RandomCrop(224) → HFlip(0.5) → ColorJitter
  ringan → RandomRotation(10°) → Normalize`. Tanpa vertical flip / cutout.
- **Imbalance:** `WeightedRandomSampler` inverse-frekuensi kelas; loss tidak
  diberi class-weight lagi.
- **Embedding:** classifier head dibuang; output penultimate (2048-d) untuk
  Visual Search & basis Digital Art Identity.
- **Baseline opsional:** slot `baseline_clip` untuk pembanding CLIP zero-shot.
- **Istilah:** "sertifikat digital keaslian", **bukan** "Hak Paten". Hanya deteksi
  duplikasi digital, bukan pemalsuan fisik.
- pHash (Digital Art Identity) = algoritmik, di `backend/`, bukan di sini.
