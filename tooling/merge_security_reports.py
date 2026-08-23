#!/usr/bin/env python3
"""Merge third-party SARIF reports into a redacted Markdown/JSON summary.

The input is treated as untrusted data. Only bounded fields are copied and
credentials, bearer values, webhook URLs, and long opaque strings are redacted.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path
from typing import Any

MAX_TEXT = 800
TOKEN_RE = re.compile(
    r"(?i)(bearer\s+|(?:api[_-]?key|token|secret|password|webhook)[=:]\s*)[^\s,;]+"
)
URL_QUERY_RE = re.compile(r"(?i)(https?://[^\s?]+)\?[^\s]+")
OPAQUE_RE = re.compile(r"\b[A-Za-z0-9_\-]{48,}\b")


def scrub(value: Any) -> str:
    text = str(value or "").replace("\x00", " ").strip()
    text = TOKEN_RE.sub(r"\1[REDACTED]", text)
    text = URL_QUERY_RE.sub(r"\1?[REDACTED]", text)
    text = OPAQUE_RE.sub("[REDACTED]", text)
    return text[:MAX_TEXT]


def nested_text(value: Any) -> str:
    if isinstance(value, dict):
        return scrub(value.get("text", ""))
    return scrub(value)


def severity(result: dict[str, Any], rule: dict[str, Any]) -> str:
    properties = {}
    properties.update(rule.get("properties") or {})
    properties.update(result.get("properties") or {})
    raw = str(properties.get("security-severity") or properties.get("severity") or result.get("level") or "unknown").lower()
    if raw in {"critical", "5", "4"}:
        return "critical"
    if raw in {"high", "error", "3"}:
        return "high"
    if raw in {"medium", "warning", "2"}:
        return "medium"
    if raw in {"low", "note", "1"}:
        return "low"
    return "unknown"


def extract_location(result: dict[str, Any]) -> tuple[str, int | None]:
    locations = result.get("locations") or []
    if not locations:
        return "", None
    physical = locations[0].get("physicalLocation") or {}
    artifact = physical.get("artifactLocation") or {}
    region = physical.get("region") or {}
    uri = scrub(artifact.get("uri", ""))
    line = region.get("startLine")
    return uri, line if isinstance(line, int) else None


def load_sarif(path: Path, source: str) -> list[dict[str, Any]]:
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot read SARIF {path}: {exc}") from exc
    findings: list[dict[str, Any]] = []
    for run in document.get("runs") or []:
        driver = (run.get("tool") or {}).get("driver") or {}
        tool_name = scrub(driver.get("name") or source)
        rules = {str(rule.get("id")): rule for rule in driver.get("rules") or []}
        for result in run.get("results") or []:
            rule_id = scrub(result.get("ruleId") or "unknown-rule")
            rule = rules.get(str(result.get("ruleId"))) or {}
            uri, line = extract_location(result)
            message = nested_text(result.get("message"))
            short = nested_text(rule.get("shortDescription"))
            help_uri = scrub(rule.get("helpUri", ""))
            item = {
                "source": tool_name,
                "rule_id": rule_id,
                "severity": severity(result, rule),
                "status": "open",
                "message": message,
                "description": short,
                "file": uri,
                "line": line,
                "help_uri": help_uri,
            }
            findings.append(item)
    return findings


def dedupe(findings: list[dict[str, Any]]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    seen: set[tuple[Any, ...]] = set()
    for finding in findings:
        key = tuple(finding.get(field) for field in ("source", "rule_id", "file", "line", "message"))
        if key not in seen:
            seen.add(key)
            result.append(finding)
    return result


def build_report(inputs: list[tuple[Path, str]]) -> dict[str, Any]:
    findings: list[dict[str, Any]] = []
    files: list[str] = []
    for path, source in inputs:
        if not path.exists():
            continue
        files.append(str(path))
        findings.extend(load_sarif(path, source))
    findings = dedupe(findings)
    counts = Counter(finding["severity"] for finding in findings)
    by_source = Counter(finding["source"] for finding in findings)
    return {
        "schema_version": 1,
        "generated_by": "smart-accountant-security-report",
        "inputs": files,
        "summary": {
            "total": len(findings),
            "by_severity": dict(sorted(counts.items())),
            "by_source": dict(sorted(by_source.items())),
        },
        "findings": findings,
    }


def markdown(report: dict[str, Any]) -> str:
    summary = report["summary"]
    lines = [
        "# Smart Accountant Security Report",
        "",
        "> Generated from SARIF reports produced by CI scanners. Findings are deduplicated and redacted.",
        "",
        "## Summary",
        "",
        "| Metric | Value |",
        "|---|---:|",
        f"| Total findings | {summary['total']} |",
    ]
    for key in ("critical", "high", "medium", "low", "unknown"):
        lines.append(f"| {key.title()} | {summary['by_severity'].get(key, 0)} |")
    lines += ["", "## Findings", "", "| Source | Severity | Rule | Location | Description |", "|---|---|---|---|---|"]
    for finding in report["findings"]:
        location = finding["file"] or "-"
        if finding["line"] is not None:
            location += f":{finding['line']}"
        description = finding["description"] or finding["message"] or "-"
        lines.append(
            f"| {finding['source']} | {finding['severity']} | `{finding['rule_id']}` | `{location}` | {description.replace('|', '/')} |"
        )
    if not report["findings"]:
        lines.append("| - | - | - | - | No findings were present in the supplied SARIF files. |")
    lines += ["", "## Interpretation", "", "A zero count means that no finding was present in the supplied SARIF inputs; it does not prove that every dependency or image is vulnerability-free.", ""]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", action="append", default=[], help="source=path or path")
    parser.add_argument("--json-output", required=True)
    parser.add_argument("--markdown-output", required=True)
    args = parser.parse_args()
    inputs: list[tuple[Path, str]] = []
    for raw in args.input:
        if "=" in raw:
            source, path = raw.split("=", 1)
        else:
            source, path = "unknown", raw
        inputs.append((Path(path), source))
    report = build_report(inputs)
    Path(args.json_output).write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    Path(args.markdown_output).write_text(markdown(report), encoding="utf-8")
    print(json.dumps(report["summary"], ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
