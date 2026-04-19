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
- The backend breakdown section should show 2 kmalloc and 2 vmalloc entries.

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

## Experiment 6: Allocation latency comparison

Goal: quantitatively compare `kmalloc` and `vmalloc` allocation speed.

Steps:

1. Load the module with default parameters.
2. Run the stress workload: `make stress`.
3. Inspect the latency section in the status output.
4. Compare per-block latency values for `kmalloc` and `vmalloc` entries.

Expected result:

- `kmalloc` allocations should show lower latency (typically hundreds of
  nanoseconds)
- `vmalloc` allocations should show higher latency (typically several
  microseconds) due to page-table setup overhead
- The `avg_alloc_latency_ns` counter provides a convenient aggregate

Discussion points:

- Why does `vmalloc` take longer?
- How does the threshold value affect average latency?
- What happens if the threshold is set very low (e.g., 64 bytes)?

## Experiment 7: Resize and backend migration

Goal: observe how resizing affects backend selection and memory layout.

Steps:

1. Allocate a 1024-byte block (should use `kmalloc`).
2. Resize to 4096 bytes — verify it stays in `kmalloc` and uses `krealloc`.
3. Resize to 32768 bytes — verify it migrates to `vmalloc` (full copy path).
4. Resize back to 512 bytes — verify it migrates back to `kmalloc`.
5. Check the backend breakdown counters after each step.

Expected result:

- step 2: `kmalloc_count` stays unchanged, `kmalloc_bytes` increases
- step 3: `kmalloc_count` decreases, `vmalloc_count` increases
- step 4: `vmalloc_count` decreases, `kmalloc_count` increases
- the resize latency should be visible in the per-block table

Discussion points:

- What extra work is required when the backend changes during resize?
- When is `krealloc` more efficient than a full copy?
- How does resize latency compare to fresh allocation latency?

## Experiment 8: Debug level impact

Goal: understand the effect of log verbosity on kernel log volume.

Steps:

1. Load the module with `debug_level=0`.
2. Perform several allocations, fills, touches, and frees.
3. Check `dmesg` — there should be no log output from the module.
4. Change the debug level at runtime: `echo 2 > /sys/module/mem_explorer/parameters/debug_level`.
5. Repeat operations and observe verbose logging.

Expected result:

- at level 0: no module messages in `dmesg`
- at level 1: alloc, free, resize events only
- at level 2: fill and touch events also appear
