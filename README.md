# GALERIA

Platform marketplace + lelang karya seni (aplikasi **mobile**, Flutter) dengan
verifikasi keaslian berbasis digital fingerprinting dan fitur AI/computer
vision. Proyek kelompok PBL — prodi Sains Data Terapan, PENS.

Konteks lengkap produk & keputusan desain ada di [CLAUDE.md](CLAUDE.md).

## Struktur repo (monorepo)

```
projek galeria/
├── CLAUDE.md                    Konteks produk, scope, riwayat keputusan
├── ml-visual-search/            Modeling CV utk Visual Search ← lihat README di dalamnya
│                                 (convnext_small fine-tuned WikiArt → embedding)
├── ml-digital-art-identity/      Modeling utk Digital Art Identity (anggota lain)
│                                 (unique-key/fingerprint kriptografi + deteksi gambar AI-generated)
├── backend/                     API inference (FastAPI) — skeleton dibuat
├── mobile/                      Aplikasi mobile (Flutter) — skeleton dibuat
└── docs/                        Data Card, laporan akademik
```

`ml-visual-search/` dan `ml-digital-art-identity/` **sengaja terpisah** — dua
model/pipeline berbeda, dikerjakan orang berbeda, supaya data/config/
checkpoint tidak tercampur.

## Pembagian kerja

| Komponen | Isi | Status |
|---|---|---|
| `ml-visual-search/` | Training model style-classification → embedding untuk **Visual Search**; di-*reuse* sebagai basis Digital Art Identity | ✅ pipeline lengkap (preprocess→train→evaluate→embedding→export) |
| `ml-digital-art-identity/` | pHash unique-key + deteksi gambar AI-generated vs asli | ⏳ (anggota lain, scaffold folder sudah ada) |
| `backend/` | Endpoint `/api/visual-search` (terima foto → cari ke index katalog → hasil), serve metadata katalog | 🔄 skeleton FastAPI dibuat, logic belum diisi |
| `mobile/` | UI marketplace, kamera Visual Search, AR Simulation (SDK ARCore/ARKit), chatbot | 🔄 project Flutter di-scaffold, UI belum diisi |

## Alur artefak

```
ml-visual-search/  ──▶  model.onnx / model.torchscript      ──▶  backend/  ──▶  mobile/ (Flutter)
                   └──▶  catalog_embeddings.npz (index katalog) ──┘
```

Model **tidak** jalan di HP. HP (Flutter) mengirim foto ke `backend/`
(FastAPI), yang menjalankan model (ONNXRuntime) + pencarian nearest-neighbor,
lalu mengembalikan hasil. Detail lihat README di masing-masing folder.
