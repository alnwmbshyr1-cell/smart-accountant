import hashlib
import hmac
import json
import os
import sys
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend/ops"))
os.environ.setdefault("GITHUB_WEBHOOK_SECRET", "test-secret")
os.environ.setdefault("REQUIRED_CHECKS", "Prometheus to Alertmanager integration,Quality gate")
os.environ.setdefault("PROTECTED_BRANCH", "main")
import github_required_checks_webhook as webhook


def payload(conclusion="failure", branch="main"):
    return {
        "repository": {"full_name": "org/repo"},
        "check_run": {
            "name": "Prometheus to Alertmanager integration",
            "status": "completed",
            "conclusion": conclusion,
            "head_sha": "abcdef1234567890",
            "html_url": "https://github.com/org/repo/runs/1",
            "check_suite": {"head_branch": branch},
        },
    }


def test_verify_signature_requires_exact_hmac_and_rejects_wrong_value():
    raw = b'{"ok":true}'
    signature = "sha256=" + hmac.new(b"test-secret", raw, hashlib.sha256).hexdigest()
    assert webhook.verify_signature(raw, signature)
    assert not webhook.verify_signature(raw, "sha256=" + "0" * 64)
    assert not webhook.verify_signature(raw, "")


def test_extract_failure_only_accepts_completed_required_failures():
    assert webhook.extract_failure(payload(), "check_run")["name"] == "Prometheus to Alertmanager integration"
    assert webhook.extract_failure(payload("success"), "check_run") is None
    assert webhook.extract_failure(payload(branch="release"), "check_run")["conclusion"] == "failure"
    assert webhook.extract_failure({"workflow_run": {"name": "Quality gate", "status": "completed", "conclusion": "failure", "head_sha": "x", "html_url": "u"}}, "workflow_run")["name"] == "Quality gate"


def test_branch_filter_accepts_main_or_pull_request_base_only():
    assert webhook._branch_matches(payload())
    assert not webhook._branch_matches(payload(branch="release"))
    pr_payload = payload(branch="feature")
    pr_payload["check_run"]["pull_requests"] = [{"base": {"ref": "main"}}]
    assert webhook._branch_matches(pr_payload)


def test_claim_delivery_deduplicates_without_redis():
    webhook.SEEN_DELIVERIES.clear()
    assert webhook.claim_delivery("delivery-1", "hash")
    assert not webhook.claim_delivery("delivery-1", "hash")
    assert webhook.claim_delivery("", "hash")


def test_slack_payload_is_redacted_and_contains_operational_context():
    failure = {"name": "Quality gate", "conclusion": "failure", "sha": "abcdef123456", "url": "https://hooks.slack.com/services/secret"}
    result = webhook.build_slack_payload(failure, "org/repo", "delivery-2")
    rendered = json.dumps(result)
    assert "[redacted]" in rendered
    assert "secret" not in rendered
    assert "Quality gate" in rendered
    assert "main" in rendered


def test_post_to_slack_returns_false_without_secret_url():
    with patch.object(webhook, "SLACK_WEBHOOK_URL", ""):
        assert webhook.post_to_slack({"text": "x"}) is False
