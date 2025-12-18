#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Must run as root."
  exit 1
fi

"${REPO_ROOT}/k8s-bootstrap/uninstall-kubeadm.sh"
echo "Master node uninstalled."
