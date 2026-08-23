# Smart Accountant Grafana dashboard

## Manual import

1. Add a Prometheus data source in Grafana with the UID `prometheus`.
2. Set its URL to the Prometheus server that scrapes the Smart Accountant Backend.
3. Import `smart-accountant-backend-dashboard.json` from the Grafana UI.
4. Select the `Prometheus` data source if Grafana asks for a data source mapping.
5. Set the time range to the operational window you want to investigate. The dashboard refreshes every 15 seconds.

## File provisioning

Mount these files into Grafana:

```text
ops/grafana/provisioning/datasources/prometheus.yml
  -> /etc/grafana/provisioning/datasources/prometheus.yml
ops/grafana/provisioning/dashboards/smart-accountant.yml
  -> /etc/grafana/provisioning/dashboards/smart-accountant.yml
ops/grafana/smart-accountant-backend-dashboard.json
  -> /etc/grafana/dashboards/smart-accountant-backend-dashboard.json
```

The provisioned data source expects `http://prometheus:9090` and UID `prometheus`; change the URL for the actual network topology. Keep `allowUiUpdates: false` in GitOps-style production and update the JSON through source control.

## Dashboard panels

The dashboard includes backend availability, request rate by route, 5xx percentage, HTTP p95 latency, JWT and Gemini failure rates, RSS memory, and response status distribution. Queries use the stable route-template and status-code labels emitted by `prom-client`; they do not use request IDs, user IDs, Arabic text, or tokens.

## Security and validation

Protect the Backend `/metrics` endpoint with `METRICS_SCRAPE_TOKEN`, private networking, mTLS, or an equivalent control. Mount the matching scrape token as a Prometheus secret through `bearer_token_file`. Do not put the token in this repository or in the dashboard JSON.

Validate the Prometheus and alert files with:

```bash
promtool check config ../prometheus/prometheus.yml
promtool check rules ../prometheus/smart-accountant-alerts.yml
```

Validate the dashboard JSON with:

```bash
node -e "JSON.parse(require('fs').readFileSync('smart-accountant-backend-dashboard.json', 'utf8')); console.log('dashboard JSON valid')"
```

The dashboard is a visualization layer, not a replacement for Alertmanager. Keep operational alerts in Prometheus rule files and configure Alertmanager receivers, owners, runbooks, and escalation policies separately.


## Live k6 load dashboard

Import `smart-accountant-load-dashboard.json` or let the existing dashboard provider discover it from `/etc/grafana/dashboards`. The dashboard refreshes every 5 seconds and uses datasource UID `prometheus`. It includes k6 request rate by scenario, p50/p95/p99 latency, request/check failures, gateway 5xx and forwarding errors, Redis health, idempotency claims/duplicates, and gateway p95 latency.

For live k6 series, run k6 with the Prometheus remote-write output and a unique test label:

```bash
export K6_PROMETHEUS_RW_SERVER_URL=https://prometheus.example/api/v1/write
export K6_PROMETHEUS_RW_TREND_STATS='p(50),p(90),p(95),p(99),avg,med,max'
k6 run \
  -e TEST_ID="staging-$(date -u +%Y%m%dT%H%M%SZ)" \
  --out experimental-prometheus-rw \
  tooling/security_gateway_load_test.js
```

Configure Prometheus remote write ingestion and authentication according to the Prometheus deployment; do not put credentials in the command history or dashboard JSON. The dashboard expects the k6 output metric names used by the Prometheus remote-write output and the `testid` and `scenario` tags emitted by the load script. If the k6 remote-write metric names differ in your pinned k6 version, inspect `/api/v1/label/__name__/values` and adjust the dashboard queries rather than inventing aliases.

Redis panels require a Redis exporter exposing `redis_*` metrics. Gateway panels require the matching `smart_accountant_*` counters and histograms from `prom-client`. Keep these metrics low-cardinality: never add request IDs, users, Arabic text, tokens, or full idempotency keys as labels. Use Grafana's dashboard variable to select a `testid` and keep the time range at `now-15m` during the run.

Validate the JSON before import:

```bash
node -e "JSON.parse(require('fs').readFileSync('smart-accountant-load-dashboard.json','utf8')); console.log('load dashboard JSON valid')"
```
