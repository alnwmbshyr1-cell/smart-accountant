# Continuous security webhook monitoring

Use Alertmanager for immediate security notifications and keep the daily report as a separate aggregation channel. Route alerts with `category="security"` to `smart-accountant-security-webhook`; keep `send_resolved: true` so recovery is visible.

The receiver must be HTTPS in staging/production and expose a secret-file URL in Alertmanager:

```text
/etc/alertmanager/secrets/security_webhook_url
```

The receiving gateway must verify the raw body with HMAC-SHA256 over `timestamp + "." + raw_body`, reject timestamps outside the configured skew window, enforce a body-size limit, validate the Alertmanager schema, and claim `X-Webhook-Id` atomically in Redis with a bounded TTL. Store a request hash with the claim and reject the same ID with a different body. Return 2xx only after durable acceptance; use a dead-letter queue for repeated delivery failures rather than infinite retries.

A minimal local receiver is provided at `backend/ops/continuous_alert_webhook.py`. It is a test harness, not a complete production gateway: set `REDIS_URL` to enable atomic Redis replay claims, but add production schema validation, metrics, durable queueing, and authenticated HTTPS termination before deployment. Without `REDIS_URL`, its in-memory replay set is process-local and is suitable only for isolated tests.

Run the local integration tests:

```bash
python3 -m unittest tooling/test_continuous_alert_webhook.py
```

For local testing, use a secret supplied through the environment and a temporary events file:

```bash
CONTINUOUS_WEBHOOK_SECRET=local-only-secret \\
CONTINUOUS_EVENTS_PATH=/tmp/continuous-events.jsonl \\
WEBHOOK_PORT=8090 \\
python3 backend/ops/continuous_alert_webhook.py
```

Never point the test harness at Slack, a production Alertmanager, a production database, or a real payment endpoint. The daily report remains responsible for 24-hour aggregation, while the continuous webhook is responsible for low-latency firing and resolved notifications.
