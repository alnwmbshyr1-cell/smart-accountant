#!/usr/bin/env python3
"""Bounded, staging-only endpoint resilience checks; never a DDoS tool."""
from __future__ import annotations

import argparse
import json
import os
import ssl
import time
import urllib.error
import urllib.request
from collections import Counter
from dataclasses import asdict, dataclass
from pathlib import Path

MAX_REQUESTS = 100
MAX_RPS = 20
ALLOWED_ENVIRONMENTS = {"staging", "lab"}


@dataclass
class Result:
    url: str
    requests: int
    elapsed_seconds: float
    statuses: dict[str, int]
    rate_limit_seen: bool
    timeout_seconds: float


def validate_scope(url: str, environment: str, authorized: bool, requests: int, rps: int) -> None:
    if not authorized:
        raise ValueError("set RESILIENCE_TEST_AUTHORIZED=true")
    if environment not in ALLOWED_ENVIRONMENTS:
        raise ValueError("environment must be staging or lab")
    if not url.startswith("https://") and not url.startswith("http://127.0.0.1") and not url.startswith("http://localhost"):
        raise ValueError("target must be HTTPS or local loopback")
    if requests < 1 or requests > MAX_REQUESTS:
        raise ValueError(f"requests must be between 1 and {MAX_REQUESTS}")
    if rps < 1 or rps > MAX_RPS:
        raise ValueError(f"rps must be between 1 and {MAX_RPS}")


def run_bounded_check(url: str, token: str, requests: int = 40, rps: int = 10, timeout: float = 3.0) -> Result:
    validate_scope(url, os.getenv("PENTEST_ENV", ""), os.getenv("RESILIENCE_TEST_AUTHORIZED", "").lower() == "true", requests, rps)
    statuses: Counter[str] = Counter()
    interval = 1.0 / rps
    started = time.monotonic()
    context = ssl.create_default_context()
    for index in range(requests):
        request = urllib.request.Request(
            url,
            method="GET",
            headers={"Accept": "application/json", "Authorization": f"Bearer {token}"} if token else {"Accept": "application/json"},
        )
        try:
            with urllib.request.urlopen(request, timeout=timeout, context=context) as response:
                statuses[str(response.status)] += 1
        except urllib.error.HTTPError as error:
            statuses[str(error.code)] += 1
        except (TimeoutError, urllib.error.URLError):
            statuses["timeout_or_network_error"] += 1
        if index + 1 < requests:
            time.sleep(interval)
    elapsed = time.monotonic() - started
    return Result(url=url, requests=requests, elapsed_seconds=round(elapsed, 3), statuses=dict(statuses), rate_limit_seen=bool(statuses.get("429")), timeout_seconds=timeout)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default=os.getenv("RESILIENCE_TEST_URL", ""))
    parser.add_argument("--token", default=os.getenv("GATEWAY_INGRESS_TOKEN", ""))
    parser.add_argument("--requests", type=int, default=40)
    parser.add_argument("--rps", type=int, default=10)
    parser.add_argument("--timeout", type=float, default=3.0)
    parser.add_argument("--output", default="resilience-results.json")
    args = parser.parse_args()
    result = run_bounded_check(args.url, args.token, args.requests, args.rps, args.timeout)
    Path(args.output).write_text(json.dumps(asdict(result), indent=2), encoding="utf-8")
    print(json.dumps(asdict(result), indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
