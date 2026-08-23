import os
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import security_gateway_resilience_test as resilience


class ResilienceSafetyTests(unittest.TestCase):
    def setUp(self):
        self.env = patch.dict(os.environ, {
            "PENTEST_ENV": "lab",
            "RESILIENCE_TEST_AUTHORIZED": "true",
        })
        self.env.start()

    def tearDown(self):
        self.env.stop()

    def test_rejects_unauthorized_or_production_scope(self):
        with patch.dict(os.environ, {"RESILIENCE_TEST_AUTHORIZED": "false"}):
            with self.assertRaises(ValueError):
                resilience.validate_scope("http://127.0.0.1:8080/healthz", "lab", False, 10, 5)
        with self.assertRaises(ValueError):
            resilience.validate_scope("https://production.example/healthz", "production", True, 10, 5)

    def test_enforces_bounded_requests_and_rate(self):
        with self.assertRaises(ValueError):
            resilience.validate_scope("http://127.0.0.1:8080/healthz", "lab", True, 101, 5)
        with self.assertRaises(ValueError):
            resilience.validate_scope("http://127.0.0.1:8080/healthz", "lab", True, 10, 21)

    def test_allows_https_staging_and_loopback_lab(self):
        resilience.validate_scope("https://staging.example/healthz", "staging", True, 40, 10)
        resilience.validate_scope("http://127.0.0.1:8080/healthz", "lab", True, 40, 10)

    @patch("security_gateway_resilience_test.urllib.request.urlopen")
    @patch("security_gateway_resilience_test.time.sleep")
    def test_classifies_429_without_retry_storm(self, sleep, urlopen):
        class Response:
            status = 429
            def __enter__(self): return self
            def __exit__(self, *_): return False
        urlopen.side_effect = [resilience.urllib.error.HTTPError("x", 429, "rate limited", {}, None)] * 2
        result = resilience.run_bounded_check("http://127.0.0.1:8080/healthz", "", 2, 20, 1)
        self.assertEqual(result.statuses.get("429"), 2)
        self.assertEqual(sleep.call_count, 1)

    def test_result_serializes_timeout_bucket(self):
        result = resilience.Result("http://127.0.0.1:8080/healthz", 1, 0.1, {"timeout_or_network_error": 1}, False, 1.0)
        self.assertIn("timeout_or_network_error", result.statuses)


if __name__ == "__main__":
    unittest.main()
