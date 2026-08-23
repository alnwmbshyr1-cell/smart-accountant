import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import detect_security_regressions as regression


class SecurityRegressionTests(unittest.TestCase):
    def finding(self, severity="high", test_id="T1", asset="/notify"):
        return {"severity": severity, "test_id": test_id, "asset": asset}

    def test_detects_new_finding_as_regression(self):
        result = regression.compare(
            {"findings": [self.finding()]},
            {"findings": []},
        )
        self.assertEqual(result["status"], "REGRESSION")
        self.assertEqual(result["regression_count"], 1)
        self.assertEqual(result["critical_or_high_regressions"], 1)

    def test_detects_severity_increase_and_decrease(self):
        current = {"findings": [self.finding("critical"), self.finding("low", "T2")]}
        previous = {"findings": [self.finding("high"), self.finding("medium", "T2")]}
        result = regression.compare(current, previous)
        self.assertEqual(len(result["severity_increased"]), 1)
        self.assertEqual(len(result["severity_decreased"]), 1)

    def test_detects_closed_and_persistent_finding(self):
        current = {"findings": [self.finding("high", "T1")]}
        previous = {"findings": [self.finding("high", "T1"), self.finding("low", "T2")]}
        result = regression.compare(current, previous)
        self.assertEqual(len(result["persistent"]), 1)
        self.assertEqual(len(result["closed"]), 1)
        self.assertEqual(result["status"], "NO_REGRESSION")

    def test_fingerprint_changes_when_asset_changes(self):
        a = regression.fingerprint(self.finding(asset="/a"))
        b = regression.fingerprint(self.finding(asset="/b"))
        self.assertNotEqual(a, b)

    def test_markdown_is_sanitized_and_actionable(self):
        result = regression.compare(
            {"findings": [self.finding("critical", "Bearer secret-token")]},
            {"findings": []},
        )
        output = regression.markdown(result)
        self.assertIn("REGRESSION", output)
        self.assertNotIn("secret-token", output)


if __name__ == "__main__":
    unittest.main()
