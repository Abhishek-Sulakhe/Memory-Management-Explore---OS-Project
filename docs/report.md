# Memory Management Explorer: An Academic Study of Kernel Allocation using `kmalloc` and `vmalloc`

## Abstract

This project presents a compact educational memory-management framework
implemented as a Linux kernel module. The work compares two common kernel memory
allocation primitives, `kmalloc` and `vmalloc`, behind a single custom
allocator-like interface. Requests are classified by size, tracked using kernel
metadata, exposed through a `/proc` interface, and reclaimed deterministically.
The project demonstrates allocator policy, synchronization, bookkeeping,
instrumentation, and safe teardown, making it suitable for an operating-systems
laboratory or academic mini-project.

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
structured way.

## 2. Objectives

- implement a custom handle-based allocator interface in kernel space
- compare `kmalloc` and `vmalloc` in a unified experiment framework
- maintain correct metadata and synchronization for live allocations
- expose runtime statistics for academic analysis
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

The records are stored in a linked list and protected by a mutex.

### 3.4 Control and observation

The project uses `/proc` for both command input and status output:

- `/proc/mem_explorer/control`
- `/proc/mem_explorer/status`

This avoids the extra complexity of an `ioctl` interface while still providing a
real kernel-user boundary for experimentation.

## 4. Implementation details

The kernel module supports the following commands:

- `alloc <size> [zero]`
- `free <id>`
- `fill <id> <byte>`
- `touch <id>`
- `freeall`

Statistics include:

- number of allocation requests
- number of free requests
- number of failed allocations
- active allocation count
- active bytes
- peak active bytes
- checksum from the most recent touch operation

Safety checks include:

- rejecting zero-byte allocations
- rejecting oversize requests
- rejecting malformed commands
- refusing operations on non-existent IDs
- freeing all remaining allocations during module unload

## 5. Results and discussion

The project clearly illustrates the difference between two kernel allocation
strategies. Small allocations remain with `kmalloc`, which is appropriate for
objects requiring low overhead and physical contiguity. Larger allocations are
moved to `vmalloc`, which reduces dependence on contiguous physical pages.

By adjusting the threshold and running repeatable workloads, students can
observe how allocator policy shapes backend usage, active memory accounting, and
cleanup behavior. The `touch` operation also demonstrates controlled access over
multi-page regions, connecting high-level allocation policy with page-level
memory activity.

## 6. Limitations

- The project is an educational wrapper, not a replacement for the Linux kernel
  allocator.
- The implementation uses a single mutex and linked-list lookup for simplicity.
- The project focuses on allocation strategy and observability rather than raw
  performance tuning.
- It does not modify the core Linux page-fault path.

## 7. Future work

- add timing instrumentation for latency comparisons
- replace the linked list with a hash table for faster handle lookup
- add tracepoint integration for deeper kernel-side observation
- extend the project with a read-only page-fault observation component
- compare behavior across different threshold values and memory pressure levels

## 8. Conclusion

Memory Management Explorer provides a clean and academically grounded way to
study kernel dynamic allocation. By combining `kmalloc`, `vmalloc`, metadata
tracking, synchronization, and a small experimental interface, the project turns
abstract memory-management concepts into a concrete, inspectable system.

## 9. References

1. Linux Kernel Documentation, memory allocation APIs.
2. Robert Love, *Linux Kernel Development*.
3. Abraham Silberschatz, Peter B. Galvin, Greg Gagne, *Operating System Concepts*.

