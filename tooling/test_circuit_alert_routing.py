from pathlib import Path

import pytest

yaml = pytest.importorskip("yaml")

ROOT = Path(__file__).resolve().parents[1]
ALERTMANAGER = ROOT / "backend/ops/alertmanager/alertmanager.yml"
RULES = ROOT / "backend/ops/alertmanager/circuit-breaker-rules.yml"


def test_circuit_open_rule_is_critical_and_security_routed():
    document = yaml.safe_load(RULES.read_text(encoding="utf-8"))
    rules = document["groups"][0]["rules"]
    open_rule = next(item for item in rules if item["alert"] == "CircuitBreakerOpen")
    assert 'circuit_breaker_state' in open_rule["expr"]
    assert open_rule["for"] == "2m"
    assert open_rule["labels"] == {
        "severity": "critical",
        "category": "security",
        "notification_class": "circuit_open",
    }


def test_alertmanager_has_immediate_pagerduty_and_webhook_routes():
    document = yaml.safe_load(ALERTMANAGER.read_text(encoding="utf-8"))
    routes = document["route"]["routes"]
    names = {route["receiver"] for route in routes if 'alertname="CircuitBreakerOpen"' in route["matchers"]}
    assert names == {"smart-accountant-circuit-pagerduty", "smart-accountant-circuit-webhook"}
    circuit_routes = [route for route in routes if 'alertname="CircuitBreakerOpen"' in route["matchers"]]
    for route in circuit_routes:
        assert route["group_wait"] == "0s"
        assert route["continue"] is True


def test_receivers_use_secret_files_and_resolved_notifications():
    receivers = {item["name"]: item for item in yaml.safe_load(ALERTMANAGER.read_text(encoding="utf-8"))["receivers"]}
    pager = receivers["smart-accountant-circuit-pagerduty"]["pagerduty_configs"][0]
    webhook = receivers["smart-accountant-circuit-webhook"]["webhook_configs"][0]
    assert pager["routing_key_file"].endswith("/pagerduty_routing_key")
    assert webhook["url_file"].endswith("/circuit_open_webhook_url")
    assert pager["send_resolved"] is True
    assert webhook["send_resolved"] is True
