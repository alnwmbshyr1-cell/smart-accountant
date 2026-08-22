#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

chmod +x tooling/ci_local.sh .githooks/pre-push

git config core.hooksPath .githooks

echo "Git hooks installed from .githooks"
echo "pre-push will run: ./tooling/ci_local.sh full"
echo "To bypass once for emergency use: SKIP_LOCAL_CI=1 git push"
