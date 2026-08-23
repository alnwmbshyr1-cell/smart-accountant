# Security scan research notes

Trivy Action documents filesystem and image scans, SARIF output, severity thresholds, `ignore-unfixed`, and its built-in vulnerability database cache: https://github.com/aquasecurity/trivy-action

Snyk documents GitHub Actions for dependency scans, `--severity-threshold`, SARIF output, `continue-on-error` for uploading results before an explicit policy failure, and the behavior that secrets are unavailable to fork pull requests: https://docs.snyk.io/developer-tools/integrations/snyk-ci-cd-integrations/github-actions-for-snyk-setup-and-checking-for-vulnerabilities

GitHub documents `github/codeql-action/upload-sarif`, unique categories for multiple results from a commit, and the `security-events: write` permission: https://docs.github.com/en/code-security/how-tos/find-and-fix-code-vulnerabilities/integrate-with-existing-tools/upload-sarif-file

Applied policy: Trivy is mandatory and scans repository filesystem plus the pinned Prometheus and Alertmanager images for HIGH/CRITICAL vulnerabilities. Snyk is optional because it requires SNYK_TOKEN; if enabled it scans `backend/package.json` and fails on high or critical issues after SARIF upload. Neither scan is allowed to print secrets, and neither uses `snyk monitor` in pull requests.
