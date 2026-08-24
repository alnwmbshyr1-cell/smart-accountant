#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path

MARKER = "<!-- smart-accountant-sast-summary -->"
MAX_FINDINGS_PER_FILE = 30

def summarize(path: Path) -> tuple[str, int]:
    data = json.loads(path.read_text(encoding="utf-8"))
    runs = data.get("runs", [])
    rows = []
    for run in runs:
        tool = run.get("tool", {}).get("driver", {}).get("name", path.stem)
        rules = {r.get("id"): r for r in run.get("tool", {}).get("driver", {}).get("rules", [])}
        for result in run.get("results", []):
            level = result.get("level", "warning").lower()
            if level not in {"error", "warning", "note"}:
                level = "warning"
            rule_id = str(result.get("ruleId", "unknown"))[:120]
            location = (result.get("locations") or [{}])[0].get("physicalLocation", {})
            artifact = str(location.get("artifactLocation", {}).get("uri", "unknown"))[:180]
            line = location.get("region", {}).get("startLine", "?")
            rows.append((tool[:80], level, rule_id, artifact, str(line)[:20]))
    rows = rows[:MAX_FINDINGS_PER_FILE]
    return rows, len(rows)

def main(output: str, *inputs: str) -> int:
    all_rows = []
    for raw in inputs:
        path = Path(raw)
        if path.exists() and path.stat().st_size:
            rows, _ = summarize(path)
            all_rows.extend(rows)
    lines = [MARKER, "## SAST summary", "", "SARIF findings from the current Pull Request run. Detailed locations remain in Code Scanning/artifacts.", "", "| Tool | Level | Rule | File | Line |", "|---|---|---|---|---:|"]
    if not all_rows:
        lines.append("| — | — | No findings reported | — | — |")
    else:
        for tool, level, rule, artifact, line in all_rows:
            lines.append(f"| `{tool}` | `{level}` | `{rule}` | `{artifact}` | {line} |")
    lines.extend(["", f"Total summarized findings: **{len(all_rows)}**.", "Review the SARIF artifact and Code Scanning result before merging."])
    Path(output).write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps({"findings": len(all_rows), "output": output}))
    return 0

if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1], *sys.argv[2:]))
