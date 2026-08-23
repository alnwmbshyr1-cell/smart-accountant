#!/usr/bin/env python3
"""Build and optionally send a bounded weekly Security Gateway operations report."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import urllib.request
from collections import Counter
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Iterable, Mapping

MAX_ERROR_TYPES = 10


def parse_time(value: Any) -> datetime | None:
    if not isinstance(value, str):
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(timezone.utc)
    except ValueError:
        return None


def load_events(path: str, now: datetime | None = None) -> list[dict[str, Any]]:
    cutoff = (now or datetime.now(timezone.utc)) - timedelta(days=7)
    events: list[dict[str, Any]] = []
    raw = Path(path).read_text(encoding="utf-8")
    try:
        decoded = json.loads(raw)
        candidates: Iterable[Any] = decoded if isinstance(decoded, list) else [decoded]
    except json.JSONDecodeError:
        parsed_lines = []
        for line in raw.splitlines():
            if not line.strip():
                continue
            try:
                parsed_lines.append(json.loads(line))
            except json.JSONDecodeError:
                continue
        candidates = parsed_lines
    for item in candidates:
        if not isinstance(item, dict):
            continue
        timestamp = parse_time(item.get("timestamp"))
        if timestamp is not None and timestamp >= cutoff:
            events.append(item)
    return events


def summarize(events: list[dict[str, Any]]) -> dict[str, Any]:
    status = Counter(str(item.get("status", "unknown")) for item in events)
    errors = Counter(str(item.get("error", "unknown"))[:120] for item in events if item.get("error"))
    duplicates = sum(1 for item in events if item.get("duplicate") is True)
    durations = [float(item["duration_ms"]) for item in events if isinstance(item.get("duration_ms"), (int, float))]
    return {
        "period_days": 7,
        "events": len(events),
        "errors": sum(count for code, count in status.items() if code == "error" or code.startswith("5")),
        "duplicates": duplicates,
        "status_counts": dict(sorted(status.items())),
        "top_errors": dict(errors.most_common(MAX_ERROR_TYPES)),
        "avg_duration_ms": round(sum(durations) / len(durations), 2) if durations else None,
    }


def render_markdown(summary: Mapping[str, Any], workflow_url: str = "") -> str:
    lines = [
        "## Smart Accountant — Weekly Security Gateway report",
        "",
        f"Period: last {summary['period_days']} days",
        "",
        f"- Gateway events: **{summary['events']}**",
        f"- Errors: **{summary['errors']}**",
        f"- Duplicate requests suppressed: **{summary['duplicates']}**",
        f"- Average duration: **{summary['avg_duration_ms'] if summary['avg_duration_ms'] is not None else 'n/a'} ms**",
        "",
        "### Status counts",
        "",
        "| Status | Count |",
        "|---|---:|",
    ]
    for key, value in summary["status_counts"].items():
        lines.append(f"| {key[:40]} | {value} |")
    lines.extend(["", "### Top error types", "", "| Error type | Count |", "|---|---:|"])
    for key, value in summary["top_errors"].items():
        lines.append(f"| {key.replace('|', '/')[:120]} | {value} |")
    if not summary["top_errors"]:
        lines.append("| none | 0 |")
    if workflow_url:
        lines.extend(["", workflow_url[:500]])
    return "\n".join(lines) + "\n"


def make_weekly_key(summary: Mapping[str, Any], context: Mapping[str, str] | None = None) -> str:
    values = os.environ if context is None else context
    week = datetime.now(timezone.utc).strftime("%G-W%V")
    material = f"{values.get('GITHUB_REPOSITORY', 'local')}|{values.get('GITHUB_WORKFLOW', 'weekly-security')}|{week}"
    return "sa-weekly-" + hashlib.sha256(material.encode()).hexdigest()[:32]


def post_slack(webhook_url: str, markdown: str, key: str) -> None:
    payload = {"text": markdown, "idempotency_key": key}
    request = urllib.request.Request(
        webhook_url,
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers={"Content-Type": "application/json", "Idempotency-Key": key},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=10) as response:
        if not 200 <= response.status < 300:
            raise RuntimeError(f"Slack returned HTTP {response.status}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--markdown-output", required=True)
    parser.add_argument("--workflow-url", default="")
    parser.add_argument("--send-slack", action="store_true")
    args = parser.parse_args()
    summary = summarize(load_events(args.input))
    markdown = render_markdown(summary, args.workflow_url)
    Path(args.markdown_output).write_text(markdown, encoding="utf-8")
    if args.send_slack:
        webhook = os.environ.get("SECURITY_SLACK_WEBHOOK_URL", "")
        if not webhook:
            raise SystemExit("SECURITY_SLACK_WEBHOOK_URL is required with --send-slack")
        post_slack(webhook, markdown, make_weekly_key(summary))
    print(json.dumps(summary, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
