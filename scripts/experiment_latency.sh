#!/usr/bin/env bash
# ============================================================
# experiment_latency.sh — Quantitative latency comparison
# between kmalloc and vmalloc
# ============================================================
set -euo pipefail

CLI="python3 tools/memx_cli.py"
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║   Experiment 6: Allocation Latency Comparison       ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${CYAN}Goal:${RESET} Quantitatively compare kmalloc vs vmalloc allocation speed."
echo -e "${CYAN}Method:${RESET} Allocate blocks of varying sizes and read per-block latency."
echo ""

# Clean slate
$CLI freeall 2>/dev/null || true

echo -e "${BOLD}--- Phase 1: Small allocations (kmalloc) ---${RESET}"
echo ""
kmalloc_ids=()
for size in 64 128 256 512 1024 2048 4096; do
  id=$($CLI alloc "$size" | awk -F= '/allocated id=/{print $2}')
  kmalloc_ids+=("$id")
  echo -e "  Allocated ${GREEN}${size}${RESET} bytes → id=${id}"
done

echo ""
echo -e "${BOLD}--- Phase 2: Large allocations (vmalloc) ---${RESET}"
echo ""
vmalloc_ids=()
for size in 16384 32768 65536 131072 262144 524288 1048576; do
  id=$($CLI alloc "$size" | awk -F= '/allocated id=/{print $2}')
  vmalloc_ids+=("$id")
  echo -e "  Allocated ${YELLOW}${size}${RESET} bytes → id=${id}"
done

echo ""
echo -e "${BOLD}--- Results: Per-block latency ---${RESET}"
echo ""
$CLI status | sed -n '/Active allocations:/,$ p'

echo ""
echo -e "${BOLD}--- Aggregate latency statistics ---${RESET}"
echo ""
$CLI status | sed -n '/Latency:/,/^$/p'

echo ""
echo -e "${BOLD}--- Backend breakdown ---${RESET}"
echo ""
$CLI status | sed -n '/Backend breakdown:/,/^$/p'

echo ""
echo -e "${BOLD}--- Analysis ---${RESET}"
echo -e "  ${GREEN}kmalloc${RESET} latencies are typically in the ${GREEN}hundreds of nanoseconds${RESET}"
echo -e "  (fast slab-allocator path, physically contiguous memory)."
echo ""
echo -e "  ${YELLOW}vmalloc${RESET} latencies are typically in the ${YELLOW}thousands of nanoseconds${RESET}"
echo -e "  (requires page-table setup, virtually contiguous only)."
echo ""
echo -e "  ${RED}Key insight:${RESET} vmalloc is slower because it must set up page-table"
echo -e "  entries to create a virtually contiguous mapping from potentially"
echo -e "  non-contiguous physical pages."

echo ""
echo -e "${BOLD}--- Cleanup ---${RESET}"
$CLI freeall
echo "  All blocks freed."
echo ""
echo -e "${BOLD}✓ Experiment 6 complete.${RESET}"
