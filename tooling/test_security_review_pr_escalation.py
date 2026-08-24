import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = (ROOT / ".github/pull_request_template.md").read_text(encoding="utf-8")
OWNERS = (ROOT / ".github/CODEOWNERS").read_text(encoding="utf-8")
WORKFLOW = (ROOT / ".github/workflows/security-review-on-quality-failure.yml").read_text(encoding="utf-8")
DOC = (ROOT / "docs/security-review-pr-template.md").read_text(encoding="utf-8")


class SecurityReviewPREscalationTests(unittest.TestCase):
    def test_template_mentions_required_checks_and_security_review(self):
        for value in ["Quality gate", "SAST and dependency security", "Code Scanning", "مراجعة الأمن"]:
            self.assertIn(value, TEMPLATE)

    def test_codeowners_covers_sensitive_paths(self):
        for value in ["/.github/workflows/", "/backend/", "/tooling/", "/supabase/"]:
            self.assertIn(value, OWNERS)

    def test_workflow_waits_for_completed_ci_and_is_fork_safe(self):
        self.assertIn("workflow_run:", WORKFLOW)
        self.assertIn('workflows: ["Smart Accountant CI/CD"]', WORKFLOW)
        self.assertIn("const sameRepo =", WORKFLOW)
        self.assertIn("same_repo == 'true'", WORKFLOW)
        self.assertIn("same_repo != 'true'", WORKFLOW)
        self.assertNotIn("pull_request_target", WORKFLOW)

    def test_workflow_uses_deduplicated_marker_and_configured_reviewer(self):
        self.assertIn("smart-accountant-security-review-required", WORKFLOW)
        self.assertIn("SECURITY_TEAM_SLUG", WORKFLOW)
        self.assertIn("SECURITY_REVIEWER", WORKFLOW)
        self.assertIn("pulls.requestReviewers", WORKFLOW)
        self.assertIn("security-review-required", WORKFLOW)

    def test_documentation_preserves_branch_protection_as_final_gate(self):
        self.assertIn("branch protection", DOC)
        self.assertIn("لا يعيد إنشاء التعليق", DOC)
        self.assertIn("لا يكتب على PR من fork", DOC)


if __name__ == "__main__":
    unittest.main()
