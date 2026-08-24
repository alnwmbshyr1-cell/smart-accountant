# Circuit Breaker alerts through Alertmanager

## Flow

`CircuitBreakerMetrics` exposes `circuit_breaker_state`. Prometheus evaluates `CircuitBreakerOpen` after the state remains open for two minutes. Alertmanager routes the alert immediately to both PagerDuty and the custom HTTPS Webhook, and sends resolved notifications when the state returns to closed.

## Prometheus rule

```yaml
- alert: CircuitBreakerOpen
  expr: circuit_breaker_state{dependency=~"slack-security|email-security|gemini"} == 1
  for: 2m
  labels:
    severity: critical
    category: security
    notification_class: circuit_open
  annotations:
    summary: "Circuit Breaker is open for {{ $labels.dependency }}"
    description: "Outbound calls are failing fast; inspect the dependency and Redis state."
```

Keep dependency values allow-listed. Do not use event IDs, request IDs, user IDs, URLs, or raw exception text as metric labels.

## Alertmanager receivers

Use secret files mounted with restricted permissions:

```yaml
- name: smart-accountant-circuit-pagerduty
  pagerduty_configs:
    - routing_key_file: /etc/alertmanager/secrets/pagerduty_routing_key
      send_resolved: true
      group: smart-accountant-circuit-breaker

- name: smart-accountant-circuit-webhook
  webhook_configs:
    - url_file: /etc/alertmanager/secrets/circuit_open_webhook_url
      send_resolved: true
      max_alerts: 10
```

The route should set `group_wait: 0s`, a short `group_interval`, a bounded `repeat_interval`, and `continue: true` when both receivers must receive the same alert. PagerDuty should use a stable deduplication identity based on environment, alertname, and dependency so repeated notifications update one incident instead of creating a new incident each time.

## Security and testing

Do not commit PagerDuty routing keys or Webhook URLs. Use a secret manager, TLS for Redis, HTTPS for the custom receiver, and mTLS or an authenticated gateway when the receiver is not on a private network. Verify `send_resolved` in a non-production service and test a synthetic alert against a local fake Webhook or a PagerDuty test service.

Run YAML tests and, where Alertmanager is installed, validate the rendered configuration with `amtool check-config`. Verify that firing and resolved payloads are delivered, grouping is bounded, retries do not produce unbounded traffic, and no secret or raw alert body is present in logs.

## References

[1] [Prometheus Alertmanager configuration](https://prometheus.io/docs/alerting/latest/configuration/)
[2] [PagerDuty Prometheus integration](https://www.pagerduty.com/docs/guides/prometheus-integration-guide/)
[3] [Prometheus metric types](https://prometheus.io/docs/concepts/metric_types/)
