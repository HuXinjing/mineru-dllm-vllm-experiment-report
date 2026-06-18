#!/usr/bin/env bash
set -euo pipefail

REPORT_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${VLLM_REPO:?set VLLM_REPO to the vLLM PR repository path}"
: "${MINERU_REPO:?set MINERU_REPO to the MinerU harness PR repository path}"
: "${MODEL_PATH:?set MODEL_PATH to the MinerU-Diffusion model path}"

PYTHON_BIN="${PYTHON_BIN:-python}"
GPU="${GPU:-0}"
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-18100}"
ENDPOINT="http://${HOST}:${PORT}/v1/chat/completions"
HEALTH_URL="http://${HOST}:${PORT}/health"
RUN_DIR="${RUN_DIR:-$REPORT_REPO/data/rerun/$(date +%Y%m%d_%H%M%S)}"
MANIFEST="${MANIFEST:-$REPORT_REPO/manifests/pdf_suite_coverage/manifest.json}"
PRO_RESULTS_JSONL="${PRO_RESULTS_JSONL:-$REPORT_REPO/data/original/pro_conc4_baseline/latest_results.jsonl}"
SERVER_LOG="$RUN_DIR/vllm_mineru_server.log"

mkdir -p "$RUN_DIR"

cleanup() {
  if [[ -n "${SERVER_PID:-}" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

echo "Starting vLLM server on ${HEALTH_URL}"
(
  VLLM_REPO="$VLLM_REPO" \
  MODEL_PATH="$MODEL_PATH" \
  PYTHON_BIN="$PYTHON_BIN" \
  HOST="$HOST" \
  PORT="$PORT" \
  GPU="$GPU" \
  ALLOWED_LOCAL_MEDIA_PATH="/" \
  FLASH_ATTN_EXT_SOURCE="${FLASH_ATTN_EXT_SOURCE:-}" \
  "$REPORT_REPO/scripts/start_vllm_mineru_server.sh"
) >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!
echo "$SERVER_PID" > "$RUN_DIR/vllm_server.pid"

for _ in $(seq 1 420); do
  if curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then
    break
  fi
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "vLLM server exited early. See $SERVER_LOG" >&2
    exit 1
  fi
  sleep 1
done
curl -fsS "$HEALTH_URL" >/dev/null

echo "Running layout sampling experiment"
(
  cd "$MINERU_REPO"
  "$PYTHON_BIN" -m benchmarks.mineru_diffusion.layout_sampling_experiment \
    --manifest "$MANIFEST" \
    --endpoint "$ENDPOINT" \
    --output-dir "$RUN_DIR/layout_sampling_t090" \
    --layout-concurrency 4 \
    --dynamic-threshold 0.90 \
    --pro-results-jsonl "$PRO_RESULTS_JSONL"
)

echo "Running DLLM two-step throughput"
(
  cd "$MINERU_REPO"
  "$PYTHON_BIN" -m benchmarks.mineru_diffusion.end2end_suite \
    run-dllm \
    --manifest "$MANIFEST" \
    --endpoint "$ENDPOINT" \
    --output-dir "$RUN_DIR/dllm_conc4_t090" \
    --content-concurrency 4 \
    --dynamic-threshold 0.90
)

echo "Running DLLM two-step throughput mode"
(
  cd "$MINERU_REPO"
  "$PYTHON_BIN" -m benchmarks.mineru_diffusion.end2end_suite \
    run-dllm-throughput \
    --manifest "$MANIFEST" \
    --endpoint "$ENDPOINT" \
    --output-dir "$RUN_DIR/dllm_conc4_t090_throughput" \
    --layout-concurrency 4 \
    --content-concurrency 4 \
    --dynamic-threshold 0.90
)

echo "Comparing rerun DLLM output against original Pro conc4 baseline"
(
  cd "$MINERU_REPO"
  "$PYTHON_BIN" -m benchmarks.mineru_diffusion.end2end_suite \
    compare \
    --baseline "$PRO_RESULTS_JSONL" \
    --candidate "$RUN_DIR/dllm_conc4_t090/latest_results.jsonl" \
    --output "$RUN_DIR/compare_pro_original_vs_dllm_rerun.json"
)

cat > "$RUN_DIR/run_metadata.json" <<EOF
{
  "vllm_repo": "$VLLM_REPO",
  "mineru_repo": "$MINERU_REPO",
  "model_path": "$MODEL_PATH",
  "manifest": "$MANIFEST",
  "endpoint": "$ENDPOINT",
  "gpu": "$GPU"
}
EOF

echo "Rerun artifacts written to $RUN_DIR"
