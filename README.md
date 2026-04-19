# Memory Management Explorer

Memory Management Explorer is an academic operating-systems project that studies
kernel-space dynamic memory allocation through a custom handle-based allocator
built on top of `kmalloc` and `vmalloc`. The project is designed for labs,
demonstrations, and report-based coursework rather than production deployment.

## Project goals

- Compare contiguous allocation (`kmalloc`) with virtually contiguous allocation
  (`vmalloc`) under a unified interface.
- Measure allocation latency with nanosecond precision to quantitatively compare
  the two backends.
- Demonstrate kernel bookkeeping, synchronization, `/proc`-based control, and
  safe reclamation of dynamically allocated memory.
- Support resizing through `krealloc` and cross-backend migration.
- Provide a small experimental framework that students can use to observe
  allocation behavior and discuss memory-management tradeoffs.

## Structure

- `src/mem_explorer.c`: Linux kernel module implementing the allocator.
- `src/Makefile`: Kbuild configuration for the module.
- `tools/memx_cli.py`: User-space helper for sending commands to `/proc`.
- `scripts/demo_allocator.sh`: Guided demo workload.
- `scripts/stress_allocator.sh`: Repeatable stress-style workload.
- `scripts/experiment_threshold.sh`: Experiment — backend selection by size.
- `scripts/experiment_memory_tracking.sh`: Experiment — byte-accurate accounting.
- `scripts/experiment_guardrails.sh`: Experiment — error handling and limits.
- `scripts/experiment_latency.sh`: Experiment — kmalloc vs vmalloc timing.
- `scripts/experiment_resize.sh`: Experiment — resize and backend migration.
- `scripts/run_all_experiments.sh`: Master script — runs all experiments for demos.
- `docs/architecture.md`: Design description.
- `docs/experiments.md`: Suggested experiments and observations (8 experiments).
- `docs/report.md`: Ready-to-submit academic report template/content.

## Features

- Automatic backend selection:
  - `kmalloc` for small allocations
  - `vmalloc` for large allocations
- Configurable threshold using a module parameter
- Handle-based allocation and deallocation
- **Allocation latency measurement** using `ktime_get_ns()`
- **Per-backend counters** (`kmalloc_count`, `vmalloc_count`, bytes per backend)
- **Resize support** via `krealloc` with automatic backend migration
- **Configurable logging** (`debug_level` parameter: 0=quiet, 1=normal, 2=verbose)
- Runtime statistics via `/proc/mem_explorer/status`
- `/proc/mem_explorer/control` command interface
- Per-block allocation age displayed in status table
- Safe cleanup on module unload
- Guard rails:
  - configurable maximum single allocation size
  - configurable maximum number of tracked live allocations

## Requirements

- Linux system with kernel headers installed (kernel ≥ 5.6 for `proc_ops`)
- `make`, `gcc`, and Python 3
- Root privileges for loading or unloading kernel modules

## Build

```bash
make
```

## Load the module

```bash
sudo insmod src/mem_explorer.ko
```

Optional module parameters:

```bash
sudo insmod src/mem_explorer.ko vmalloc_threshold=8192 max_allocation=4194304 max_tracked_allocations=256 debug_level=1
```

## Inspect status

```bash
cat /proc/mem_explorer/status
python3 tools/memx_cli.py status
python3 tools/memx_cli.py latency
```

## Control commands

Write commands to `/proc/mem_explorer/control`:

```bash
echo "alloc 4096 zero" | sudo tee /proc/mem_explorer/control
echo "alloc 16384" | sudo tee /proc/mem_explorer/control
echo "fill 1 170" | sudo tee /proc/mem_explorer/control
echo "touch 1" | sudo tee /proc/mem_explorer/control
echo "resize 1 8192" | sudo tee /proc/mem_explorer/control
echo "free 1" | sudo tee /proc/mem_explorer/control
echo "freeall" | sudo tee /proc/mem_explorer/control
```

Equivalent CLI usage:

```bash
python3 tools/memx_cli.py alloc 4096 --zero
python3 tools/memx_cli.py free 1
python3 tools/memx_cli.py fill 1 170
python3 tools/memx_cli.py touch 1
python3 tools/memx_cli.py resize 1 8192
python3 tools/memx_cli.py freeall
```

## Change debug level at runtime

```bash
echo 2 | sudo tee /sys/module/mem_explorer/parameters/debug_level
```

## Run the prepared demonstrations

```bash
make demo                # guided walkthrough
make stress              # stress workload
make expt-threshold      # experiment: backend selection
make expt-memory         # experiment: memory tracking
make expt-guardrails     # experiment: error handling
make expt-latency        # experiment: latency comparison
make expt-resize         # experiment: resize & migration
make present             # run ALL experiments (interactive, for live demos)
```

## Unload

```bash
sudo rmmod mem_explorer
```

## Safety notes

- This project is intended for an isolated lab or VM.
- It does not replace the Linux kernel allocator.
- It keeps explicit allocation metadata to avoid double free and stale-handle
  usage.
- All live allocations are reclaimed during module unload.