"""GALERIA backend — FastAPI app entrypoint.

Tanggung jawab file ini:
- Buat `FastAPI` app, daftarkan semua router (`routers/`).
- Muat model Visual Search SEKALI saat startup (bukan per-request) via
  `lifespan`/`startup` event, simpan di `app.state`.
- CORS untuk aplikasi mobile (Flutter, lihat `../mobile/`).

Jalankan:
    uvicorn main:app --reload --port 8000
Docs otomatis: http://localhost:8000/docs
"""

from __future__ import annotations

import os
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers import katalog, visual_search
from services.visual_search_service import VisualSearchService

BASE_DIR = Path(__file__).parent
ML_DIR = BASE_DIR.parent / "ml-visual-search"


@asynccontextmanager
async def lifespan(app: FastAPI):
    # startup: muat model SEKALI (katalog sekarang dari database, bukan lagi
    # file .npz statis -- lihat services/visual_search_service.py)
    app.state.visual_search_service = VisualSearchService(
        model_path=os.environ.get("VS_MODEL_PATH", ML_DIR / "export" / "model.onnx"),
        label_map_path=os.environ.get(
            "VS_LABEL_MAP_PATH", ML_DIR / "data" / "cache" / "label_to_idx__style_name.json"
        ),
    )
    app.state.visual_search_service.load()
    yield
    # shutdown: (belum ada resource yang perlu ditutup eksplisit)


app = FastAPI(title="GALERIA API", version="0.1.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # TODO: ganti ke origin spesifik sebelum produksi
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(visual_search.router)
app.include_router(katalog.router)


@app.get("/")
async def root():
    return {"service": "GALERIA API", "status": "ok"}
