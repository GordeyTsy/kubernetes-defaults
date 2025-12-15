# Session Startup & Operations Guide

Use these steps when opening a new shell so `kubectl`/manifests work and storage auto-provisioning picks up your disks.

## Start a fresh session
1) Ensure kubeconfig is in place (from bootstrap it is `/home/gt/.kube/config`).  
2) Disable proxies for cluster access:  
   `env -u HTTPS_PROXY -u https_proxy -u HTTP_PROXY -u http_proxy -u ALL_PROXY -u all_proxy kubectl get nodes`
3) Verify cluster is reachable and Longhorn is up:  
   `kubectl -n longhorn-system get pods -o wide`
4) If `vless-mesh` is enabled, remember the master hosts the mesh server **inside a Pod**. Use the mesh virtual IP you assigned (e.g., `10.10.0.X`) when talking to the cluster API instead of the host IP; adjust kubeconfig/clients after the mesh is up.
5) Веб-UI vless-mesh доступен только с мастер-ноды по её mesh-IP. Страница `/login`: вход для зарегистрированных и форма заявки (почта + комментарий). Админ может смотреть/подтверждать заявки в UI (временный режим: добавить `?admin=1` к URL).

## Run bootstrap (host-based)
```
sudo ./bootstrap-master.sh --yes \
  --k8s-version 1.33.0 \
  --containerd-version 2.0.3 \
  --modules "dns gpu registry storage vless-mesh"
# ph-network is maintained in a separate repository now.
```
Notes: script resets kubeadm unless `--skip-reset`; installs containerd/runc, Calico, and applies each module (uses install.sh if present).

## Storage (Longhorn) workflow
- Install/refresh Longhorn + StorageClasses + auto disk prep:  
  `env -u HTTPS_PROXY -u https_proxy -u HTTP_PROXY -u http_proxy -u ALL_PROXY -u all_proxy LONGHORN_ALLOW_CP=1 ./storage/install.sh`
- Auto disk prep DaemonSet behavior (`longhorn-disk-prep` in `longhorn-system`):  
  - Scans disks/partitions (`sd*`, `vd*`, `xvd*`, `nvme*`, `mmcblk*`) via host namespace.  
  - Uses disks/partitions with ext4 or no FS; skips system mounts (`/`, `/boot*`, `/usr*`, `/opt*`, `/run*`, `/home*`).  
  - If already ext4 and mounted (e.g., `/mnt/hard-data`, `/mnt/VirtualMachineRepository`), with ≥8GiB free, it patches Longhorn node disk config to use that mountpoint.  
  - If no FS: wipe + mkfs.ext4, mount under `/var/lib/longhorn/disks/<name>`, add to fstab, and patch node config.  
  - To re-run: `kubectl -n longhorn-system rollout restart ds/longhorn-disk-prep`
- If a disk still shows under `/var/lib/longhorn/disks/*` but you want to use an existing mount (e.g., `/mnt/hard-data`):  
  1) Unmount the old path: `sudo umount /var/lib/longhorn/disks/<name>`  
  2) Remove related fstab line(s) under `/var/lib/longhorn/disks/...`  
  3) Ensure the desired mount is active (ext4, ≥8GiB free).  
  4) Restart DaemonSet as above; it will patch Longhorn with the live mountpoint.

## Quick commands
- Check Longhorn disks on node: `kubectl get nodes gt-pc -o json | jq -r '.metadata.annotations["node.longhorn.io/default-disks-config"]' | jq .`
- Forward Longhorn UI: `kubectl -n longhorn-system port-forward svc/longhorn-frontend 9999:80`

## Control-plane IP changed?
Use the helper to retarget manifests/certs after the host IP moves:
`sudo k8s-bootstrap/fix-control-plane-ip.sh <new_ip>`
Then verify without proxies: `env -u HTTPS_PROXY -u https_proxy -u HTTP_PROXY -u http_proxy -u ALL_PROXY -u all_proxy kubectl get nodes`.

## VIP / kube-vip for API
Bootstrap supports setting a control-plane VIP (ARP via kube-vip) so new nodes/clients hit a stable endpoint:
- Run master bootstrap with `--control-plane-vip <vip>` (optionally `--vip-interface <if>`). The script sets `controlPlaneEndpoint` to the VIP and drops a static kube-vip pod under `/etc/kubernetes/manifests/`.
- Verify kube-vip: `kubectl -n kube-system get pod kube-vip-*` and `ip addr show <if>` contains the VIP.

## Public/mesh API endpoint (no VIP)
If you have a stable API endpoint that is not an ARP VIP (public IP / mesh IP / DNS), use:
- `sudo ./bootstrap-master.sh --public-api-endpoint <host:port> ...` to set kubeadm `controlPlaneEndpoint` and retarget kubeconfigs.

## Client/worker bootstrap (mesh-aware)
Use `--client-only` to install containerd + kubeadm/kubelet/kubectl without control-plane init; optional helpers:
- Join: pass `--join-command "<kubeadm join ...>"`.
- Mesh client: `--mesh-server-addr <srv> --mesh-ip <ip> --mesh-token <token> [--mesh-pub-addr <addr>] [--mesh-dial-only]` to auto-run `vless-mesh/setup-client` so API is reachable via mesh.
