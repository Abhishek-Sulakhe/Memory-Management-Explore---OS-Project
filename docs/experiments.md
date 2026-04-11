# Suggested Experiments

## Experiment 1: Threshold behavior

Goal: observe when the module switches from `kmalloc` to `vmalloc`.

Steps:

1. Load the module with `vmalloc_threshold=8192`.
2. Allocate blocks of 4096, 8192, 8193, and 16384 bytes.
3. Read `/proc/mem_explorer/status`.
4. Correlate the chosen backend with the request size.

Expected result:

- 4096 and 8192 byte allocations should use `kmalloc`.
- 8193 and 16384 byte allocations should use `vmalloc`.

## Experiment 2: Active memory accounting

Goal: validate byte-accurate tracking of live memory.

Steps:

1. Free all blocks.
2. Allocate sizes 1024, 2048, and 4096.
3. Read `active_bytes`.
4. Free the 2048-byte block and read `active_bytes` again.

Expected result:

- active bytes should move from 0 to 7168, then from 7168 to 5120.

## Experiment 3: Upper-bound enforcement

Goal: test defensive checks.

Steps:

1. Load the module with `max_allocation=65536`.
2. Attempt `alloc 131072`.
3. Observe the failure and verify that accounting values do not drift.

Expected result:

- the allocation request should fail cleanly
- `failed_allocations` should increase
- `active_allocations` and `active_bytes` should remain unchanged

## Experiment 4: Page-touch behavior

Goal: observe deliberate access across pages.

Steps:

1. Allocate a large block such as 65536 bytes.
2. Fill it with a byte pattern.
3. Run `touch`.
4. Check kernel logs and status output.

Expected result:

- the module should compute and store a checksum derived from page-spaced reads
- this demonstrates controlled access to a multi-page region

## Experiment 5: Cleanup on unload

Goal: verify deterministic memory reclamation.

Steps:

1. Leave several allocations active.
2. Unload the module with `sudo rmmod mem_explorer`.
3. Inspect kernel logs.

Expected result:

- the module should free every remaining block before unload completes

