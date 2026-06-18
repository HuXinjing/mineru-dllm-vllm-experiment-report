#!/usr/bin/env bash
set -euo pipefail

: "${VLLM_REPO:?set VLLM_REPO to the vLLM PR repository path}"
: "${MODEL_PATH:?set MODEL_PATH to the MinerU-Diffusion model path}"

PYTHON_BIN="${PYTHON_BIN:-python}"
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-18100}"
GPU="${GPU:-0}"
LOG_PATH="${LOG_PATH:-artifacts/logs/vllm_mineru_server.log}"
ALLOWED_LOCAL_MEDIA_PATH="${ALLOWED_LOCAL_MEDIA_PATH:-/}"
SERVED_MODEL_NAME="${SERVED_MODEL_NAME:-mineru-diffusion}"

mkdir -p "$(dirname "$LOG_PATH")"

cd "$VLLM_REPO"
export CUDA_VISIBLE_DEVICES="$GPU"
export VLLM_ATTENTION_BACKEND="${VLLM_ATTENTION_BACKEND:-TRITON_ATTN}"

if [[ -n "${FLASH_ATTN_EXT_SOURCE:-}" ]]; then
  mkdir -p "$VLLM_REPO/vllm/vllm_flash_attn"
  cp "$FLASH_ATTN_EXT_SOURCE"/_vllm_fa*_C*.so \
    "$VLLM_REPO/vllm/vllm_flash_attn"/
fi

exec "$PYTHON_BIN" -m vllm.entrypoints.openai.api_server \
  --host "$HOST" \
  --port "$PORT" \
  --disable-uvicorn-access-log \
  --model "$MODEL_PATH" \
  --trust-remote-code \
  --dtype bfloat16 \
  --allowed-local-media-path "$ALLOWED_LOCAL_MEDIA_PATH" \
  --max-model-len 4096 \
  --served-model-name "$SERVED_MODEL_NAME" \
  --attention-backend TRITON_ATTN \
  --gpu-memory-utilization 0.8 \
  --enable-logging-iteration-details \
  --max-num-batched-tokens 4096 \
  --max-num-seqs 4
