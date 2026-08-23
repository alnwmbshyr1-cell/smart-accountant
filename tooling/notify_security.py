#!/usr/bin/env python3
"""Notify configured channels when a unified SARIF report contains critical findings.

The script never sends the SARIF document itself. It sends only a bounded summary
and a link to the GitHub workflow. Secrets are supplied through environment vars.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any

MAX_FINDINGS = 10


@dataclass(frozen=True)
class NotificationResult:
    channel: str
    sent: bool
    error: str = ""


def load_report(path: str) -> dict[str, Any]:
    with open(path, encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict) or not isinstance(value.get("summary"), dict):
        raise ValueError("security report must contain an object summary")
    return value


def critical_findings(report: dict[str, Any]) -> list[dict[str, Any]]:
    findings = report.get("findings") or []
    return [item for item in findings if isinstance(item, dict) and item.get("severity") == "critical"]


def safe_summary(report: dict[str, Any], workflow_url: str) -> dict[str, Any]:
    findings = critical_findings(report)
    rows = []
    for item in findings[:MAX_FINDINGS]:
        location = str(item.get("file") or "unknown")
        line = item.get("line")
        if isinstance(line, int):
            location += f":{line}"
        rows.append({
            "source": str(item.get("source") or "unknown")[:80],
            "rule_id": str(item.get("rule_id") or "unknown")[:120],
            "location": location[:240],
        })
    return {
        "title": "Smart Accountant: critical security findings",
        "total_critical": len(findings),
        "shown": len(rows),
        "findings": rows,
        "workflow_url": workflow_url[:500],
    }


def post_json(url: str, payload: dict[str, Any], timeout: float = 10.0, headers: dict[str, str] | None = None) -> None:
    request_headers = {"Content-Type": "application/json", "User-Agent": "smart-accountant-security-notifier/1"}
    request_headers.update(headers or {})
    request = urllib.request.Request(
        url,
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers=request_headers,
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        if response.status < 200 or response.status >= 300:
            raise RuntimeError(f"notification endpoint returned HTTP {response.status}")


def send_slack(webhook_url: str, summary: dict[str, Any]) -> None:
    lines = [f"*{summary['title']}*", f"Critical findings: `{summary['total_critical']}`"]
    for item in summary["findings"]:
        lines.append(f"• `{item['source']}` `{item['rule_id']}` at `{item['location']}`")
    if summary["total_critical"] > summary["shown"]:
        lines.append(f"…and {summary['total_critical'] - summary['shown']} more. See GitHub Security.")
    if summary["workflow_url"]:
        lines.append(summary["workflow_url"])
    post_json(webhook_url, {"text": "\n".join(lines)})


def send_webhook(webhook_url: str, summary: dict[str, Any]) -> None:
    post_json(webhook_url, {"event": "critical_security_findings", **summary})


def send_email(email_url: str, summary: dict[str, Any], token: str) -> None:
    # The endpoint is an internal mail gateway, not a provider-specific API.
    post_json(email_url, {
        "subject": f"Smart Accountant: {summary['total_critical']} critical security finding(s)",
        "text": json.dumps(summary, ensure_ascii=False),
    }, timeout=10.0, headers={"Authorization": f"Bearer {token}"})


def notify(report: dict[str, Any], workflow_url: str, env: dict[str, str] | None = None) -> list[NotificationResult]:
    values = os.environ if env is None else env
    findings = critical_findings(report)
    if not findings:
        return []
    summary = safe_summary(report, workflow_url)
    results: list[NotificationResult] = []
    slack = values.get("SECURITY_SLACK_WEBHOOK_URL", "")
    ops_webhook = values.get("SECURITY_OPS_WEBHOOK_URL", "")
    email_url = values.get("SECURITY_EMAIL_WEBHOOK_URL", "")
    email_token = values.get("SECURITY_EMAIL_WEBHOOK_TOKEN", "")
    for name, url, sender in [
        ("slack", slack, send_slack),
        ("webhook", ops_webhook, send_webhook),
    ]:
        if not url:
            continue
        try:
            sender(url, summary)
            results.append(NotificationResult(name, True))
        except (OSError, urllib.error.URLError, RuntimeError) as exc:
            results.append(NotificationResult(name, False, type(exc).__name__))
    if email_url and email_token:
        try:
            send_email(email_url, summary, email_token)
            results.append(NotificationResult("email", True))
        except (OSError, urllib.error.URLError, RuntimeError) as exc:
            results.append(NotificationResult("email", False, type(exc).__name__))
    return results


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", required=True)
    parser.add_argument("--workflow-url", default="")
    args = parser.parse_args()
    report = load_report(args.report)
    findings = critical_findings(report)
    print(json.dumps({"critical": len(findings)}, sort_keys=True))
    results = notify(report, args.workflow_url)
    for result in results:
        print(json.dumps({"channel": result.channel, "sent": result.sent, "error": result.error}, sort_keys=True))
    if findings and not results:
        print("No notification channel is configured; configure Slack or email secrets.", file=sys.stderr)
    failed = [result for result in results if not result.sent]
    if failed:
        print("One or more configured notification channels failed.", file=sys.stderr)
        return 2
    # The security gate, not the notifier, enforces the Critical policy.
    return 0


if __name__ == "__main__":
    sys.exit(main())
