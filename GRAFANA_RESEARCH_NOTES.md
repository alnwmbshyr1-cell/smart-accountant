# Grafana dashboard research notes

## Grafana provisioning

Grafana supports provisioning data sources and dashboards from YAML configuration and dashboard JSON files. The dashboard provider can load files from a configured path, making the dashboard reproducible through source control rather than manual UI edits. Source: https://grafana.com/docs/grafana/latest/administration/provisioning/

## Prometheus data source

Grafana's Prometheus data source uses a Prometheus HTTP endpoint and can be configured through the data source provisioning file. A stable datasource UID makes dashboard JSON portable between manual import and file provisioning. Source: https://grafana.com/docs/grafana/latest/datasources/prometheus/

## Prometheus configuration

Prometheus uses `scrape_configs` to define targets and scrape intervals, and supports bearer token files for authentication. Keep the scrape token outside Git and mount it as a secret. Source: https://prometheus.io/docs/prometheus/latest/configuration/configuration/

## Applied design

The project now contains a dashboard JSON with seven panels and stable Prometheus datasource UID `prometheus`, dashboard provider and datasource provisioning files, a Grafana README, and a Vitest contract test that parses the JSON and checks that PromQL references only metrics emitted by the Backend registry. The local environment does not contain `promtool` or a running Grafana/Prometheus instance; therefore live rendering and PromQL evaluation still belong in CI/staging validation.
