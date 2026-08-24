import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ALERTMANAGER = ROOT / "backend/ops/alertmanager/alertmanager.yml"
WEBHOOK = ROOT / "backend/ops/continuous_alert_webhook.py"
DAILY = ROOT / ".github/workflows/daily-ci-security-report.yml"


class ContinuousMonitoringPolicyTests(unittest.TestCase):
    def test_alertmanager_routes_security_to_dedicated_webhook_and_resolved(self):
        text = ALERTMANAGER.read_text(encoding="utf-8")
        self.assertIn('category="security"', text)
        self.assertIn("smart-accountant-security-webhook", text)
        self.assertIn("security_webhook_url", text)
        self.assertIn("send_resolved: true", text)

    def test_receiver_has_hmac_timestamp_body_limit_and_dedupe(self):
        text = WEBHOOK.read_text(encoding="utf-8")
        for expected in ["hmac.new", "compare_digest", "MAX_SKEW", "Content-Length", "X-Webhook-Id", "SEEN"]:
            self.assertIn(expected, text)
        self.assertNotIn("slack.com", text)

    def test_daily_report_remains_separate_and_uses_read_permissions(self):
        text = DAILY.read_text(encoding="utf-8")
        self.assertIn("schedule:", text)
        self.assertIn("SECURITY_REPORT_SLACK_WEBHOOK", text)
        self.assertIn("actions: read", text)
        self.assertIn("security-events: read", text)


if __name__ == "__main__":
    unittest.main()
