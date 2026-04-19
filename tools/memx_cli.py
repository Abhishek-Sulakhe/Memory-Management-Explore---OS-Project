#!/usr/bin/env python3
"""
Simple user-space CLI for the Memory Management Explorer kernel module.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

CONTROL = Path("/proc/mem_explorer/control")
STATUS = Path("/proc/mem_explorer/status")


def write_command(command: str) -> None:
    if not CONTROL.exists():
        raise FileNotFoundError(
            "control file not found; is the mem_explorer module loaded?"
        )
    CONTROL.write_text(command + "\n", encoding="ascii")


def print_status() -> None:
    if not STATUS.exists():
        raise FileNotFoundError(
            "status file not found; is the mem_explorer module loaded?"
        )
    sys.stdout.write(STATUS.read_text(encoding="ascii"))


def read_status_text() -> str:
    if not STATUS.exists():
        raise FileNotFoundError(
            "status file not found; is the mem_explorer module loaded?"
        )
    return STATUS.read_text(encoding="ascii")


def get_status_value(key: str) -> str:
    for line in read_status_text().splitlines():
        stripped = line.strip()
        if stripped.startswith(f"{key}:"):
            return stripped.split(":", 1)[1].strip()
    raise KeyError(f"status key not found: {key}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Control the mem_explorer kernel module"
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    alloc = subparsers.add_parser("alloc", help="allocate a new block")
    alloc.add_argument("size", type=int, help="allocation size in bytes")
    alloc.add_argument(
        "--zero",
        action="store_true",
        help="zero-initialize the allocation",
    )

    free = subparsers.add_parser("free", help="free an existing block")
    free.add_argument("id", type=int, help="block identifier")

    fill = subparsers.add_parser("fill", help="fill a block with a byte value")
    fill.add_argument("id", type=int, help="block identifier")
    fill.add_argument("value", type=int, help="byte value in decimal or 0x.. form")

    touch = subparsers.add_parser("touch", help="touch a block page by page")
    touch.add_argument("id", type=int, help="block identifier")

    resize = subparsers.add_parser("resize", help="resize an existing block")
    resize.add_argument("id", type=int, help="block identifier")
    resize.add_argument("new_size", type=int, help="new size in bytes")

    subparsers.add_parser("freeall", help="free every active block")
    subparsers.add_parser("status", help="show current allocator status")
    subparsers.add_parser(
        "latency", help="show allocation latency summary"
    )

    return parser


def print_latency_summary() -> None:
    """Print a focused latency summary from the status output."""
    text = read_status_text()
    lines = text.splitlines()

    print("=== Allocation Latency Summary ===")
    for line in lines:
        stripped = line.strip()
        if any(
            stripped.startswith(k)
            for k in (
                "total_alloc_latency_ns:",
                "avg_alloc_latency_ns:",
                "total_allocations:",
                "kmalloc_count:",
                "vmalloc_count:",
            )
        ):
            print(f"  {stripped}")

    # Print per-block latencies from the table
    in_table = False
    for line in lines:
        if "ID" in line and "Latency" in line:
            in_table = True
            print(f"\n  {line.strip()}")
            continue
        if in_table and line.strip():
            print(f"  {line.strip()}")


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    try:
        if args.command == "alloc":
            command = f"alloc {args.size}"
            if args.zero:
                command += " zero"
            write_command(command)
            print(f"allocated id={get_status_value('last_allocated_id')}")

        elif args.command == "free":
            write_command(f"free {args.id}")

        elif args.command == "fill":
            if args.value < 0 or args.value > 255:
                parser.error("fill value must be between 0 and 255")
            write_command(f"fill {args.id} {args.value}")

        elif args.command == "touch":
            write_command(f"touch {args.id}")

        elif args.command == "resize":
            if args.new_size <= 0:
                parser.error("new_size must be a positive integer")
            write_command(f"resize {args.id} {args.new_size}")
            print(f"resized id={args.id} to {args.new_size} bytes")

        elif args.command == "freeall":
            write_command("freeall")

        elif args.command == "status":
            print_status()

        elif args.command == "latency":
            print_latency_summary()

        else:
            parser.error("unsupported command")

    except (OSError, KeyError) as exc:
        sys.stderr.write(f"memx_cli error: {exc}\n")
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
