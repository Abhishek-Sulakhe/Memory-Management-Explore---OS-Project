#!/usr/bin/env bash
# ============================================================
# experiment_guardrails.sh — Demonstrate error handling and
# safety limits
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
echo -e "${BOLD}║   Experiment 3: Guard Rails and Error Handling       ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${CYAN}Goal:${RESET} Verify that safety limits work correctly and accounting"
echo -e "  does not drift on failed operations."
echo ""

# Clean slate
$CLI freeall 2>/dev/null || true

# Show limits
max_alloc=$($CLI status | grep max_allocation_bytes | awk '{print $2}')
max_tracked=$($CLI status | grep max_tracked_allocations | awk '{print $2}')
echo -e "${YELLOW}max_allocation_bytes    = ${max_alloc}${RESET}"
echo -e "${YELLOW}max_tracked_allocations = ${max_tracked}${RESET}"
echo ""

# Test 1: Oversize allocation
echo -e "${BOLD}--- Test 1: Attempt allocation exceeding max_allocation ---${RESET}"
echo -e "  Trying to allocate $((max_alloc + 1)) bytes..."
if $CLI alloc $((max_alloc + 1)) 2>/dev/null; then
  echo -e "  ${RED}ERROR: should have been rejected!${RESET}"
else
  echo -e "  ${GREEN}✓ Correctly rejected (oversize)${RESET}"
fi
echo ""
active=$($CLI status | grep 'active_allocations:' | awk '{print $2}')
echo -e "  active_allocations = ${active} (should be 0)"
echo -e "  ${CYAN}(Note: oversize rejects return -EINVAL at input validation,${RESET}"
echo -e "  ${CYAN} before any counters are touched — this is correct)${RESET}"

# Test 2: Zero-size allocation
echo ""
echo -e "${BOLD}--- Test 2: Attempt zero-size allocation ---${RESET}"
echo -e "  Trying to allocate 0 bytes..."
if echo "alloc 0" | sudo tee /proc/mem_explorer/control > /dev/null 2>&1; then
  echo -e "  ${RED}ERROR: should have been rejected!${RESET}"
else
  echo -e "  ${GREEN}✓ Correctly rejected (zero size)${RESET}"
fi

# Test 3: Free non-existent block
echo ""
echo -e "${BOLD}--- Test 3: Free a non-existent block ---${RESET}"
echo -e "  Trying to free id=99999..."
if $CLI free 99999 2>/dev/null; then
  echo -e "  ${RED}ERROR: should have been rejected!${RESET}"
else
  echo -e "  ${GREEN}✓ Correctly rejected (unknown handle)${RESET}"
fi

# Test 4: Fill non-existent block
echo ""
echo -e "${BOLD}--- Test 4: Fill a non-existent block ---${RESET}"
echo -e "  Trying to fill id=99999..."
if $CLI fill 99999 170 2>/dev/null; then
  echo -e "  ${RED}ERROR: should have been rejected!${RESET}"
else
  echo -e "  ${GREEN}✓ Correctly rejected (unknown handle)${RESET}"
fi

# Test 5: Resize non-existent block
echo ""
echo -e "${BOLD}--- Test 5: Resize a non-existent block ---${RESET}"
echo -e "  Trying to resize id=99999..."
if $CLI resize 99999 4096 2>/dev/null; then
  echo -e "  ${RED}ERROR: should have been rejected!${RESET}"
else
  echo -e "  ${GREEN}✓ Correctly rejected (unknown handle)${RESET}"
fi

# Test 6: Malformed command
echo ""
echo -e "${BOLD}--- Test 6: Malformed command ---${RESET}"
echo -e "  Sending 'garbage xyz'..."
if echo "garbage xyz" | sudo tee /proc/mem_explorer/control > /dev/null 2>&1; then
  echo -e "  ${RED}ERROR: should have been rejected!${RESET}"
else
  echo -e "  ${GREEN}✓ Correctly rejected (unknown command)${RESET}"
fi

# Verify accounting is clean
echo ""
echo -e "${BOLD}--- Final accounting check ---${RESET}"
echo ""
active=$($CLI status | grep 'active_allocations:' | awk '{print $2}')
bytes=$($CLI status | grep 'active_bytes:' | grep -v peak | awk '{print $2}')
echo -e "  active_allocations = ${active}  ${GREEN}(expected: 0)${RESET}"
echo -e "  active_bytes       = ${bytes}  ${GREEN}(expected: 0)${RESET}"

if [ "$active" = "0" ] && [ "$bytes" = "0" ]; then
  echo ""
  echo -e "  ${GREEN}✓ Accounting is clean — no drift from failed operations${RESET}"
else
  echo ""
  echo -e "  ${RED}✗ Accounting drifted — investigate!${RESET}"
fi

echo ""
echo -e "${BOLD}✓ Experiment 3 complete.${RESET}"
