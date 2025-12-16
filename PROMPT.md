# Session Resume Prompt

Paste this into a fresh terminal to continue work exactly from the current state.

```bash
# Environment
cd /home/gt/projects/my/kubernetes-defaults
export KUBECONFIG=/home/gt/.kube/config
env -u HTTPS_PROXY -u https_proxy -u HTTP_PROXY -u http_proxy -u ALL_PROXY -u all_proxy kubectl get nodes

# Check Longhorn
env -u HTTPS_PROXY -u https_proxy -u HTTP_PROXY -u http_proxy -u ALL_PROXY -u all_proxy kubectl -n longhorn-system get pods -o wide

# If you need to reapply storage stack with auto-disks:
env -u HTTPS_PROXY -u https_proxy -u HTTP_PROXY -u http_proxy -u ALL_PROXY -u all_proxy LONGHORN_ALLOW_CP=1 ./storage/install.sh
env -u HTTPS_PROXY -u https_proxy -u HTTP_PROXY -u http_proxy -u ALL_PROXY -u all_proxy kubectl -n longhorn-system rollout restart ds/longhorn-disk-prep
```

## What is already done
- Cluster bootstrapped with kubeadm v1.33.0, containerd 2.0.3, runc 1.2.5; Calico installed.
- Longhorn v1.10.0 installed; StorageClasses `longhorn-ssd` and `longhorn-hdd` exist.
- Auto disk prep DaemonSet `longhorn-disk-prep` (namespace `longhorn-system`) is running. Behavior:
  - Scans host disks/partitions (`sd*|vd*|xvd*|nvme*|mmcblk*`) in host mount namespace.
  - Uses ext4 or empty devices; skips system mounts (`/`, `/boot*`, `/usr*`, `/opt*`, `/run*`, `/home*`).
  - If FS missing: wipe + mkfs.ext4, mounts under `/var/lib/longhorn/disks/<name>`, adds to fstab, patches `node.longhorn.io/default-disks-config`.
  - If already ext4 and mounted (e.g., `/mnt/hard-data`, `/mnt/VirtualMachineRepository`) with ≥8GiB free, patches Longhorn to use that mountpoint.
  - Restart it any time: `kubectl -n longhorn-system rollout restart ds/longhorn-disk-prep`.
- Current fstab (host) includes prior mounts under `/var/lib/longhorn/disks/*`. If you want Longhorn to use existing mounts (e.g., `/mnt/hard-data`, `/mnt/VirtualMachineRepository`):
  1) `sudo umount /var/lib/longhorn/disks/<disk>`
  2) Remove corresponding fstab lines pointing to `/var/lib/longhorn/disks/...`
  3) Ensure the desired ext4 mount is active and has ≥8GiB free.
  4) Restart DaemonSet (`rollout restart`) — it will patch Longhorn with the real mountpoint.

## Quick helpers
- Longhorn UI port-forward: `kubectl -n longhorn-system port-forward svc/longhorn-frontend 9999:80`
- See Longhorn disk config on node:  
  `kubectl get node gt-pc -o json | jq -r '.metadata.annotations["node.longhorn.io/default-disks-config"]' | jq .`
