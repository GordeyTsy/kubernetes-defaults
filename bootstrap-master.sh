#!/usr/bin/env bash
set -euo pipefail

# Wrapper to keep backwards compatibility; real bootstrap logic now lives in k8s-bootstrap/bootstrap.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/k8s-bootstrap/bootstrap.sh" "$@"
