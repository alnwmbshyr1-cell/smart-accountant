#!/usr/bin/env python3
"""Local-only mock receivers for Alertmanager Webhook and PagerDuty tests."""
from __future__ import annotations

import argparse
import hashlib
import hmac
import json
import os
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any


class State:
    def __init__(self, output: Path, secret: str) -> None:
        self.output = output
        self.secret = secret.encode()
        self.lock = threading.Lock()
        self.events: list[dict[str, Any]] = []
        self.memory_rss = 100000000

    def record(self, channel: str, body: bytes, headers: Any) -> None:
        item = {
            "channel": channel,
            "body_sha256": hashlib.sha256(body).hexdigest(),
            "content_type": headers.get("Content-Type", ""),
        }
        try:
            payload = json.loads(body.decode("utf-8"))
            item["status"] = payload.get("status")
            item["alert_count"] = len(payload.get("alerts", []))
            item["alertnames"] = [a.get("labels", {}).get("alertname") for a in payload.get("alerts", [])]
        except (UnicodeDecodeError, json.JSONDecodeError):
            item["status"] = "invalid-json"
        with self.lock:
            self.events.append(item)
            self.output.parent.mkdir(parents=True, exist_ok=True)
            self.output.write_text(json.dumps(self.events, ensure_ascii=False, indent=2), encoding="utf-8")


class Handler(BaseHTTPRequestHandler):
    server_version = "SyntheticReceiver/1.0"

    def do_POST(self) -> None:  # noqa: N802
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length)
        state: State = self.server.state  # type: ignore[attr-defined]
        if self.path == "/metrics-state":
            try:
                value = int(json.loads(body.decode("utf-8"))["memory_rss_bytes"])
            except (KeyError, TypeError, ValueError, json.JSONDecodeError):
                self.send_error(400, "memory_rss_bytes is required")
                return
            with state.lock:
                state.memory_rss = value
            self.send_response(204)
            self.end_headers()
            return
        if self.path == "/webhook":
            signature = self.headers.get("X-Synthetic-Signature", "")
            expected = hmac.new(state.secret, body, hashlib.sha256).hexdigest()
            unsigned_allowed = os.environ.get("ALLOW_UNSIGNED_SYNTHETIC", "false").lower() == "true"
            if not signature and not unsigned_allowed:
                self.send_error(401, "missing synthetic signature")
                return
            if signature and not hmac.compare_digest(signature, expected):
                self.send_error(401, "invalid synthetic signature")
                return
            channel = "webhook"
        elif self.path == "/pagerduty/v2/enqueue":
            channel = "pagerduty"
        else:
            self.send_error(404)
            return
        state.record(channel, body, self.headers)
        self.send_response(202)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"accepted":true}')

    def do_GET(self) -> None:  # noqa: N802
        state: State = self.server.state  # type: ignore[attr-defined]
        if self.path == "/metrics":
            with state.lock:
                value = state.memory_rss
            body = f"# HELP otelcol_process_memory_rss_bytes Collector RSS for synthetic testing\\n# TYPE otelcol_process_memory_rss_bytes gauge\\notelcol_process_memory_rss_bytes {value}\\n".encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; version=0.0.4")
            self.end_headers()
            self.wfile.write(body)
            return
        if self.path != "/received":
            self.send_error(404)
            return
        state: State = self.server.state  # type: ignore[attr-defined]
        with state.lock:
            body = json.dumps(state.events, ensure_ascii=False).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args: Any) -> None:
        return


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=18080)
    parser.add_argument("--secret", default=os.environ.get("SYNTHETIC_WEBHOOK_SECRET", "local-only"))
    parser.add_argument("--output", type=Path, default=Path("artifacts/synthetic-receiver-events.json"))
    args = parser.parse_args()
    if args.host not in {"127.0.0.1", "localhost"}:
        raise SystemExit("synthetic receiver is local-only")
    httpd = ThreadingHTTPServer((args.host, args.port), Handler)
    httpd.state = State(args.output, args.secret)  # type: ignore[attr-defined]
    print(f"synthetic receivers listening on http://{args.host}:{args.port}", flush=True)
    httpd.serve_forever()


if __name__ == "__main__":
    main()
