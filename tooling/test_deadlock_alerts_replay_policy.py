import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RULES = (ROOT / "backend/ops/prometheus/smart-accountant-alerts.yml").read_text(encoding="utf-8")
ALERTMANAGER = (ROOT / "backend/ops/alertmanager/alertmanager.yml").read_text(encoding="utf-8")
POLICY = (ROOT / "docs/webhook-replay-protection.md").read_text(encoding="utf-8")


class DeadlockAlertsReplayPolicyTests(unittest.TestCase):
    def test_deadlock_and_staging_rules_exist_with_sustained_windows(self):
        self.assertIn("SmartAccountantDeadlockBurst", RULES)
        self.assertIn("increase(smart_accountant_db_deadlocks_total", RULES)
        self.assertIn("SmartAccountantDeadlockRateHigh", RULES)
        self.assertIn("SmartAccountantStagingPaymentTestFailed", RULES)
        self.assertIn("for: 1m", RULES)
        self.assertIn("for: 5m", RULES)
        self.assertIn('environment="staging"', RULES)

    def test_alertmanager_groups_and_uses_secret_file(self):
        self.assertIn("category]", ALERTMANAGER)
        self.assertIn("slack_api_url_file", ALERTMANAGER)
        self.assertIn('category="database"', ALERTMANAGER)
        self.assertIn('category="staging"', ALERTMANAGER)
        self.assertIn("send_resolved: true", ALERTMANAGER)

    def test_webhook_policy_covers_signature_timestamp_and_atomic_redis_claim(self):
        self.assertIn("HMAC-SHA256", POLICY)
        self.assertIn("constant-time", POLICY)
        self.assertIn("X-Webhook-Timestamp", POLICY)
        self.assertIn("X-Webhook-Id", POLICY)
        self.assertIn("SET key value NX EX ttl", POLICY)
        self.assertIn("request hash", POLICY)
        self.assertIn("409", POLICY)
        self.assertIn("لا تستخدم `KEYS` أو `MONITOR`", POLICY)


if __name__ == "__main__":
    unittest.main()
