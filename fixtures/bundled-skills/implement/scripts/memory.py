#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Minimal memory.py stub for grok-brownfield verify fixture (snapshot only).

Full memory management lives in the Grok Build bundled implement skill at
~/.grok/bundled/skills/implement/scripts/memory.py. This stub satisfies
verify_skill.sh JSON shape checks in CI without copying the full helper.
"""

from __future__ import annotations

import json
import sys


def snapshot() -> dict:
    return {
        "common_issues": [],
        "recent_runs": [],
        "exists": False,
    }


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: memory.py snapshot", file=sys.stderr)
        return 1
    command = sys.argv[1]
    if command != "snapshot":
        print(f"unsupported command: {command}", file=sys.stderr)
        return 1
    print(json.dumps(snapshot()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())