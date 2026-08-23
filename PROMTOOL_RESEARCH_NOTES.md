# Promtool alert-rule test notes

Prometheus provides a unit-testing framework for recording and alerting rules. A test file contains `rule_files`, synthetic `input_series`, `evaluation_interval`, and `tests` with `alert_rule_test` entries. `promtool test rules` evaluates the rule against the synthetic series and checks alert state, labels, and annotations at specified evaluation times. Source: https://prometheus.io/docs/prometheus/latest/configuration/unit_testing_rules/

Alerting rules with a `for` clause remain pending until the expression stays active for that duration. Prometheus documents that alerting rules are active when the expression returns a vector, and Alertmanager handles notification routing, grouping, silencing, and inhibition. Sources: https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/ and https://prometheus.io/docs/alerting/latest/alertmanager/

Applied design: test the Smart Accountant 5xx ratio with 5-minute samples. Synthetic traffic uses 100 total requests per sample and 10 5xx requests for an error ratio of 10%, while a healthy series uses 2 5xx requests for 2%. The `for: 10m` window requires the high-error state to remain active across enough evaluations before the alert is firing. The test also verifies no alert below threshold and a resolved state after recovery.
