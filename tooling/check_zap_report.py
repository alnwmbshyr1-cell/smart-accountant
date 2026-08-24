#!/usr/bin/env python3
"""Fail a local DAST gate only for high/critical findings."""
from __future__ import annotations

import json
import sys
from pathlib import Path

HIGH_RISK = {"High", "Critical"}


def main(path: str) -> int:
    report = json.loads(Path(path).read_text(encoding="utf-8"))
    alerts = report.get("site", [{}])[0].get("alerts", [])
    blocking = [
        {
            "name": item.get("name", "unknown")[:160],
            "risk": item.get("riskdesc", item.get("riskcode", "unknown"))[:80],
            "count": len(item.get("instances", [])),
        }
        for item in alerts
        if item.get("risk") in HIGH_RISK
    ]
    print(json.dumps({"status": "FAIL" if blocking else "PASS", "blocking": blocking}, sort_keys=True))
    return 1 if blocking else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1]))
