#!/usr/bin/env bash
# ============================================================
# run_all_experiments.sh — Run all experiments in sequence
# for a complete project demonstration
# ============================================================
set -euo pipefail

BOLD='\033[1m'
CYAN='\033[0;36m'
RESET='\033[0m'
DIVIDER="════════════════════════════════════════════════════════"

echo -e "${BOLD}${DIVIDER}${RESET}"
echo -e "${BOLD}   Memory Management Explorer — Full Demonstration${RESET}"
echo -e "${BOLD}${DIVIDER}${RESET}"
echo ""
echo -e "${CYAN}This script runs all experiments in sequence.${RESET}"
echo -e "${CYAN}Press Enter to begin each experiment or Ctrl+C to exit.${RESET}"
echo ""

run_experiment() {
  local name="$1"
  local script="$2"

  echo -e "${BOLD}${DIVIDER}${RESET}"
  echo -e "${BOLD}  Next: ${name}${RESET}"
  echo -e "${BOLD}${DIVIDER}${RESET}"
  read -r -p "  Press Enter to run..."
  echo ""
  bash "$script"
  echo ""
}

run_experiment "Experiment 1 — Threshold Behavior"      scripts/experiment_threshold.sh
run_experiment "Experiment 2 — Memory Tracking"          scripts/experiment_memory_tracking.sh
run_experiment "Experiment 3 — Guard Rails"              scripts/experiment_guardrails.sh
run_experiment "Experiment 6 — Latency Comparison"       scripts/experiment_latency.sh
run_experiment "Experiment 7 — Resize & Migration"       scripts/experiment_resize.sh
run_experiment "Demo — Guided Allocator Walkthrough"     scripts/demo_allocator.sh
run_experiment "Stress — Multi-block Workload"           scripts/stress_allocator.sh

echo -e "${BOLD}${DIVIDER}${RESET}"
echo -e "${BOLD}   All experiments complete!${RESET}"
echo -e "${BOLD}${DIVIDER}${RESET}"
