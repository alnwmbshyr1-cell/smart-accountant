#!/usr/bin/env python3
import json
import os
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).parent))
import notify_security


class NotifySecurityTests(unittest.TestCase):
    def test_no_critical_sends_nothing(self):
        report = {"summary": {}, "findings": [{"severity": "high", "source": "trivy"}]}
        with patch.object(notify_security, "post_json") as post:
            result = notify_security.notify(report, "https://example.test/run", {})
        self.assertEqual(result, [])
        post.assert_not_called()

    def test_critical_summary_is_bounded_and_does_not_include_secret_message(self):
        secret = "Bearer live-secret-token"
        report = {
            "summary": {},
            "findings": [
                {
                    "severity": "critical",
                    "source": "snyk",
                    "rule_id": "SNYK-JS-1",
                    "file": "backend/package.json",
                    "line": 7,
                    "message": secret,
                }
            ],
        }
        payloads = []
        with patch.object(notify_security, "post_json", side_effect=lambda url, payload, **kwargs: payloads.append(payload)):
            result = notify_security.notify(
                report,
                "https://github.com/org/repo/actions/runs/123",
                {"SECURITY_SLACK_WEBHOOK_URL": "https://hooks.slack.test"},
            )
        self.assertEqual([item.channel for item in result], ["slack"])
        body = json.dumps(payloads, ensure_ascii=False)
        self.assertIn("SNYK-JS-1", body)
        self.assertNotIn(secret, body)
        self.assertNotIn("message", body)

    def test_email_uses_bearer_token_without_putting_it_in_payload(self):
        captured = {}
        with patch.object(notify_security, "post_json", side_effect=lambda url, payload, **kwargs: captured.update({"url": url, "payload": payload, "headers": kwargs.get("headers")})):
            result = notify_security.notify(
                {"summary": {}, "findings": [{"severity": "critical", "source": "trivy"}]},
                "run-url",
                {
                    "SECURITY_EMAIL_WEBHOOK_URL": "https://mail-gateway.test/send",
                    "SECURITY_EMAIL_WEBHOOK_TOKEN": "email-secret",
                },
            )
        self.assertEqual([item.channel for item in result], ["email"])
        self.assertEqual(captured["headers"]["Authorization"], "Bearer email-secret")
        self.assertNotIn("email-secret", json.dumps(captured["payload"]))

    def test_failed_configured_channel_is_reported(self):
        with patch.object(notify_security, "send_slack", side_effect=OSError("network")):
            result = notify_security.notify(
                {"summary": {}, "findings": [{"severity": "critical", "source": "trivy"}]},
                "run-url",
                {"SECURITY_SLACK_WEBHOOK_URL": "https://hooks.slack.test"},
            )
        self.assertEqual(len(result), 1)
        self.assertFalse(result[0].sent)
        self.assertEqual(result[0].error, "OSError")


if __name__ == "__main__":
    unittest.main()
