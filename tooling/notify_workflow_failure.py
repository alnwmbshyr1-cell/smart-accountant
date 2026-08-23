#!/usr/bin/env python3
"""Send a bounded Slack alert when the weekly workflow fails."""
from __future__ import annotations

import hashlib
import json
import os
import sys
from typing import Any

sys.path.insert(0, os.path.dirname(__file__))
from notify_security import post_json  # noqa: E402


def failure_key(env: dict[str, str] | None = None) -> str:
    values = os.environ if env is None else env
    material = "|".join([
        values.get("GITHUB_REPOSITORY", "local"),
        values.get("GITHUB_WORKFLOW", "weekly-security"),
        values.get("GITHUB_RUN_ID", "local-run"),
        values.get("GITHUB_JOB", "weekly-security-report"),
    ])
    return "sa-failure-" + hashlib.sha256(material.encode("utf-8")).hexdigest()[:32]


def build_payload(env: dict[str, str] | None = None) -> dict[str, Any]:
    values = os.environ if env is None else env
    key = failure_key(values)
    repository = values.get("GITHUB_REPOSITORY", "local")
    run_id = values.get("GITHUB_RUN_ID", "local-run")
    url = values.get("WORKFLOW_URL", f"https://github.com/{repository}/actions/runs/{run_id}")
    return {
        "text": "*Smart Accountant: weekly security workflow failed*\n"
        f"Repository: `{repository}`\n"
        f"Run: `{run_id}`\n"
        f"<{url}|Open workflow run>\n"
        "Inspect the failed step and rerun only after the root cause is understood.",
        "event": "weekly_security_workflow_failed",
        "idempotency_key": key,
        "repository": repository,
        "run_id": run_id,
        "workflow_url": url[:500],
    }


def send_failure_alert(webhook_url: str, env: dict[str, str] | None = None) -> None:
    payload = build_payload(env)
    post_json(
        webhook_url,
        payload,
        headers={"Idempotency-Key": payload["idempotency_key"]},
    )


def main() -> int:
    webhook = os.environ.get("SECURITY_SLACK_WEBHOOK_URL", "")
    if not webhook:
        print("SECURITY_SLACK_WEBHOOK_URL is not configured; failure alert skipped.", file=sys.stderr)
        return 0
    send_failure_alert(webhook)
    print(json.dumps({"alert": "workflow_failure", "sent": True}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
