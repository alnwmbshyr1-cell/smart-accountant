import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = (ROOT / "tooling/payment_idempotency_stress_test.js").read_text(encoding="utf-8")


class PaymentIdempotencyStressTests(unittest.TestCase):
    def test_has_idempotency_and_bounded_retry_contract(self):
        self.assertIn("Idempotency-Key", SCRIPT)
        self.assertIn("MAX_RETRIES", SCRIPT)
        self.assertIn("Math.min(Number(__ENV.MAX_RETRIES || 2), 3)", SCRIPT)
        self.assertIn("timeout: '3s'", SCRIPT)
        self.assertIn("Math.pow(2, attempts - 1)", SCRIPT)

    def test_retries_only_transient_statuses(self):
        self.assertIn("response.status === 429", SCRIPT)
        self.assertIn("response.status >= 500", SCRIPT)
        self.assertIn("replay.status === 409", SCRIPT)
        self.assertNotIn("response.status === 401", SCRIPT)
        self.assertNotIn("response.status === 403", SCRIPT)

    def test_replay_requires_safe_outcome_or_same_payment_id(self):
        self.assertIn("idempotency_violation_rate", SCRIPT)
        self.assertIn("responsePaymentId", SCRIPT)
        self.assertIn("firstPaymentId === replayPaymentId", SCRIPT)
        self.assertIn("'replay has an idempotent outcome'", SCRIPT)
        self.assertIn("'accepted replay is identical to first result'", SCRIPT)


if __name__ == "__main__":
    unittest.main()
