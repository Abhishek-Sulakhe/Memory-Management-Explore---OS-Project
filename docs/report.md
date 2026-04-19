# Memory Management Explorer: An Academic Study of Kernel Allocation using `kmalloc` and `vmalloc`

## Abstract

This project presents a compact educational memory-management framework
implemented as a Linux kernel module. The work compares two common kernel memory
allocation primitives, `kmalloc` and `vmalloc`, behind a single custom
allocator-like interface. Requests are classified by size, tracked using kernel
metadata, exposed through a `/proc` interface, and reclaimed deterministically.
The module also provides nanosecond-resolution allocation latency measurement,
per-backend usage counters, and a `resize` command that demonstrates `krealloc`
and cross-backend migration. The project demonstrates allocator policy,
synchronization, bookkeeping, instrumentation, and safe teardown, making it
suitable for an operating-systems laboratory or academic mini-project.

## 1. Introduction

Memory management is one of the central responsibilities of an operating system.
In Linux kernel development, memory may be obtained through multiple APIs with
different guarantees and tradeoffs. `kmalloc` provides physically contiguous
memory and is efficient for smaller objects, while `vmalloc` provides virtually
contiguous mappings that are more suitable for larger regions but with extra
overhead. Understanding when and why to choose between them is an important OS
concept.

This project builds an educational allocator wrapper that selects between the
two APIs automatically. The module exposes status information and controlled
commands so that students can perform experiments and observe behavior in a
structured way, including quantitative latency comparisons between the two
backends.

## 2. Objectives

- implement a custom handle-based allocator interface in kernel space
- compare `kmalloc` and `vmalloc` in a unified experiment framework
- measure and report allocation latency with nanosecond precision
- maintain correct metadata and synchronization for live allocations
- expose runtime statistics, per-backend breakdowns, and timing data
- support resizing through `krealloc` and cross-backend migration
- ensure safe deallocation and clean module unload behavior

## 3. Design and methodology

### 3.1 Allocation policy

The module defines a configurable threshold named `vmalloc_threshold`.

- If `size <= vmalloc_threshold`, the request is served using `kmalloc`.
- If `size > vmalloc_threshold`, the request is served using `vmalloc`.

This size-aware policy is intentionally simple, making the consequences easy to
observe in experiments.

### 3.2 Handle-based abstraction

Instead of returning raw pointers, each successful allocation receives a unique
numeric ID. This creates a safer interface for educational control commands and
avoids direct user exposure to kernel virtual addresses.

### 3.3 Metadata tracking

For every allocation, the module stores:

- allocation ID
- base pointer
- size in bytes
- backend type
- zero-initialization state
- wall-clock timestamp of allocation
- measured allocation latency in nanoseconds

The records are stored in a linked list and protected by a mutex.

### 3.4 Latency instrumentation

Each allocation call is bracketed by `ktime_get_ns()` to measure the time
consumed by the underlying `kmalloc`, `vmalloc`, or `krealloc` call. This
latency is stored per-block and also accumulated into a global counter. The
status output computes and displays the average allocation latency, and the
active-allocation table shows per-block latency and age.

### 3.5 Per-backend counters

The module maintains separate counters for each backend:

- `kmalloc_count` / `kmalloc_bytes`
- `vmalloc_count` / `vmalloc_bytes`

These are updated on every alloc, free, and resize operation, giving students a
clear picture of how the threshold affects backend usage distribution.

### 3.6 Resize support

The `resize` command adjusts the size of an existing allocation. The
implementation uses:

- **`krealloc`** when both the old and new sizes fall within the `kmalloc`
  backend — this can resize in place without a copy.
- **Full allocate-copy-free** when the backend changes (e.g., `kmalloc` →
  `vmalloc`) or when the source uses `vmalloc` (since no `vrealloc` exists in
  the kernel).

This demonstrates a real-world kernel pattern and makes the cost of backend
migration visible through latency measurements.

### 3.7 Control and observation

The project uses `/proc` for both command input and status output:

- `/proc/mem_explorer/control`
- `/proc/mem_explorer/status`

This avoids the extra complexity of an `ioctl` interface while still providing a
real kernel-user boundary for experimentation.

### 3.8 Configurable logging

A `debug_level` module parameter controls log verbosity:

- Level 0: quiet — no log messages
- Level 1: normal — alloc, free, resize events
- Level 2: verbose — fill and touch events included

This prevents `dmesg` flooding during stress workloads and can be changed at
runtime through `/sys/module/mem_explorer/parameters/debug_level`.

## 4. Implementation details

The kernel module supports the following commands:

- `alloc <size> [zero]`
- `free <id>`
- `fill <id> <byte>`
- `touch <id>`
- `resize <id> <new_size>`
- `freeall`

Statistics include:

- number of allocation, free, and resize requests
- number of failed allocations
- active allocation count and active bytes
- peak active bytes (high-water mark)
- per-backend allocation counts and byte totals
- total and average allocation latency in nanoseconds
- per-block latency and age in the active allocation table
- checksum from the most recent touch operation

Safety checks include:

- rejecting zero-byte allocations
- rejecting oversize requests
- rejecting malformed commands
- refusing operations on non-existent IDs
- freeing all remaining allocations during module unload
- SPDX license identifier for kernel coding standards compliance

### 4.1 Synchronization design

The mutex is held only during list manipulation and counter updates. Heavy
allocation calls (`kmalloc`, `vmalloc`, `krealloc`) are performed outside the
lock to avoid blocking other operations. A single lock-then-check-then-insert
pattern eliminates the TOCTOU race that would exist if the capacity were checked,
the lock dropped, and then checked again.

## 5. Results and discussion

The project clearly illustrates the difference between two kernel allocation
strategies. Small allocations remain with `kmalloc`, which is appropriate for
objects requiring low overhead and physical contiguity. Larger allocations are
moved to `vmalloc`, which reduces dependence on contiguous physical pages.

The latency measurements confirm the expected performance characteristics:
`kmalloc` allocations typically complete in hundreds of nanoseconds, while
`vmalloc` allocations require several microseconds due to page-table setup. The
`resize` command further demonstrates that in-place `krealloc` is significantly
faster than a cross-backend migration.

By adjusting the threshold and running repeatable workloads, students can
observe how allocator policy shapes backend usage, active memory accounting,
latency distribution, and cleanup behavior. The `touch` operation also
demonstrates controlled access over multi-page regions, connecting high-level
allocation policy with page-level memory activity.

## 6. Limitations

- The project is an educational wrapper, not a replacement for the Linux kernel
  allocator.
- The implementation uses a single mutex and linked-list lookup for simplicity.
- The project focuses on allocation strategy and observability rather than raw
  performance tuning.
- It does not modify the core Linux page-fault path.
- The resize implementation accesses block metadata outside the lock in the
  intended single-user `/proc` workflow; true concurrent access would require
  reference counting.

## 7. Future work

- replace the linked list with an IDR or rbtree for O(1) / O(log n) handle
  lookup
- add a histogram of allocation latencies for richer statistical analysis
- add tracepoint integration for deeper kernel-side observation
- extend the project with a read-only page-fault observation component
- compare behavior across different threshold values and memory pressure levels
- add NUMA-aware allocation using `kmalloc_node` and `vmalloc_node`

## 8. Conclusion

Memory Management Explorer provides a clean and academically grounded way to
study kernel dynamic allocation. By combining `kmalloc`, `vmalloc`, `krealloc`,
metadata tracking, latency measurement, per-backend instrumentation,
synchronization, and a small experimental interface, the project turns abstract
memory-management concepts into a concrete, measurable, and inspectable system.

## 9. References

1. Linux Kernel Documentation, memory allocation APIs.
2. Robert Love, *Linux Kernel Development*.
3. Abraham Silberschatz, Peter B. Galvin, Greg Gagne, *Operating System Concepts*.
4. Linux kernel source, `include/linux/slab.h` and `mm/vmalloc.c`.
