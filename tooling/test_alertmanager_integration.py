from pathlib import Path
import ast
import yaml

ROOT = Path(__file__).resolve().parents[1]
HARNESS = ROOT / "tooling/integration_test_alertmanager.py"
RECEIVER = ROOT / "tooling/synthetic_alert_receiver.py"
COMPOSE = ROOT / "backend/ops/observability/docker-compose.alertmanager-integration.yml"
AM = ROOT / "backend/ops/observability/alertmanager-synthetic.yml"


def test_harness_is_loopback_only_and_checks_both_states():
    source = HARNESS.read_text(encoding="utf-8")
    assert 'http://127.0.0.1:' in source
    assert '"firing"' in source
    assert '"resolved"' in source
    assert "/metrics-state" in source
    assert "/received" in source
    ast.parse(source)


def test_compose_is_local_and_has_the_three_services():
    data = yaml.safe_load(COMPOSE.read_text(encoding="utf-8"))
    assert set(data["services"]) == {"synthetic-receiver", "prometheus", "alertmanager"}
    assert "prom/prometheus" in data["services"]["prometheus"]["image"]
    assert "prom/alertmanager" in data["services"]["alertmanager"]["image"]
    assert "alerting" in data["networks"]
    assert "production" not in COMPOSE.read_text(encoding="utf-8").lower()


def test_synthetic_alertmanager_routes_resolved_and_uses_no_real_secrets():
    data = yaml.safe_load(AM.read_text(encoding="utf-8"))
    receivers = {item["name"]: item for item in data["receivers"]}
    assert receivers["synthetic-webhook"]["webhook_configs"][0]["send_resolved"] is True
    assert receivers["synthetic-pagerduty"]["webhook_configs"][0]["send_resolved"] is True
    assert all("127.0.0.1" not in str(item) for item in data["receivers"])
    assert "pagerduty.com" not in AM.read_text(encoding="utf-8")
    assert "routing_key" not in AM.read_text(encoding="utf-8")
