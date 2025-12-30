#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
POD_CIDR="10.244.0.0/16"
MODULES=""
PROXY_FLAG=""
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Colors ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { printf "${GREEN}[%s] %s${NC}\n" "$(date +'%H:%M:%S')" "$*"; }
warn() { printf "${YELLOW}[%s] WARN: %s${NC}\n" "$(date +'%H:%M:%S')" "$*" >&2; }
die() { printf "${RED}[%s] ERROR: %s${NC}\n" "$(date +'%H:%M:%S')" "$*" >&2; exit 1; }

# --- Args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --modules)
      MODULES="$2"
      shift 2
      ;;
    --proxy)
      PROXY_FLAG="--proxy $2"
      PROXY_URL="$2"
      export HTTP_PROXY="$2"
      export HTTPS_PROXY="$2"
      export http_proxy="$2"
      export https_proxy="$2"
      export NO_PROXY="127.0.0.1,localhost,10.96.0.0/12,10.244.0.0/16,192.168.0.0/16"
      export no_proxy="$NO_PROXY"
      shift 2
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

if [[ "$(id -u)" -ne 0 ]]; then
  die "Must run as root."
fi

# --- Install Dependencies ---
log "Ensuring base dependencies..."
"${REPO_ROOT}/k8s-bootstrap/install-kubeadm.sh" ${PROXY_FLAG}

# Unset proxy variables for kubeadm to ensure direct communication with local API server
# Containerd has its own proxy config in systemd, so this is safe.
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy NO_PROXY no_proxy
log "Removing containerd proxy config..."
rm -f /etc/systemd/system/containerd.service.d/http-proxy.conf
systemctl daemon-reload
systemctl restart containerd

# --- Kubeadm Init ---
if [[ -f /etc/kubernetes/admin.conf ]]; then
  log "Cluster already existing (admin.conf found). Skipping init."
else
  log "Initializing Kubernetes master..."
  # IP_ADDR is not defined in the original script, assuming it's meant to be added or is defined elsewhere.
  # For now, using a placeholder or removing it if not defined.
  # Assuming IP_ADDR should be the primary IP of the host.
  IP_ADDR=$(hostname -I | awk '{print $1}')
  


  kubeadm init --pod-network-cidr="${POD_CIDR}" \
    --apiserver-cert-extra-sans="127.0.0.1,localhost,${IP_ADDR}" \
    --skip-token-print
  
  log "Configuring kubectl for root..."
  mkdir -p "$HOME/.kube"
  cp -f /etc/kubernetes/admin.conf "$HOME/.kube/config"
  chown "$(id -u):$(id -g)" "$HOME/.kube/config"
fi

export KUBECONFIG=/etc/kubernetes/admin.conf

# --- Helper Functions ---
wait_for_resource() {
  local type="$1"
  local name="$2"
  local ns="$3"
  local timeout="${4:-300s}"
  log "Waiting for ${type}/${name} in ${ns}..."
  if ! kubectl rollout status "${type}/${name}" -n "${ns}" --timeout="${timeout}"; then
    warn "Timeout waiting for ${type}/${name}. Checking logs..."
    kubectl logs -n "${ns}" -l app="${name}" --tail=20 || true
    return 1
  fi
}

ensure_kube_dns_policy() {
  if kubectl -n kube-system get svc kube-dns >/dev/null 2>&1; then
    local policy=""
    policy="$(kubectl -n kube-system get svc kube-dns -o jsonpath='{.spec.internalTrafficPolicy}' 2>/dev/null || true)"
    if [[ "${policy}" == "Local" ]]; then
      log "Resetting kube-dns internalTrafficPolicy=Cluster"
      kubectl -n kube-system patch svc kube-dns --type=merge -p '{"spec":{"internalTrafficPolicy":"Cluster"}}' >/dev/null 2>&1 || true
    fi
  fi
}

# --- Calico ---
log "Checking for localhost in /etc/hosts..."
if ! grep -q "127.0.0.1 localhost" /etc/hosts; then
  log "Adding '127.0.0.1 localhost' to /etc/hosts (Required for Calico Health Checks)..."
  echo "127.0.0.1 localhost" >> /etc/hosts
fi

log "Installing Calico..."
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.2/manifests/operator-crds.yaml || true
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.2/manifests/tigera-operator.yaml || true
    
log "Applying Calico Resources (Iptables mode)..."
kubectl apply -f "${REPO_ROOT}/calico-resources.yaml"

# Explicitly create IPPool to ensure Calico starts (Operator often waits for this)
log "Creating Calico IPPool..."
cat <<EOF | kubectl apply -f -
apiVersion: crd.projectcalico.org/v1
kind: IPPool
metadata:
  name: default-ipv4-ippool
spec:
  cidr: 10.244.0.0/16
  ipipMode: Never
  vxlanMode: Always
  natOutgoing: true
EOF

log "Waiting for Calico to initialize..."
wait_for_resource deployment tigera-operator tigera-operator 120s

# Wait for Calico System (triggered by Installation CR)
log "Waiting for Calico Node DaemonSet to appear..."
for i in {1..60}; do
  if kubectl get ds calico-node -n calico-system >/dev/null 2>&1; then break; fi
  sleep 5
done
wait_for_resource daemonset calico-node calico-system 300s
log "Calico is Ready."

ensure_kube_dns_policy

log "Untainting control-plane..."
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true

# --- NVIDIA RuntimeClass ---
if lspci | grep -qi nvidia; then
  log "Applying NVIDIA RuntimeClass..."
  kubectl apply -f "${REPO_ROOT}/gpu/runtime-class.yaml"
  
  log "Installing NVIDIA Device Plugin (DaemonSet)..."
  kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/1.0.0-beta4/nvidia-device-plugin.yml || warn "Failed to install NVIDIA Device Plugin. Please install manually."
fi

# --- Module Logic ---
# Mandatory modules: Storage -> Registry
# Optional modules: others (passed via --modules)

has_module() { [[ " $MODULES " == *" $1 "* ]]; }

# 1. Storage (Mandatory)
log "Applying Module: STORAGE (Longhorn + Disk Prep)"
(cd "${REPO_ROOT}/storage" && ./install.sh)
kubectl apply -f "${REPO_ROOT}/storage/longhorn-disk-prep.yaml"

log "Waiting for Longhorn components..."
# Longhorn install.sh applies files, but we need to wait for the manager
# Note: Longhorn manager often takes a bit to create daemonsets
for i in {1..60}; do
  if kubectl get ds longhorn-manager -n longhorn-system >/dev/null 2>&1; then break; fi
  sleep 5
done
wait_for_resource daemonset longhorn-manager longhorn-system 300s
log "Storage (Longhorn) is Ready."

# 2. Registry (Mandatory)
log "Applying Module: REGISTRY"

if kubectl get secret -n default registry-tls >/dev/null 2>&1; then
    log "Registry secret already exists."
else 
    log "Generating Registry Certs..."
    mkdir -p /tmp/reg-certs
    openssl req -x509 -nodes -newkey rsa:2048 \
      -keyout /tmp/reg-certs/tls.key \
      -out /tmp/reg-certs/tls.crt \
      -days 3650 \
      -subj "/CN=registry.default.svc.cluster.local" \
      -addext "subjectAltName=DNS:registry,DNS:registry.default,DNS:registry.default.svc,DNS:registry.default.svc.cluster.local"

    log "Creating Secret via kubectl..."
    kubectl create secret tls registry-tls --cert=/tmp/reg-certs/tls.crt --key=/tmp/reg-certs/tls.key -n default || true
    rm -rf /tmp/reg-certs
fi

log "Applying Registry Manifests..."
kubectl apply -f "${REPO_ROOT}/registry/registry-cert-daemonset.yaml"
kubectl apply -f "${REPO_ROOT}/registry/registry.yaml"

log "Waiting for Registry to be ready..."
wait_for_resource deployment registry default 300s
log "Registry is Ready."
sleep 5

systemctl restart docker

# 3. DNS
if has_module "dns"; then
  log "Applying Module: DNS (CoreDNS Patching)"
  # Assuming dns/install.sh handles this or we apply manifests
  if [[ -f "${REPO_ROOT}/dns/install.sh" ]]; then
    (cd "${REPO_ROOT}/dns" && ./install.sh)
  else
    warn "DNS module requested but no install script found."
  fi
fi

# 4. Other Modules
for m in $MODULES; do
  [[ "$m" == "storage" || "$m" == "registry" || "$m" == "dns" ]] && continue
  
  log "Applying Module: $m"
  MOD_DIR="${REPO_ROOT}/${m}"
  
  if [[ -f "${MOD_DIR}/build.sh" ]]; then
    # We need to build/push to registry first?
    # User said: "All non-mandatory modules first build image and push to our registry:443"
    # Assuming registry is up.
    log "Building module $m..."
    (cd "${MOD_DIR}" && ./build.sh)
  fi
  
  if [[ -f "${MOD_DIR}/install.sh" ]]; then
    (cd "${MOD_DIR}" && ./install.sh)
  elif [[ -d "${MOD_DIR}" ]]; then
    kubectl apply -f "${MOD_DIR}/"
  else
    warn "Module $m not found."
  fi
done

log "Master setup complete."
