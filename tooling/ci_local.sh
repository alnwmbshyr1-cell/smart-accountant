#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
MODE="${1:-fast}"

if ! command -v flutter >/dev/null 2>&1 && [ -x /home/ubuntu/flutter/bin/flutter ]; then
  export PATH="/home/ubuntu/flutter/bin:${PATH}"
fi
command -v flutter >/dev/null 2>&1 || { echo "Flutter is not available in PATH" >&2; exit 127; }

fail() { echo "CI failed: $1" >&2; exit 1; }
step() { printf '\n==> %s\n' "$1"; }

run_fast() {
  step "Flutter dependencies"
  flutter pub get
  step "Dart formatting"
  dart format --output=none --set-exit-if-changed lib test tooling
  step "Static analysis"
  flutter analyze
  step "Unit and widget tests"
  flutter test test --exclude-tags=integration --concurrency=1
}

run_integration() {
  step "Integration tests"
  flutter test test/integration_workflow_test.dart --concurrency=1
  flutter test test/integration_full_workflow_test.dart --concurrency=1
}

run_coverage() {
  step "Full tests with coverage"
  flutter test --coverage --concurrency=1
  test -s coverage/lcov.info || fail "coverage/lcov.info is missing or empty"
  step "HTML coverage report"
  python3 tooling/generate_coverage_report.py
  python3 tooling/report_coverage.py > coverage/coverage_by_file.txt
  step "Coverage gate"
  awk -F: '
    /^LF:/ { total += $2 }
    /^LH:/ { hit += $2 }
    END {
      if (total == 0) exit 2
      coverage = 100 * hit / total
      printf "Coverage: %.2f%% (%d/%d)\n", coverage, hit, total
      if (coverage < 70) exit 1
    }
  ' coverage/lcov.info
}

run_performance() {
  step "Performance tests"
  if [ ! -d test/performance ]; then
    echo "test/performance not found; performance tests skipped"
    return 0
  fi
  mkdir -p performance
  /usr/bin/time -v -o performance/resource-usage.txt \
    flutter test test/performance --concurrency=1
}

run_security() {
  step "Secret scan"
  command -v gitleaks >/dev/null 2>&1 || fail "gitleaks is required for security mode"
  gitleaks detect --source . --redact --exit-code 1
  step "Dart dependency vulnerability scan"
  command -v osv-scanner >/dev/null 2>&1 || fail "osv-scanner is required for security mode"
  mkdir -p security
  osv-scanner scan source --lockfile=pubspec.lock \
    --format=sarif --output=security/osv-results.sarif
  step "GitHub Actions lint"
  if command -v actionlint >/dev/null 2>&1; then actionlint; else echo "actionlint not installed; skipped"; fi
}

case "$MODE" in
  fast) run_fast ;;
  integration) run_integration ;;
  coverage) run_coverage ;;
  full) run_fast; run_integration; run_coverage; run_performance ;;
  security) run_security ;;
  *)
    echo "Usage: $0 {fast|integration|coverage|full|security}" >&2
    exit 2
    ;;
esac

echo "CI mode '$MODE' completed successfully"
