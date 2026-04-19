#!/usr/bin/env bash
# stress_allocator.sh — repeatable stress workload for timing analysis
set -euo pipefail

CLI="python3 tools/memx_cli.py"

echo "=== Stress Workload ==="

$CLI freeall || true
ids=()

echo ""
echo "--- Allocating 10 blocks across the threshold boundary ---"
for size in 64 128 256 512 1024 2048 4096 8192 16384 32768; do
  id=$($CLI alloc "$size" | awk -F= '/allocated id=/{print $2}')
  ids+=("$id")
  echo "  alloc $size bytes -> id=$id"
done

echo ""
echo "--- Touching all blocks ---"
for id in "${ids[@]}"; do
  $CLI touch "$id"
done

echo ""
echo "--- Resizing selected blocks ---"
# Resize a small block up (stays kmalloc)
$CLI resize "${ids[0]}" 512
echo "  resized id=${ids[0]} 64->512"

# Resize a small block past the threshold (kmalloc -> vmalloc)
$CLI resize "${ids[4]}" 16384
echo "  resized id=${ids[4]} 1024->16384"

# Resize a large block down (vmalloc -> kmalloc)
$CLI resize "${ids[9]}" 2048
echo "  resized id=${ids[9]} 32768->2048"

echo ""
echo "--- Status after allocations and resizes ---"
$CLI status

echo ""
echo "--- Latency summary ---"
$CLI latency

echo ""
echo "--- Freeing all blocks ---"
for id in "${ids[@]}"; do
  $CLI free "$id"
done

echo ""
echo "--- Final status ---"
$CLI status

echo ""
echo "=== Stress workload complete ==="
