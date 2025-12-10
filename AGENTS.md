# Session Startup & Operations Guide

Use these steps when opening a new shell so `kubectl`/manifests work and storage auto-provisioning picks up your disks.

## Start a fresh session
1) Ensure kubeconfig is in place (from bootstrap it is `/home/gt/.kube/config`).  
2) Disable proxies for cluster access:  
   `env -u HTTPS_PROXY -u https_proxy -u HTTP_PROXY -u http_proxy -u ALL_PROXY -u all_proxy kubectl get nodes`
3) Verify cluster is reachable and Longhorn is up:  
   `kubectl -n longhorn-system get pods -o wide`

## Run bootstrap (host-based)
```
sudo ./bootstrap-master.sh --yes \
  --k8s-version 1.33.0 \
  --containerd-version 2.0.3 \
  --modules "dns gpu registry storage vless-mesh"
# add --with-ph-network if needed
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

