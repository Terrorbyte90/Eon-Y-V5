#!/usr/bin/env bash
set -euo pipefail

model_dir="${HOME}/Library/Application Support/Eon/Models"
model_file="Qwen3-1.7B-Q4_K_M.gguf"
mkdir -p "$model_dir"
if [[ -f "$model_dir/$model_file" ]]; then
  echo "Model already installed: $model_dir/$model_file"
  exit 0
fi
echo "The model is intentionally not checked into Git because it is large."
echo "Download the exact Qwen3 GGUF release approved for this build, then place it at:"
echo "$model_dir/$model_file"
echo "Afterward restart Eon; the app searches this Mac path before falling back."
