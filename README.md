# Memory Management Explorer

Memory Management Explorer is an academic operating-systems project that studies
kernel-space dynamic memory allocation through a custom handle-based allocator
built on top of `kmalloc` and `vmalloc`. The project is designed for labs,
demonstrations, and report-based coursework rather than production deployment.

## Project goals

- Compare contiguous allocation (`kmalloc`) with virtually contiguous allocation
  (`vmalloc`) under a unified interface.
- Demonstrate kernel bookkeeping, synchronization, `/proc`-based control, and
  safe reclamation of dynamically allocated memory.
- Provide a small experimental framework that students can use to observe
  allocation behavior and discuss memory-management tradeoffs.

## Structure

- `src/mem_explorer.c`: Linux kernel module implementing the allocator.
- `src/Makefile`: Kbuild configuration for the module.
- `tools/memx_cli.py`: User-space helper for sending commands to `/proc`.
- `scripts/demo_allocator.sh`: Guided demo workload.
- `scripts/stress_allocator.sh`: Repeatable stress-style workload.
- `docs/architecture.md`: Design description.
- `docs/experiments.md`: Suggested experiments and observations.
- `docs/report.md`: Ready-to-submit academic report template/content.

## Features

- Automatic backend selection:
  - `kmalloc` for small allocations
  - `vmalloc` for large allocations
- Configurable threshold using a module parameter
- Handle-based allocation and deallocation
- Runtime statistics via `/proc/mem_explorer/status`
- `/proc/mem_explorer/control` command interface
- Safe cleanup on module unload
- Guard rails:
  - configurable maximum single allocation size
  - configurable maximum number of tracked live allocations

## Requirements

- Linux system with kernel headers installed
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
sudo insmod src/mem_explorer.ko vmalloc_threshold=8192 max_allocation=4194304 max_tracked_allocations=256
```

## Inspect status

```bash
cat /proc/mem_explorer/status
python3 tools/memx_cli.py status
```

## Control commands

Write commands to `/proc/mem_explorer/control`:

```bash
echo "alloc 4096 zero" | sudo tee /proc/mem_explorer/control
echo "alloc 16384" | sudo tee /proc/mem_explorer/control
echo "fill 1 170" | sudo tee /proc/mem_explorer/control
echo "touch 1" | sudo tee /proc/mem_explorer/control
echo "free 1" | sudo tee /proc/mem_explorer/control
echo "freeall" | sudo tee /proc/mem_explorer/control
```

Equivalent CLI usage:

```bash
python3 tools/memx_cli.py alloc 4096 --zero
python3 tools/memx_cli.py free 1
python3 tools/memx_cli.py fill 1 170
python3 tools/memx_cli.py touch 1
python3 tools/memx_cli.py freeall
```

## Run the prepared demonstrations

```bash
make demo
make stress
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

## Academic angle

This project is appropriate for topics such as:

- kernel heap management
- physical versus virtual contiguity
- allocator threshold design
- synchronization in kernel subsystems
- memory usage instrumentation and experimentation

See `docs/report.md` for a full academic write-up you can adapt into your
submission.

