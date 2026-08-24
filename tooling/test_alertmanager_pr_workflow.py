from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github/workflows/alertmanager-integration-pr.yml"


def test_workflow_runs_on_relevant_pull_request_changes():
    data = yaml.safe_load(WORKFLOW.read_text(encoding="utf-8"))
    trigger = data.get("on") or data.get(True)
    assert "pull_request" in trigger
    assert "paths" in trigger["pull_request"]
    assert any("alertmanager" in item for item in trigger["pull_request"]["paths"])
    assert any("prometheus" in item for item in trigger["pull_request"]["paths"])


def test_workflow_is_read_only_and_has_timeout_cleanup_and_artifacts():
    data = yaml.safe_load(WORKFLOW.read_text(encoding="utf-8"))
    job = data["jobs"]["alertmanager-integration"]
    assert job["timeout-minutes"] <= 15
    assert data["permissions"]["contents"] == "read"
    steps = job["steps"]
    text = WORKFLOW.read_text(encoding="utf-8")
    assert any("up -d" in step.get("run", "") for step in steps)
    assert any("down -v --remove-orphans" in step.get("run", "") for step in steps)
    assert any(step.get("if") == "always()" and "upload-artifact" in step.get("uses", "") for step in steps)
    assert "STAGING" not in text
    assert "PAGERDUTY" not in text.upper()
    assert "SLACK" not in text.upper()


def test_workflow_runs_harness_on_loopback_only():
    text = WORKFLOW.read_text(encoding="utf-8")
    assert "--receiver http://127.0.0.1:18080" in text
    assert "--prometheus http://127.0.0.1:9090" in text
    assert "integration_test_alertmanager.py" in text
