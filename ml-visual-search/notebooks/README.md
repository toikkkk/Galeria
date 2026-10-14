# Notebook Visual Search

Klasifikasi gaya lukisan (pretext task) dan embedding untuk pencarian karya mirip. Tiap versi punya folder sendiri.

| Versi | Data | Kelas | Test macro-F1 | Catatan |
|---|---|---|---|---|
| `v1_11class_backup` | 5.659 gambar | 11 | 0,78 | test kecil (24 seniman), kemungkinan optimis |
| `v2_22class` | 33.937 gambar | 22 | 0,687 (Colab) | model yang **terpasang di backend** adalah run lama (epoch 21) |
| `v3_clip` | 33.937 gambar | 22 | 0,666 | pembanding: CLIP beku + linear probe |
| `v4_11class/standard` | 20.764 gambar | 11 | **0,748** | model 11 kelas terbaik, belum dipasang di backend |

Model 11 kelas dan 22 kelas tidak sebanding. Semua split tidak memisahkan seniman.

## Penamaan

Tiap folder versi: `01_train` → `02_embedding_retrieval` → `03_demo_inference`. Akhiran `_colab` = dijalankan di Google Colab.

```
notebooks/
├── 00_scrape_wikiart.ipynb        unduh data WikiArt
├── 01_train / 02_embedding_retrieval / 03_demo_inference   template umum (configs/config.yaml)
├── 04_compare_models.ipynb        perbandingan semua versi
├── v1_11class_backup/             01_train, 01_train_colab, 02, 03, eda_wikiart
├── v2_22class/                    01_train, 01_train_colab, eksperimen_A/C/(B)_colab, 02, 03
├── v3_clip/                       01_train, 02, 03
└── v4_11class/standard/           01_train_colab, 02_embedding_retrieval_colab, 03_demo_inference
    ├── checkpoints/ (best.pth, last.pth)   outputs/   data_cache/   export/
```

Riwayat training dan insiden: `RIWAYAT_TRAINING.md`.
