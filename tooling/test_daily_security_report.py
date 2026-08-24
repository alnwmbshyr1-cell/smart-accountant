import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tooling/daily_security_report.py"


class DailySecurityReportTests(unittest.TestCase):
    def run_report(self, runs, alerts):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            runs_path = tmp_path / "runs.json"
            alerts_path = tmp_path / "alerts.json"
            out_dir = tmp_path / "out"
            runs_path.write_text(json.dumps(runs), encoding="utf-8")
            alerts_path.write_text(json.dumps(alerts), encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(SCRIPT), "--runs", str(runs_path), "--alerts", str(alerts_path), "--out-dir", str(out_dir), "--report-only"],
                capture_output=True,
                text=True,
                check=True,
            )
            return json.loads(result.stdout), (out_dir / "daily-security-report.md").read_text(encoding="utf-8")

    def test_failed_workflow_and_high_alert_make_report_fail(self):
        report, markdown = self.run_report(
            {"workflow_runs": [{"name": "Integration tests", "status": "completed", "conclusion": "failure", "head_branch": "main", "head_sha": "abc"}]},
            {"alerts": [{"rule": {"id": "CVE-TEST", "security_severity_level": "high"}, "state": "open", "tool": {"name": "Trivy"}}]},
        )
        self.assertEqual(report["status"], "FAIL")
        self.assertEqual(len(report["failed_workflows"]), 1)
        self.assertEqual(len(report["open_high_critical"]), 1)
        self.assertIn("Daily CI and Security Report", markdown)

    def test_clean_report_passes_and_has_stable_idempotency_key(self):
        payload = {"workflow_runs": [{"name": "Fast checks", "status": "completed", "conclusion": "success", "head_branch": "main", "head_sha": "abc"}]}
        report_a, _ = self.run_report(payload, {"alerts": []})
        report_b, _ = self.run_report(payload, {"alerts": []})
        self.assertEqual(report_a["status"], "PASS")
        self.assertEqual(report_a["idempotency_key"], report_b["idempotency_key"])

    def test_report_redacts_secret_like_values(self):
        _, markdown = self.run_report(
            {"workflow_runs": [{"name": "secret-token", "status": "completed", "conclusion": "success"}]},
            {"alerts": [{"rule": {"id": "webhook-secret", "security_severity_level": "low"}, "state": "open"}]},
        )
        self.assertNotIn("secret-token", markdown)
        self.assertNotIn("webhook-secret", markdown)
        self.assertIn("[REDACTED]", markdown)


if __name__ == "__main__":
    unittest.main()
