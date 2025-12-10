# kubernetes-defaults

Opinionated kubeadm bootstrap plus a grab‑bag of cluster modules and mesh tooling. Use `bootstrap-master.sh` on a fresh Ubuntu host to bring up a control-plane and apply the bundled modules.

## Layout
- `bootstrap-master.sh` — thin wrapper around `k8s-bootstrap/bootstrap.sh` for end-to-end control-plane bootstrap. Installs runc + containerd (latest upstream by default), kubeadm/kubelet/kubectl (latest stable from pkgs.k8s.io by default), deploys Calico, and applies selected modules (`dns gpu registry storage vless-mesh` by default; add `--with-ph-network` to include `ph-network`).
- `k8s-bootstrap/` — bootstrap logic and host-prep notes; `bootstrap.sh` contains the main flow, `dev/setup.sh` has the LUKS + systemd-nspawn experiment.
- `gpu/` — NVIDIA support: installs the device plugin DaemonSet + RuntimeClass, expects nodes labeled `nvidia.com/gpu.present=true` (labeling is auto-done by bootstrap when a GPU + toolkit are detected).
- `dns/` — dnscrypt-proxy Deployment + Service, CoreDNS patched to forward to it with fallback 8.8.8.8.
- `dns/` — dnscrypt-proxy container image (`Dockerfile`, `build.sh`) and a simple deployment manifest for running it on node `k8s-hdd`.
- `registry/` — private Docker registry with TLS: deployment/service, TLS materials under `tls/`, and a daemonset that propagates the registry CA + hosts.toml into every node runtime (containerd/docker).
- `storage/` — Longhorn references plus two StorageClasses (`longhorn-ssd`, `longhorn-hdd`). `storage/install.sh` installs Longhorn (default v1.10.0), untaints control-plane/master nodes for single-node clusters, deploys a DaemonSet that auto-prepares free disks and patches Longhorn node disk config, and applies the StorageClasses. Set `APPLY_STORAGE_TEST=1` to also create a `storage-test` namespace with the sample PVC/Pod under `storage/test/`.
- `gpu/` — note on making `nvidia-container-runtime` the default runtime for containerd so the NVIDIA device plugin can see GPUs.
- `vless-mesh/` — VLESS+Reality transport carrying a tinc L2 mesh; includes `setup-server`/`setup-client` scripts, Docker/compose/k8s deployment helpers, and a small Django backend (`backend/`) with a static web UI (`web/`).
- `ph-network/` — prompt with requirements for flashing Xiaomi AX3000T to OpenWrt and desired LAN/DNS behavior.

## Fresh session checklist
- Use kubeconfig from bootstrap: `/home/gt/.kube/config`.
- Уберите прокси перед kubectl: `env -u HTTPS_PROXY -u https_proxy -u HTTP_PROXY -u http_proxy -u ALL_PROXY -u all_proxy kubectl get nodes`.
- Проверить Longhorn: `kubectl -n longhorn-system get pods -o wide`.

## Bootstrapping a control-plane
```bash
sudo ./bootstrap-master.sh --yes \
  --k8s-version 1.33.0 \
  --containerd-version 2.0.3 \
  --modules "dns gpu registry storage vless-mesh"
# add --with-ph-network to apply that module too
```
If you omit versions, the script pulls the latest stable Kubernetes from pkgs.k8s.io and the latest upstream runc/containerd. It resets any existing kubeadm state (unless `--skip-reset`), installs prerequisites, runs `kubeadm init` with Calico, then applies manifests or `install.sh` found in each selected module directory. Use `--wipe-all` for a full teardown (kubeadm reset + purge k8s/containerd/docker + remove data/config) before bootstrapping. Docker Engine (docker-ce + containerd.io) is installed automatically for image builds.

Bootstrap order: cluster core → Calico → storage (Longhorn) → registry (PVC on Longhorn, prefers `longhorn-hdd`) → build/push module images (e.g. `dns/`) → remaining modules. DNS module patches CoreDNS to use dnscrypt-proxy by default with fallback 8.8.8.8.

## Storage details (Longhorn + авто диски)
- Установка/обновление: `env -u HTTPS_PROXY -u https_proxy -u HTTP_PROXY -u http_proxy -u ALL_PROXY -u all_proxy LONGHORN_ALLOW_CP=1 ./storage/install.sh`
- Auto disk prep DaemonSet (`longhorn-disk-prep`):
  - Сканы в host namespace (`lsblk`) и берет диски/разделы `sd*|vd*|xvd*|nvme*|mmcblk*` с ext4 или без ФС.
  - Если ФС нет — `wipefs + mkfs.ext4`, монтирует в `/var/lib/longhorn/disks/<name>`, добавляет в fstab и аннотацию `node.longhorn.io/default-disks-config`.
  - Если ext4 уже смонтирован (например `/mnt/hard-data`, `/mnt/VirtualMachineRepository`) и свободно ≥8ГБ, патчит Longhorn с этим mountpoint (системные точки `/`, `/boot*`, `/usr*`, `/opt*`, `/run*`, `/home*` пропускает).
  - Перезапуск: `kubectl -n longhorn-system rollout restart ds/longhorn-disk-prep`
- Сменить mountpoint на существующий (если раньше примонтировало в `/var/lib/longhorn/disks/...`):
  1) `sudo umount /var/lib/longhorn/disks/<disk>`
  2) Удалить строку из `/etc/fstab`, где указан этот путь.
  3) Убедиться, что нужный ext4-монтаж активен и свободно ≥8ГБ.
  4) `kubectl -n longhorn-system rollout restart ds/longhorn-disk-prep` — аннотация обновится на реальный путь.
