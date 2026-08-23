import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = (ROOT / ".github/workflows/payment-idempotency-stress.yml").read_text(encoding="utf-8")
DB_POLICY = (ROOT / "docs/payment-transient-db-errors.md").read_text(encoding="utf-8")


class PaymentCiAndDatabasePolicyTests(unittest.TestCase):
    def test_ci_is_manual_and_staging_only(self):
        self.assertIn("workflow_dispatch", WORKFLOW)
        self.assertIn("environment: staging-security-test", WORKFLOW)
        self.assertIn("PAYMENT_URL must use HTTPS", WORKFLOW)
        self.assertIn("Production payment targets are forbidden", WORKFLOW)
        self.assertIn("retention-days: 7", WORKFLOW)

    def test_ci_has_smoke_and_medium_profiles(self):
        self.assertIn("default: smoke", WORKFLOW)
        self.assertIn("- medium", WORKFLOW)
        self.assertIn("--vus 2", WORKFLOW)
        self.assertIn("--duration 20s", WORKFLOW)
        self.assertIn("tooling/payment_idempotency_stress_test.js", WORKFLOW)

    def test_db_policy_protects_financial_side_effects(self):
        self.assertIn("40P01", DB_POLICY)
        self.assertIn("40001", DB_POLICY)
        self.assertIn("1213", DB_POLICY)
        self.assertIn("1205", DB_POLICY)
        self.assertIn("قيداً فريداً", DB_POLICY)
        self.assertIn("بعد commit فقط", DB_POLICY)
        self.assertIn("لا تعِد المحاولة مع أخطاء التحقق", DB_POLICY)


if __name__ == "__main__":
    unittest.main()
