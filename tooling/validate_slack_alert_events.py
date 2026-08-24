#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path

SECRET_RE = re.compile(r"(?i)(bearer\s+|token|api[_-]?key|secret|password|webhook)")


def validate(path: Path, expected_testid: str | None = None) -> dict:
    events = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    if not events:
        raise ValueError("no webhook events found")

    statuses = {event.get("status") for event in events}
    if not {"firing", "resolved"}.issubset(statuses):
        raise ValueError(f"expected firing and resolved, got {sorted(statuses)}")

    fingerprints = {str(event.get("groupKey") or event.get("fingerprint") or "") for event in events}
    fingerprints.discard("")
    if not fingerprints:
        raise ValueError("missing Alertmanager fingerprint/groupKey")

    if expected_testid:
        serialized = json.dumps(events, ensure_ascii=False)
        if expected_testid not in serialized:
            raise ValueError("expected testid is missing")

    unique_status_events = {(str(event.get("status")), str(event.get("groupKey") or event.get("fingerprint") or "")) for event in events}
    if len(unique_status_events) != len(events):
        raise ValueError("duplicate status/fingerprint notification detected")

    serialized = json.dumps(events, ensure_ascii=False)
    if SECRET_RE.search(serialized):
        raise ValueError("secret-like content found in webhook events")

    return {
        "event_count": len(events),
        "statuses": sorted(statuses),
        "fingerprints": sorted(fingerprints),
        "result": "pass",
    }


if __name__ == "__main__":
    report = validate(Path(sys.argv[1]), sys.argv[2] if len(sys.argv) > 2 else None)
    print(json.dumps(report, ensure_ascii=False, sort_keys=True))
