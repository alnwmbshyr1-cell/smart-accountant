import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = (ROOT / ".github/workflows/webhook-security-pr.yml").read_text(encoding="utf-8")
CHECKER = (ROOT / "tooling/check_zap_report.py").read_text(encoding="utf-8")
COMPOSE = (ROOT / "backend/ops/alert-lab/docker-compose.yml").read_text(encoding="utf-8")


class WebhookSecurityPrWorkflowTests(unittest.TestCase):
    def test_runs_on_pr_without_production_secrets(self):
        self.assertIn("pull_request:", WORKFLOW)
        self.assertIn("contents: read", WORKFLOW)
        self.assertNotIn("STAGING_PAYMENT_TOKEN", WORKFLOW)
        self.assertIn("workflow_dispatch:", WORKFLOW)

    def test_sast_has_semgrep_trivy_and_sarif_artifacts(self):
        self.assertIn("semgrep/semgrep-action@v1", WORKFLOW)
        self.assertIn("p/secrets", WORKFLOW)
        self.assertIn("aquasecurity/trivy-action@0.28.0", WORKFLOW)
        self.assertIn("format: sarif", WORKFLOW)
        self.assertIn("security-events: write", WORKFLOW)
        self.assertIn("actions/upload-artifact@v4", WORKFLOW)

    def test_dast_is_local_and_blocks_high_risk_zap_findings(self):
        self.assertIn("Safe local DAST", WORKFLOW)
        self.assertIn("http://127.0.0.1:8080/healthz", WORKFLOW)
        self.assertIn("ghcr.io/zaproxy/zaproxy:stable", WORKFLOW)
        self.assertIn("check_zap_report.py", WORKFLOW)
        self.assertIn("HIGH_RISK", CHECKER)
        self.assertIn("return 1 if blocking else 0", CHECKER)
        self.assertIn('"8080:8080"', COMPOSE)

    def test_cleanup_and_diagnostics_are_always_run(self):
        self.assertIn("if: always()", WORKFLOW)
        self.assertIn("Upload DAST artifacts", WORKFLOW)
        self.assertIn("docker compose -f backend/ops/alert-lab/docker-compose.yml down -v", WORKFLOW)
        self.assertIn("zap-report.json", WORKFLOW)


if __name__ == "__main__":
    unittest.main()
