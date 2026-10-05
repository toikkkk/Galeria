# Riwayat Training Visual Search — Perbandingan Model

> Ditulis 2026-10-01, diperbarui 2026-10-02 setelah menambahkan model v3
> (CLIP) + notebook perbandingan lintas-model. Dipakai langsung sbg bahan
> presentasi Minggu ke-8 (perbandingan model, hyperparameter, model terbaik).
> **v1 dan v2 BELUM pernah di-run ulang secara end-to-end setelah notebook
> `01_train.ipynb` masing-masing dirombak (override path, fix bug
> `RUN_TUNING=False`, dst) — status "selesai"/"live" di bawah ini masih
> merujuk ke checkpoint HASIL run lama (sebelum rombak), yang tetap valid
> dipakai (file checkpoint tidak berubah). Kalau run ulang dari notebook yang
> sudah dirombak, angka final SEHARUSNYA identik (sama data, sama seed, sama
> hyperparameter) -- tapi belum diverifikasi ulang. User menjalankan sendiri.**

## Tabel Perbandingan

| Run | Dataset | Kelas | Tuning | Val macro-F1 | Test macro-F1 | Status |
|---|---|---|---|---|---|---|
| Baseline awal | 1.132 gambar | 12 | — | — | **~0.44** (dikutip di notebook, **tidak ada checkpoint tersimpan** — data `data/raw/` sudah ditimpa dataset lebih besar, tidak direproduksi) | historis |
| **v1_11class** (`checkpoints/v1_11class_backup/`) | 5.659 gambar (shard 0–4) | 11 | Optuna, 15 trial | 0.76 (epoch 30, `last.pth` — `best.pth` ASLI epoch 24 **hilang/tertimpa**) | **0.78** (epoch 24, dicatat di `outputs/v1_11class_backup/metrics_report.json`) | selesai dievaluasi penuh, **tidak live**, siap di-run ulang (`notebooks/v1_11class_backup/01_train.ipynb`, dataset split direkonstruksi otomatis) |
| **v2_22class** (`checkpoints/v2_22class/`) | 33.937 gambar | 22 | **reuse** hyperparameter study lama (BUKAN tuning baru) | 0.67 @ epoch 21/40 (training terhenti tengah epoch 26, bukan early-stopping resmi) | belum dievaluasi (kernel terhenti sblm sampai section 7) | **LIVE di backend sekarang**, siap di-run ULANG PENUH 40 epoch (`notebooks/v2_22class/01_train.ipynb`) utk hasil final + evaluasi test set |
| **v3_clip** (`checkpoints/v3_clip/`) | 33.937 gambar (SAMA dgn v2) | 22 | sweep 25 konfigurasi classifier head (backbone CLIP dibekukan, tidak di-tuning) | 0.667 | 0.666 (akurasi 0.711) — angka dari run verifikasi setting final; isi ulang dari `outputs/v3_clip/metrics_report.json` setelah notebook dijalankan | baseline akademik (pembanding), **tidak live**. Riwayat tuning 0.517 → 0.614 → 0.629 → 0.667: lihat section 8 `v3_clip/01_train.ipynb` |

**Kenapa v3 (CLIP) dibuat**: pembanding "seberapa kompetitif frozen CLIP +
linear probe vs fine-tuning penuh ConvNeXt?" — latihan murah (menit, bukan
jam) karena backbone tidak dilatih sama sekali, dataset SAMA dgn v2 (22
kelas/33.937 gambar) biar perbandingan murni soal strategi training, bukan
beda data. Detail arsitektur & desain: `notebooks/v3_clip/01_train.ipynb`
section "MODEL v3". **Belum pernah dijalankan** — baris v3 di tabel di atas
akan terisi begitu user menjalankannya sendiri.

**Demo & perbandingan lintas-model**: tiap folder (`v1_11class_backup/`,
`v2_22class/`, `v3_clip/`) punya `03_demo_inference.ipynb` sendiri (fungsi
`scan_lukisan`) — jalankan ketiganya dgn gambar INPUT yang sama
(`wikiart_00042.jpg`, default di semua 3 demo) untuk lihat langsung bedanya.
Untuk tabel/chart otomatis dari `metrics_report.json` tiap run, pakai
`notebooks/04_compare_models.ipynb` — baca hasil evaluasi tiap model
langsung dari disk (bukan angka hardcode), aman dijalankan walau sebagian
run belum selesai dievaluasi (baris itu tampil "belum dijalankan").

**Model yang sekarang live** = `v2_22class`, BUKAN `v1_11class` yang
justru evaluasinya lebih lengkap. Alasan: dites langsung ke 8 gambar katalog
produksi (`mobile/assets/images/catalog/`) — `v2_22class` benar
**8/8**, `v1_11class` cuma benar **5/8** (salah: Expressionism→Post
Impressionism, Post Impressionism→Impressionism, Symbolism→Impressionism).

**Kenapa angka macro-F1 tidak bisa dibandingkan apel-ke-apel**: baseline
tebak-acak utk 11 kelas ≈9%, utk 22 kelas ≈4,5% — macro-F1 0,67 di 22 kelas
secara relatif bisa jadi *lebih* kuat drpd 0,76 di 11 kelas, bukan lebih
lemah. Jangan sajikan "0,78 > 0,67 jadi 11-kelas lebih baik" tanpa konteks
ini saat presentasi.

## Insiden yang Ditemukan (konteks kenapa struktur folder berubah)

Sebelum dirapikan, `checkpoints/best.pth`/`export/model.onnx`/
`data/cache/label_to_idx__style_name.json` di ROOT **diam-diam tertimpa**
checkpoint `v2_22class` (13 Sep 17:50) menggantikan `v1_11class`
yang sebelumnya ada di situ (13 Sep 02:43) — karena keduanya training ke
path yang SAMA (`checkpoints/best.pth`, dst, dari `configs/config.yaml`
yang generik). Akibatnya backend sempat menyajikan model yang belum selesai
tanpa ada yang sadar, dan checkpoint `v1_11class` TERBAIK (epoch 24) hilang
selamanya — cuma `last.pth` (epoch 30) yang selamat krn namanya beda.

**Perbaikan struktural** (supaya tidak terulang): `configs/config.yaml`
sekarang mengarah ke `checkpoints/continued_training/` (BUKAN root) utk
SEMUA training berikutnya. Root = slot "model live", HANYA diisi lewat
promosi manual (copy file), tidak pernah ditulis otomatis oleh training.
Detail: lihat komentar di `configs/config.yaml` section `checkpoint`/`export`.

## Struktur Folder

```
ml-visual-search/
├── checkpoints/
│   ├── best.pth, last.pth              <- LIVE (promosi manual, saat ini = v2_22class)
│   ├── v1_11class_backup/last.pth      <- run 1, selesai dievaluasi, tidak live
│   ├── v2_22class/last.pth     <- snapshot pelindung dari yang live sekarang
│   ├── v3_clip/                        <- classifier head v3 (checkpoint CLIP itu sendiri
│   │                                       TIDAK disimpan di sini -- didownload ulang
│   │                                       otomatis dari open_clip tiap run, cuma head kecil
│   │                                       yang disimpan lokal)
│   └── continued_training/             <- tujuan training BERIKUTNYA (lanjut/ulang 22 kelas)
├── export/            (pola folder sama: root=live, v1_11class_backup/, v2_22class/, continued_training/;
│                        v3_clip/ SENGAJA kosong -- v3 baseline akademik, tidak diekspor ke backend)
├── outputs/            (sama; v1_11class_backup berisi history/metrics/plot lengkap,
│                         v2_22class/ & v3_clip/ terisi setelah masing-masing dijalankan)
├── data/cache/         (sama; label_to_idx + catalog_embeddings per run;
│                         v3_clip/catalog_embeddings_clip.npz beda DIMENSI (512-d CLIP)
│                         dari v1/v2 (768-d ConvNeXt) -- jangan dicampur satu index)
└── notebooks/
    ├── 00_scrape_wikiart.ipynb      <- umum, tidak per-run (download shard tambahan)
    ├── 01_train.ipynb               <- AKTIF, ikut configs/config.yaml (-> continued_training/)
    ├── 02_embedding_retrieval.ipynb <- AKTIF, sama
    ├── 03_demo_inference.ipynb      <- punya toggle MODEL_VERSION ("latest" vs "v1_11class")
    ├── 04_compare_models.ipynb      <- BARU: tabel + chart otomatis dari metrics_report.json
    │                                    v1/v2/v3 (baca dari disk, bukan hardcode) -- bahan
    │                                    utama slide "perbandingan model" presentasi
    ├── v1_11class_backup/           <- salinan 01/02/03 run 1 + eda_wikiart.ipynb (EDA versi
    │                                    5.659 gambar, SUDAH BASI utk dataset 33.937 gambar
    │                                    sekarang). 01_train.ipynb SIAP di-run ulang kapan
    │                                    saja (split dataset asli direkonstruksi otomatis
    │                                    dari catalog_embeddings.npz, lihat sel ke-2 notebook)
    ├── v2_22class/                  <- salinan 01/02/03 run 2 (= model LIVE sekarang),
    │                                    override path ke checkpoints/v2_22class/ dll.
    │                                    01_train.ipynb SIAP di-run ulang -- training FULL
    │                                    dari awal (40 epoch), bukan resume dari epoch 21
    │                                    (state optimizer/scheduler/EMA tidak pernah
    │                                    disimpan di run asli); 02/03 override TAPI 02 BELUM
    │                                    pernah dijalankan utk run ini (training keburu
    │                                    berhenti) -- catalog_embeddings_regenerated belum
    │                                    ada, 03 akan error jelas kalau dijalankan sblm 02.
    └── v3_clip/                     <- BARU: MODEL v3, CLIP ViT-B-32 (frozen, open_clip) +
                                         linear-probe classifier head. Dataset SAMA dgn v2
                                         (22 kelas/33.937 gambar) -- perbandingan murni soal
                                         strategi training. 01_train.ipynb (ekstrak embedding
                                         CLIP sekali + latih classifier head kecil, jauh lebih
                                         cepat dari fine-tuning penuh) -> 02_embedding_retrieval
                                         (Recall@k + index katalog CLIP) -> 03_demo_inference
                                         (scan_lukisan, TANPA demo webcam -- lihat catatan
                                         scope di notebook). BELUM pernah dijalankan.
```

## Hyperparameter (utk slide "hyperparameter tiap model")

Sama persis dipakai kedua run yang punya tuning (`v1_11class` DAN
`v2_22class` reuse hasil yang sama, lihat catatan tuning di atas):

```json
{
  "learning_rate": 0.0002584949196006611,
  "backbone_lr_mult": 0.18427033274320545,
  "weight_decay": 0.0009849813063176139,
  "dropout": 0.2017262123368978,
  "unfreeze_frac": 0.4406353983164585
}
```
(hasil Optuna, trial #13 dari 15, TPE sampler — `outputs/v1_11class_backup/` /
`outputs/tune_best_params.json`). Arsitektur: `convnext_small` pretrained
ImageNet, `finetune_partial`, backbone + classifier head custom. Detail
augmentasi/preprocessing: lihat `configs/config.yaml`.

**v3_clip TIDAK punya hyperparameter backbone** (CLIP dibekukan total, tidak
ada `learning_rate`/`unfreeze_frac` dst yang relevan ke backbone). Yang
di-tuning cuma classifier head kecil, config di `configs/config.yaml` ->
`baseline_clip.classifier`:
```json
{
  "hidden_dim": 0,
  "dropout": 0.2,
  "epochs": 30,
  "learning_rate": 0.001,
  "weight_decay": 0.0001,
  "batch_size": 256
}
```
(`hidden_dim: 0` = linear probe murni/`nn.Linear`, bukan MLP — nilai ini
dipilih manual, bukan hasil Optuna, krn classifier head kecil ini jauh lebih
cepat dikonvergensikan, re-tuning Optuna dirasa tidak sepadan biayanya utk
scope 2 minggu). Model: `CLIP ViT-B-32` pretrained `laion2b_s34b_b79k`
(open_clip, BUKAN checkpoint ImageNet) — detail lengkap di
`notebooks/v3_clip/01_train.ipynb`.

## Baseline 1.132 gambar/12 kelas — kenapa tidak dibuatkan folder

Angka ~0.44 cuma dikutip sbg konteks di cell print `01_train.ipynb`, TIDAK
ADA checkpoint/notebook/split CSV yang tersisa (data `data/raw/` sudah
ditimpa 2x oleh dataset yang lebih besar). Reproduksi persis subset asli
itu tidak praktis — kalau mau run baseline baru sbg pembanding, lebih masuk
akal pakai subset BARU (mis. 1 shard WikiArt) drpd mencoba merekonstruksi
subset lama yang sudah hilang.
