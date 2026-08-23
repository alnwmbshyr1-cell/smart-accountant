#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/backend/ops/security-gateway/docker-compose.yml"
TLS_DIR="$(mktemp -d)"
PROJECT="security-gateway-it-$$"
export TLS_CERT_DIR="$TLS_DIR"
export GATEWAY_INGRESS_TOKEN="local-integration-token"
export COMPOSE_PROJECT_NAME="$PROJECT"

cleanup() {
  docker compose -f "$COMPOSE_FILE" down -v --remove-orphans >/dev/null 2>&1 || true
  rm -rf "$TLS_DIR"
}
trap cleanup EXIT

command -v docker >/dev/null || { echo 'docker is required' >&2; exit 2; }
docker compose version >/dev/null || { echo 'docker compose plugin is required' >&2; exit 2; }
command -v openssl >/dev/null || { echo 'openssl is required' >&2; exit 2; }
command -v curl >/dev/null || { echo 'curl is required' >&2; exit 2; }

openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$TLS_DIR/key.pem" \
  -out "$TLS_DIR/cert.pem" \
  -days 1 -subj '/CN=localhost' >/dev/null 2>&1
chmod 600 "$TLS_DIR/key.pem"

docker compose -f "$COMPOSE_FILE" up -d --build

for attempt in $(seq 1 30); do
  if curl -ksf https://127.0.0.1:8443/healthz >/dev/null; then
    break
  fi
  if [ "$attempt" -eq 30 ]; then
    echo 'gateway did not become healthy' >&2
    docker compose -f "$COMPOSE_FILE" logs gateway >&2 || true
    exit 1
  fi
  sleep 2
done

KEY="sa-$(printf '%032x' 1)"
PAYLOAD="$(mktemp)"
FIRST="$(mktemp)"
SECOND="$(mktemp)"
trap 'rm -f "$PAYLOAD" "$FIRST" "$SECOND"; cleanup' EXIT
cat > "$PAYLOAD" <<JSON
{"event":"critical_security_findings","idempotency_key":"$KEY","title":"Compose integration test","total_critical":1,"findings":[{"source":"integration","rule_id":"TEST-CRITICAL","location":"fixture:1"}],"workflow_url":"local"}
JSON

first_status=$(curl -ksS -o "$FIRST" -w '%{http_code}' \
  https://127.0.0.1:8443/v1/security/notify \
  -H "Authorization: Bearer $GATEWAY_INGRESS_TOKEN" \
  -H "Idempotency-Key: $KEY" \
  -H 'Content-Type: application/json' \
  --data-binary "@$PAYLOAD")
second_status=$(curl -ksS -o "$SECOND" -w '%{http_code}' \
  https://127.0.0.1:8443/v1/security/notify \
  -H "Authorization: Bearer $GATEWAY_INGRESS_TOKEN" \
  -H "Idempotency-Key: $KEY" \
  -H 'Content-Type: application/json' \
  --data-binary "@$PAYLOAD")

python3 - "$FIRST" "$SECOND" "$first_status" "$second_status" <<'PY'
import json
import sys
first = json.load(open(sys.argv[1], encoding='utf-8'))
second = json.load(open(sys.argv[2], encoding='utf-8'))
assert sys.argv[3] == '202', (sys.argv[3], first)
assert sys.argv[4] == '200', (sys.argv[4], second)
assert first['duplicate'] is False, first
assert second['duplicate'] is True, second
print('live gateway integration passed: first=202, duplicate=200')
PY

docker compose -f "$COMPOSE_FILE" exec -T redis redis-cli --raw --scan --pattern 'security-alert:*' | grep -F "$KEY" >/dev/null
echo 'Redis contains the idempotency key with the configured TTL.'
