import json
from pathlib import Path

path = Path("backend/ops/grafana/redis-stream-circuit-breaker.json")
data = json.loads(path.read_text(encoding="utf-8"))
panels = data["panels"]
existing = {panel["id"] for panel in panels}
new_panels = [
    {
        "id": 30, "type": "timeseries", "title": "Collector memory utilization",
        "description": "Process RSS and configured memory limiter utilization.",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 40},
        "datasource": {"type": "prometheus", "uid": "${DS_PROMETHEUS}"},
        "targets": [
            {"expr": "max by (service_instance_id) (otelcol_process_memory_rss_bytes)", "legendFormat": "RSS {{service_instance_id}}", "refId": "A"},
            {"expr": "max by (service_instance_id) (otelcol_processor_memory_limiter_limit_mib) * 1024 * 1024", "legendFormat": "limit {{service_instance_id}}", "refId": "B"},
        ],
        "fieldConfig": {"defaults": {"unit": "bytes", "custom": {"lineWidth": 2, "fillOpacity": 12}}},
        "options": {"legend": {"displayMode": "table", "placement": "bottom"}},
    },
    {
        "id": 31, "type": "timeseries", "title": "Collector exporter queue size",
        "description": "Queued spans awaiting export; sustained growth indicates exporter pressure.",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 40},
        "datasource": {"type": "prometheus", "uid": "${DS_PROMETHEUS}"},
        "targets": [
            {"expr": "sum by (service_instance_id, exporter) (otelcol_exporter_queue_size)", "legendFormat": "{{exporter}} / {{service_instance_id}}", "refId": "A"},
            {"expr": "sum by (service_instance_id, exporter) (otelcol_exporter_queue_capacity)", "legendFormat": "capacity {{exporter}} / {{service_instance_id}}", "refId": "B"},
        ],
        "fieldConfig": {"defaults": {"unit": "short", "custom": {"lineWidth": 2, "fillOpacity": 12}}},
        "options": {"legend": {"displayMode": "table", "placement": "bottom"}},
    },
    {
        "id": 32, "type": "timeseries", "title": "Collector refused and dropped telemetry",
        "description": "Receiver refusals and processor/exporter drops.",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 48},
        "datasource": {"type": "prometheus", "uid": "${DS_PROMETHEUS}"},
        "targets": [
            {"expr": "sum by (receiver, transport) (rate(otelcol_receiver_refused_spans_total[5m]))", "legendFormat": "refused {{receiver}}/{{transport}}", "refId": "A"},
            {"expr": "sum by (processor) (rate(otelcol_processor_dropped_spans_total[5m]))", "legendFormat": "processor drop {{processor}}", "refId": "B"},
            {"expr": "sum by (exporter) (rate(otelcol_exporter_send_failed_spans_total[5m]))", "legendFormat": "export fail {{exporter}}", "refId": "C"},
        ],
        "fieldConfig": {"defaults": {"unit": "reqps", "custom": {"lineWidth": 2, "fillOpacity": 12}}},
        "options": {"legend": {"displayMode": "table", "placement": "bottom"}},
    },
    {
        "id": 33, "type": "timeseries", "title": "Tail sampling decisions",
        "description": "Traces sampled and rejected by the tail_sampling processor.",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 48},
        "datasource": {"type": "prometheus", "uid": "${DS_PROMETHEUS}"},
        "targets": [
            {"expr": "sum by (decision) (rate(otelcol_processor_tail_sampling_global_count_traces_sampled[5m]))", "legendFormat": "{{decision}}", "refId": "A"},
            {"expr": "sum(rate(otelcol_processor_tail_sampling_global_count_traces_dropped[5m]))", "legendFormat": "dropped", "refId": "B"},
        ],
        "fieldConfig": {"defaults": {"unit": "reqps", "custom": {"lineWidth": 2, "fillOpacity": 12}}},
        "options": {"legend": {"displayMode": "table", "placement": "bottom"}},
    },
    {
        "id": 34, "type": "stat", "title": "Collector exporter error rate",
        "description": "Any non-zero value requires investigation.",
        "gridPos": {"h": 5, "w": 6, "x": 0, "y": 56},
        "datasource": {"type": "prometheus", "uid": "${DS_PROMETHEUS}"},
        "targets": [{"expr": "sum(rate(otelcol_exporter_send_failed_spans_total[5m]))", "legendFormat": "failed spans/s", "refId": "A"}],
        "fieldConfig": {"defaults": {"unit": "reqps", "thresholds": {"mode": "absolute", "steps": [{"color": "green", "value": None}, {"color": "yellow", "value": 0.01}, {"color": "red", "value": 1}]}}},
        "options": {"colorMode": "background", "graphMode": "area", "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": False}},
    },
    {
        "id": 35, "type": "stat", "title": "Collector queue utilization",
        "description": "Highest exporter queue utilization across instances.",
        "gridPos": {"h": 5, "w": 6, "x": 6, "y": 56},
        "datasource": {"type": "prometheus", "uid": "${DS_PROMETHEUS}"},
        "targets": [{"expr": "max(100 * otelcol_exporter_queue_size / clamp_min(otelcol_exporter_queue_capacity, 1))", "legendFormat": "queue utilization", "refId": "A"}],
        "fieldConfig": {"defaults": {"unit": "percent", "thresholds": {"mode": "absolute", "steps": [{"color": "green", "value": None}, {"color": "yellow", "value": 70}, {"color": "red", "value": 90}]}}},
        "options": {"colorMode": "background", "graphMode": "area", "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": False}},
    },
]
for panel in new_panels:
    if panel["id"] not in existing:
        panels.append(panel)
data["version"] = int(data.get("version", 0)) + 1
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
