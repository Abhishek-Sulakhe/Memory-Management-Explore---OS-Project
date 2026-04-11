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

The records are stored in a linked list protected by a mutex.

## Synchronization

The module uses a single mutex to protect:

- the allocation list
- allocator statistics
- ID generation and lifetime transitions

This keeps the design simple and suitable for teaching. A more advanced version
could move to hashed lookup tables or finer-grained locking.

## `/proc` interface

Two files are created:

- `/proc/mem_explorer/control`
  - accepts write commands such as `alloc`, `free`, `fill`, `touch`, `freeall`
- `/proc/mem_explorer/status`
  - exposes configuration, statistics, and the list of active allocations

## Command semantics

- `alloc <size> [zero]`
  - allocates a block and assigns a numeric ID
- `free <id>`
  - frees an existing allocation
- `fill <id> <byte>`
  - writes a repeated byte into a block
- `touch <id>`
  - reads one byte per page to emulate page-touch behavior and force access
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

