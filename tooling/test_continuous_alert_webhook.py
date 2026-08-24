import hashlib
import hmac
import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError

ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / "backend/ops/continuous_alert_webhook.py"


def signed_request(port, secret, payload, event_id, timestamp=None):
    raw = json.dumps(payload, separators=(",", ":")).encode()
    timestamp = str(timestamp or int(time.time()))
    signature = hmac.new(secret.encode(), timestamp.encode() + b"." + raw, hashlib.sha256).hexdigest()
    return Request(
        f"http://127.0.0.1:{port}/alertmanager",
        data=raw,
        headers={"Content-Type": "application/json", "X-Webhook-Id": event_id, "X-Webhook-Timestamp": timestamp, "X-Webhook-Signature": f"sha256={signature}"},
        method="POST",
    )


class ContinuousWebhookIntegrationTests(unittest.TestCase):
    def test_accepts_signed_event_and_deduplicates_replay(self):
        port = 18090
        secret = "local-only-secret"
        with tempfile.TemporaryDirectory() as tmp:
            events = Path(tmp) / "events.jsonl"
            env = {**os.environ, "CONTINUOUS_WEBHOOK_SECRET": secret, "CONTINUOUS_EVENTS_PATH": str(events), "WEBHOOK_PORT": str(port)}
            server = subprocess.Popen([sys.executable, str(SERVER)], env=env)
            try:
                time.sleep(0.15)
                payload = {"status": "firing", "alerts": [{"labels": {"alertname": "DeadlockBurst", "severity": "critical"}}]}
                with urlopen(signed_request(port, secret, payload, "event-1"), timeout=2) as response:
                    self.assertEqual(response.status, 202)
                with urlopen(signed_request(port, secret, payload, "event-1"), timeout=2) as response:
                    self.assertEqual(response.status, 202)
                rows = [json.loads(line) for line in events.read_text(encoding="utf-8").splitlines()]
                self.assertEqual(len(rows), 1)
                self.assertEqual(rows[0]["event_id"], "event-1")
            finally:
                server.terminate(); server.wait(timeout=3)

    def test_rejects_bad_signature_and_stale_timestamp(self):
        port = 18091
        secret = "local-only-secret"
        with tempfile.TemporaryDirectory() as tmp:
            env = {**os.environ, "CONTINUOUS_WEBHOOK_SECRET": secret, "CONTINUOUS_EVENTS_PATH": str(Path(tmp) / "events.jsonl"), "WEBHOOK_PORT": str(port)}
            server = subprocess.Popen([sys.executable, str(SERVER)], env=env)
            try:
                time.sleep(0.15)
                payload = {"status": "firing", "alerts": []}
                bad = signed_request(port, "wrong-secret", payload, "bad")
                with self.assertRaises(HTTPError) as error:
                    urlopen(bad, timeout=2)
                self.assertEqual(error.exception.code, 401)
                stale = signed_request(port, secret, payload, "stale", int(time.time()) - 3600)
                with self.assertRaises(HTTPError) as error:
                    urlopen(stale, timeout=2)
                self.assertEqual(error.exception.code, 401)
            finally:
                server.terminate(); server.wait(timeout=3)


if __name__ == "__main__":
    unittest.main()
