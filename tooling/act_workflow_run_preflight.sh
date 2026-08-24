#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVENT_DIR="$ROOT/.github/act/events"
EVENT_NAME="${1:-workflow_run-quality-failed.json}"
shift || true
EVENT_FILE="$EVENT_DIR/$EVENT_NAME"

if ! command -v act >/dev/null 2>&1; then
  echo "act is required. Install it from https://github.com/nektos/act before running this preflight." >&2
  exit 2
fi

if [[ ! -f "$EVENT_FILE" ]]; then
  echo "Unknown event fixture: $EVENT_FILE" >&2
  exit 2
fi

# The workflow must never call GitHub write APIs in local mode.
export ACT_LOCAL=true
export GITHUB_TOKEN=""
export SECURITY_TEAM_SLUG=""
export SECURITY_REVIEWER=""

exec act workflow_run \
  --eventpath "$EVENT_FILE" \
  --workflows "$ROOT/.github/workflows/security-review-on-quality-failure.yml" \
  --env ACT_LOCAL=true \
  --env GITHUB_TOKEN= \
  --env SECURITY_TEAM_SLUG= \
  --env SECURITY_REVIEWER= \
  --secret GITHUB_TOKEN= \
  "$@"
