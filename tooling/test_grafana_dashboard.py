import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DASHBOARD = ROOT / "backend/ops/grafana/redis-stream-circuit-breaker.json"


def test_dashboard_is_importable_and_has_expected_panels():
    dashboard = json.loads(DASHBOARD.read_text(encoding="utf-8"))
    assert dashboard["uid"] == "smart-accountant-redis-circuit"
    assert dashboard["refresh"] == "15s"
    assert dashboard["templating"]["list"][0]["type"] == "datasource"
    titles = {panel["title"] for panel in dashboard["panels"]}
    assert {"Circuit state", "Stream queue depth", "Dead-letter rate", "Collector memory utilization", "Collector exporter queue size", "Collector refused and dropped telemetry", "Tail sampling decisions", "Collector exporter error rate", "Collector queue utilization"} <= titles


def test_queries_use_prometheus_metrics_without_high_cardinality_labels():
    dashboard = json.loads(DASHBOARD.read_text(encoding="utf-8"))
    serialized = json.dumps(dashboard)
    assert "event_id" not in serialized
    assert "user_id" not in serialized
    expressions = [target["expr"] for panel in dashboard["panels"] for target in panel.get("targets", [])]
    assert any("circuit_breaker_state" in expression for expression in expressions)
    assert any("security_webhook_queue_depth" in expression for expression in expressions)
    assert any("histogram_quantile" in expression for expression in expressions)
    assert any("otelcol_process_memory_rss_bytes" in expression for expression in expressions)
    assert any("otelcol_exporter_queue_size" in expression for expression in expressions)
    assert any("otelcol_processor_tail_sampling_global_count_traces_sampled" in expression for expression in expressions)
