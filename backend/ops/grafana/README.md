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
