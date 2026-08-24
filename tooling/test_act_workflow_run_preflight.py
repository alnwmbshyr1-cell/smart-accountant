import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = (ROOT / ".github/workflows/security-review-on-quality-failure.yml").read_text(encoding="utf-8")
SCRIPT = (ROOT / "tooling/act_workflow_run_preflight.sh").read_text(encoding="utf-8")
EVENT_DIR = ROOT / ".github/act/events"


class ActWorkflowRunPreflightTests(unittest.TestCase):
    def test_local_runner_disables_writes_and_secrets(self):
        self.assertIn("ACT_LOCAL=true", SCRIPT)
        self.assertIn("--secret GITHUB_TOKEN=", SCRIPT)
        self.assertIn("--env GITHUB_TOKEN=", SCRIPT)
        self.assertIn("--env SECURITY_TEAM_SLUG=", SCRIPT)
        self.assertIn("env.ACT_LOCAL != 'true'", WORKFLOW)

    def test_workflow_handles_workflow_run_and_fork_without_writes(self):
        self.assertIn("workflow_run:", WORKFLOW)
        self.assertIn("same_repo != 'true'", WORKFLOW)
        self.assertIn("Fork PR detected; no reviewer request", WORKFLOW)
        self.assertNotIn("pull_request_target", WORKFLOW)

    def test_event_fixtures_are_valid_and_cover_required_paths(self):
        failed = json.loads((EVENT_DIR / "workflow_run-quality-failed.json").read_text())
        passed = json.loads((EVENT_DIR / "workflow_run-quality-passed.json").read_text())
        fork = json.loads((EVENT_DIR / "workflow_run-fork-failed.json").read_text())
        self.assertEqual(failed["workflow_run"]["conclusion"], "failure")
        self.assertEqual(passed["workflow_run"]["conclusion"], "success")
        self.assertNotEqual(
            fork["workflow_run"]["pull_requests"][0]["head"]["repo"]["full_name"],
            fork["repository"]["full_name"],
        )


if __name__ == "__main__":
    unittest.main()
