# Architecture

## Overview

The project implements a small educational allocator layer inside a Linux kernel
module. Instead of exposing raw kernel pointers to user space, it exposes stable
numeric handles. Each handle maps to one tracked allocation record.

## Core idea

Allocation requests are classified by size:

- Small requests use `kmalloc`, which returns physically contiguous memory.
- Large requests use `vmalloc`, which returns virtually contiguous memory that
  may be backed by non-contiguous physical pages.

This threshold-based policy makes the backend choice explicit and easy to study.

## Internal data structures

Each active allocation is represented by:

- unique allocation ID
- kernel pointer
- allocation size
- backend type (`kmalloc` or `vmalloc`)
- zero-initialization flag
- wall-clock timestamp of the allocation (`alloc_time_ns`)
- measured allocation latency in nanoseconds (`alloc_latency_ns`)

The records are stored in a linked list protected by a mutex.

## Statistics and instrumentation

### Aggregate counters

The module tracks request-level counters:

- `alloc_requests`, `free_requests`, `resize_requests`
- `failed_allocations`, `total_allocations_created`
- `active_allocations`, `active_bytes`, `peak_active_bytes`

### Per-backend counters

Separate counters give visibility into how each backend is being used:

- `kmalloc_count` / `kmalloc_bytes`
- `vmalloc_count` / `vmalloc_bytes`

These update on allocation, free, and resize operations.

### Latency tracking

Every allocation records the time it took using `ktime_get_ns()` before and
after the kernel allocation call. The module also maintains:

- `total_alloc_latency_ns` — cumulative latency across all allocations
- computed average latency shown in the status output
- per-block latency visible in the allocation table

This turns the project from a qualitative demonstration into a quantitative
measurement tool.

## Synchronization

The module uses a single mutex to protect:

- the allocation list
- allocator statistics
- ID generation and lifetime transitions

Heavy-weight operations (the actual `kmalloc` / `vmalloc` / `krealloc` calls)
are performed outside the mutex so that sleeping allocators never block other
tracking operations. The lock is acquired afterwards for a single atomic
check-and-insert step, eliminating TOCTOU races.

This keeps the design simple and suitable for teaching. A more advanced version
could move to hashed lookup tables, IDR-based ID management, or finer-grained
locking.

## Logging

All log messages use a `memx_log(level, fmt, ...)` macro controlled by the
`debug_level` module parameter:

- `0` — quiet (no log messages)
- `1` — normal (alloc, free, resize events)
- `2` — verbose (fill, touch, and extra detail)

This prevents log flooding during stress workloads while still allowing
detailed observation when needed.

## `/proc` interface

Two files are created:

- `/proc/mem_explorer/control`
  - accepts write commands such as `alloc`, `free`, `fill`, `touch`, `resize`,
    `freeall`
- `/proc/mem_explorer/status`
  - exposes configuration, statistics, backend breakdown, latency data, and the
    list of active allocations with per-block latency and age

## Command semantics

- `alloc <size> [zero]`
  - allocates a block and assigns a numeric ID
- `free <id>`
  - frees an existing allocation
- `fill <id> <byte>`
  - writes a repeated byte into a block
- `touch <id>`
  - reads one byte per page to emulate page-touch behavior and force access
- `resize <id> <new_size>`
  - resizes an existing block; uses `krealloc` when both the old and new sizes
    stay within `kmalloc`, and performs a full allocate-copy-free cycle when
    the backend changes or the source uses `vmalloc`
- `freeall`
  - reclaims every live block

## Error handling

The module rejects:

- zero-sized allocations
- allocations beyond the configured maximum
- requests when the tracked-allocation limit is already reached
- operations on unknown handles
- malformed commands

## Why this design is academically useful

The design is intentionally narrow:

- It is small enough to review line-by-line.
- It highlights real kernel APIs without modifying the kernel source tree.
- It supports experiments on fragmentation-aware policy decisions.
- It demonstrates safe allocation ownership and deterministic cleanup.
- It provides quantitative latency data for comparing `kmalloc` vs `vmalloc`.
- It shows how `krealloc` works and how resizing can trigger backend changes.
