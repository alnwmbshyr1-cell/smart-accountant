#!/usr/bin/env python3
"""Controlled Redis outage experiment for an approved staging namespace only."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib.request import urlopen


def kubectl(args: list[str], namespace: str) -> str:
    result = subprocess.run(["kubectl", "-n", namespace, *args], check=True, capture_output=True, text=True, timeout=20)
    return result.stdout.strip()


def replicas(namespace: str, deployment: str) -> int:
    data = json.loads(kubectl(["get", "deployment", deployment, "-o", "json"], namespace))
    return int(data.get("spec", {}).get("replicas", 0))


def write_event(handle, phase: str, **fields: object) -> None:
    handle.write(json.dumps({
        "time": datetime.now(timezone.utc).isoformat(),
        "phase": phase,
        **fields,
    }, sort_keys=True) + "\n")
    handle.flush()


def fetch_text(url: str) -> str:
    with urlopen(url, timeout=5) as response:  # nosec B310: URL is supplied by protected staging environment
        return response.read().decode("utf-8", errors="replace")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--namespace", default=os.getenv("K8S_NAMESPACE", "smart-accountant-staging"))
    parser.add_argument("--redis-deployment", default=os.getenv("REDIS_DEPLOYMENT", "redis"))
    parser.add_argument("--fault-seconds", type=int, default=int(os.getenv("FAULT_SECONDS", "30")))
    parser.add_argument("--recovery-timeout", type=int, default=int(os.getenv("RECOVERY_TIMEOUT", "180")))
    parser.add_argument("--poll-seconds", type=int, default=10)
    parser.add_argument("--metrics-url", default=os.getenv("METRICS_URL", ""))
    parser.add_argument("--output", type=Path, default=Path("artifacts/redis-chaos-observations.jsonl"))
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--confirm-staging-chaos", action="store_true")
    args = parser.parse_args()

    if "staging" not in args.namespace:
        raise SystemExit("Refusing to run: namespace must contain 'staging'")
    if args.fault_seconds < 5 or args.fault_seconds > 300:
        raise SystemExit("Refusing to run: fault duration must be between 5 and 300 seconds")
    if args.recovery_timeout <= args.fault_seconds:
        raise SystemExit("Refusing to run: recovery timeout must exceed fault duration")
    if not args.execute:
        print(json.dumps({"dry_run": True, "namespace": args.namespace, "redis_deployment": args.redis_deployment, "fault_seconds": args.fault_seconds}))
        return 0
    if not args.confirm_staging_chaos:
        raise SystemExit("Refusing to run: add --confirm-staging-chaos for the destructive staging experiment")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    original = replicas(args.namespace, args.redis_deployment)
    if original < 1:
        raise SystemExit("Refusing to run: Redis deployment has no positive replica baseline")

    with args.output.open("w", encoding="utf-8") as observations:
        write_event(observations, "baseline", redis_replicas=original)
        try:
            kubectl(["scale", "deployment", args.redis_deployment, "--replicas=0"], args.namespace)
            write_event(observations, "fault_injected", redis_replicas=0)
            deadline = time.monotonic() + args.fault_seconds
            while time.monotonic() < deadline:
                if args.metrics_url:
                    try:
                        write_event(observations, "fault_observation", metrics=fetch_text(args.metrics_url)[:20000])
                    except Exception as exc:  # diagnostic collection must not prevent recovery
                        write_event(observations, "observation_error", error=type(exc).__name__)
                time.sleep(args.poll_seconds)
        finally:
            kubectl(["scale", "deployment", args.redis_deployment, f"--replicas={original}"], args.namespace)
            write_event(observations, "restore_requested", redis_replicas=original)

        deadline = time.monotonic() + args.recovery_timeout
        while time.monotonic() < deadline:
            current = replicas(args.namespace, args.redis_deployment)
            write_event(observations, "recovery_observation", redis_replicas=current)
            if current == original:
                write_event(observations, "recovery_confirmed", redis_replicas=current)
                return 0
            time.sleep(args.poll_seconds)

    raise RuntimeError("Redis did not return to its original replica count before the recovery timeout")


if __name__ == "__main__":
    raise SystemExit(main())
