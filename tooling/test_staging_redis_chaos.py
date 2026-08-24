from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tooling/staging_redis_chaos.py"
WORKFLOW = ROOT / ".github/workflows/staging-redis-chaos.yml"


def test_chaos_runner_has_explicit_safety_and_restore_guards():
    source = SCRIPT.read_text(encoding="utf-8")
    assert "staging" in source
    assert "--confirm-staging-chaos" in source
    assert "--execute" in source
    assert "fault_seconds < 5" in source
    assert "fault_seconds > 300" in source
    assert "finally:" in source
    assert "--replicas={original}" in source
    assert "recovery_timeout" in source


def test_chaos_workflow_requires_manual_confirmation_and_protected_environment():
    source = WORKFLOW.read_text(encoding="utf-8")
    assert "workflow_dispatch" in source
    assert "confirm_chaos" in source
    assert "environment: staging-chaos" in source
    assert "STAGING_KUBECONFIG_B64" in source
    assert "if: ${{ inputs.confirm_chaos == true }}" in source
    assert "Upload chaos evidence" in source
    assert "if: always()" in source
