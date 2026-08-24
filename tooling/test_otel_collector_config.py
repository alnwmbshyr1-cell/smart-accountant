from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "backend/ops/observability/otel-collector-production.yml"


def test_collector_has_bounded_pipeline_and_tail_sampling_policies():
    data = yaml.safe_load(CONFIG.read_text(encoding="utf-8"))
    pipeline = data["service"]["pipelines"]["traces"]
    processors = pipeline["processors"]
    assert processors[0] == "memory_limiter"
    assert "tail_sampling" in processors
    assert "batch" == processors[-1]
    sampling = data["processors"]["tail_sampling"]
    assert sampling["decision_wait"] == "10s"
    assert sampling["num_traces"] == 50000
    names = {policy["name"] for policy in sampling["policies"]}
    assert {"errors", "slow-or-critical-latency", "chaos-experiment", "circuit-open", "baseline"} <= names


def test_collector_redacts_sensitive_attributes_and_does_not_export_debug():
    source = CONFIG.read_text(encoding="utf-8")
    assert "http.request.header.authorization" in source
    assert "http.request.header.cookie" in source
    assert "db.connection_string" in source
    assert "REDACTED" in source
    assert "exporters: [otlphttp/jaeger]" in source
    assert "exporters: [debug]" not in source


def test_collector_limits_ingress_and_exporter_retry():
    data = yaml.safe_load(CONFIG.read_text(encoding="utf-8"))
    assert data["receivers"]["otlp"]["protocols"]["grpc"]["max_recv_msg_size_mib"] == 4
    retry = data["exporters"]["otlphttp/jaeger"]["retry_on_failure"]
    assert retry["enabled"] is True
    assert retry["max_elapsed_time"] == "30s"
