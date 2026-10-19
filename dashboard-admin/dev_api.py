"""API ringan utk dashboard admin (hanya memuat /api/admin/*).

Dipakai saat `backend/main.py` penuh belum bisa start (mis. model.onnx Visual Search belum ada).
Jalankan dari folder backend/:
    python -m uvicorn dev_api:app --app-dir ../dashboard-admin --port 8000
"""

import sys
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1] / "backend"
sys.path.insert(0, str(BACKEND))

from dotenv import load_dotenv  # noqa: E402

load_dotenv(BACKEND / ".env")

from fastapi import FastAPI  # noqa: E402
from fastapi.middleware.cors import CORSMiddleware  # noqa: E402

from routers import admin_dashboard  # noqa: E402

app = FastAPI(title="GALERIA Admin API (dev)")
app.add_middleware(CORSMiddleware, allow_origins=["http://localhost:5173", "http://127.0.0.1:5173"],
                   allow_methods=["GET"], allow_headers=["*"])
app.include_router(admin_dashboard.router)
