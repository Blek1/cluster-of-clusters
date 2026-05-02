#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

echo "==> Cleaning up previous state"
"${ROOT_DIR}/scripts/cleanup.sh"

echo "==> Bootstrapping Karmada"
"${ROOT_DIR}/scripts/bootstrap-karmada.sh"

echo "==> Checking status"
"${ROOT_DIR}/scripts/status.sh"

echo "==> Capturing artifacts"
"${ROOT_DIR}/scripts/capture-artifacts.sh"

echo "==> Setting up monitoring"
"${ROOT_DIR}/scripts/setup-monitoring.sh"

echo "==> All done!"
