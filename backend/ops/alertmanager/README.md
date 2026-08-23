# Smart Accountant Alertmanager delivery

## Architecture

Prometheus evaluates `backend/ops/prometheus/smart-accountant-alerts.yml` and sends firing/resolved alerts to Alertmanager. Alertmanager groups related alerts, routes critical/high severity notifications, suppresses dependent alerts during a backend outage, and sends notifications to Slack or a generic HTTPS webhook.

## Secret files

Create these files outside Git and mount them read-only into Alertmanager:

```text
/etc/alertmanager/secrets/slack_webhook_url
/etc/alertmanager/secrets/ops_webhook_url
```

The first file contains the Slack Incoming Webhook API URL. The second contains the HTTPS URL of the internal incident or automation receiver. Set ownership and permissions so only the Alertmanager process can read them. Never put either URL in `alertmanager.yml`, GitHub Actions logs, dashboard JSON, or a chat message.

## Start and validate

Use the configuration file with Alertmanager:

```bash
alertmanager \
  --config.file=/etc/alertmanager/alertmanager.yml \
  --storage.path=/alertmanager
```

Validate before starting or reloading:

```bash
amtool check-config /etc/alertmanager/alertmanager.yml
```

Reload safely after a configuration change:

```bash
curl -X POST http://alertmanager:9093/-/reload
```

A malformed configuration must not be promoted. Keep Alertmanager and Prometheus on a private network and use HTTPS or an authenticated reverse proxy for management endpoints.

## Test without production data

Use a staging Prometheus rule or the Alertmanager API to send a synthetic alert with `alertname=SmartAccountantSynthetic`, `severity=warning`, and `job=smart-accountant-backend`. Confirm one grouped Slack/Webhook notification, then send the same alert with `status=resolved` and confirm the resolved notification. Delete or expire the test alert and verify it does not page production responders.

For the real 5xx rule, `SmartAccountantHigh5xxRate` fires when the 5xx rate exceeds 5% of total requests for 10 minutes. The `for` clause prevents a short deployment blip from paging immediately. Adjust the threshold and duration only after measuring a production baseline.

## Delivery design

The default route sends normal warnings to Slack. Critical alerts route to a critical Slack channel and continue to the normal route. High alerts route to the operations webhook and continue to Slack. A backend-down alert inhibits warning/high alerts for the same job to reduce notification storms. Keep `send_resolved: true` so responders know when the incident has recovered.

## Webhook contract

Alertmanager sends a JSON notification containing `status`, `receiver`, `groupLabels`, `commonLabels`, `commonAnnotations`, and an `alerts` array. The webhook receiver must authenticate the request independently, validate the payload schema, apply idempotency using the alert fingerprint, respond quickly with 2xx, and queue slow downstream work. Do not trust alert annotations as executable commands.
