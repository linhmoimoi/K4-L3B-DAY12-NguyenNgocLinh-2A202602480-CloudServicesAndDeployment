#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# Script kiểm tra bản deploy Cloud — Checkpoint 5
# Cách dùng:
#   chmod +x test_deploy.sh
#   ./test_deploy.sh https://your-service.up.railway.app
# Hoặc gán URL trực tiếp bên dưới rồi chạy: ./test_deploy.sh
# ─────────────────────────────────────────────────────────────

URL="${1:-https://TODO-thay-bang-url-that.up.railway.app}"
# Xóa dấu gạch chéo cuối nếu có
URL="${URL%/}"

echo "=================================================="
echo "Kiểm tra bản deploy tại: $URL"
echo "=================================================="

# Đọc DEPLOY_API_KEY từ file .env nếu có
if [ -f .env ]; then
  DEPLOY_API_KEY=$(grep -E '^DEPLOY_API_KEY=' .env | cut -d '=' -f2- | tr -d '"' | tr -d "'" | tr -d '\r')
  if [ -z "$DEPLOY_API_KEY" ]; then
    DEPLOY_API_KEY=$(grep -E '^AGENT_API_KEY=' .env | cut -d '=' -f2- | tr -d '"' | tr -d "'" | tr -d '\r')
  fi
fi

echo ""
echo "[1] GET /health (Liveness) — mong đợi: 200 {\"status\": \"ok\", ...}"
curl -i -s -S "$URL/health"
echo ""

echo ""
echo "[2] GET /ready (Readiness) — mong đợi: 200 {\"status\": \"ready\", \"redis\": true}"
curl -i -s -S "$URL/ready"
echo ""

echo ""
echo "[3] POST /ask (Không có API key) — mong đợi: 401 Unauthorized"
curl -i -s -S -X POST "$URL/ask" \
  -H "Content-Type: application/json" \
  -d '{"question":"Hello"}'
echo ""

if [ -n "$DEPLOY_API_KEY" ]; then
  echo ""
  echo "[4] POST /ask (Có API key) — mong đợi: 200 kèm câu trả lời"
  curl -i -s -S -X POST "$URL/ask" \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $DEPLOY_API_KEY" \
    -H "X-User-Id: sv01" \
    -d '{"question":"Docker là gì?"}'
  echo ""

  echo ""
  echo "[5] Rate Limiter check (gửi 15 request liên tiếp, những lần cuối phải là 429):"
  for i in $(seq 1 15); do
    code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$URL/ask" \
      -H "Content-Type: application/json" \
      -H "X-API-Key: $DEPLOY_API_KEY" \
      -H "X-User-Id: sv-rate-test" \
      -d '{"question":"test rate limit"}')
    echo -n "$code "
  done
  echo ""
else
  echo ""
  echo "[!] Chưa tìm thấy DEPLOY_API_KEY hoặc AGENT_API_KEY trong file .env để chạy test có xác thực."
fi

echo ""
echo "=================================================="
echo "Hoàn thành kiểm tra. Hãy copy output dán vào DEPLOYMENT.md"
echo "=================================================="
