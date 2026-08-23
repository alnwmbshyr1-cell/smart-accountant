#!/usr/bin/env python3
"""Compare two sanitized weekly PenTest summaries and report regressions."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import urllib.request
from pathlib import Path
from typing import Any

from weekly_pentest_digest import redact

RANK = {"info": 0, "low": 1, "medium": 2, "high": 3, "critical": 4}


def fingerprint(finding: dict[str, Any]) -> str:
    explicit = finding.get("fingerprint")
    if explicit:
        return str(explicit)
    parts = [
        finding.get("source", ""), finding.get("rule_id", ""),
        finding.get("test_id", ""), finding.get("asset", ""),
        finding.get("file", ""), str(finding.get("line", "")),
    ]
    return hashlib.sha256("|".join(map(str, parts)).encode()).hexdigest()[:24]


def safe_finding(item: dict[str, Any]) -> dict[str, Any]:
    return {key: redact(value) if isinstance(value, str) else value for key, value in item.items()}


def findings_by_id(report: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {fingerprint(item): safe_finding(item) for item in report.get("findings", []) if isinstance(item, dict)}


def compare(current: dict[str, Any], previous: dict[str, Any]) -> dict[str, Any]:
    now = findings_by_id(current)
    old = findings_by_id(previous)
    new = [now[key] for key in now.keys() - old.keys()]
    closed = [old[key] for key in old.keys() - now.keys()]
    persistent = []
    increased = []
    decreased = []
    for key in now.keys() & old.keys():
        current_item, previous_item = now[key], old[key]
        current_severity = str(current_item.get("severity", "info")).lower()
        previous_severity = str(previous_item.get("severity", "info")).lower()
        item = {"fingerprint": key, "current": current_item, "previous": previous_item}
        if RANK.get(current_severity, 0) > RANK.get(previous_severity, 0):
            increased.append(item)
        elif RANK.get(current_severity, 0) < RANK.get(previous_severity, 0):
            decreased.append(item)
        else:
            persistent.append(item)
    regressions = [*new, *increased]
    critical_regressions = [item for item in regressions if str(item.get("severity", item.get("current", {}).get("severity", "info"))).lower() in {"critical", "high"}]
    return {
        "new": new,
        "closed": closed,
        "persistent": persistent,
        "severity_increased": increased,
        "severity_decreased": decreased,
        "regression_count": len(regressions),
        "critical_or_high_regressions": len(critical_regressions),
        "status": "REGRESSION" if regressions else "NO_REGRESSION",
    }


def markdown(result: dict[str, Any]) -> str:
    lines = ["# Security Regression Report", "", f"- Status: **{result['status']}**", f"- Regression count: {result['regression_count']}", f"- Critical/High regressions: {result['critical_or_high_regressions']}", ""]
    for title, key in (("New findings", "new"), ("Severity increases", "severity_increased"), ("Closed findings", "closed"), ("Persistent findings", "persistent")):
        items = result[key]
        lines.extend([f"## {title} ({len(items)})"])
        if not items:
            lines.append("None.")
        for item in items[:20]:
            current = item.get("current", item)
            lines.append(f"- `{current.get('test_id', current.get('rule_id', 'unknown'))}` `{current.get('asset', 'unknown')}` — {current.get('severity', 'info')}")
        lines.append("")
    lines.append("Only sanitized finding fields are included; raw payloads and credentials are excluded.")
    return "\n".join(lines) + "\n"


def fetch(url: str, token: str) -> dict[str, Any]:
    request = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}", "Accept": "application/json"})
    with urllib.request.urlopen(request, timeout=20) as response:
        data = response.read(2_000_001)
    if len(data) > 2_000_000:
        raise RuntimeError("previous report exceeds the 2 MB safety limit")
    return json.loads(data.decode("utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--current", required=True)
    parser.add_argument("--previous")
    parser.add_argument("--previous-url")
    parser.add_argument("--token", default=os.getenv("SECURITY_PENTEST_EXPORT_TOKEN", ""))
    parser.add_argument("--markdown-output", default="weekly-pentest/regressions.md")
    parser.add_argument("--json-output", default="weekly-pentest/regressions.json")
    args = parser.parse_args()
    if bool(args.previous) == bool(args.previous_url):
        parser.error("provide exactly one of --previous or --previous-url")
    current = json.loads(Path(args.current).read_text(encoding="utf-8"))
    previous = json.loads(Path(args.previous).read_text(encoding="utf-8")) if args.previous else fetch(args.previous_url, args.token)
    result = compare(current, previous)
    Path(args.markdown_output).parent.mkdir(parents=True, exist_ok=True)
    Path(args.json_output).parent.mkdir(parents=True, exist_ok=True)
    Path(args.markdown_output).write_text(markdown(result), encoding="utf-8")
    Path(args.json_output).write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote {args.markdown_output} and {args.json_output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
