#!/usr/bin/env python3
"""Notify configured channels for critical findings in a unified security report."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import ssl
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from email.utils import parsedate_to_datetime
from typing import Any, Callable, Mapping

MAX_FINDINGS = 10
MAX_ATTEMPTS = 3
DEFAULT_BACKOFF_SECONDS = 1.0
RETRYABLE_STATUS_CODES = frozenset({429, 500, 501, 502, 503, 504, 505, 507, 508, 510, 511})


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


def critical_findings(report: Mapping[str, Any]) -> list[dict[str, Any]]:
    findings = report.get("findings") or []
    return [item for item in findings if isinstance(item, dict) and item.get("severity") == "critical"]


def finding_fingerprint(findings: list[dict[str, Any]]) -> str:
    stable = [
        {
            "source": item.get("source", ""),
            "rule_id": item.get("rule_id", ""),
            "file": item.get("file", ""),
            "line": item.get("line", ""),
            "severity": item.get("severity", ""),
        }
        for item in findings
    ]
    encoded = json.dumps(stable, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def make_idempotency_key(report: Mapping[str, Any], channel: str, context: Mapping[str, str] | None = None) -> str:
    values = context or os.environ
    material = {
        "repository": values.get("GITHUB_REPOSITORY", "local"),
        "workflow": values.get("GITHUB_WORKFLOW", "security"),
        "sha": values.get("GITHUB_SHA", "local"),
        "channel": channel,
        "critical_fingerprint": finding_fingerprint(critical_findings(report)),
    }
    encoded = json.dumps(material, ensure_ascii=True, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return "sa-" + hashlib.sha256(encoded).hexdigest()[:32]


def safe_summary(report: Mapping[str, Any], workflow_url: str, idempotency_key: str = "") -> dict[str, Any]:
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
        "idempotency_key": idempotency_key,
    }


def _retry_after_seconds(error: urllib.error.HTTPError, default: float) -> float:
    value = error.headers.get("Retry-After") if error.headers else None
    if value:
        try:
            return max(0.0, min(float(value), 60.0))
        except ValueError:
            try:
                retry_at = parsedate_to_datetime(value).timestamp()
                return max(0.0, min(retry_at - time.time(), 60.0))
            except (TypeError, ValueError, OverflowError):
                pass
    return min(default, 60.0)


def post_json(
    url: str,
    payload: dict[str, Any],
    timeout: float = 10.0,
    headers: dict[str, str] | None = None,
    attempts: int = MAX_ATTEMPTS,
    sleep_fn: Callable[[float], None] = time.sleep,
    ssl_context: ssl.SSLContext | None = None,
) -> None:
    request_headers = {"Content-Type": "application/json", "User-Agent": "smart-accountant-security-notifier/1"}
    request_headers.update(headers or {})
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    last_error: Exception | None = None
    for attempt in range(1, max(1, attempts) + 1):
        request = urllib.request.Request(url, data=body, headers=request_headers, method="POST")
        try:
            open_args: dict[str, Any] = {"timeout": timeout}
            if ssl_context is not None:
                open_args["context"] = ssl_context
            with urllib.request.urlopen(request, **open_args) as response:
                if 200 <= response.status < 300:
                    return
                error = RuntimeError(f"notification endpoint returned HTTP {response.status}")
                last_error = error
                if response.status not in RETRYABLE_STATUS_CODES or attempt == attempts:
                    raise error
                delay = min(DEFAULT_BACKOFF_SECONDS * (2 ** (attempt - 1)), 60.0)
        except urllib.error.HTTPError as error:
            last_error = error
            if error.code not in RETRYABLE_STATUS_CODES or attempt == attempts:
                raise
            delay = _retry_after_seconds(error, DEFAULT_BACKOFF_SECONDS * (2 ** (attempt - 1)))
        except (urllib.error.URLError, TimeoutError, OSError) as error:
            last_error = error
            if attempt == attempts:
                raise
            delay = min(DEFAULT_BACKOFF_SECONDS * (2 ** (attempt - 1)), 60.0)
        sleep_fn(delay)
    if last_error:
        raise last_error


def send_slack(webhook_url: str, summary: dict[str, Any]) -> None:
    lines = [f"*{summary['title']}*", f"Critical findings: `{summary['total_critical']}`"]
    for item in summary["findings"]:
        lines.append(f"• `{item['source']}` `{item['rule_id']}` at `{item['location']}`")
    if summary["total_critical"] > summary["shown"]:
        lines.append(f"…and {summary['total_critical'] - summary['shown']} more. See GitHub Security.")
    if summary["workflow_url"]:
        lines.append(summary["workflow_url"])
    post_json(
        webhook_url,
        {"text": "\n".join(lines), "idempotency_key": summary["idempotency_key"]},
        headers={"Idempotency-Key": summary["idempotency_key"]},
    )


def send_webhook(
    webhook_url: str,
    summary: dict[str, Any],
    ssl_context: ssl.SSLContext | None = None,
    ingress_token: str = "",
) -> None:
    headers = {"Idempotency-Key": summary["idempotency_key"]}
    if ingress_token:
        headers["Authorization"] = f"Bearer {ingress_token}"
    post_json(
        webhook_url,
        {"event": "critical_security_findings", **summary},
        headers=headers,
        ssl_context=ssl_context,
    )


def send_email(email_url: str, summary: dict[str, Any], token: str, ssl_context: ssl.SSLContext | None = None) -> None:
    post_json(
        email_url,
        {
            "subject": f"Smart Accountant: {summary['total_critical']} critical security finding(s)",
            "text": json.dumps(summary, ensure_ascii=False),
        },
        headers={
            "Authorization": f"Bearer {token}",
            "Idempotency-Key": summary["idempotency_key"],
        },
        ssl_context=ssl_context,
    )


def gateway_ssl_context(values: Mapping[str, str]) -> ssl.SSLContext | None:
    ca_file = values.get("SECURITY_GATEWAY_CA_FILE", "")
    cert_file = values.get("SECURITY_GATEWAY_CLIENT_CERT_FILE", "")
    key_file = values.get("SECURITY_GATEWAY_CLIENT_KEY_FILE", "")
    if not any((ca_file, cert_file, key_file)):
        return None
    if not ca_file or not cert_file or not key_file:
        raise ValueError("all SECURITY_GATEWAY_* TLS files are required together")
    context = ssl.create_default_context(cafile=ca_file)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(certfile=cert_file, keyfile=key_file)
    return context


def notify(report: dict[str, Any], workflow_url: str, env: Mapping[str, str] | None = None) -> list[NotificationResult]:
    values = os.environ if env is None else env
    findings = critical_findings(report)
    if not findings:
        return []
    results: list[NotificationResult] = []
    slack = values.get("SECURITY_SLACK_WEBHOOK_URL", "")
    ops_webhook = values.get("SECURITY_OPS_WEBHOOK_URL", "")
    email_url = values.get("SECURITY_EMAIL_WEBHOOK_URL", "")
    email_token = values.get("SECURITY_EMAIL_WEBHOOK_TOKEN", "")
    gateway_url = values.get("SECURITY_GATEWAY_WEBHOOK_URL", "")
    gateway_token = values.get("SECURITY_GATEWAY_INGRESS_TOKEN", "")
    if gateway_url:
        if not gateway_token:
            raise ValueError("SECURITY_GATEWAY_INGRESS_TOKEN is required with the gateway URL")
        ops_webhook = gateway_url
    gateway_context = gateway_ssl_context(values)
    for name, url, sender in [("slack", slack, send_slack), ("webhook", ops_webhook, send_webhook)]:
        if not url:
            continue
        key = make_idempotency_key(report, name, values)
        summary = safe_summary(report, workflow_url, key)
        try:
            if name == "webhook":
                sender(url, summary, gateway_context, gateway_token)
            else:
                sender(url, summary)
            results.append(NotificationResult(name, True))
        except (OSError, urllib.error.URLError, RuntimeError) as exc:
            results.append(NotificationResult(name, False, type(exc).__name__))
    if email_url and email_token:
        key = make_idempotency_key(report, "email", values)
        summary = safe_summary(report, workflow_url, key)
        try:
            send_email(email_url, summary, email_token, gateway_context)
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
    return 0


if __name__ == "__main__":
    sys.exit(main())
