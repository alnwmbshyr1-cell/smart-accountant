#!/usr/bin/env python3
"""Run a guarded staging load test and assert KEDA scale-up and recovery."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable


def run(command: list[str], *, timeout: int = 10) -> str:
    result = subprocess.run(command, check=True, capture_output=True, text=True, timeout=timeout)
    return result.stdout.strip()


def kubectl_replicas(namespace: str, deployment: str) -> dict[str, int]:
    data = json.loads(run(["kubectl", "-n", namespace, "get", "deployment", deployment, "-o", "json"]))
    status = data.get("status", {})
    return {
        "desired": int(status.get("replicas", 0)),
        "ready": int(status.get("readyReplicas", 0)),
        "available": int(status.get("availableReplicas", 0)),
    }


def hpa_replicas(namespace: str, name: str) -> dict[str, int]:
    data = json.loads(run(["kubectl", "-n", namespace, "get", "hpa", name, "-o", "json"]))
    status = data.get("status", {})
    return {
        "current": int(status.get("currentReplicas", 0)),
        "desired": int(status.get("desiredReplicas", 0)),
        "min": int(data.get("spec", {}).get("minReplicas", 0)),
        "max": int(data.get("spec", {}).get("maxReplicas", 0)),
    }


def stream_pending(redis_url: str, stream: str, group: str) -> int:
    raw = run(["redis-cli", "--tls", "-u", redis_url, "XINFO", "GROUPS", stream, "--json"])
    for item in json.loads(raw):
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


def write_sample(handle, value: dict) -> None:
    handle.write(json.dumps(value, sort_keys=True) + "\n")
    handle.flush()


def wait_for(
    predicate: Callable[[dict], bool],
    observe: Callable[[], dict],
    handle,
    timeout_seconds: int,
    poll_seconds: int,
    failure_message: str,
) -> dict:
    deadline = time.monotonic() + timeout_seconds
    last = {}
    while time.monotonic() < deadline:
        try:
            last = observe()
            write_sample(handle, last)
            if predicate(last):
                return last
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired, json.JSONDecodeError) as exc:
            write_sample(handle, {"time": datetime.now(timezone.utc).isoformat(), "observation_error": type(exc).__name__})
        time.sleep(poll_seconds)
    raise RuntimeError(failure_message + f" Last observation: {last}")


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
    parser.add_argument("--scale-up-timeout", type=int, default=240)
    parser.add_argument("--scale-down-timeout", type=int, default=420)
    parser.add_argument("--minimum-scale-up", type=int, default=3)
    parser.add_argument("--output", type=Path, default=Path("artifacts/keda-load-observations.jsonl"))
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if not args.target_url or not args.target_url.startswith("https://") or "staging" not in args.target_url:
        raise SystemExit("Refusing to run: --target-url must be an approved https://...staging... endpoint")
    if not args.redis_url.startswith("rediss://"):
        raise SystemExit("Refusing to run: --redis-url must use rediss://")
    if not 1 <= args.rps <= 2000:
        raise SystemExit("Refusing to run: RPS must be between 1 and 2000")
    if args.scale_up_timeout <= 0 or args.scale_down_timeout <= 0 or args.poll_seconds <= 0:
        raise SystemExit("Refusing to run: timeout and polling values must be positive")

    command = ["k6", "run", "--summary-export=artifacts/k6-summary.json", "tooling/k6/redis_stream_circuit_breaker.js"]
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

    observe = lambda: sample(args.namespace, args.deployment, args.hpa, args.redis_url, args.stream, args.consumer_group)
    with args.output.open("w", encoding="utf-8") as observations:
        baseline = observe()
        write_sample(observations, {"phase": "baseline", **baseline})
        baseline_replicas = max(baseline["deployment"]["desired"], baseline["hpa"]["current"], baseline["hpa"]["desired"])
        process = subprocess.Popen(command, env=env)
        try:
            scaled = wait_for(
                lambda item: max(item["deployment"]["desired"], item["hpa"]["current"], item["hpa"]["desired"]) >= max(args.minimum_scale_up, baseline_replicas + 1),
                observe,
                observations,
                args.scale_up_timeout,
                args.poll_seconds,
                "KEDA did not scale up to the expected replica count while load was running.",
            )
            write_sample(observations, {"phase": "scale_up_confirmed", **scaled})
            return_code = process.wait()
            if return_code != 0:
                raise RuntimeError(f"k6 failed with exit code {return_code}")
            recovered = wait_for(
                lambda item: item["pending"] == 0 and item["hpa"]["current"] <= item["hpa"]["min"] and item["deployment"]["ready"] >= item["hpa"]["min"],
                observe,
                observations,
                args.scale_down_timeout,
                args.poll_seconds,
                "Redis backlog did not drain and KEDA did not return to min replicas.",
            )
            write_sample(observations, {"phase": "recovery_confirmed", **recovered})
            return 0
        finally:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=20)


if __name__ == "__main__":
    raise SystemExit(main())
