# backend/ — API Inference GALERIA (FastAPI)

FastAPI + Neon Postgres (pgvector). Visual Search & katalog karya sudah jalan
beneran (bukan skeleton lagi) — lihat CLAUDE.md bagian "Backend & Database"
untuk arsitektur lengkap & bagian "Di Luar Scope Fase Ini" untuk apa yang
masih belum dikerjakan (auth, R2, dll).

## Struktur

```
backend/
├── main.py                     entrypoint FastAPI, load model saat startup
├── database.py                 async engine/session SQLAlchemy + get_db()
├── models/
│   └── karya.py                Karya, KaryaEmbedding (pgvector Vector(768))
├── alembic/                    migration schema (Alembic, async)
├── scripts/
│   └── seed_karya.py           isi 8 karya contoh + embedding-nya
├── routers/
│   ├── visual_search.py        POST /api/visual-search
│   └── katalog.py              GET /api/katalog, GET /api/karya/{id}
├── services/
│   └── visual_search_service.py   business logic: load model.onnx, preprocessing, search
├── schemas/
│   ├── visual_search.py        Pydantic request/response Visual Search
│   └── katalog.py              Pydantic request/response katalog
├── requirements.txt
└── .env.example
```

## Cara jalan (pertama kali)

```bash
cd backend
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env
```

Isi `DATABASE_URL` di `.env` (connection string Neon — lihat komentar di
`.env.example` untuk cara convert format-nya). Baru setelah itu:

```bash
alembic upgrade head          # bikin tabel + extension pgvector di Neon
python -m scripts.seed_karya  # isi 8 karya contoh + embedding-nya
uvicorn main:app --reload --port 8000
```
Docs: http://localhost:8000/docs

## Artefak yang dipakai (hasil dari `ml-visual-search/`)

- `../ml-visual-search/export/model.onnx` — encoder gambar, output embedding
  **768-d** (BUKAN 2048 — itu komentar basi di `config.yaml`, sisa baseline
  ResNet50 lama; sudah diverifikasi langsung dari graph ONNX-nya).
- `../ml-visual-search/data/cache/label_to_idx__style_name.json` — mapping
  kelas (disimpan tapi belum dipakai — lihat catatan `style_predictions` di
  bawah).

Model **TIDAK** dimuat ulang per-request — sekali saat startup (`main.py`
lifespan), disimpan di `app.state`. Katalog embedding **TIDAK** lagi dari
file `.npz` statis — sekarang dari tabel `karya_embeddings` (pgvector),
di-query pakai cosine distance tiap ada request Visual Search.

## Yang belum diisi (TODO / di luar scope fase Visual Search)

- `style_predictions` di response Visual Search selalu `[]` — `model.onnx`
  cuma expose embedding, TIDAK expose logit klasifikasi style. Butuh
  re-export model dgn output tambahan kalau field ini mau diisi.
- Auth (`users`, JWT, Google Sign-In), tabel `transaksi`/`events`/
  `auth_sessions` — lihat CLAUDE.md "Autentikasi", belum dikerjakan.
- Cloudflare R2 — gambar karya masih dirujuk via `image_filename`, dicocokkan
  ke aset lokal yang sudah dibundling di `mobile/assets/images/catalog/`.
  Belum ada hosting gambar nyata.
- Endpoint Digital Art Identity (dari `ml-digital-art-identity/`) — belum ada,
  nanti dari anggota tim yang pegang fitur itu.

## Penting

- Jangan overclaim di response API — kalau `confidence_verdict` hasilnya
  `"ambiguous"`, JANGAN klaim satu karya pasti sama; tampilkan sebagai
  beberapa kandidat (lihat `ml-visual-search/notebooks/03_demo_inference.ipynb`
  untuk contoh perilaku yang benar).
- Istilah Digital Art Identity nanti: **"sertifikat digital keaslian"**,
  BUKAN "Hak Paten" (lihat CLAUDE.md).
