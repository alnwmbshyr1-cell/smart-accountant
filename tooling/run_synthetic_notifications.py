#!/usr/bin/env python3
"""Send deterministic firing/resolved notifications to local mock receivers only."""
from __future__ import annotations

import argparse
import hashlib
import hmac
import json
import time
from pathlib import Path
from urllib.error import URLError
from urllib.request import Request, urlopen


def payload(status: str) -> dict:
    return {
        "version": "4",
        "groupKey": "synthetic-circuit-open",
        "status": status,
        "receiver": "synthetic",
        "groupLabels": {"alertname": "CircuitBreakerOpen", "category": "security"},
        "commonLabels": {"alertname": "CircuitBreakerOpen", "severity": "critical", "dependency": "synthetic"},
        "commonAnnotations": {"summary": "Synthetic Circuit Open", "description": "Local-only delivery test"},
        "externalURL": "http://localhost/alertmanager",
        "alerts": [{
            "status": status,
            "labels": {"alertname": "CircuitBreakerOpen", "severity": "critical", "category": "security", "dependency": "synthetic"},
            "annotations": {"summary": "Synthetic Circuit Open"},
            "startsAt": "2026-01-01T00:00:00Z",
            "endsAt": "2026-01-01T00:05:00Z" if status == "resolved" else "0001-01-01T00:00:00Z",
            "fingerprint": "synthetic-fingerprint",
        }],
    }


def post(url: str, body: bytes, headers: dict[str, str]) -> int:
    request = Request(url, data=body, headers={"Content-Type": "application/json", **headers}, method="POST")
    with urlopen(request, timeout=3) as response:
        return response.status


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", default="http://127.0.0.1:18080")
    parser.add_argument("--secret", default="local-only")
    parser.add_argument("--output", type=Path, default=Path("artifacts/synthetic-results.json"))
    args = parser.parse_args()
    if not args.base_url.startswith("http://127.0.0.1:"):
        raise SystemExit("synthetic runner accepts localhost only")
    results = []
    for status in ("firing", "resolved"):
        body = json.dumps(payload(status), separators=(",", ":")).encode()
        signature = hmac.new(args.secret.encode(), body, hashlib.sha256).hexdigest()
        results.append({"status": status, "webhook": post(f"{args.base_url}/webhook", body, {"X-Synthetic-Signature": signature}), "pagerduty": post(f"{args.base_url}/pagerduty/v2/enqueue", body, {"X-Synthetic-Event": "true"})})
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps({"generated_at": time.time(), "results": results}, indent=2), encoding="utf-8")
    if any(item["webhook"] != 202 or item["pagerduty"] != 202 for item in results):
        raise SystemExit("synthetic delivery failed")
    print(json.dumps(results))


if __name__ == "__main__":
    try:
        main()
    except URLError as exc:
        raise SystemExit(f"mock receiver unavailable: {exc}") from exc
