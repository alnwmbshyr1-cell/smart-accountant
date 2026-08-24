from pathlib import Path
import ast

ROOT = Path(__file__).resolve().parents[1]
RECEIVER = ROOT / "tooling/synthetic_alert_receiver.py"
RUNNER = ROOT / "tooling/run_synthetic_notifications.py"


def test_receiver_is_local_only_and_supports_both_channels():
    source = RECEIVER.read_text(encoding="utf-8")
    assert "127.0.0.1" in source
    assert "/webhook" in source
    assert "/pagerduty/v2/enqueue" in source
    assert "compare_digest" in source
    ast.parse(source)


def test_runner_covers_firing_and_resolved_with_hmac():
    source = RUNNER.read_text(encoding="utf-8")
    assert 'for status in ("firing", "resolved")' in source
    assert "hmac.new" in source
    assert "X-Synthetic-Signature" in source
    assert 'http://127.0.0.1:' in source
    assert "pagerduty" in source
    ast.parse(source)


def test_synthetic_code_has_no_production_endpoints_or_secrets():
    receiver = RECEIVER.read_text(encoding="utf-8")
    runner = RUNNER.read_text(encoding="utf-8")
    combined = receiver + runner
    assert "pagerduty.com" not in combined
    assert "hooks.slack.com" not in combined
    assert "routing_key_file" not in combined
    assert "WEBHOOK_HMAC_CURRENT" not in combined
