#!/usr/bin/env bash
# ============================================================
# experiment_threshold.sh — Demonstrate kmalloc vs vmalloc
# threshold-based backend selection
# ============================================================
set -euo pipefail

CLI="python3 tools/memx_cli.py"
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║   Experiment 1: Threshold-Based Backend Selection   ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${CYAN}Goal:${RESET} Observe when the module switches from kmalloc to vmalloc."
echo -e "${CYAN}Threshold:${RESET} Sizes > vmalloc_threshold use vmalloc, otherwise kmalloc."
echo ""

# Clean slate
$CLI freeall 2>/dev/null || true

# Read current threshold
threshold=$($CLI status | grep vmalloc_threshold_bytes | awk '{print $2}')
echo -e "${YELLOW}Current vmalloc_threshold = ${threshold} bytes${RESET}"
echo ""

echo -e "${BOLD}--- Allocating blocks at various sizes ---${RESET}"
echo ""

ids=()
for size in 64 512 2048 4096 8192 8193 16384 65536; do
  id=$($CLI alloc "$size" | awk -F= '/allocated id=/{print $2}')
  ids+=("$id")

  # Determine expected backend
  if [ "$size" -gt "$threshold" ]; then
    expected="vmalloc"
  else
    expected="kmalloc"
  fi
  echo -e "  Allocated ${GREEN}${size}${RESET} bytes → id=${id}  (expected: ${YELLOW}${expected}${RESET})"
done

echo ""
echo -e "${BOLD}--- Status: Active allocations table ---${RESET}"
echo ""
$CLI status | sed -n '/Active allocations:/,$ p'

echo ""
echo -e "${BOLD}--- Backend breakdown ---${RESET}"
echo ""
$CLI status | sed -n '/Backend breakdown:/,/^$/p'

echo ""
echo -e "${BOLD}--- Observation ---${RESET}"
echo -e "  Sizes ≤ ${threshold}: allocated via ${GREEN}kmalloc${RESET} (physically contiguous)"
echo -e "  Sizes > ${threshold}: allocated via ${GREEN}vmalloc${RESET} (virtually contiguous)"

echo ""
echo -e "${BOLD}--- Cleanup ---${RESET}"
$CLI freeall
echo "  All blocks freed."
echo ""
echo -e "${BOLD}✓ Experiment 1 complete.${RESET}"
