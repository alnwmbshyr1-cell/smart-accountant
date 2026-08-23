#!/usr/bin/env python3
"""Analyze a k6 summary export and create a self-contained visual HTML report."""
from __future__ import annotations

import argparse
import base64
import html
import json
import math
from pathlib import Path
from typing import Any


def metric_values(metrics: dict[str, Any], name: str) -> dict[str, Any]:
    metric = metrics.get(name, {})
    values = metric.get("values", {}) if isinstance(metric, dict) else {}
    return values if isinstance(values, dict) else {}


def number(value: Any) -> float | None:
    try:
        result = float(value)
        return result if math.isfinite(result) else None
    except (TypeError, ValueError):
        return None


def analyze(data: dict[str, Any]) -> dict[str, Any]:
    metrics = data.get("metrics", {})
    duration = metric_values(metrics, "http_req_duration")
    requests = metric_values(metrics, "http_reqs")
    failed = metric_values(metrics, "http_req_failed")
    checks = metric_values(metrics, "checks")
    return {
        "requests": int(number(requests.get("count")) or 0),
        "request_rate_rps": number(requests.get("rate")),
        "failed_rate": number(failed.get("rate")),
        "checks_rate": number(checks.get("rate")),
        "latency_ms": {
            key: number(duration.get(key))
            for key in ("avg", "med", "p(90)", "p(95)", "p(99)", "max")
            if number(duration.get(key)) is not None
        },
        "thresholds": data.get("thresholds", {}),
    }


def threshold_status(summary: dict[str, Any]) -> str:
    thresholds = summary.get("thresholds", {})
    if isinstance(thresholds, dict) and thresholds:
        values = []
        for item in thresholds.values():
            if isinstance(item, dict) and "ok" in item:
                values.append(bool(item["ok"]))
        if values and not all(values):
            return "FAIL"
        if values:
            return "PASS"
    failed_rate = summary.get("failed_rate")
    p95 = summary.get("latency_ms", {}).get("p(95)")
    if failed_rate is not None and failed_rate >= 0.01:
        return "FAIL"
    if p95 is not None and p95 >= 500:
        return "FAIL"
    return "PASS"


def chart_data_uri(summary: dict[str, Any]) -> str:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    labels = ["avg", "p90", "p95", "p99", "max"]
    source = summary.get("latency_ms", {})
    values = [source.get("avg", 0), source.get("p(90)", 0), source.get("p(95)", 0), source.get("p(99)", 0), source.get("max", 0)]
    fig, ax = plt.subplots(figsize=(9, 3.2), dpi=140)
    bars = ax.bar(labels, values, color=["#40C6FF", "#40C6FF", "#FFC107", "#FF8A65", "#FF5C61"])
    ax.set_title("k6 latency summary (milliseconds)")
    ax.set_ylabel("ms")
    ax.grid(axis="y", alpha=0.25)
    for bar, value in zip(bars, values):
        ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height(), f"{value:.1f}", ha="center", va="bottom", fontsize=8)
    fig.tight_layout()
    from io import BytesIO
    buffer = BytesIO()
    fig.savefig(buffer, format="png", transparent=False)
    plt.close(fig)
    return "data:image/png;base64," + base64.b64encode(buffer.getvalue()).decode("ascii")


def render_html(summary: dict[str, Any], chart_uri: str, source_name: str) -> str:
    status = threshold_status(summary)
    status_color = "#4ADE80" if status == "PASS" else "#FF5C61"
    latency_rows = "".join(
        f"<tr><td>{html.escape(key)}</td><td>{value:.2f}</td></tr>"
        for key, value in summary["latency_ms"].items()
    ) or "<tr><td colspan='2'>n/a</td></tr>"
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>k6 Security Gateway Report</title>
<style>body{{font-family:Arial,sans-serif;max-width:1100px;margin:32px auto;color:#172033}}h1{{margin-bottom:4px}}.muted{{color:#627089}}.grid{{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin:24px 0}}.metric{{border-top:4px solid #40C6FF;padding:14px;background:#f4f8fb}}.metric b{{display:block;font-size:26px;margin-top:8px}}table{{border-collapse:collapse;width:100%;margin-top:12px}}td,th{{border-bottom:1px solid #d9e1e8;padding:9px;text-align:left}}img{{max-width:100%;border:1px solid #d9e1e8;margin-top:20px}}.status{{font-weight:800;color:{status_color}}}</style></head>
<body><h1>Security Gateway — k6 Load Test</h1><div class="muted">Source: {html.escape(source_name)}</div>
<div class="status">Threshold result: {status}</div>
<div class="grid"><div class="metric">Requests<b>{summary['requests']}</b></div><div class="metric">Rate (RPS)<b>{summary['request_rate_rps'] if summary['request_rate_rps'] is not None else 'n/a'}</b></div><div class="metric">Failed rate<b>{(summary['failed_rate'] * 100):.3f}%</b></div><div class="metric">Checks<b>{(summary['checks_rate'] * 100):.3f}%</b></div></div>
<h2>Latency</h2><table><tr><th>Percentile/statistic</th><th>Milliseconds</th></tr>{latency_rows}</table>
<img src="{chart_uri}" alt="Latency chart"><h2>Interpretation</h2><p>Use this summary together with gateway and Redis metrics. A passing k6 threshold does not prove production capacity; validate CPU, memory, Redis saturation, dropped iterations, and forwarding behavior in the same run.</p></body></html>"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input")
    parser.add_argument("--html-output", required=True)
    parser.add_argument("--json-output", required=True)
    args = parser.parse_args()
    data = json.loads(Path(args.input).read_text(encoding="utf-8"))
    if not isinstance(data, dict) or not isinstance(data.get("metrics", {}), dict):
        raise SystemExit("Input must be a k6 summary export with a metrics object")
    summary = analyze(data)
    summary["threshold_status"] = threshold_status(summary)
    Path(args.json_output).write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    Path(args.html_output).write_text(render_html(summary, chart_data_uri(summary), Path(args.input).name), encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
