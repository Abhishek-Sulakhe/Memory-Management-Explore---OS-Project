#!/usr/bin/env bash
# ============================================================
# experiment_resize.sh — Demonstrate resize and backend
# migration using krealloc
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
echo -e "${BOLD}║   Experiment 7: Resize and Backend Migration        ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${CYAN}Goal:${RESET} Observe how resizing affects backend selection."
echo -e "${CYAN}Key concept:${RESET} krealloc can resize in-place within kmalloc;"
echo -e "  cross-backend resize requires full allocate-copy-free."
echo ""

# Clean slate
$CLI freeall 2>/dev/null || true

threshold=$($CLI status | grep vmalloc_threshold_bytes | awk '{print $2}')
echo -e "${YELLOW}Current vmalloc_threshold = ${threshold} bytes${RESET}"
echo ""

# Step 1: Allocate a small block
echo -e "${BOLD}--- Step 1: Allocate 1024 bytes (kmalloc) ---${RESET}"
id=$($CLI alloc 1024 | awk -F= '/allocated id=/{print $2}')
echo -e "  Block id=${id} allocated via ${GREEN}kmalloc${RESET}"
echo ""
$CLI status | sed -n '/Active allocations:/,$ p'

# Step 2: Resize within kmalloc
echo ""
echo -e "${BOLD}--- Step 2: Resize ${id} from 1024 → 4096 (stays in kmalloc) ---${RESET}"
echo -e "  ${CYAN}Using krealloc — may resize in place, no backend change${RESET}"
$CLI resize "$id" 4096
echo ""
$CLI status | sed -n '/Active allocations:/,$ p'
echo ""
$CLI status | sed -n '/Backend breakdown:/,/^$/p'

# Step 3: Resize across threshold (kmalloc → vmalloc)
echo ""
echo -e "${BOLD}--- Step 3: Resize ${id} from 4096 → 32768 (kmalloc → vmalloc) ---${RESET}"
echo -e "  ${RED}Backend change! Full allocate-copy-free cycle required${RESET}"
echo -e "  ${CYAN}Cannot use krealloc — must vmalloc new, memcpy, kfree old${RESET}"
$CLI resize "$id" 32768
echo ""
$CLI status | sed -n '/Active allocations:/,$ p'
echo ""
$CLI status | sed -n '/Backend breakdown:/,/^$/p'

# Step 4: Resize back down (vmalloc → kmalloc)
echo ""
echo -e "${BOLD}--- Step 4: Resize ${id} from 32768 → 512 (vmalloc → kmalloc) ---${RESET}"
echo -e "  ${RED}Backend change again! Full allocate-copy-free in reverse${RESET}"
$CLI resize "$id" 512
echo ""
$CLI status | sed -n '/Active allocations:/,$ p'
echo ""
$CLI status | sed -n '/Backend breakdown:/,/^$/p'

# Step 5: Show resize counter
echo ""
echo -e "${BOLD}--- Resize request counter ---${RESET}"
$CLI status | grep resize_requests

echo ""
echo -e "${BOLD}--- Analysis ---${RESET}"
echo -e "  • ${GREEN}Same-backend resize${RESET} (kmalloc→kmalloc) uses ${GREEN}krealloc${RESET}"
echo -e "    → fast, may avoid memory copy entirely"
echo -e "  • ${RED}Cross-backend resize${RESET} (kmalloc↔vmalloc) requires"
echo -e "    → allocate new + memcpy + free old (slower, visible in latency)"
echo -e "  • No ${YELLOW}vrealloc${RESET} exists in the Linux kernel, so vmalloc→vmalloc"
echo -e "    resize also uses the full copy path"

echo ""
echo -e "${BOLD}--- Cleanup ---${RESET}"
$CLI freeall
echo "  All blocks freed."
echo ""
echo -e "${BOLD}✓ Experiment 7 complete.${RESET}"
