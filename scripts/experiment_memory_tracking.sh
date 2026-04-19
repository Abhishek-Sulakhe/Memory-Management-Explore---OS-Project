#!/usr/bin/env bash
# ============================================================
# experiment_memory_tracking.sh — Demonstrate byte-accurate
# memory accounting and peak tracking
# ============================================================
set -euo pipefail

CLI="python3 tools/memx_cli.py"
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║   Experiment 2: Active Memory Accounting            ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${CYAN}Goal:${RESET} Validate byte-accurate tracking of live memory and"
echo -e "  peak memory high-water mark."
echo ""

# Clean slate
$CLI freeall 2>/dev/null || true

get_val() {
  $CLI status | grep "$1" | head -1 | awk '{print $2}'
}

echo -e "${BOLD}--- Initial state ---${RESET}"
echo -e "  active_bytes:     $(get_val 'active_bytes:')"
echo -e "  peak_active_bytes: $(get_val 'peak_active_bytes:')"
echo ""

# Allocate 1024
echo -e "${BOLD}--- Allocate 1024 bytes ---${RESET}"
id1=$($CLI alloc 1024 --zero | awk -F= '/allocated id=/{print $2}')
echo -e "  id=${id1}"
echo -e "  active_bytes:     $(get_val 'active_bytes:')  ${GREEN}(expected: 1024)${RESET}"
echo ""

# Allocate 2048
echo -e "${BOLD}--- Allocate 2048 bytes ---${RESET}"
id2=$($CLI alloc 2048 | awk -F= '/allocated id=/{print $2}')
echo -e "  id=${id2}"
echo -e "  active_bytes:     $(get_val 'active_bytes:')  ${GREEN}(expected: 3072)${RESET}"
echo ""

# Allocate 4096
echo -e "${BOLD}--- Allocate 4096 bytes ---${RESET}"
id3=$($CLI alloc 4096 | awk -F= '/allocated id=/{print $2}')
echo -e "  id=${id3}"
echo -e "  active_bytes:     $(get_val 'active_bytes:')  ${GREEN}(expected: 7168)${RESET}"
echo -e "  peak_active_bytes: $(get_val 'peak_active_bytes:')  ${GREEN}(expected: ≥ 7168)${RESET}"
echo ""

# Free the 2048 block
echo -e "${BOLD}--- Free 2048-byte block (id=${id2}) ---${RESET}"
$CLI free "$id2"
echo -e "  active_bytes:     $(get_val 'active_bytes:')  ${GREEN}(expected: 5120)${RESET}"
echo -e "  peak_active_bytes: $(get_val 'peak_active_bytes:')  ${YELLOW}(unchanged — high-water mark never decreases)${RESET}"
echo ""

# Free remaining
echo -e "${BOLD}--- Free remaining blocks ---${RESET}"
$CLI free "$id1"
$CLI free "$id3"
echo -e "  active_bytes:     $(get_val 'active_bytes:')  ${GREEN}(expected: 0)${RESET}"
echo -e "  peak_active_bytes: $(get_val 'peak_active_bytes:')  ${YELLOW}(unchanged — never resets on free)${RESET}"
echo ""

echo -e "${BOLD}--- Analysis ---${RESET}"
echo -e "  • active_bytes tracks the ${GREEN}exact sum${RESET} of all live allocations"
echo -e "  • peak_active_bytes records the ${YELLOW}highest value ever reached${RESET}"
echo -e "  • freeing blocks decreases active_bytes but ${YELLOW}never${RESET} decreases peak"
echo ""
echo -e "${BOLD}✓ Experiment 2 complete.${RESET}"
