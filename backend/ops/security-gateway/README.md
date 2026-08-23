# Local HTTPS Redis Idempotency Gateway

This lab gateway accepts the redacted payload sent by `tooling/notify_security.py` at `/v1/security/notify`. It validates the `Idempotency-Key`, atomically claims `security-alert:<key>` in Redis with `SET NX EX`, and forwards only the first accepted delivery. A successful delivery is retained as `delivered` until the TTL expires. A failed forward releases the claim so a later retry can deliver it.

## Start locally

Generate a local certificate. The certificate is for local testing only:

```bash
mkdir -p /tmp/smart-accountant-tls
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout /tmp/smart-accountant-tls/key.pem \
  -out /tmp/smart-accountant-tls/cert.pem \
  -days 1 -subj '/CN=localhost'
```

Start Redis and the gateway from the repository root:

```bash
export GATEWAY_INGRESS_TOKEN="local-only-change-me"
export TLS_CERT_DIR=/tmp/smart-accountant-tls
docker compose -f backend/ops/security-gateway/docker-compose.yml up --build
```

The gateway listens at `https://localhost:8443`. `curl` needs `-k` for the self-signed certificate. Never use this certificate or the local ingress token in production.

## Send a synthetic notification

Generate a key with the same repository context used by GitHub Actions:

```bash
KEY=$(GITHUB_REPOSITORY=org/repo GITHUB_WORKFLOW=security GITHUB_SHA=local \
  python3 -c 'import sys; sys.path.insert(0, "tooling"); import notify_security; print(notify_security.make_idempotency_key({"findings":[{"severity":"critical","source":"test","rule_id":"TEST-1","file":"a","line":1}]}, "webhook", {"GITHUB_REPOSITORY":"org/repo","GITHUB_WORKFLOW":"security","GITHUB_SHA":"local"}))')
```

Use `notify_security.py` with the gateway as the operations Webhook. For a self-signed local certificate, the Python client must be adapted with an explicit test-only SSL context; do not disable certificate verification in production. The simplest local gateway check is a direct `curl` request:

```bash
curl -k -i https://localhost:8443/v1/security/notify \
  -H "Authorization: Bearer local-only-change-me" \
  -H "Idempotency-Key: $KEY" \
  -H 'Content-Type: application/json' \
  --data '{"event":"critical_security_findings","idempotency_key":"'$KEY'","title":"Synthetic Critical test","total_critical":1,"findings":[{"source":"test","rule_id":"TEST-1","location":"a:1"}],"workflow_url":"local"}'
```

Repeat the same request. The first response is `202` with `duplicate:false`; the second is `200` with `duplicate:true`. Inspect Redis without exposing any secret:

```bash
docker compose -f backend/ops/security-gateway/docker-compose.yml exec redis \
  redis-cli --scan --pattern 'security-alert:*'
```

Stop and remove the local Redis volume after testing if the data is disposable:

```bash
docker compose -f backend/ops/security-gateway/docker-compose.yml down -v
rm -rf /tmp/smart-accountant-tls
```

## Production differences

Use a CA-issued certificate, a private network or mTLS, a secret manager, a managed Redis instance with TLS and authentication, and a durable audit store. Preserve the atomic `SET NX EX` operation. Do not use a local self-signed certificate, unauthenticated Redis, or a runner-local file as the production deduplication store.

## Production environment contract

Use a CA-issued server certificate on the gateway and require client certificates signed by a dedicated client CA:

```text
TLS_CERT_FILE=/run/secrets/gateway-server.crt
TLS_KEY_FILE=/run/secrets/gateway-server.key
TLS_REQUIRE_CLIENT_CERT=true
TLS_CLIENT_CA_FILE=/run/secrets/client-ca.crt
GATEWAY_INGRESS_TOKEN=<from-secret-manager>
```

For Redis TLS, use a `rediss://` URL or set `REDIS_TLS=true`. Require a CA file and, when Redis is configured for client authentication, a gateway client certificate and key:

```text
REDIS_URL=rediss://redis-production.example:6380/0
REDIS_TLS=true
REDIS_CA_FILE=/run/secrets/redis-ca.crt
REDIS_CLIENT_CERT_FILE=/run/secrets/redis-client.crt
REDIS_CLIENT_KEY_FILE=/run/secrets/redis-client.key
REDIS_SSL_CHECK_HOSTNAME=true
REDIS_USERNAME=<from-secret-manager>
REDIS_PASSWORD=<from-secret-manager>
```

The gateway validates the Redis server certificate through `REDIS_CA_FILE` and presents the client certificate when configured. Keep the Redis server CA separate from the gateway client CA unless your PKI explicitly approves a shared trust boundary. Mount files read-only with restrictive permissions, rotate them before expiry, and restart or reload the gateway using the platform's secret rotation mechanism.

## GitHub Actions integration

A hosted GitHub runner cannot reach `localhost` on your production gateway. Publish the gateway behind a private HTTPS endpoint reachable by the runner, use a self-hosted runner inside the private network, or expose only a tightly allowlisted ingress. Configure these GitHub secrets:

```text
SECURITY_GATEWAY_WEBHOOK_URL
SECURITY_GATEWAY_INGRESS_TOKEN
SECURITY_GATEWAY_CA_B64
SECURITY_GATEWAY_CLIENT_CERT_B64
SECURITY_GATEWAY_CLIENT_KEY_B64
```

The Workflow decodes the three base64 certificate values into `$RUNNER_TEMP`, passes their paths to `notify_security.py`, and removes them with the runner workspace cleanup. The gateway URL and ingress token are passed as environment variables, never as command-line arguments. If using a self-hosted runner, prefer a mounted secret file or OIDC-issued short-lived credential over long-lived certificate material in repository secrets.

Generate base64 values without adding a trailing newline:

```bash
base64 -w 0 ca.crt > ca.crt.b64
base64 -w 0 github-actions-client.crt > github-actions-client.crt.b64
base64 -w 0 github-actions-client.key > github-actions-client.key.b64
```

Never commit the `.b64` files. For higher assurance, store the certificate bundle in an environment protected by reviewers and use a short-lived client certificate issued by your internal CA.
