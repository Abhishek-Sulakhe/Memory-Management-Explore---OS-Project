#!/usr/bin/env bash
set -euo pipefail

python3 tools/memx_cli.py freeall || true
ids=()

for size in 64 128 256 512 1024 2048 4096 8192 16384 32768; do
  id=$(python3 tools/memx_cli.py alloc "$size" | awk -F= '/allocated id=/{print $2}')
  ids+=("$id")
done

for id in "${ids[@]}"; do
  python3 tools/memx_cli.py touch "$id"
done

python3 tools/memx_cli.py status

for id in "${ids[@]}"; do
  python3 tools/memx_cli.py free "$id"
done

python3 tools/memx_cli.py status
