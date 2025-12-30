# Kubernetes Bootstrap (Ubuntu 24.04 / K8s 1.34)

A modular, robust installer for Kubernetes clusters on Ubuntu 24.04, optimized for modern hardware (NVIDIA GPUs, NVMe Storage) and restricted network environments (Proxy support).

## Usage

### 1. Bootstrap Master Node
Run this on the machine intended to be the control plane.

```bash
# Basic Installation
sudo ./install-master.sh

# With Optional Modules (e.g., DNS over HTTPS)
sudo ./install-master.sh --modules "dns"

# With HTTP Proxy (if behind a corporate firewall/VPN)
sudo ./install-master.sh --proxy "http://127.0.0.1:10888"
```

**What happens?**
- Installs Containerd 2.2, Runc 1.4, K8s 1.34.
- Initializes the cluster (`kubeadm init`).
- Sets up Calico CNI (VXLAN, Iptables mode).
- Auto-detects NVIDIA GPUs and installs drivers/runtime.
- Deploys Longhorn (Storage) and a Local Registry.

### 2. Bootstrap Worker Node
Run this on additional nodes to join them to the cluster.

```bash
# Join the cluster (paste the command output from master initialization)
sudo ./install-worker.sh <kubeadm-join-command-flags...>

# Example:
sudo ./install-worker.sh 192.168.1.133:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

### 3. Mesh Overlay (VLESS)
Use this when nodes cannot reach each other directly. The mesh puts nodes on `10.10.0.0/24` (by default) and rewrites kubelet node IPs to mesh addresses.

**Master (control-plane)**:
```bash
sudo ./vless-mesh/setup-server --pub-addr <MASTER_PUBLIC_IP>
# Optional: --mesh-ip auto (default), --image-registry registry:443/
```
Notes:
- `setup-server` starts tinc/xray, writes `/etc/vless-mesh/*`, and (by default) sets kubelet `--node-ip` to the mesh IP.
- If `kubectl` is configured, it auto-applies the mesh client DaemonSet to non-control-plane nodes (use `--no-k8s-clients` to skip).

**Worker (single command)**:
```bash
sudo ./install-worker.sh \
  --mesh-server-addr <MASTER_PUBLIC_IP> \
  --mesh-token <TOKEN> \
  --mesh-ip auto \
  <kubeadm-join-flags...>
```
Notes:
- `install-worker.sh` disables proxy envs before `kubeadm join`.
- If you want to pre-bootstrap mesh before joining, run the same command without the join flags.

---

## Project Description

This repository contains a set of modular scripts designed to automate the lifecycle of a Kubernetes cluster. It solves common "Day 0" problems like GPU configuration, storage persistence, and networking quirks in home/lab environments.

### Core Architecture

*   **Modular Design**: Logic is split into `k8s-bootstrap` (shared core), `install-master.sh` (control plane logic), and `install-worker.sh` (join logic).
*   **Strict Versioning**: Defaults to Kubernetes **v1.34.3**, Containerd **v2.2.0**, and NVIDIA Toolkit **v1.18**.
*   **Self-Healing**: Scripts automatically check for common host misconfigurations (e.g., missing `localhost` in `/etc/hosts`, proxy settings) and fix them.

### Key Features

#### 1. NVIDIA GPU Support
The installer automatically detects if an NVIDIA GPU is present (`lspci`).
*   Installs the **NVIDIA Container Toolkit**.
*   Configures `containerd` to use the `nvidia` runtime.
*   Deploys the **NVIDIA Device Plugin** (v1.0.0-beta4) and a custom `RuntimeClass`.
*   *Result*: Pods can request `nvidia.com/gpu: 1` immediately.

#### 2. Storage (Longhorn)
*   Deploys **Longhorn** for distributed block storage.
*   Includes a custom `longhorn-disk-prep` DaemonSet that auto-formats and mounts unmounted disks (>5GB) as Longhorn storage.
*   Patches the default StorageClass to `longhorn-ssd` for better performance.

#### 3. Networking (Calico)
*   Uses **Calico v3.31** in Iptables mode (stable for LXD/VMs).
*   Hardens configuration to strictly use physical interfaces (`enp*`) to avoid MTU issues with virtual bridges.
*   Automatically manages `IPPool` (VXLAN) to prevent overlap with local networks.

#### 4. Local Registry
*   Deploys a secure local Docker registry inside the cluster.
*   Generates self-signed TLS certificates.
*   Installs a DaemonSet to trust these certificates on all nodes automatically.

### Technical Notes

*   **Proxy Handling**: The scripts respect `--proxy` flags and persist them into `systemd` configuration for `containerd`, ensuring images can be pulled even if the shell proxy environment variable is unset.
*   **Safety**: The installer creates uninstallation scripts (`uninstall-master.sh`, `uninstall-worker.sh`) to wipe the node clean if a reset is needed.
