#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROXY_FLAG=""

# Extract proxy flag if present to pass to install-kubeadm.sh
# We need to preserve other args for kubeadm join
JOIN_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --proxy)
      PROXY_FLAG="--proxy $2"
      shift 2
      ;;
    *)
      JOIN_ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Must run as root."
  exit 1
fi

echo "Installing Worker Node..."
"${REPO_ROOT}/k8s-bootstrap/install-kubeadm.sh" ${PROXY_FLAG}

if [[ ${#JOIN_ARGS[@]} -eq 0 ]]; then
  echo "Dependencies installed. Run 'kubeadm join ...' manually."
else
  echo "Joining cluster..."
  kubeadm join "${JOIN_ARGS[@]}"
fi
