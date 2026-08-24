#!/usr/bin/env python3
"""Local-only integration harness for Prometheus -> Alertmanager -> mock receivers."""
from __future__ import annotations

import argparse
import json
import time
from pathlib import Path
from urllib.request import Request, urlopen


def request(url: str, method: str = "GET", body: bytes | None = None) -> dict | str:
    req = Request(url, data=body, method=method, headers={"Content-Type": "application/json"})
    with urlopen(req, timeout=3) as response:
        raw = response.read()
        return json.loads(raw) if raw else {"status": response.status}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--receiver", default="http://127.0.0.1:18080")
    parser.add_argument("--prometheus", default="http://127.0.0.1:9090")
    parser.add_argument("--wait-seconds", type=int, default=30)
    parser.add_argument("--output", type=Path, default=Path("artifacts/alertmanager-integration.json"))
    args = parser.parse_args()
    for url in (args.receiver, args.prometheus):
        if not url.startswith("http://127.0.0.1:"):
            raise SystemExit("integration harness accepts localhost only")

    observations: list[dict] = []
    high = json.dumps({"memory_rss_bytes": 800000000}).encode()
    low = json.dumps({"memory_rss_bytes": 100000000}).encode()
    request(f"{args.receiver}/metrics-state", "POST", high)
    deadline = time.time() + args.wait_seconds
    firing_seen = False
    while time.time() < deadline:
        events = request(f"{args.receiver}/received")
        observations.append({"phase": "firing", "events": events})
        firing_seen = any(event.get("status") == "firing" for event in events) if isinstance(events, list) else False
        if firing_seen:
            break
        time.sleep(2)
    if not firing_seen:
        raise SystemExit("Alertmanager did not deliver firing notification")

    request(f"{args.receiver}/metrics-state", "POST", low)
    deadline = time.time() + args.wait_seconds
    resolved_seen = False
    while time.time() < deadline:
        events = request(f"{args.receiver}/received")
        observations.append({"phase": "resolved", "events": events})
        resolved_seen = any(event.get("status") == "resolved" for event in events) if isinstance(events, list) else False
        if resolved_seen:
            break
        time.sleep(2)
    if not resolved_seen:
        raise SystemExit("Alertmanager did not deliver resolved notification")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps({"firing": firing_seen, "resolved": resolved_seen, "observations": observations}, indent=2), encoding="utf-8")
    print(json.dumps({"firing": firing_seen, "resolved": resolved_seen}))


if __name__ == "__main__":
    main()
