#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

apply_dnscrypt() {
  echo "[dns] Applying dnscrypt-proxy Deployment/Service..."
  kubectl apply -f "${SCRIPT_DIR}/dnscrypt-proxy.yaml"
}

patch_coredns() {
  echo "[dns] Patching CoreDNS to forward to dnscrypt-proxy with fallback 8.8.8.8..."
  local svc_ip
  svc_ip="$(kubectl -n default get svc dnscrypt-proxy -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)"
  if [[ -z "${svc_ip}" ]]; then
    echo "[dns] ERROR: dnscrypt-proxy service IP not found; cannot patch CoreDNS."
    return 1
  fi
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        forward . ${svc_ip}:53 8.8.8.8 {
           policy sequential
           prefer_udp
        }
        prometheus :9153
        cache 30
        loop
        reload
        loadbalance
    }
EOF
  kubectl -n kube-system rollout restart deploy/coredns
}

# --- Execution ---
if [[ -f "${SCRIPT_DIR}/build.sh" ]]; then
  echo "[dns] Building DNS module..."
  (cd "${SCRIPT_DIR}" && ./build.sh)
fi

apply_dnscrypt
patch_coredns
