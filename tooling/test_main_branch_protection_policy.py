import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
POLICY = json.loads((ROOT / ".github/main-branch-protection.json").read_text(encoding="utf-8"))
SKILL = (Path("/home/ubuntu/skills/smart-accountant-backend-security/SKILL.md")).read_text(encoding="utf-8")


class MainBranchProtectionPolicyTests(unittest.TestCase):
    def test_required_security_and_quality_checks_are_present(self):
        contexts = POLICY["required_status_checks"]["contexts"]
        for context in [
            "SAST and dependency security",
            "Security scanning",
            "Quality gate",
            "Integration tests",
            "Full coverage",
            "Fast checks",
        ]:
            self.assertIn(context, contexts)
        self.assertTrue(POLICY["required_status_checks"]["strict"])

    def test_review_and_history_controls_are_enabled(self):
        reviews = POLICY["required_pull_request_reviews"]
        self.assertEqual(reviews["required_approving_review_count"], 1)
        self.assertTrue(reviews["require_code_owner_reviews"])
        self.assertTrue(reviews["dismiss_stale_reviews"])
        self.assertTrue(reviews["require_last_push_approval"])
        self.assertTrue(POLICY["required_linear_history"])
        self.assertTrue(POLICY["required_conversation_resolution"])

    def test_destructive_bypass_controls_are_disabled(self):
        self.assertTrue(POLICY["enforce_admins"])
        self.assertFalse(POLICY["allow_force_pushes"])
        self.assertFalse(POLICY["allow_deletions"])
        self.assertIn("SAST and dependency security", SKILL)
        self.assertIn("Protected production branch", SKILL)


if __name__ == "__main__":
    unittest.main()
