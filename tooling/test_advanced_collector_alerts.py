from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
RULES = ROOT / "backend/ops/prometheus/collector-alerts.yml"
ALERTMANAGER = ROOT / "backend/ops/alertmanager/alertmanager.yml"


def test_collector_alerts_cover_resource_and_delivery_failures():
    data = yaml.safe_load(RULES.read_text(encoding="utf-8"))
    rules = data["groups"][0]["rules"]
    names = {rule["alert"] for rule in rules}
    assert {"OTelCollectorMemoryPressure", "OTelCollectorMemoryCritical", "OTelCollectorExporterQueueSaturation", "OTelCollectorRefusedSpans", "OTelCollectorExporterFailures", "OTelCollectorScrapeMissing", "OTelCollectorTailSamplingDropSpike"} <= names
    for rule in rules:
        assert rule["labels"]["category"] == "observability"
        assert "runbook" in rule["annotations"]
        assert "secret" not in rule["expr"].lower()


def test_alertmanager_routes_critical_collector_alerts_to_pagerduty_and_resolved_webhook():
    data = yaml.safe_load(ALERTMANAGER.read_text(encoding="utf-8"))
    routes = data["route"]["routes"]
    assert any(route["receiver"] == "smart-accountant-circuit-pagerduty" and any('category="observability"' in matcher for matcher in route["matchers"]) for route in routes)
    assert any(route["receiver"] == "smart-accountant-observability" for route in routes)
    receivers = {receiver["name"]: receiver for receiver in data["receivers"]}
    assert receivers["smart-accountant-observability"]["webhook_configs"][0]["send_resolved"] is True
    assert receivers["smart-accountant-circuit-pagerduty"]["pagerduty_configs"][0]["send_resolved"] is True


def test_alertmanager_inhibits_warning_when_critical_memory_alert_is_active():
    data = yaml.safe_load(ALERTMANAGER.read_text(encoding="utf-8"))
    inhibition = data["inhibit_rules"]
    assert any(
        any('OTelCollectorMemoryCritical' in matcher for matcher in rule["source_matchers"])
        and any('OTelCollectorMemoryPressure' in matcher for matcher in rule["target_matchers"])
        for rule in inhibition
    )
    source = ALERTMANAGER.read_text(encoding="utf-8")
    assert "routing_key_file:" in source
    assert "url_file:" in source
    assert "pagerduty.com" not in source
