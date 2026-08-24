#!/usr/bin/env python3
import hashlib
import hmac
import json
import os
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

try:
    import redis
except ImportError:  # The local harness remains runnable without Redis.
    redis = None

SECRET = os.environ.get("CONTINUOUS_WEBHOOK_SECRET", "")
EVENTS_PATH = Path(os.environ.get("CONTINUOUS_EVENTS_PATH", "/data/continuous-events.jsonl"))
MAX_SKEW = int(os.environ.get("CONTINUOUS_MAX_TIMESTAMP_SKEW", "300"))
IDEMPOTENCY_TTL = int(os.environ.get("CONTINUOUS_IDEMPOTENCY_TTL", "900"))
REDIS_URL = os.environ.get("REDIS_URL", "")
SEEN = set()
REDIS = redis.Redis.from_url(REDIS_URL, decode_responses=True, socket_timeout=2) if REDIS_URL and redis else None


def verify_signature(raw: bytes, timestamp: str, signature: str) -> bool:
    if not SECRET or not timestamp or not signature:
        return False
    try:
        if abs(int(time.time()) - int(timestamp)) > MAX_SKEW:
            return False
    except ValueError:
        return False
    expected = hmac.new(SECRET.encode(), timestamp.encode() + b"." + raw, hashlib.sha256).hexdigest()
    provided = signature.removeprefix("sha256=")
    return hmac.compare_digest(expected, provided)


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/healthz":
            self.send_response(200); self.end_headers(); self.wfile.write(b"ok"); return
        self.send_response(404); self.end_headers()

    def do_POST(self):
        if self.path != "/alertmanager":
            self.send_response(404); self.end_headers(); return
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            length = 0
        if length <= 0 or length > 65536:
            self.send_response(413); self.end_headers(); return
        raw = self.rfile.read(length)
        timestamp = self.headers.get("X-Webhook-Timestamp", "")
        signature = self.headers.get("X-Webhook-Signature", "")
        if not verify_signature(raw, timestamp, signature):
            self.send_response(401); self.end_headers(); return
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            self.send_response(400); self.end_headers(); return
        event_id = self.headers.get("X-Webhook-Id", "") or hashlib.sha256(raw).hexdigest()
        body_hash = hashlib.sha256(raw).hexdigest()
        if REDIS is not None:
            claim_key = f"continuous:webhook:{event_id}"
            claimed = REDIS.set(claim_key, body_hash, nx=True, ex=IDEMPOTENCY_TTL)
            if not claimed:
                previous_hash = REDIS.get(claim_key)
                self.send_response(202 if previous_hash == body_hash else 409)
                self.end_headers(); self.wfile.write(b"duplicate" if previous_hash == body_hash else b"idempotency-key-reuse"); return
        else:
            if event_id in SEEN:
                self.send_response(202); self.end_headers(); self.wfile.write(b"duplicate"); return
            SEEN.add(event_id)
        EVENTS_PATH.parent.mkdir(parents=True, exist_ok=True)
        safe = {"event_id": event_id, "status": payload.get("status"), "alerts": payload.get("alerts", []), "received_at": int(time.time())}
        EVENTS_PATH.open("a", encoding="utf-8").write(json.dumps(safe, ensure_ascii=False, sort_keys=True) + "\n")
        self.send_response(202); self.end_headers(); self.wfile.write(b"accepted")

    def log_message(self, *_args):
        return


if __name__ == "__main__":
    HTTPServer((os.environ.get("WEBHOOK_BIND", "0.0.0.0"), int(os.environ.get("WEBHOOK_PORT", "8090"))), Handler).serve_forever()
