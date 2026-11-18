# Cú Brain trên Google Cloud Run (bản cloud). Bản chạy trên máy tính ở nhà vẫn dùng run_backend.ps1.
# Cloud dùng Gemini đọc ảnh trực tiếp → không cài EasyOCR/torch (nhẹ, khởi động nhanh).
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /srv
COPY requirements.txt requirements-cloud.txt ./
RUN pip install -r requirements-cloud.txt

COPY app ./app

# Mặc định cho cloud (có thể ghi đè bằng env.yaml khi deploy)
ENV STORE_BACKEND=firestore \
    OCR_MODE=off \
    CORS_ORIGIN_REGEX=off \
    WEB_DIR=/srv/no-web

# Cloud Run truyền cổng qua biến PORT (mặc định 8080)
CMD exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080} --workers 1 --timeout-keep-alive 30
