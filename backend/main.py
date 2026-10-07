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

import logging
import os
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

import models  # noqa: F401 -- registrasi SEMUA model ke Base.metadata, lihat models/__init__.py
from routers import karya_upload, katalog, verification, visual_search
from services.digital_art_identity_service import DigitalArtIdentityService
from services.visual_search_service import VisualSearchService

logger = logging.getLogger("galeria.startup")

BASE_DIR = Path(__file__).parent
ML_DIR = BASE_DIR.parent / "ml-visual-search"
DAI_DIR = BASE_DIR.parent / "ml-digital-art-identity"
# Penyimpanan gambar LOKAL sementara (ganti Cloudflare R2 begitu
# diimplementasi, lihat routers/karya_upload.py untuk alasan lengkap).
UPLOADS_DIR = BASE_DIR / "uploads"


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
    try:
        app.state.visual_search_service.load()
    except Exception as exc:
        # Graceful degrade -- pola SAMA PERSIS dgn database.py (DATABASE_URL
        # kosong tidak bikin app gagal start). Visual Search adalah fitur
        # TERPISAH (model/checkpoint dikerjakan anggota tim lain); kalau
        # ONNX-nya belum di-export di mesin ini, verification engine
        # (Art-to-Art/Art-to-AI, fitur terpisah) tetap harus bisa dipakai --
        # endpoint /api/visual-search sendiri yang akan gagal jelas
        # (RuntimeError "belum di-load", lihat visual_search_service.py)
        # kalau benar-benar dipanggil tanpa model, bukan silent-wrong.
        #
        # exc_info SENGAJA tidak dipakai -- traceback penuh di konsol startup
        # mudah disalahartikan sbg crash fatal (sudah pernah terjadi: user
        # menekan Ctrl+C begitu melihatnya, padahal startup lanjut normal
        # setelah ini). Satu baris ringkas sudah cukup informatif.
        logger.warning(
            "VisualSearchService gagal di-load (%s) -- endpoint "
            "/api/visual-search TIDAK akan berfungsi, fitur lain (termasuk "
            "verification engine Art-to-Art/Art-to-AI) tetap jalan normal.",
            exc,
        )

    # Verification engine (Art-to-Art + Art-to-AI) -- lihat
    # services/digital_art_identity_service.py. Threshold dibaca dari env
    # supaya bisa dikalibrasi ulang tanpa redeploy kode, default sama persis
    # dgn ml-digital-art-identity/configs/config.yaml.
    app.state.digital_art_identity_service = DigitalArtIdentityService(
        art_to_art_model_path=os.environ.get(
            "DAI_ART_TO_ART_MODEL_PATH", DAI_DIR / "export" / "art_to_art.onnx"
        ),
        art_to_ai_model_path=os.environ.get(
            "DAI_ART_TO_AI_MODEL_PATH", DAI_DIR / "export" / "art_to_ai.onnx"
        ),
        distance_threshold=float(os.environ.get("DAI_DISTANCE_THRESHOLD", "0.10")),
        ai_probability_threshold=float(os.environ.get("DAI_AI_PROBABILITY_THRESHOLD", "0.5")),
        phash_hamming_threshold=int(os.environ.get("DAI_PHASH_HAMMING_THRESHOLD", "5")),
    )
    app.state.digital_art_identity_service.load()

    yield
    # shutdown: (belum ada resource yang perlu ditutup eksplisit)


app = FastAPI(title="GALERIA API", version="0.1.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # TODO: ganti ke origin spesifik sebelum produksi
    allow_methods=["*"],
    allow_headers=["*"],
)

# Serve gambar karya yang di-upload lewat POST /api/karya (lihat
# routers/karya_upload.py) -- dibuat kalau belum ada, supaya startup tidak
# gagal di instalasi baru yang belum pernah ada upload sama sekali.
UPLOADS_DIR.mkdir(parents=True, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOADS_DIR), name="uploads")

app.include_router(visual_search.router)
app.include_router(katalog.router)
app.include_router(verification.router)
app.include_router(karya_upload.router)


@app.get("/")
async def root():
    return {"service": "GALERIA API", "status": "ok"}
