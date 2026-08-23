import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = (ROOT / "tooling/security_gateway_stress_test.js").read_text(encoding="utf-8")
WORKFLOW = (ROOT / ".github/workflows/security-gateway-stress-test.yml").read_text(encoding="utf-8")


class MediumStressSafetyTests(unittest.TestCase):
    def test_script_uses_bounded_medium_ramp_and_thresholds(self):
        self.assertIn("ramping-arrival-rate", SCRIPT)
        self.assertIn("target: 100", SCRIPT)
        self.assertIn("maxVUs: 100", SCRIPT)
        self.assertIn("p(95)<750", SCRIPT)
        self.assertIn("p(99)<1500", SCRIPT)
        self.assertIn("http_req_failed", SCRIPT)

    def test_script_is_read_only_and_bounded(self):
        self.assertIn("http.get", SCRIPT)
        self.assertNotIn("http.post", SCRIPT)
        self.assertIn("timeout: '3s'", SCRIPT)
        self.assertIn("response is bounded", SCRIPT)

    def test_workflow_requires_https_and_protected_environment(self):
        self.assertIn("environment: staging-security-test", WORKFLOW)
        self.assertIn("STRESS_TEST_URL must use HTTPS", WORKFLOW)
        self.assertIn("workflow_dispatch", WORKFLOW)
        self.assertIn("retention-days: 7", WORKFLOW)


if __name__ == "__main__":
    unittest.main()
