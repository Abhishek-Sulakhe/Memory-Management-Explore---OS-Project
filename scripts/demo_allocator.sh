#!/usr/bin/env bash
# demo_allocator.sh — guided demonstration of the Memory Management Explorer
set -euo pipefail

CLI="python3 tools/memx_cli.py"

echo "=== Memory Management Explorer Demo ==="
echo ""

echo "--- Initial status ---"
$CLI status

echo ""
echo "--- Allocating 1024 bytes (kmalloc, zeroed) ---"
id1=$($CLI alloc 1024 --zero | awk -F= '/allocated id=/{print $2}')
echo "  -> id=$id1"

echo ""
echo "--- Allocating 16384 bytes (vmalloc) ---"
id2=$($CLI alloc 16384 | awk -F= '/allocated id=/{print $2}')
echo "  -> id=$id2"

echo ""
echo "--- Fill block $id1 with byte 0xAA ---"
$CLI fill "$id1" 170

echo ""
echo "--- Touch both blocks (page-stride checksum) ---"
$CLI touch "$id1"
$CLI touch "$id2"

echo ""
echo "--- Resize block $id1: 1024 -> 4096 (kmalloc stays kmalloc) ---"
$CLI resize "$id1" 4096

echo ""
echo "--- Resize block $id1: 4096 -> 32768 (kmalloc -> vmalloc) ---"
$CLI resize "$id1" 32768

echo ""
echo "--- Current status (notice backend breakdown & latency) ---"
$CLI status

echo ""
echo "--- Latency summary ---"
$CLI latency

echo ""
echo "--- Free both blocks ---"
$CLI free "$id1"
$CLI free "$id2"

echo ""
echo "--- Final status ---"
$CLI status

echo ""
echo "=== Demo complete ==="
