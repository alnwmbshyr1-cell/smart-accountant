import json
import tempfile
import unittest
from pathlib import Path

from sarif_pr_summary import main, MARKER


class SarifPrSummaryTests(unittest.TestCase):
    def test_summary_is_marked_and_contains_safe_locations(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            sarif = root / "semgrep.sarif"
            output = root / "summary.md"
            sarif.write_text(json.dumps({
                "runs": [{"tool": {"driver": {"name": "Semgrep"}}, "results": [{
                    "level": "error", "ruleId": "webhook.secret",
                    "locations": [{"physicalLocation": {"artifactLocation": {"uri": "backend/webhook.py"}, "region": {"startLine": 42}}}]
                }]}]
            }), encoding="utf-8")
            self.assertEqual(main(str(output), str(sarif)), 0)
            content = output.read_text(encoding="utf-8")
            self.assertIn(MARKER, content)
            self.assertIn("webhook.secret", content)
            self.assertIn("backend/webhook.py", content)
            self.assertNotIn("Authorization", content)

    def test_missing_reports_produce_empty_summary(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "summary.md"
            self.assertEqual(main(str(output), "/not-present/semgrep.sarif"), 0)
            self.assertIn("No findings reported", output.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
