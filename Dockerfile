# ═══════════════════════════════════════════════════════════════════
# Stage 1: builder — cài dependency, có thể cần compiler
# ═══════════════════════════════════════════════════════════════════
FROM python:3.11-slim AS builder

WORKDIR /build

# Copy requirements trước → Docker cache layer này khi dependency không đổi
COPY requirements.txt .

# Cài dependency vào /install để dễ copy sang stage runtime
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ═══════════════════════════════════════════════════════════════════
# Stage 2: runtime — image gọn, chỉ chứa kết quả
# ═══════════════════════════════════════════════════════════════════
FROM python:3.11-slim AS runtime

WORKDIR /app

# Copy packages đã cài từ builder — không mang theo pip cache hay compiler
COPY --from=builder /install /usr/local

# Copy source code ứng dụng (sau pip install → tận dụng cache)
COPY app ./app
COPY utils ./utils
COPY requirements.txt .

# Tạo user thường — container chạy root = lỗ hổng bảo mật nghiêm trọng
RUN useradd --create-home --uid 10001 appuser
USER appuser

# Health check — Docker tự gọi /health để biết container còn phục vụ không
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:${PORT:-8000}/health').read()" || exit 1

EXPOSE ${PORT:-8000}

# Đọc PORT từ biến môi trường (cloud tự gán), mặc định 8000
# Phải bind 0.0.0.0 — bind 127.0.0.1 thì bên ngoài container không gọi được
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
