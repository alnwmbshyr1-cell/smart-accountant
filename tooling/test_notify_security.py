#!/usr/bin/env python3
import json
import os
import sys
import urllib.error
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).parent))
import notify_security
import security_gateway


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

    def test_post_json_retries_429_using_retry_after_then_succeeds(self):
        class Response:
            status = 204
            def __enter__(self):
                return self
            def __exit__(self, *_args):
                return False

        rate_limited = urllib.error.HTTPError(
            "https://hooks.test", 429, "rate limited", {"Retry-After": "0"}, None
        )
        sleeps = []
        with patch.object(notify_security.urllib.request, "urlopen", side_effect=[rate_limited, Response()]) as urlopen:
            notify_security.post_json(
                "https://hooks.test",
                {"ok": True},
                attempts=3,
                sleep_fn=sleeps.append,
            )
        self.assertEqual(urlopen.call_count, 2)
        self.assertEqual(sleeps, [0.0])

    def test_post_json_retries_503_three_times_then_raises(self):
        errors = [
            urllib.error.HTTPError("https://hooks.test", 503, "unavailable", {}, None)
            for _ in range(3)
        ]
        sleeps = []
        with patch.object(notify_security.urllib.request, "urlopen", side_effect=errors) as urlopen:
            with self.assertRaises(urllib.error.HTTPError):
                notify_security.post_json(
                    "https://hooks.test",
                    {"ok": True},
                    attempts=3,
                    sleep_fn=sleeps.append,
                )
        self.assertEqual(urlopen.call_count, 3)
        self.assertEqual(sleeps, [1.0, 2.0])

    def test_idempotency_key_is_stable_for_same_run_and_changes_by_channel(self):
        report = {"summary": {}, "findings": [{"severity": "critical", "source": "trivy", "rule_id": "CVE-1", "file": "a", "line": 1}]}
        context = {"GITHUB_REPOSITORY": "org/repo", "GITHUB_WORKFLOW": "security", "GITHUB_SHA": "abc"}
        first = notify_security.make_idempotency_key(report, "slack", context)
        second = notify_security.make_idempotency_key(report, "slack", context)
        other_channel = notify_security.make_idempotency_key(report, "email", context)
        other_commit = notify_security.make_idempotency_key(report, "slack", {**context, "GITHUB_SHA": "def"})
        self.assertEqual(first, second)
        self.assertNotEqual(first, other_channel)
        self.assertNotEqual(first, other_commit)
        self.assertTrue(first.startswith("sa-"))

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

    def test_redis_claim_accepts_first_key_and_rejects_duplicate(self):
        class FakeRedis:
            def __init__(self):
                self.values = {}
            def set(self, name, value, *, nx, ex):
                if nx and name in self.values:
                    return False
                self.values[name] = value
                return True
            def get(self, name):
                return self.values.get(name)
            def delete(self, name):
                return int(self.values.pop(name, None) is not None)
            def expire(self, name, time):
                return name in self.values

        redis = FakeRedis()
        self.assertTrue(security_gateway.claim(redis, "sa-" + "a" * 32, "owner-1", 86400))
        self.assertFalse(security_gateway.claim(redis, "sa-" + "a" * 32, "owner-2", 86400))

    def test_redis_release_only_removes_key_for_same_owner(self):
        class FakeRedis:
            def __init__(self):
                self.values = {}
            def set(self, name, value, *, nx, ex):
                if nx and name in self.values:
                    return False
                self.values[name] = value
                return True
            def get(self, name):
                return self.values.get(name)
            def delete(self, name):
                return int(self.values.pop(name, None) is not None)
            def expire(self, name, time):
                return name in self.values

        redis = FakeRedis()
        key = "sa-" + "b" * 32
        security_gateway.claim(redis, key, "owner-1", 86400)
        security_gateway.release_if_owner(redis, key, "owner-2")
        self.assertEqual(redis.get("security-alert:" + key), "owner-1")
        security_gateway.release_if_owner(redis, key, "owner-1")
        self.assertIsNone(redis.get("security-alert:" + key))

    def test_gateway_payload_requires_matching_header_and_bounded_key(self):
        payload = {
            "event": "critical_security_findings",
            "idempotency_key": "sa-" + "c" * 32,
            "total_critical": 1,
            "findings": [],
        }
        validated = security_gateway.validate_payload(payload, payload["idempotency_key"])
        self.assertEqual(validated["idempotency_key"], payload["idempotency_key"])
        with self.assertRaises(ValueError):
            security_gateway.validate_payload(payload, "sa-" + "d" * 32)

    def test_partial_gateway_mtls_configuration_is_rejected(self):
        with self.assertRaises(ValueError):
            notify_security.gateway_ssl_context({"SECURITY_GATEWAY_CA_FILE": "/tmp/ca.pem"})

    def test_webhook_sends_idempotency_header_and_payload_field(self):
        captured = {}
        with patch.object(notify_security, "post_json", side_effect=lambda url, payload, **kwargs: captured.update({"payload": payload, "headers": kwargs.get("headers")})):
            notify_security.send_webhook(
                "https://ops.test",
                {"idempotency_key": "sa-123", "total_critical": 1, "findings": [], "workflow_url": ""},
            )
        self.assertEqual(captured["headers"]["Idempotency-Key"], "sa-123")
        self.assertEqual(captured["payload"]["idempotency_key"], "sa-123")


if __name__ == "__main__":
    unittest.main()
