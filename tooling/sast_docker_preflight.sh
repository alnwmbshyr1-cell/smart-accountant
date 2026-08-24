#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${SAST_OUT_DIR:-$ROOT/.sast-local}"
SEMGREP_IMAGE="${SEMGREP_IMAGE:-semgrep/semgrep:1.136.0}"
TRIVY_IMAGE="${TRIVY_IMAGE:-aquasec/trivy:0.59.1}"
mkdir -p "$OUT_DIR"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required for the local SAST preflight." >&2
  exit 2
fi

run_semgrep() {
  docker run --rm \
    --user "$(id -u):$(id -g)" \
    --cap-drop=ALL \
    --security-opt=no-new-privileges \
    -v "$ROOT:/src:ro" \
    -v "$OUT_DIR:/out" \
    "$SEMGREP_IMAGE" \
    semgrep --config p/python --config p/javascript --config p/secrets \
      --sarif --output /out/semgrep.sarif /src
}

run_trivy() {
  docker run --rm \
    --user "$(id -u):$(id -g)" \
    --cap-drop=ALL \
    --security-opt=no-new-privileges \
    -v "$ROOT:/src:ro" \
    -v "$OUT_DIR:/out" \
    "$TRIVY_IMAGE" fs /src \
      --scanners vuln,misconfig,secret \
      --severity HIGH,CRITICAL \
      --format sarif --output /out/trivy-webhook.sarif \
      --exit-code 1
}

semgrep_status=0
trivy_status=0
run_semgrep || semgrep_status=$?
run_trivy || trivy_status=$?

python3 - "$OUT_DIR" "$semgrep_status" "$trivy_status" <<'PY'
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
semgrep_status = int(sys.argv[2])
trivy_status = int(sys.argv[3])
summary = {
    "status": "PASS" if semgrep_status == 0 and trivy_status == 0 else "FAIL",
    "semgrep_exit": semgrep_status,
    "trivy_exit": trivy_status,
    "reports": [str(p.name) for p in sorted(out.glob("*.sarif"))],
}
(out / "summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
print(json.dumps(summary, sort_keys=True))
PY

if [[ "$semgrep_status" -ne 0 || "$trivy_status" -ne 0 ]]; then
  echo "SAST preflight failed; inspect $OUT_DIR/*.sarif" >&2
  exit 1
fi
