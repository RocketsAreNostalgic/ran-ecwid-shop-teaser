#!/usr/bin/env python3
"""Require valid Plugin Check diagnostics and fail on reported errors."""

import json
from pathlib import Path
import sys


try:
    results = json.loads(Path(sys.argv[1]).read_text())
    if not isinstance(results, list) or not all(
        isinstance(item, dict)
        and item.get("type") in ("ERROR", "WARNING")
        and isinstance(item.get("code"), str)
        for item in results
    ):
        raise ValueError("Expected an array of typed Plugin Check diagnostics.")
except (IndexError, OSError, ValueError) as error:
    print(f"Invalid Plugin Check report: {error}", file=sys.stderr)
    sys.exit(1)

print(json.dumps(results, indent=2))
errors = sum(item["type"] == "ERROR" for item in results)
warnings = sum(item["type"] == "WARNING" for item in results)
print(f"Plugin Check: {errors} error(s), {warnings} warning(s).")
sys.exit(1 if errors else 0)
