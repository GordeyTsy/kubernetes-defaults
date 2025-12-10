# Checklist: Longhorn storage

- [ ] kubectl доступ к кластеру: `env -u HTTPS_PROXY -u https_proxy -u HTTP_PROXY -u http_proxy -u ALL_PROXY -u all_proxy kubectl get nodes`.
- [ ] Аннотация дисков совпадает с реальными маунтами/тегами: `kubectl get node <node> -o json | jq -r '.metadata.annotations["node.longhorn.io/default-disks-config"]'`.
- [ ] LonghornNode содержит диски с ожидаемыми тегами (ssd/hdd) и дефолтный `/var/lib/longhorn/` с `storageReserved=40Gi`: `kubectl -n longhorn-system get lhn <node> -o json | jq '.spec.disks'`.
- [ ] Статусы дисков Ready/Schedulable без DiskPressure (или задокументируй причину): `kubectl -n longhorn-system get lhn <node> -o json | jq '.status.diskStatus'`.
- [ ] UI проверка: `kubectl -n longhorn-system port-forward svc/longhorn-frontend 9999:80 --address 127.0.0.1` и страница `http://127.0.0.1:9999/#/node` показывает все диски.
- [ ] Для новых нод: нет лишних строк `/var/lib/longhorn/disks/*` в `/etc/fstab`; авто-prep лог без неожиданных WARN (MSR/битые разделы можно игнорировать).
- [ ] Если DiskPressure из-за нехватки места — освободить/расширить или снизить `Storage Minimal Available Percentage` и перепроверить.
- [ ] GPU: на GPU-нодах `containerd` имеет `default_runtime_name = "nvidia"` и секцию `runtimes.nvidia` в `/etc/containerd/config.toml`; на ноде стоит лейбл `nvidia.com/gpu.present=true`.
- [ ] GPU: DaemonSet `nvidia-device-plugin-daemonset` (`kube-system`) готов и поды не CrashLoop; RuntimeClass `nvidia` существует.
- [ ] GPU: тестовый под с `resources.limits.nvidia.com/gpu: 1` стартует на GPU-ноде (с runtimeClass `nvidia`, если требуется).
- [ ] Registry использует PVC `registry-data` на StorageClass `longhorn-hdd` (или fallback на дефолтный SC), PVC в статусе Bound.
- [ ] DNS: Deployment/Service `dnscrypt-proxy` работает; CoreDNS ConfigMap форвардит запросы на `dnscrypt-proxy.default.svc.cluster.local:53` с fallback на `8.8.8.8`, pods `coredns` перезапущены и Ready.
