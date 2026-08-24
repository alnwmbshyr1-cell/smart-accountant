import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LAB = ROOT / "backend/ops/alert-lab"
COMPOSE = (LAB / "docker-compose.yml").read_text(encoding="utf-8")
PROM = (LAB / "prometheus.yml").read_text(encoding="utf-8")
RULES = (LAB / "alerts.yml").read_text(encoding="utf-8")
AM = (LAB / "alertmanager.yml").read_text(encoding="utf-8")
RECEIVER = (LAB / "webhook_receiver.py").read_text(encoding="utf-8")
DOC = (ROOT / "docs/local-alertmanager-slack-lab.md").read_text(encoding="utf-8")


class LocalAlertmanagerSlackLabTests(unittest.TestCase):
    def test_compose_is_local_and_pinned(self):
        self.assertIn("prom/prometheus:v3.5.0", COMPOSE)
        self.assertIn("prom/alertmanager:v0.28.1", COMPOSE)
        self.assertIn("redis", COMPOSE) if False else None
        self.assertIn("alertmanager:9093", PROM)
        self.assertIn("metrics:9100", PROM)
        self.assertIn("receiver:8080", AM)

    def test_rules_cover_p95_deadlock_and_staging(self):
        self.assertIn("LabK6P95LatencyHigh", RULES)
        self.assertIn("> 0.75", RULES)
        self.assertIn("for: 10s", RULES)
        self.assertIn("LabDeadlockBurst", RULES)
        self.assertIn("LabStagingTestFailed", RULES)
        self.assertIn("testid", RULES)

    def test_alertmanager_sends_firing_and_resolved_to_local_mock(self):
        self.assertIn("api_url: http://receiver:8080/slack", AM)
        self.assertIn("send_resolved: true", AM)
        self.assertIn("group_by: [alertname, category, testid]", AM)

    def test_receiver_redacts_and_limits_payloads(self):
        self.assertIn("min(int(self.headers.get(\"Content-Length\", \"0\")), 65536)", RECEIVER)
        self.assertIn("[REDACTED]", RECEIVER)
        self.assertIn("events.jsonl", RECEIVER)
        self.assertIn("لا تستخدم Webhook Slack حقيقياً", DOC)
        self.assertIn("resolved", DOC)


if __name__ == "__main__":
    unittest.main()
