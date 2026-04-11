#!/usr/bin/env bash
set -euo pipefail

python3 tools/memx_cli.py status
id1=$(python3 tools/memx_cli.py alloc 1024 --zero | awk -F= '/allocated id=/{print $2}')
id2=$(python3 tools/memx_cli.py alloc 16384 | awk -F= '/allocated id=/{print $2}')
python3 tools/memx_cli.py fill "$id1" 170
python3 tools/memx_cli.py touch "$id1"
python3 tools/memx_cli.py touch "$id2"
python3 tools/memx_cli.py status
python3 tools/memx_cli.py free "$id1"
python3 tools/memx_cli.py free "$id2"
python3 tools/memx_cli.py status
