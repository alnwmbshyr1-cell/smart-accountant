import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = (ROOT / ".github/workflows/payment-idempotency-stress.yml").read_text(encoding="utf-8")


class PaymentIdempotencyCiWorkflowTests(unittest.TestCase):
    def test_integration_precedes_load_job(self):
        self.assertIn("redis-integration:", WORKFLOW)
        self.assertIn("payment-load:", WORKFLOW)
        self.assertIn("needs: redis-integration", WORKFLOW)
        self.assertIn("if: github.event_name == 'workflow_dispatch'", WORKFLOW)

    def test_redis_service_is_pinned_and_healthy(self):
        self.assertIn("image: redis:7.4-alpine", WORKFLOW)
        self.assertIn("health-cmd \"redis-cli ping\"", WORKFLOW)
        self.assertIn("redis://127.0.0.1:6379/15", WORKFLOW)
        self.assertIn("python tooling/redis_idempotency_integration.py", WORKFLOW)

    def test_load_job_has_profiles_artifact_and_target_guard(self):
        self.assertIn("default: smoke", WORKFLOW)
        self.assertIn("- medium", WORKFLOW)
        self.assertIn("PAYMENT_URL must use HTTPS", WORKFLOW)
        self.assertIn("Production payment targets are forbidden", WORKFLOW)
        self.assertIn("--summary-export=payment-stress-results.json", WORKFLOW)
        self.assertIn("retention-days: 7", WORKFLOW)
        self.assertIn("MAX_RETRIES: '2'", WORKFLOW)


if __name__ == "__main__":
    unittest.main()
