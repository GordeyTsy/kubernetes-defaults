#!/usr/bin/env bash
set -euo pipefail

# Longhorn bootstrap + StorageClasses + optional test PVC/Pod.
# Env knobs:
#   LONGHORN_VERSION          Longhorn release (default 1.10.0)
#   LONGHORN_ALLOW_CP=1       Untaint control-plane/master nodes for single-node installs (default on)
#   APPLY_STORAGE_TEST=0      Create storage-test namespace + PVC/Pod sample when set to 1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LONGHORN_VERSION="${LONGHORN_VERSION:-1.10.0}"
LONGHORN_URL="${LONGHORN_URL:-https://raw.githubusercontent.com/longhorn/longhorn/v${LONGHORN_VERSION}/deploy/longhorn.yaml}"
LONGHORN_ALLOW_CP="${LONGHORN_ALLOW_CP:-1}"
APPLY_STORAGE_TEST="${APPLY_STORAGE_TEST:-0}"

echo "[storage] Installing Longhorn ${LONGHORN_VERSION} from ${LONGHORN_URL}"
kubectl apply -f "${LONGHORN_URL}"

# Make sure Longhorn respects the node annotation-based disk config by requiring the
# create-default-disk label; otherwise it falls back to a single /var/lib/longhorn disk.
echo "[storage] Waiting for Longhorn CRDs to become available ..."
if kubectl wait --for=condition=Established --timeout=120s crd/settings.longhorn.io crd/nodes.longhorn.io >/dev/null 2>&1; then
  echo "[storage] Enabling create-default-disk-labeled-nodes (honor auto disk prep annotations)"
  kubectl -n longhorn-system patch setting create-default-disk-labeled-nodes --type merge -p '{"value":"true"}' >/dev/null 2>&1 || true
else
  echo "[storage] WARN: Longhorn CRDs not ready; skipping create-default-disk-labeled-nodes patch"
fi

if [[ "${LONGHORN_ALLOW_CP}" == "1" ]]; then
  echo "[storage] Allowing scheduling on control-plane/master nodes (single-node friendly)"
  kubectl taint nodes --all node-role.kubernetes.io/control-plane- 2>/dev/null || true
  kubectl taint nodes --all node-role.kubernetes.io/master- 2>/dev/null || true
fi

echo "[storage] Deploying auto disk prep DaemonSet"
kubectl apply -f "${SCRIPT_DIR}/longhorn-disk-prep.yaml"

echo "[storage] Applying StorageClasses"
kubectl apply -f "${SCRIPT_DIR}/storageclasses.yaml"

if [[ "$APPLY_STORAGE_TEST" == "1" ]]; then
  kubectl get namespace storage-test >/dev/null 2>&1 || kubectl create namespace storage-test
  kubectl apply -f "${SCRIPT_DIR}/test/pvc-ssd.yaml" -n storage-test
  kubectl apply -f "${SCRIPT_DIR}/test/pod.yaml" -n storage-test
else
  echo "[storage] Skipping test PVC/Pod (set APPLY_STORAGE_TEST=1 to enable)."
fi
