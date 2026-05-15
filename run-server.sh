#!/usr/bin/env bash
set -euo pipefail

# ── Choose your model variant ──
MODEL_CONFIG="${1:-q4}"  # q4 or q6

case "$MODEL_CONFIG" in
  q4)
    # unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q4_K_M
    # Benchmark winner: f16 KV + ubatch 1024 + flash-attn on
    HF_REPO="unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q4_K_M"
    THREADS=6
    THREADS_BATCH=6
    BATCH_SIZE=4096
    UBATCH_SIZE=1024
    FIT_TARGET=4096
    CACHE_TYPE_K="f16"
    CACHE_TYPE_V="f16"
    FLASH_ATTN="on"
    CTX_SIZE=0
    ;;
  q6)
    # unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q6_K_XL
    # Q6 uses ~1.5× RAM of Q4 — keep threads/ubatch/fit-target same as Q4
    HF_REPO="unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q6_K_XL"
    THREADS=6
    THREADS_BATCH=6
    BATCH_SIZE=4096
    UBATCH_SIZE=1024
    FIT_TARGET=4096
    CACHE_TYPE_K="f16"
    CACHE_TYPE_V="f16"
    FLASH_ATTN="on"
    CTX_SIZE=0
    ;;
  *)
    echo "Usage: $0 [q4|q6]"
    exit 1
    ;;
esac

# Kill any existing llama-server
pkill llama-server 2>/dev/null || true

# Run the server natively (Metal on Apple Silicon)
# Optimizations from benchmarks (M5 Max, 48 GB):
#   --cache-type-k/v f16     → ~5% faster decode than q8_0
#   --ubatch-size 1024       → faster prefill on long prompts
#   --flash-attn on          → enabled for this model architecture
#   --ctx-size 0             → use model's native context (262144)
exec llama-server \
  -hf "$HF_REPO" \
  --no-mmproj \
  --alias claude-sonnet-4-6,sonnet,opus,haiku,local \
  --host 0.0.0.0 \
  --port 8000 \
  --n-gpu-layers 999 \
  --flash-attn "$FLASH_ATTN" \
  --threads "$THREADS" \
  --threads-batch "$THREADS_BATCH" \
  --batch-size "$BATCH_SIZE" \
  --ubatch-size "$UBATCH_SIZE" \
  --ctx-size "$CTX_SIZE" \
  --fit on \
  --fit-target "$FIT_TARGET" \
  --cache-type-k "$CACHE_TYPE_K" \
  --cache-type-v "$CACHE_TYPE_V" \
  --cache-prompt \
  --cache-reuse 256 \
  --parallel 1 \
  --temp 0.6 \
  --top-p 0.95 \
  --top-k 20 \
  --min-p 0.0 \
  --presence-penalty 0.0 \
  --mlock \
  --prio 2
