# ml-digital-art-identity/ — Modeling untuk Digital Art Identity

**Bagian ini BUKAN dikerjakan oleh modeler Visual Search** (lihat
[`../ml-visual-search/`](../ml-visual-search/)) — folder terpisah sengaja,
supaya dua pipeline modeling tidak tercampur (data, checkpoint, config,
requirements masing-masing independen).

## Scope (sesuai CLAUDE.md — fitur "Digital Art Identity")

1. **Unique-key / fingerprint digital** — tiap karya yang diupload dapat kunci
   unik. Upload lain dengan fingerprint sama/sangat mirip → ditandai/diblokir
   (cegah klaim ganda kepemilikan karya yang sama di platform).
   - Teknis (CLAUDE.md): **perceptual hashing (pHash)** untuk deteksi cepat,
     dan/atau **deep embedding** (bisa reuse encoder dari
     `ml-visual-search/export/model.onnx` — CLAUDE.md: "satu CNN backbone
     dipakai ulang di 2 fitur") untuk deteksi lebih robust terhadap manipulasi
     ringan (crop, watermark).
2. **Deteksi gambar AI-generated vs asli** — cek apakah karya yang diupload
   dibuat AI generatif (Midjourney/DALL-E/Stable Diffusion/dll) atau karya
   asli. *(Sub-fitur ini belum tertulis rinci di CLAUDE.md sebelumnya —
   tambahkan detail teknis di sini begitu didesain, lalu sinkronkan ke
   `CLAUDE.md` bagian "Digital Art Identity".)*

## PENTING — istilah wajib (dari CLAUDE.md)

**JANGAN PERNAH** sebut fitur unique-key ini sebagai **"Hak Paten"** di UI,
dokumen, atau materi apa pun yang dilihat pengguna/dosen. Istilah yang benar:
**"sertifikat digital keaslian"** atau **"bukti registrasi kepemilikan
digital"**.

**Batasan:** sistem ini mendeteksi duplikasi **UPLOAD DIGITAL** di platform,
**BUKAN** deteksi pemalsuan fisik karya seni di dunia nyata. Jangan overclaim
"AI kami deteksi lukisan palsu".

## Struktur folder (skeleton, isi sesuai kebutuhanmu)

```
ml-digital-art-identity/
├── data/           data training/referensi (pHash test set, dataset AI-vs-asli, dll)
├── notebooks/      EDA, eksperimen, training, evaluasi
├── src/            kode reusable (fungsi pHash, model classifier AI-vs-asli, dll)
├── configs/        config.yaml — jangan hardcode path/hyperparameter di script
├── checkpoints/    model terlatih (.pth/.onnx)
├── outputs/        hasil evaluasi, plot, laporan
└── requirements.txt
```

Silakan diisi sesuai desainmu sendiri — ini cuma kerangka awal supaya
strukturnya konsisten dengan `ml-visual-search/` dan terpisah rapi dari
pekerjaan CV Visual Search.

## Kalau butuh reuse encoder Visual Search

```python
import onnxruntime as ort
sess = ort.InferenceSession("../ml-visual-search/export/model.onnx")
# input: gambar 224x224 RGB, SquarePad + normalize ImageNet (lihat
# ml-visual-search/src/transforms.py) -> output: embedding 768-d ter-L2-normalize
```
