Судя по всему, проблема не в отсутствии самих GPU (устройства в /dev присутствуют), а в том, что containerd не использует nvidia‑container‑runtime по умолчанию. В результате плагин NVIDIA не может обнаружить GPU, поскольку стратегия обнаружения остаётся «auto», и ожидает, что будет настроен правильный runtime.

### Что происходит

- Вы выполнили команду настройки:
  ```bash
  sudo nvidia-ctk runtime configure --runtime=containerd
  ```
  Эта команда добавляет конфигурацию для nvidia‑runtime в файл containerd (как видно в секции `plugins."io.containerd.cri.v1.runtime".containerd.runtimes.nvidia`), но по умолчанию default‑runtime у вас всё ещё установлен на runc (см. параметр `default_runtime_name = "runc"`).

- Из-за этого, когда Kubernetes запускает под, не указывая `runtimeClassName: nvidia`, containerd использует обычный runtime runc, и NVIDIA device plugin не видит корректного окружения для обнаружения GPU. Именно поэтому в логах плагина вы видите ошибку «Incompatible strategy detected auto» и сообщение о том, что на GPU‑узле не настроен NVIDIA Container Toolkit.

### Как это исправить

Есть два основных пути:

1. **Сделать nvidia‑runtime дефолтным для containerd.**  
   При выполнении команды настройки укажите флаг `--set-as-default`, чтобы nvidia‑container‑runtime стал дефолтным:
   ```bash
   sudo nvidia-ctk runtime configure --runtime=containerd --set-as-default
   sudo systemctl restart containerd
   ```
   После этого containerd будет использовать nvidia‑runtime по умолчанию, и плагин сможет корректно обнаруживать GPU.

2. **Использовать runtimeClassName для подов.**  
   Если вы не хотите менять дефолтный runtime для containerd, то нужно явно указать в манифесте пода, чтобы он использовал runtimeClassName, соответствующий nvidia‑runtime (например, "nvidia"). Например:
   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: gpu-pod
   spec:
     runtimeClassName: nvidia   # указываем nvidia‑runtime
     restartPolicy: Never
     containers:
       - name: cuda-container
         image: nvcr.io/nvidia/k8s/cuda-sample:vectoradd-cuda12.5.0
         resources:
           limits:
             nvidia.com/gpu: 1
     tolerations:
       - key: nvidia.com/gpu
         operator: Exists
         effect: NoSchedule
   ```
   Это позволит запускать под с использованием nvidia‑runtime, даже если дефолтный runtime остаётся runc.

### Вывод

Если у вас GPU-устройства обнаруживаются в /dev (как видно из вашего вывода), то правильное решение – либо установить nvidia‑runtime как дефолтный (с помощью `--set-as-default`), либо явно указывать runtimeClassName для подов, которым нужны GPU.

После внесения этих изменений перезапустите containerd и убедитесь, что плагин NVIDIA больше не пишет об «Incompatible strategy detected auto» и под с GPU запускается на одном из узлов с GPU.

### todo сделать авто настройку на новых узлах