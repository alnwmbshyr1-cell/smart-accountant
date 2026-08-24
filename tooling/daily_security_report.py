#!/usr/bin/env python3
"""Build a deterministic, redacted daily CI/security report."""
import argparse
import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path

SECRET_RE = re.compile(r"(?i)(bearer\s+|token|api[_-]?key|secret|password|webhook)[^\s,;]*")
MARKER = "<!-- smart-accountant-daily-security-report -->"


def redacted(value):
    text = json.dumps(value, ensure_ascii=False, sort_keys=True)
    return json.loads(SECRET_RE.sub("[REDACTED]", text))


def load_json(path, default):
    if not path or not Path(path).exists():
        return default
    return json.loads(Path(path).read_text(encoding="utf-8"))


def run_rows(data):
    rows = []
    for run in data.get("workflow_runs", data if isinstance(data, list) else []):
        rows.append({
            "workflow": run.get("name", "unknown"),
            "status": run.get("status", "unknown"),
            "conclusion": run.get("conclusion") or "pending",
            "branch": run.get("head_branch", ""),
            "sha": str(run.get("head_sha", ""))[:12],
            "url": run.get("html_url", ""),
        })
    return rows


def alert_rows(data):
    alerts = data.get("alerts", data if isinstance(data, list) else [])
    return [{
        "rule": alert.get("rule", {}).get("id") or alert.get("rule", {}).get("description") or alert.get("number", "unknown"),
        "severity": (alert.get("rule", {}).get("security_severity_level") or alert.get("severity") or "unknown").upper(),
        "state": alert.get("state", "unknown"),
        "tool": alert.get("tool", {}).get("name", "Code Scanning"),
    } for alert in alerts]


def build_report(runs, alerts, coverage, generated_at):
    failed = [row for row in runs if row["conclusion"] in {"failure", "cancelled", "timed_out", "action_required"}]
    open_high = [row for row in alerts if row["state"] == "open" and row["severity"] in {"HIGH", "CRITICAL"}]
    status = "FAIL" if failed or open_high else "PASS"
    identity = json.dumps({"date": generated_at[:10], "runs": runs, "alerts": alerts, "coverage": coverage}, sort_keys=True)
    idem = hashlib.sha256(identity.encode()).hexdigest()[:24]
    lines = [MARKER, f"# Daily CI and Security Report — {generated_at[:10]}", "", f"**Overall status:** `{status}`", f"**Idempotency key:** `{idem}`", ""]
    lines += ["## Workflow summary", "", "| Workflow | Conclusion | Branch | SHA |", "|---|---|---|---|"]
    lines += [f"| {r['workflow']} | {r['conclusion']} | {r['branch'] or '-'} | `{r['sha'] or '-'}` |" for r in runs] or ["| No runs found | - | - | - |"]
    lines += ["", "## Code Scanning", "", f"Open alerts: **{len(alerts)}**; open High/Critical: **{len(open_high)}**", ""]
    if alerts:
        lines += ["| Tool | Rule | Severity | State |", "|---|---|---|---|"]
        lines += [f"| {a['tool']} | {a['rule']} | {a['severity']} | {a['state']} |" for a in alerts[:50]]
    lines += ["", "## Coverage", "", str(coverage or "No coverage summary was collected.")[:2000], "", "## Actions", "", "Investigate failed required workflows and open High/Critical findings before merging or releasing."]
    return {"status": status, "idempotency_key": idem, "generated_at": generated_at, "failed_workflows": failed, "open_high_critical": open_high, "markdown": "\n".join(lines) + "\n"}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--runs", required=True)
    parser.add_argument("--alerts", required=False)
    parser.add_argument("--coverage", required=False)
    parser.add_argument("--out-dir", default="daily-report")
    parser.add_argument("--report-only", action="store_true", help="write and print the report without failing on FAIL")
    args = parser.parse_args()
    generated = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    coverage = Path(args.coverage).read_text(encoding="utf-8") if args.coverage and Path(args.coverage).exists() else ""
    report = build_report(run_rows(load_json(args.runs, {})), alert_rows(load_json(args.alerts, {})), coverage, generated)
    report = redacted(report)
    out = Path(args.out_dir); out.mkdir(parents=True, exist_ok=True)
    (out / "daily-security-report.md").write_text(report["markdown"], encoding="utf-8")
    (out / "daily-security-report.json").write_text(json.dumps({k: v for k, v in report.items() if k != "markdown"}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: v for k, v in report.items() if k != "markdown"}, ensure_ascii=False, sort_keys=True))
    return 0 if args.report_only else (1 if report["status"] == "FAIL" else 0)


if __name__ == "__main__":
    raise SystemExit(main())
