#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[gpu] Applying NVIDIA device plugin (RuntimeClass + DaemonSet)..."
kubectl apply -f "${SCRIPT_DIR}/device-plugin.yaml"

if command -v lspci >/dev/null 2>&1 && lspci | grep -qi nvidia; then
  node_name="$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || hostname -s || hostname)"
  echo "[gpu] Labeling node ${node_name} with nvidia.com/gpu.present=true (if not already)..."
  kubectl label node "${node_name}" nvidia.com/gpu.present=true --overwrite || true
fi
