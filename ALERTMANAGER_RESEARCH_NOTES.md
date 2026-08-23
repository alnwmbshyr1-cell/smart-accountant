# Alertmanager research notes

Prometheus alerting rules evaluate PromQL expressions and send active alerts to an external notification layer. The `for` clause keeps a condition pending until it remains active for the configured duration; annotations are suitable for descriptions and runbook links. Prometheus documentation explicitly states that Alertmanager provides summarization, notification rate limiting, silencing, and alert dependencies. Sources: https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/ and https://prometheus.io/docs/alerting/latest/alertmanager/

Alertmanager configuration defines routing, grouping, inhibition, silences, and receivers. The official configuration supports Slack receiver settings, webhook receivers, secret files, and runtime reload using SIGHUP or `/-/reload`; malformed configuration is not applied. Source: https://prometheus.io/docs/alerting/latest/configuration/

Applied design: the existing Prometheus rule `SmartAccountantHigh5xxRate` calculates 5xx request rate divided by total request rate, uses a 5% threshold and 10-minute `for`, and carries severity, summary, description, and runbook annotations. The next reusable resource is an Alertmanager configuration with Slack and generic webhook receivers using environment expansion or mounted secret files, plus a dry-run test and recovery verification.
