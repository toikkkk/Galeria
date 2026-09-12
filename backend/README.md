# backend/ — API Inference GALERIA (FastAPI)

Skeleton FastAPI sudah dibuat (struktur + docstring, logic inti masih
`NotImplementedError` — pola yang sama seperti `ml-visual-search/src/`
waktu pertama dibuat).

## Struktur

```
backend/
├── main.py                     entrypoint FastAPI, load model saat startup
├── routers/
│   ├── visual_search.py        POST /api/visual-search
│   └── katalog.py              GET /api/katalog, GET /api/karya/{id}
├── services/
│   └── visual_search_service.py   business logic: load model.onnx + katalog, inferensi
├── schemas/
│   └── visual_search.py        Pydantic request/response
├── requirements.txt
└── .env.example
```

## Cara jalan

```bash
cd backend
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env
uvicorn main:app --reload --port 8000
```
Docs: http://localhost:8000/docs

## Artefak yang dipakai (hasil dari `ml-visual-search/`)

- `../ml-visual-search/export/model.onnx` — encoder gambar (768-d embedding)
- `../ml-visual-search/data/cache/catalog_embeddings.npz` — index katalog
- `../ml-visual-search/data/cache/label_to_idx__style_name.json` — mapping kelas

Model **TIDAK** dimuat ulang per-request — sekali saat startup (`main.py`
lifespan), disimpan di `app.state`.

## Yang belum diisi (TODO)

- `VisualSearchService.load()` / `._preprocess()` / `.search()` — port logic
  dari `ml-visual-search/src/transforms.py` (SquarePad) +
  `ml-visual-search/src/embedding.py` (`nearest_neighbors`,
  `confidence_verdict`) ke numpy/ONNXRuntime murni (server tidak perlu
  install PyTorch penuh, cukup `onnxruntime`).
- `routers/katalog.py` — perlu skema database karya asli (bukan lagi metadata
  WikiArt riset) begitu tabel karya/penjual/harga dirancang.
- Endpoint Digital Art Identity (dari `ml-digital-art-identity/`) — belum ada,
  nanti dari anggota tim yang pegang fitur itu.

## Penting

- Jangan overclaim di response API — kalau `confidence_verdict` hasilnya
  `"ambiguous"`, JANGAN klaim satu karya pasti sama; tampilkan sebagai
  beberapa kandidat (lihat `ml-visual-search/notebooks/03_demo_inference.ipynb`
  untuk contoh perilaku yang benar).
- Istilah Digital Art Identity nanti: **"sertifikat digital keaslian"**,
  BUKAN "Hak Paten" (lihat CLAUDE.md).
