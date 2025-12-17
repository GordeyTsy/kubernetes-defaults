И надо что бы в coredns был из /etc/resolv.conf в в /etc/resolv.conf указан был этот
➜  kubernetes-defaults git:(main) ✗ sudo ./bootstrap-master.sh --yes --wipe-all
[sudo] password for gt:
[21:35:00] Installing base prerequisites ...
Get:1 https://linux.teamviewer.com/deb stable InRelease [11.9 kB]
Get:2 https://dl.google.com/linux/chrome/deb stable InRelease [1,825 B]
Hit:3 https://nvidia.github.io/libnvidia-container/stable/deb/amd64  InRelease
Hit:4 https://cli.github.com/packages stable InRelease
Get:5 https://download.docker.com/linux/ubuntu noble InRelease [48.5 kB]
Hit:6 https://nvidia.github.io/libnvidia-container/stable/ubuntu18.04/amd64  InRelease
Hit:7 https://ppa.launchpadcontent.net/wireshark-dev/stable/ubuntu noble InRelease
Get:8 https://dl.google.com/linux/chrome/deb stable/main amd64 Packages [1,210 B]
Get:9 https://download.docker.com/linux/ubuntu noble/stable amd64 Packages [40.0 kB]
Get:10 http://security.ubuntu.com/ubuntu noble-security InRelease [126 kB]
Get:11 http://security.ubuntu.com/ubuntu noble-security/main amd64 Packages [1,349 kB]
Get:12 http://security.ubuntu.com/ubuntu noble-security/main i386 Packages [358 kB]
Get:13 http://security.ubuntu.com/ubuntu noble-security/main amd64 Components [21.5 kB]
Get:14 http://security.ubuntu.com/ubuntu noble-security/restricted amd64 Components [212 B]
Get:15 http://security.ubuntu.com/ubuntu noble-security/universe amd64 Packages [915 kB]
Get:16 http://security.ubuntu.com/ubuntu noble-security/universe i386 Packages [565 kB]
Get:17 http://security.ubuntu.com/ubuntu noble-security/universe amd64 Components [71.4 kB]
Get:18 http://security.ubuntu.com/ubuntu noble-security/multiverse amd64 Components [208 B]
Hit:19 http://ru.archive.ubuntu.com/ubuntu noble InRelease
Hit:20 http://download.virtualbox.org/virtualbox/debian noble InRelease
Get:21 http://ru.archive.ubuntu.com/ubuntu noble-updates InRelease [126 kB]
Get:23 http://ru.archive.ubuntu.com/ubuntu noble-backports InRelease [126 kB]
Get:24 http://ru.archive.ubuntu.com/ubuntu noble-updates/main amd64 Packages [1,627 kB]
Get:25 http://ru.archive.ubuntu.com/ubuntu noble-updates/main i386 Packages [559 kB]
Get:26 http://ru.archive.ubuntu.com/ubuntu noble-updates/main amd64 Components [175 kB]
Get:27 http://ru.archive.ubuntu.com/ubuntu noble-updates/restricted amd64 Components [212 B]
Get:28 http://ru.archive.ubuntu.com/ubuntu noble-updates/universe i386 Packages [990 kB]
Get:29 http://ru.archive.ubuntu.com/ubuntu noble-updates/universe amd64 Packages [1,501 kB]
Get:30 http://ru.archive.ubuntu.com/ubuntu noble-updates/universe amd64 Components [378 kB]
Get:31 http://ru.archive.ubuntu.com/ubuntu noble-updates/multiverse amd64 Components [940 B]
Get:32 http://ru.archive.ubuntu.com/ubuntu noble-backports/main amd64 Components [7,132 B]
Get:33 http://ru.archive.ubuntu.com/ubuntu noble-backports/restricted amd64 Components [216 B]
Get:34 http://ru.archive.ubuntu.com/ubuntu noble-backports/universe amd64 Components [11.0 kB]
Get:35 http://ru.archive.ubuntu.com/ubuntu noble-backports/multiverse amd64 Components [212 B]
Hit:22 https://prod-cdn.packages.k8s.io/repositories/isv:/kubernetes:/core:/stable:/v1.33/deb  InRelease
Fetched 9,011 kB in 10s (866 kB/s)
Reading package lists... Done
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
apt-transport-https is already the newest version (2.8.3).
ca-certificates is already the newest version (20240203).
curl is already the newest version (8.5.0-2ubuntu10.6).
gnupg is already the newest version (2.4.4-2ubuntu17.3).
lsb-release is already the newest version (12.0-2).
software-properties-common is already the newest version (0.99.49.3).
pciutils is already the newest version (1:3.10.0-2build1).
0 upgraded, 0 newly installed, 0 to remove and 45 not upgraded.
[21:35:16] Performing hard wipe (kubeadm reset + purge packages + remove state)...
[preflight] Running pre-flight checks
W1208 21:35:17.048874 1025885 removeetcdmember.go:106] [reset] No kubeadm config, using etcd pod spec to get data directory
[reset] Stopping the kubelet service
[reset] Unmounting mounted directories in "/var/lib/kubelet"
W1208 21:35:17.055360 1025885 cleanupnode.go:105] [reset] Failed to remove containers: failed to create new CRI runtime service: validate service connection: validate CRI v1 runtime API for endpoint "unix:///var/run/containerd/containerd.sock": rpc error: code = Unavailable desc = connection error: desc = "transport: Error while dialing: dial unix /var/run/containerd/containerd.sock: connect: no such file or directory"
[reset] Deleting contents of directories: [/etc/kubernetes/manifests /var/lib/kubelet /etc/kubernetes/pki]
[reset] Deleting files: [/etc/kubernetes/admin.conf /etc/kubernetes/super-admin.conf /etc/kubernetes/kubelet.conf /etc/kubernetes/bootstrap-kubelet.conf /etc/kubernetes/controller-manager.conf /etc/kubernetes/scheduler.conf]

The reset process does not perform cleanup of CNI plugin configuration,
network filtering rules and kubeconfig files.

For information on how to perform this cleanup manually, please see:
    https://k8s.io/docs/reference/setup-tools/kubeadm/kubeadm-reset/

containerd.io was already not on hold.
containerd was already not on hold.
runc was already not on hold.
docker.io was already not on hold.
cri-tools was already not on hold.
kubernetes-cni was already not on hold.
Canceled hold on kubeadm.
Canceled hold on kubelet.
Canceled hold on kubectl.
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
Package 'containerd.io' is not installed, so not removed
Package 'containerd' is not installed, so not removed
Package 'runc' is not installed, so not removed
Package 'docker.io' is not installed, so not removed
The following package was automatically installed and is no longer required:
  conntrack
Use 'sudo apt autoremove' to remove it.
The following packages will be REMOVED:
  cri-tools* kubeadm* kubectl* kubelet* kubernetes-cni*
0 upgraded, 0 newly installed, 5 to remove and 42 not upgraded.
After this operation, 351 MB disk space will be freed.
(Reading database ... 321681 files and directories currently installed.)
Removing kubeadm (1.33.0-1.1) ...
Removing cri-tools (1.33.0-1.1) ...
Removing kubectl (1.33.0-1.1) ...
Removing kubelet (1.33.0-1.1) ...
Removing kubernetes-cni (1.6.0-1.1) ...
dpkg: warning: while removing kubernetes-cni, directory '/opt/cni/bin' not empty so not removed
dpkg: warning: while removing kubernetes-cni, directory '/etc/cni/net.d' not empty so not removed
(Reading database ... 321630 files and directories currently installed.)
Purging configuration files for kubelet (1.33.0-1.1) ...
dpkg: warning: while removing kubelet, directory '/etc/kubernetes' not empty so not removed
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following packages will be REMOVED:
  conntrack
0 upgraded, 0 newly installed, 1 to remove and 42 not upgraded.
After this operation, 119 kB disk space will be freed.
(Reading database ... 321628 files and directories currently installed.)
Removing conntrack (1:1.4.8-1ubuntu1) ...
Processing triggers for man-db (2.12.0-4build2) ...
[21:36:53] Installing runc 1.2.5 ...
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
100 10.6M  100 10.6M    0     0  7279k      0  0:00:01  0:00:01 --:--:-- 10.6M
[21:36:55] Installing containerd 2.0.3 from upstream tarball ...
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
100 35.2M  100 35.2M    0     0  9665k      0  0:00:03  0:00:03 --:--:-- 10.9M
bin/
bin/ctr
bin/containerd-stress
bin/containerd
bin/containerd-shim-runc-v2
[21:37:01] NVIDIA GPU detected.
[21:37:01] Installing NVIDIA container toolkit ...
curl: (22) The requested URL returned error: 404
[21:37:01] WARN: NVIDIA repo not found for ubuntu24.04, trying fallback ubuntu22.04
Hit:1 https://dl.google.com/linux/chrome/deb stable InRelease
Hit:2 https://nvidia.github.io/libnvidia-container/stable/deb/amd64  InRelease
Hit:3 https://cli.github.com/packages stable InRelease
Hit:4 https://download.docker.com/linux/ubuntu noble InRelease
Hit:5 https://nvidia.github.io/libnvidia-container/stable/ubuntu18.04/amd64  InRelease
Hit:6 http://security.ubuntu.com/ubuntu noble-security InRelease
Hit:7 http://download.virtualbox.org/virtualbox/debian noble InRelease
Hit:8 http://ru.archive.ubuntu.com/ubuntu noble InRelease
Hit:9 http://ru.archive.ubuntu.com/ubuntu noble-updates InRelease
Hit:10 http://ru.archive.ubuntu.com/ubuntu noble-backports InRelease
Hit:11 https://linux.teamviewer.com/deb stable InRelease
Hit:12 https://ppa.launchpadcontent.net/wireshark-dev/stable/ubuntu noble InRelease
Reading package lists... Done
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
nvidia-container-toolkit is already the newest version (1.18.1-1).
0 upgraded, 0 newly installed, 0 to remove and 42 not upgraded.
INFO[0000] Using config version 2
INFO[0000] Using CRI runtime plugin name "io.containerd.grpc.v1.cri"
WARN[0000] Could not infer options from runtimes [runc crun]
INFO[0000] Wrote updated config to /etc/containerd/conf.d/99-nvidia.toml
INFO[0000] It is recommended that containerd daemon be restarted.
[21:37:09] Configuring containerd (systemd cgroups, optional NVIDIA runtime) ...
[21:37:09] Configuring kernel modules and sysctl ...
[21:37:09] Configuring Kubernetes apt repo for v1.34 ...
File '/etc/apt/keyrings/kubernetes-apt-keyring.gpg' exists. Overwrite? (y/N)