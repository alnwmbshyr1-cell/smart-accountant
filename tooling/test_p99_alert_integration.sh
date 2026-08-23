#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAB_DIR="$ROOT/backend/ops/alertmanager"
STATE_DIR="$LAB_DIR/lab/state"
RECEIVED_DIR="$LAB_DIR/lab/received"
PROM_URL="http://127.0.0.1:19090"
AM_URL="http://127.0.0.1:19093"
COMPOSE=(docker compose -f "$LAB_DIR/docker-compose.yml")
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-180}"

cleanup() {
  printf '0.1\n' > "$STATE_DIR/latency_seconds" 2>/dev/null || true
  "${COMPOSE[@]}" down >/dev/null 2>&1 || true
}
trap cleanup EXIT

command -v docker >/dev/null || { echo 'docker is required' >&2; exit 2; }
mkdir -p "$STATE_DIR" "$RECEIVED_DIR"
printf '0.10\n' > "$STATE_DIR/error_ratio"
printf '1.0\n' > "$STATE_DIR/latency_seconds"
rm -f "$RECEIVED_DIR"/*.json

"${COMPOSE[@]}" up -d

alert_state() {
  curl -fsS "$PROM_URL/api/v1/alerts" | python3 "$ROOT/tooling/read_prom_alert_state.py" SmartAccountantLocalHighP99Latency
}

wait_for() {
  local description="$1"
  local command="$2"
  local deadline=$((SECONDS + TIMEOUT_SECONDS))
  while (( SECONDS < deadline )); do
    if eval "$command"; then
      echo "PASS: $description"
      return 0
    fi
    sleep 5
  done
  echo "FAIL: timed out waiting for $description" >&2
  return 1
}

wait_for 'Prometheus readiness' "curl -fsS '$PROM_URL/-/ready' >/dev/null"
wait_for 'Alertmanager readiness' "curl -fsS '$AM_URL/-/ready' >/dev/null"

# The local rule uses a 45-second `for`; allow one full scrape/evaluation cycle.
wait_for 'p99 alert pending in Prometheus' "test \"\$(alert_state)\" = pending"
wait_for 'p99 alert firing in Prometheus' "test \"\$(alert_state)\" = firing"
wait_for 'firing notification received' "grep -l 'SmartAccountantLocalHighP99Latency' '$RECEIVED_DIR'/*.json 2>/dev/null | xargs -r grep -l 'firing' >/dev/null"

printf '0.1\n' > "$STATE_DIR/latency_seconds"
wait_for 'p99 alert resolved in Prometheus' "test \"\$(alert_state)\" = inactive"
wait_for 'resolved notification received' "grep -l 'SmartAccountantLocalHighP99Latency' '$RECEIVED_DIR'/*.json 2>/dev/null | xargs -r grep -l 'resolved' >/dev/null"

echo 'PASS: p99 integration flow pending -> firing -> resolved -> Alertmanager webhook'
