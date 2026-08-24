import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = (ROOT / ".github/workflows/local-alert-lab-pr.yml").read_text(encoding="utf-8")


class LocalAlertLabWorkflowTests(unittest.TestCase):
    def test_runs_on_pull_request_and_manual_dispatch(self):
        self.assertIn("pull_request:", WORKFLOW)
        self.assertIn("workflow_dispatch:", WORKFLOW)
        self.assertIn("permissions:\n  contents: read", WORKFLOW)

    def test_runtime_job_depends_on_static_validation(self):
        self.assertIn("static-validation:", WORKFLOW)
        self.assertIn("runtime-validation:", WORKFLOW)
        self.assertIn("needs: static-validation", WORKFLOW)
        self.assertIn("docker compose -f backend/ops/alert-lab/docker-compose.yml up -d", WORKFLOW)

    def test_firing_resolved_and_redaction_checks_exist(self):
        self.assertIn("Trigger synthetic firing state", WORKFLOW)
        self.assertIn("Assert firing alert reached local receiver", WORKFLOW)
        self.assertIn('"status": "firing"', WORKFLOW)
        self.assertIn("Trigger resolved state", WORKFLOW)
        self.assertIn('"status": "resolved"', WORKFLOW)
        self.assertIn("! grep -Eiq", WORKFLOW)

    def test_cleanup_and_failure_diagnostics_are_always_available(self):
        self.assertIn("if: failure()", WORKFLOW)
        self.assertIn("actions/upload-artifact@v4", WORKFLOW)
        self.assertIn("if: always()", WORKFLOW)
        self.assertIn("docker compose -f backend/ops/alert-lab/docker-compose.yml down -v", WORKFLOW)


if __name__ == "__main__":
    unittest.main()
