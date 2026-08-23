# Production observability research notes

## OpenTelemetry Node.js

OpenTelemetry's Node.js getting-started guidance instruments Express and supports traces and metrics through the Node SDK and auto-instrumentations. Instrumentation setup should run before application imports. The official page notes that the JavaScript OpenTelemetry logging API is still under development, so the application logger should remain an independent structured JSON logger while traces and metrics use OpenTelemetry. Source: https://opentelemetry.io/docs/languages/js/getting-started/nodejs/

## OWASP Logging Cheat Sheet

OWASP recommends consistent application logging, centralized collection, correct encoding, restricted access, separate audit/security/operational purposes, and explicit protection of sensitive data. Logs should support debugging, performance monitoring, security events, and audit trails without logging more information than necessary. Source: https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html

## OWASP Top 10 2025 A09

Security Logging and Alerting Failures includes sensitive data in logs, insufficient logging, missing monitoring, weak log integrity, local-only retention, ineffective thresholds, false-positive overload, and missing incident playbooks. Recommended controls include logging authentication/access-control/validation failures, monitoring suspicious behavior, protecting audit trails from tampering, using consumable formats, and maintaining response playbooks. Source: https://owasp.org/Top10/2025/A09_2025-Security_Logging_and_Alerting_Failures/

## Applied design

The Backend now has structured JSON `logEvent`, request correlation via `x-request-id`, `/healthz`, `/readyz`, JSON `/metrics`, counters for request classes/auth/Gemini failures, bounded duration, and tests that assert Authorization and sensitive Arabic text do not appear in logs. These endpoints are a lightweight baseline; production deployment should connect them to the platform collector, Prometheus/OpenTelemetry, centralized retention, access controls, and alerting with runbooks.
