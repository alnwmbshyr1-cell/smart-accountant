#!/usr/bin/env python3
"""Run a guarded staging load test and record KEDA/HPA/Redis observations."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path



def run(command: list[str], *, timeout: int = 10) -> str:
    result = subprocess.run(command, check=True, capture_output=True, text=True, timeout=timeout)
    return result.stdout.strip()


def kubectl_replicas(namespace: str, deployment: str) -> dict[str, int]:
    raw = run(["kubectl", "-n", namespace, "get", "deployment", deployment, "-o", "json"])
    data = json.loads(raw)
    status = data.get("status", {})
    return {
        "desired": int(status.get("replicas", 0)),
        "ready": int(status.get("readyReplicas", 0)),
        "available": int(status.get("availableReplicas", 0)),
    }


def hpa_replicas(namespace: str, name: str) -> dict[str, int]:
    raw = run(["kubectl", "-n", namespace, "get", "hpa", name, "-o", "json"])
    data = json.loads(raw)
    status = data.get("status", {})
    return {
        "current": int(status.get("currentReplicas", 0)),
        "desired": int(status.get("desiredReplicas", 0)),
        "min": int(data.get("spec", {}).get("minReplicas", 0)),
        "max": int(data.get("spec", {}).get("maxReplicas", 0)),
    }


def stream_pending(redis_url: str, stream: str, group: str) -> int:
    raw = run([
        "redis-cli", "--tls", "-u", redis_url,
        "XINFO", "GROUPS", stream,
        "--json",
    ])
    groups = json.loads(raw)
    for item in groups:
        values = dict(zip(item[::2], item[1::2]))
        if values.get("name") == group:
            return int(values.get("pending", 0))
    return 0


def sample(namespace: str, deployment: str, hpa: str, redis_url: str, stream: str, group: str) -> dict:
    return {
        "time": datetime.now(timezone.utc).isoformat(),
        "deployment": kubectl_replicas(namespace, deployment),
        "hpa": hpa_replicas(namespace, hpa),
        "pending": stream_pending(redis_url, stream, group),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target-url", default=os.getenv("TARGET_URL", ""))
    parser.add_argument("--namespace", default=os.getenv("K8S_NAMESPACE", "smart-accountant-staging"))
    parser.add_argument("--deployment", default="security-webhook-worker")
    parser.add_argument("--hpa", default="keda-hpa-security-webhook-worker")
    parser.add_argument("--stream", default="security:webhook:events")
    parser.add_argument("--consumer-group", default="security-webhook-workers")
    parser.add_argument("--redis-url", default=os.getenv("REDIS_URL", ""))
    parser.add_argument("--rps", type=int, default=int(os.getenv("RPS", "100")))
    parser.add_argument("--duration", default=os.getenv("DURATION", "2m"))
    parser.add_argument("--poll-seconds", type=int, default=15)
    parser.add_argument("--output", type=Path, default=Path("artifacts/keda-load-observations.jsonl"))
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if not args.target_url or not args.target_url.startswith("https://") or "staging" not in args.target_url:
        raise SystemExit("Refusing to run: --target-url must be an approved https://...staging... endpoint")
    if not args.redis_url.startswith("rediss://"):
        raise SystemExit("Refusing to run: --redis-url must use rediss://")
    if not 1 <= args.rps <= 2000:
        raise SystemExit("Refusing to run: RPS must be between 1 and 2000")

    command = [
        "k6", "run", "--summary-export=artifacts/k6-summary.json",
        "tooling/k6/redis_stream_circuit_breaker.js",
    ]
    env = os.environ.copy()
    env.update({
        "TARGET_URL": args.target_url,
        "RPS": str(args.rps),
        "DURATION": args.duration,
        "ALLOW_NON_LOCAL_LOAD_TEST": "true",
    })

    args.output.parent.mkdir(parents=True, exist_ok=True)
    if args.dry_run:
        print(json.dumps({"command": command, "namespace": args.namespace, "rps": args.rps, "duration": args.duration}))
        return 0

    with args.output.open("a", encoding="utf-8") as observations:
        process = subprocess.Popen(command, env=env)
        try:
            while process.poll() is None:
                try:
                    observations.write(json.dumps(sample(
                        args.namespace, args.deployment, args.hpa,
                        args.redis_url, args.stream, args.consumer_group,
                    )) + "\n")
                    observations.flush()
                except (subprocess.CalledProcessError, subprocess.TimeoutExpired, json.JSONDecodeError) as exc:
                    observations.write(json.dumps({
                        "time": datetime.now(timezone.utc).isoformat(),
                        "observation_error": type(exc).__name__,
                    }) + "\n")
                    observations.flush()
                time.sleep(args.poll_seconds)
        finally:
            return_code = process.wait()
    return return_code


if __name__ == "__main__":
    raise SystemExit(main())
