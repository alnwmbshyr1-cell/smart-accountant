import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
RECEIVER = ROOT / "backend/ops/alert-lab/webhook_receiver.py"
VALIDATOR = ROOT / "tooling/validate_slack_alert_events.py"


class SlackNotificationIntegrationTests(unittest.TestCase):
    def test_receiver_accepts_firing_and_resolved_and_validator_passes(self):
        with tempfile.TemporaryDirectory() as tmp:
            events = Path(tmp) / "events.jsonl"
            env = {**os.environ, "ALERT_LAB_EVENTS_PATH": str(events)}
            server = subprocess.Popen([sys.executable, str(RECEIVER)], env=env)
            try:
                time.sleep(0.15)
                payloads = [
                    {"status": "firing", "groupKey": "alertname=SmartAccountantK6P95,testid=act-1", "alerts": [{"labels": {"testid": "act-1"}}], "commonAnnotations": {"summary": "p95 high"}},
                    {"status": "resolved", "groupKey": "alertname=SmartAccountantK6P95,testid=act-1", "alerts": [{"labels": {"testid": "act-1"}}], "commonAnnotations": {"summary": "p95 recovered"}},
                ]
                for payload in payloads:
                    request = Request("http://127.0.0.1:8080/", data=json.dumps(payload).encode(), headers={"Content-Type": "application/json"}, method="POST")
                    with urlopen(request, timeout=2) as response:
                        self.assertEqual(response.status, 200)
                report = subprocess.run([sys.executable, str(VALIDATOR), str(events), "act-1"], capture_output=True, text=True, check=True)
                self.assertIn('"result": "pass"', report.stdout)
            finally:
                server.terminate()
                server.wait(timeout=3)

    def test_validator_rejects_duplicate_status_and_fingerprint(self):
        with tempfile.TemporaryDirectory() as tmp:
            events = Path(tmp) / "duplicates.jsonl"
            firing = {"status": "firing", "groupKey": "g", "commonAnnotations": {"summary": "safe"}}
            resolved = {"status": "resolved", "groupKey": "g", "commonAnnotations": {"summary": "safe"}}
            events.write_text(
                json.dumps(firing) + "\n" + json.dumps(resolved) + "\n" + json.dumps(firing) + "\n",
                encoding="utf-8",
            )
            result = subprocess.run([sys.executable, str(VALIDATOR), str(events)], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("duplicate", result.stderr + result.stdout)


if __name__ == "__main__":
    unittest.main()
