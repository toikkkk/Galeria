# Backend GALERIA (FastAPI + ONNXRuntime). Build dari ROOT repo: docker build -t galeria-api .
# Model v4 (ONNX, ~190 MB) di-bake ke image dari ml-visual-search/export/v4_11class/
# (file ini tidak ada di git, jadi build harus di mesin yang punya file itu).
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1

# libgomp1: dibutuhkan onnxruntime; opencv-headless tidak perlu libGL
RUN apt-get update && apt-get install -y --no-install-recommends libgomp1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY backend/requirements.txt .
RUN pip install -r requirements.txt

COPY backend/ /app/
COPY ml-visual-search/export/v4_11class/model.onnx /app/model/model.onnx
COPY ml-visual-search/export/v4_11class/label_to_idx__style_name.json /app/model/label_to_idx__style_name.json

ENV VS_MODEL_PATH=/app/model/model.onnx \
    VS_LABEL_MAP_PATH=/app/model/label_to_idx__style_name.json

# Cloud Run/Render/Railway menyuntikkan $PORT
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}"]
