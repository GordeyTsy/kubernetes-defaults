#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROXY_FLAG=""
PROXY_URL=""
MESH_SERVER_ADDR="${MESH_SERVER_ADDR:-}"
MESH_TOKEN="${MESH_TOKEN:-}"
MESH_IP="${MESH_IP:-auto}"
MESH_UUID="${MESH_UUID:-}"
MESH_PUB_ADDR="${MESH_PUB_ADDR:-}"
MESH_DIAL_ONLY="${MESH_DIAL_ONLY:-0}"
MESH_TOP_PEERS="${MESH_TOP_PEERS:-2}"
MESH_VLESS_PORT="${MESH_VLESS_PORT:-443}"
MESH_TINC_PORT="${MESH_TINC_PORT:-6060}"
MESH_REGISTRY_PORT="${MESH_REGISTRY_PORT:-9000}"
MESH_REALITY_DEST="${MESH_REALITY_DEST:-www.microsoft.com:443}"
MESH_DEPLOY="${MESH_DEPLOY:-host}"

usage() {
  cat <<'EOF'
Usage: install-worker.sh [options] <kubeadm-join-flags...>
  --proxy URL                 Proxy for install steps (disabled before join)
  --mesh-server-addr ADDR     Mesh server/peer address (required with --mesh-token)
  --mesh-token TOKEN          Mesh registry token (required with --mesh-server-addr)
  --mesh-ip IP|auto           Mesh IP (default: auto)
  --mesh-uuid UUID            Mesh UUID override
  --mesh-pub-addr ADDR        Public/DNS address for this node
  --mesh-dial-only            NAT outbound-only mode
  --mesh-top-peers N          Dial-only: keep top N peers (default 2)
  --mesh-vless-port PORT      VLESS port (default 443)
  --mesh-tinc-port PORT       tinc port (default 6060)
  --mesh-registry-port PORT   Registry port (default 9000)
  --mesh-reality-dest H:P     Reality dest/SNI (default www.microsoft.com:443)
  --mesh-deploy MODE          host|docker|compose|k8s (default host)
  -h, --help                  Show this help

Env overrides: MESH_SERVER_ADDR, MESH_TOKEN, MESH_IP, MESH_UUID, MESH_PUB_ADDR,
MESH_DIAL_ONLY, MESH_TOP_PEERS, MESH_VLESS_PORT, MESH_TINC_PORT,
MESH_REGISTRY_PORT, MESH_REALITY_DEST, MESH_DEPLOY
EOF
}

unset_proxy_env() {
  unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy NO_PROXY no_proxy ALL_PROXY all_proxy
}

setup_mesh() {
  if [[ -z "${MESH_SERVER_ADDR}" && -z "${MESH_TOKEN}" ]]; then
    return 0
  fi
  if [[ -z "${MESH_SERVER_ADDR}" || -z "${MESH_TOKEN}" ]]; then
    echo "MESH_SERVER_ADDR and MESH_TOKEN must both be set to bootstrap mesh." >&2
    exit 1
  fi
  local setup_script="${REPO_ROOT}/vless-mesh/setup-client"
  if [[ ! -x "${setup_script}" ]]; then
    echo "Missing ${setup_script}. Copy vless-mesh/ into this repo before running." >&2
    exit 1
  fi

  local args=(
    --server-addr "${MESH_SERVER_ADDR}"
    --token "${MESH_TOKEN}"
    --mesh-ip "${MESH_IP}"
    --vless-port "${MESH_VLESS_PORT}"
    --tinc-port "${MESH_TINC_PORT}"
    --registry-port "${MESH_REGISTRY_PORT}"
    --reality-dest "${MESH_REALITY_DEST}"
    --deploy "${MESH_DEPLOY}"
  )
  if [[ -n "${MESH_UUID}" ]]; then
    args+=(--mesh-uuid "${MESH_UUID}")
  fi
  if [[ -n "${MESH_PUB_ADDR}" ]]; then
    args+=(--pub-addr "${MESH_PUB_ADDR}")
  fi
  if [[ "${MESH_DIAL_ONLY}" == "1" ]]; then
    args+=(--dial-only --top-peers "${MESH_TOP_PEERS}")
  fi

  echo "Bootstrapping VLESS mesh..."
  "${setup_script}" "${args[@]}"
}

configure_kubelet_mesh_ip() {
  local mesh_ip=""
  local config_json="/etc/vless-mesh/config.json"
  if [[ ! -f "${config_json}" ]]; then
    return 0
  fi
  if command -v jq >/dev/null 2>&1; then
    mesh_ip="$(jq -r '.mesh_ip // empty' "${config_json}" 2>/dev/null || true)"
  elif command -v python3 >/dev/null 2>&1; then
    mesh_ip="$(python3 - <<'PY' "${config_json}" 2>/dev/null || true
import json
import sys
path = sys.argv[1]
try:
    with open(path) as fh:
        print(json.load(fh).get("mesh_ip", ""))
except Exception:
    pass
PY
)"
  fi
  if [[ -z "${mesh_ip}" ]]; then
    return 0
  fi

  set_kubelet_node_ip "${mesh_ip}"
}

set_kubelet_node_ip() {
  local mesh_ip="$1"
  local kubelet_file="/etc/default/kubelet"
  local tmp_file=""
  local updated=0

  if [[ -z "${mesh_ip}" ]]; then
    return 0
  fi
  if ! command -v systemctl >/dev/null 2>&1; then
    return 0
  fi
  if ! systemctl list-unit-files kubelet.service >/dev/null 2>&1; then
    return 0
  fi

  tmp_file="$(mktemp)"
  if [[ -f "${kubelet_file}" ]]; then
    while IFS= read -r line || [[ -n "${line}" ]]; do
      if [[ "${line}" == KUBELET_EXTRA_ARGS=* ]]; then
        local raw="${line#KUBELET_EXTRA_ARGS=}"
        raw="${raw%\"}"
        raw="${raw#\"}"
        raw="$(printf '%s' "${raw}" | sed -E 's/--node-ip=[^ ]+//g; s/[[:space:]]+/ /g; s/^ //; s/ $//')"
        if [[ -n "${raw}" ]]; then
          printf 'KUBELET_EXTRA_ARGS="%s --node-ip=%s"\n' "${raw}" "${mesh_ip}" >> "${tmp_file}"
        else
          printf 'KUBELET_EXTRA_ARGS=--node-ip=%s\n' "${mesh_ip}" >> "${tmp_file}"
        fi
        updated=1
      else
        printf '%s\n' "${line}" >> "${tmp_file}"
      fi
    done < "${kubelet_file}"
  fi
  if [[ "${updated}" -eq 0 ]]; then
    printf 'KUBELET_EXTRA_ARGS=--node-ip=%s\n' "${mesh_ip}" >> "${tmp_file}"
  fi
  mv "${tmp_file}" "${kubelet_file}"
  systemctl daemon-reload
  systemctl restart kubelet
}

# Extract proxy flag if present to pass to install-kubeadm.sh
# We need to preserve other args for kubeadm join
JOIN_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
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
    --mesh-server-addr)
      MESH_SERVER_ADDR="$2"
      shift 2
      ;;
    --mesh-token)
      MESH_TOKEN="$2"
      shift 2
      ;;
    --mesh-ip)
      MESH_IP="$2"
      shift 2
      ;;
    --mesh-uuid)
      MESH_UUID="$2"
      shift 2
      ;;
    --mesh-pub-addr)
      MESH_PUB_ADDR="$2"
      shift 2
      ;;
    --mesh-dial-only)
      MESH_DIAL_ONLY=1
      shift 1
      ;;
    --mesh-top-peers)
      MESH_TOP_PEERS="$2"
      shift 2
      ;;
    --mesh-vless-port)
      MESH_VLESS_PORT="$2"
      shift 2
      ;;
    --mesh-tinc-port)
      MESH_TINC_PORT="$2"
      shift 2
      ;;
    --mesh-registry-port)
      MESH_REGISTRY_PORT="$2"
      shift 2
      ;;
    --mesh-reality-dest)
      MESH_REALITY_DEST="$2"
      shift 2
      ;;
    --mesh-deploy)
      MESH_DEPLOY="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
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
  if [[ -n "${MESH_SERVER_ADDR}" || -n "${MESH_TOKEN}" ]]; then
    setup_mesh
    configure_kubelet_mesh_ip
  fi
  echo "Dependencies installed. Run 'kubeadm join ...' manually."
else
  setup_mesh
  configure_kubelet_mesh_ip
  echo "Joining cluster..."
  unset_proxy_env
  kubeadm join "${JOIN_ARGS[@]}"
fi
