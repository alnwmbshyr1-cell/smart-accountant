import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = (ROOT / "tooling/redis_idempotency_integration.py").read_text(encoding="utf-8")
WORKFLOW = (ROOT / ".github/workflows/redis-idempotency-integration.yml").read_text(encoding="utf-8")


class RedisIdempotencyIntegrationTests(unittest.TestCase):
    def test_script_uses_atomic_claim_and_fencing(self):
        self.assertIn("nx=True", SCRIPT)
        self.assertIn("ex=ttl", SCRIPT)
        self.assertIn("register_script", SCRIPT)
        self.assertIn("redis.call('INCR'", SCRIPT)
        self.assertIn("current ~= ARGV[1]", SCRIPT)
        self.assertIn("old_owner", SCRIPT)
        self.assertIn("financial_effects", SCRIPT)

    def test_script_covers_key_reuse_and_concurrent_claims(self):
        self.assertIn("ThreadPoolExecutor(max_workers=12)", SCRIPT)
        self.assertIn('outcomes.count("CLAIMED") == 1', SCRIPT)
        self.assertIn('outcomes.count("DUPLICATE") == 11', SCRIPT)
        self.assertIn('reuse == "KEY_REUSE"', SCRIPT)
        self.assertIn('request_hash({"amount": 2', SCRIPT)

    def test_ci_is_isolated_and_secret_free(self):
        self.assertIn("workflow_dispatch", WORKFLOW)
        self.assertIn("services:", WORKFLOW)
        self.assertIn("image: redis:7.4-alpine", WORKFLOW)
        self.assertIn("health-cmd \"redis-cli ping\"", WORKFLOW)
        self.assertIn("REDIS_URL: redis://127.0.0.1:6379/15", WORKFLOW)
        self.assertNotIn("PAYMENT_TOKEN", WORKFLOW)
        self.assertIn("python tooling/redis_idempotency_integration.py", WORKFLOW)


if __name__ == "__main__":
    unittest.main()
