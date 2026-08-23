import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = (ROOT / ".github/workflows/payment-idempotency-stress.yml").read_text(encoding="utf-8")
RULES = (ROOT / "backend/ops/prometheus/smart-accountant-alerts.yml").read_text(encoding="utf-8")
ALERTMANAGER = (ROOT / "backend/ops/alertmanager/alertmanager.yml").read_text(encoding="utf-8")


class K6LiveGrafanaAlertingTests(unittest.TestCase):
    def test_workflow_exports_remote_write_and_stable_testid(self):
        self.assertIn("STAGING_PROMETHEUS_REMOTE_WRITE_URL", WORKFLOW)
        self.assertIn("K6_PROMETHEUS_RW_SERVER_URL", WORKFLOW)
        self.assertIn("--out experimental-prometheus-rw", WORKFLOW)
        self.assertIn("--tag testid=\"$TEST_ID\"", WORKFLOW)
        self.assertIn("PROMETHEUS_RW_URL must use HTTPS", WORKFLOW)

    def test_p95_rule_is_per_run_and_has_sustained_window(self):
        self.assertIn("SmartAccountantK6P95LatencyHigh", RULES)
        self.assertIn("histogram_quantile(0.95", RULES)
        self.assertIn("sum by (testid, le)", RULES)
        self.assertIn("> 0.75", RULES)
        self.assertIn("for: 1m", RULES)
        self.assertIn('testid!=""', RULES)

    def test_alertmanager_routes_load_test_to_slack_with_recovery(self):
        self.assertIn('category="load_test"', ALERTMANAGER)
        self.assertIn("receiver: smart-accountant-slack", ALERTMANAGER)
        self.assertIn("group_by: [alertname, job, severity, category]", ALERTMANAGER)
        self.assertIn("send_resolved: true", ALERTMANAGER)
        self.assertIn("slack_api_url_file", ALERTMANAGER)


if __name__ == "__main__":
    unittest.main()
