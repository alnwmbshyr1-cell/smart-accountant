#!/usr/bin/env python3
import json
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).parent))
import notify_workflow_failure


class WorkflowFailureAlertTests(unittest.TestCase):
    def test_failure_key_is_stable_across_rerun_attempts(self):
        base = {
            "GITHUB_REPOSITORY": "org/repo",
            "GITHUB_WORKFLOW": "Weekly Security Gateway Report",
            "GITHUB_RUN_ID": "123",
            "GITHUB_JOB": "weekly-security-report",
            "GITHUB_RUN_ATTEMPT": "1",
        }
        rerun = {**base, "GITHUB_RUN_ATTEMPT": "2"}
        self.assertEqual(
            notify_workflow_failure.failure_key(base),
            notify_workflow_failure.failure_key(rerun),
        )

    def test_payload_is_bounded_and_contains_workflow_link(self):
        payload = notify_workflow_failure.build_payload({
            "GITHUB_REPOSITORY": "org/repo",
            "GITHUB_RUN_ID": "123",
            "WORKFLOW_URL": "https://github.com/org/repo/actions/runs/123",
        })
        self.assertEqual(payload["event"], "weekly_security_workflow_failed")
        self.assertTrue(payload["idempotency_key"].startswith("sa-failure-"))
        self.assertIn("actions/runs/123", payload["text"])
        self.assertNotIn("Authorization", json.dumps(payload))

    def test_k6_payload_has_safe_kind_and_bounded_summary(self):
        payload = notify_workflow_failure.build_payload({
            "GITHUB_REPOSITORY": "org/repo",
            "GITHUB_RUN_ID": "456",
            "SECURITY_FAILURE_KIND": "k6_load_test",
            "SECURITY_FAILURE_TITLE": "Smart Accountant load test failed",
            "SECURITY_FAILURE_SUMMARY": "Inspect thresholds and Redis saturation.",
        })
        self.assertEqual(payload["event"], "k6_load_test_failed")
        self.assertIn("load test failed", payload["text"])
        self.assertIn("Redis saturation", payload["text"])
        self.assertLessEqual(len(payload["text"]), 1000)

    def test_failure_payload_does_not_include_attempt_or_secret_material(self):
        payload = notify_workflow_failure.build_payload({
            "GITHUB_REPOSITORY": "org/repo",
            "GITHUB_RUN_ID": "456",
            "GITHUB_RUN_ATTEMPT": "7",
            "SECURITY_FAILURE_SUMMARY": "Bearer should-never-appear",
        })
        encoded = json.dumps(payload)
        self.assertNotIn("Bearer", encoded)
        self.assertNotIn("should-never-appear", encoded)
        self.assertNotIn("GITHUB_RUN_ATTEMPT", encoded)

    def test_send_failure_alert_passes_idempotency_header(self):
        captured = {}
        with patch.object(notify_workflow_failure, "post_json", side_effect=lambda url, payload, **kwargs: captured.update({"url": url, "payload": payload, "headers": kwargs["headers"]})):
            notify_workflow_failure.send_failure_alert(
                "https://hooks.test",
                {"GITHUB_REPOSITORY": "org/repo", "GITHUB_RUN_ID": "123"},
            )
        self.assertEqual(captured["headers"]["Idempotency-Key"], captured["payload"]["idempotency_key"])


if __name__ == "__main__":
    unittest.main()
