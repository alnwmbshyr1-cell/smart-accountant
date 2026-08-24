#!/usr/bin/env python3
"""Secure GitHub check webhook -> Slack notifier.

Accepts GitHub `check_run` and `workflow_run` events, filters failures for
configured required checks, verifies GitHub HMAC signatures, deduplicates
GitHub delivery IDs, and posts a redacted message to Slack.
"""
from __future__ import annotations

import hashlib
import hmac
import json
import os
import re
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

try:
    import redis
except ImportError:
    redis = None

GITHUB_SECRET = os.environ.get("GITHUB_WEBHOOK_SECRET", "")
SLACK_WEBHOOK_URL = os.environ.get("SLACK_WEBHOOK_URL", "")
REQUIRED_CHECKS = {
    value.strip() for value in os.environ.get(
        "REQUIRED_CHECKS",
        "SAST and dependency security,Security scanning,Quality gate,Integration tests,Full coverage,Fast checks,Prometheus to Alertmanager integration",
    ).split(",") if value.strip()
}
PROTECTED_BRANCH = os.environ.get("PROTECTED_BRANCH", "main")
MAX_BODY_BYTES = int(os.environ.get("GITHUB_WEBHOOK_MAX_BODY", "131072"))
MAX_SKEW_SECONDS = int(os.environ.get("GITHUB_WEBHOOK_MAX_SKEW", "300"))
IDEMPOTENCY_TTL = int(os.environ.get("GITHUB_WEBHOOK_IDEMPOTENCY_TTL", "86400"))
SLACK_TIMEOUT_SECONDS = float(os.environ.get("SLACK_TIMEOUT_SECONDS", "5"))
SLACK_MAX_RETRIES = int(os.environ.get("SLACK_MAX_RETRIES", "2"))
REDIS_URL = os.environ.get("REDIS_URL", "")
SEEN_DELIVERIES: set[str] = set()
REDIS = redis.Redis.from_url(REDIS_URL, decode_responses=True, socket_timeout=2) if REDIS_URL and redis else None
_SECRET_PATTERN = re.compile(r"(https://hooks\.slack\.com/services/)[^\s]+", re.I)


def verify_signature(raw: bytes, signature: str) -> bool:
    if not GITHUB_SECRET or not signature.startswith("sha256="):
        return False
    expected = "sha256=" + hmac.new(GITHUB_SECRET.encode(), raw, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, signature)


def _branch_matches(payload: dict[str, Any]) -> bool:
    ref = payload.get("check_run", payload.get("workflow_run", {})).get("check_suite", {}).get("head_branch")
    if ref is None:
        ref = payload.get("workflow_run", {}).get("head_branch") or payload.get("check_run", {}).get("head_branch")
    return ref == PROTECTED_BRANCH or any(pr.get("base", {}).get("ref") == PROTECTED_BRANCH for pr in payload.get("check_run", {}).get("pull_requests", []))


def extract_failure(payload: dict[str, Any], event: str) -> dict[str, str] | None:
    if event == "check_run":
        item = payload.get("check_run", {})
        name = str(item.get("name", ""))
        conclusion = str(item.get("conclusion", ""))
        status = str(item.get("status", ""))
        if name not in REQUIRED_CHECKS or status != "completed" or conclusion not in {"failure", "timed_out", "action_required", "cancelled"}:
            return None
        return {"name": name, "conclusion": conclusion, "sha": str(item.get("head_sha", "")), "url": str(item.get("html_url", ""))}
    if event == "workflow_run":
        item = payload.get("workflow_run", {})
        name = str(item.get("name", ""))
        conclusion = str(item.get("conclusion", ""))
        if name not in REQUIRED_CHECKS or item.get("status") != "completed" or conclusion not in {"failure", "timed_out", "cancelled"}:
            return None
        return {"name": name, "conclusion": conclusion, "sha": str(item.get("head_sha", "")), "url": str(item.get("html_url", ""))}
    return None


def _redact(value: str) -> str:
    return _SECRET_PATTERN.sub(r"\1[redacted]", value)


def build_slack_payload(failure: dict[str, str], repository: str, delivery_id: str) -> dict[str, Any]:
    url = _redact(failure.get("url", ""))
    text = f":x: Required check failed: {failure['name']} ({failure['conclusion']}) in {repository}"
    return {"text": text, "blocks": [{"type": "section", "text": {"type": "mrkdwn", "text": _redact(text)}}, {"type": "context", "elements": [{"type": "mrkdwn", "text": f"branch: `{PROTECTED_BRANCH}` • sha: `{failure.get('sha', '')[:12]}` • delivery: `{delivery_id}`"}, {"type": "mrkdwn", "text": f"<{url}|View check>" if url else "Check URL unavailable"}]}]}


def post_to_slack(payload: dict[str, Any]) -> bool:
    if not SLACK_WEBHOOK_URL:
        return False
    raw = json.dumps(payload, ensure_ascii=False).encode()
    for attempt in range(SLACK_MAX_RETRIES + 1):
        try:
            request = Request(SLACK_WEBHOOK_URL, data=raw, headers={"Content-Type": "application/json"}, method="POST")
            with urlopen(request, timeout=SLACK_TIMEOUT_SECONDS) as response:
                if 200 <= response.status < 300:
                    return True
        except HTTPError as error:
            if error.code not in {429, 500, 502, 503, 504} or attempt >= SLACK_MAX_RETRIES:
                return False
            retry_after = min(float(error.headers.get("Retry-After", "1")), 10.0)
            time.sleep(retry_after * (2**attempt))
        except (URLError, TimeoutError):
            if attempt >= SLACK_MAX_RETRIES:
                return False
            time.sleep(min(2**attempt, 10))
    return False


def claim_delivery(delivery_id: str, body_hash: str) -> bool:
    if not delivery_id:
        return True
    if REDIS is not None:
        key = f"github:required-checks:{delivery_id}"
        return bool(REDIS.set(key, body_hash, nx=True, ex=IDEMPOTENCY_TTL))
    if delivery_id in SEEN_DELIVERIES:
        return False
    SEEN_DELIVERIES.add(delivery_id)
    return True


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        if self.path == "/healthz":
            self.send_response(200); self.end_headers(); self.wfile.write(b"ok"); return
        self.send_response(404); self.end_headers()

    def do_POST(self) -> None:
        if self.path != "/github":
            self.send_response(404); self.end_headers(); return
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            length = 0
        if length <= 0 or length > MAX_BODY_BYTES:
            self.send_response(413); self.end_headers(); return
        raw = self.rfile.read(length)
        if not verify_signature(raw, self.headers.get("X-Hub-Signature-256", "")):
            self.send_response(401); self.end_headers(); return
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            self.send_response(400); self.end_headers(); return
        event = self.headers.get("X-GitHub-Event", "")
        delivery_id = self.headers.get("X-GitHub-Delivery", "")
        failure = extract_failure(payload, event)
        if failure is None or not _branch_matches(payload):
            self.send_response(202); self.end_headers(); self.wfile.write(b"ignored"); return
        if not claim_delivery(delivery_id, hashlib.sha256(raw).hexdigest()):
            self.send_response(202); self.end_headers(); self.wfile.write(b"duplicate"); return
        repository = str(payload.get("repository", {}).get("full_name", "unknown/unknown"))
        accepted = post_to_slack(build_slack_payload(failure, repository, delivery_id))
        self.send_response(202 if accepted else 502); self.end_headers(); self.wfile.write(b"notified" if accepted else b"notification-failed")

    def log_message(self, *_args: Any) -> None:
        return


if __name__ == "__main__":
    HTTPServer((os.environ.get("WEBHOOK_BIND", "0.0.0.0"), int(os.environ.get("WEBHOOK_PORT", "8091"))), Handler).serve_forever()
