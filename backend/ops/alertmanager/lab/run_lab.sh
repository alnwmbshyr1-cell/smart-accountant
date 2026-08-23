#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$ROOT/lab/state/error_ratio"
RECEIVED="$ROOT/lab/received"

mkdir -p "$ROOT/lab/state" "$RECEIVED" "$ROOT/lab/prometheus-data" "$ROOT/lab/alertmanager-data"
printf '0.10\n' > "$STATE"
rm -f "$RECEIVED"/*.json

echo 'Starting local Prometheus, Alertmanager, metrics fixture, and webhook receiver...'
docker compose -f "$ROOT/docker-compose.yml" up -d

echo 'Services:'
echo '  Prometheus:  http://localhost:19090'
echo '  Alertmanager: http://localhost:19093'
echo '  Webhook:      http://localhost:18080/alertmanager'
echo
echo 'Keep 0.10 for approximately 60 seconds to observe the alert become firing.'
echo 'Then run: printf "0.01\\n" > lab/state/error_ratio'
echo 'Wait for the 1-minute rate window and inspect lab/received for the resolved payload.'
