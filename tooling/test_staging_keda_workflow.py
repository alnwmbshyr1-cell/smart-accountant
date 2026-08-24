from pathlib import Path

import pytest

yaml = pytest.importorskip("yaml")

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github/workflows/staging-keda-load.yml"


def test_workflow_runs_after_successful_staging_deploy_or_manually():
    workflow = yaml.safe_load(WORKFLOW.read_text(encoding="utf-8"))
    triggers = workflow.get("on", workflow.get(True))
    assert triggers is not None
    assert "workflow_dispatch" in triggers
    assert "workflow_run" in triggers
    assert triggers["workflow_run"]["types"] == ["completed"]
    assert workflow["jobs"]["staging-keda-load"]["environment"] == "staging"


def test_workflow_uses_secrets_and_collects_failure_artifacts():
    source = WORKFLOW.read_text(encoding="utf-8")
    assert "STAGING_KUBECONFIG_B64" in source
    assert "STAGING_REDIS_URL" in source
    assert "STAGING_TEST_WEBHOOK_SECRET" in source
    assert "actions/upload-artifact@v4" in source
    assert "if: failure()" in source
    assert "rollout status" in source
