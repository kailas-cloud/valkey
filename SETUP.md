# Valkey с координатором в k3s - Рабочая конфигурация

## Архитектура решения

### Компоненты
1. **valkey-bundle** - Docker образ с модулями (build & publish в GHCR)
2. **valkey** - GitOps репозиторий с K8s манифестами для деплоя в k3s

### Схема работы
```
valkey-bundle (GitHub Actions)
  ├─ Собирает Valkey 9.0 с модулями
  ├─ Python entrypoint для динамической загрузки модулей
  └─ Публикует в ghcr.io/kailas-cloud/valkey-bundle:9.0-coordinator

valkey (GitOps)
  ├─ K8s манифесты (StatefulSet, ConfigMap, Service)
  └─ Деплой в k3s кластер
```

## Ключевые моменты запуска

### 1. Docker образ (valkey-bundle)

**Образ:** `ghcr.io/kailas-cloud/valkey-bundle:9.0-coordinator`

**Особенности:**
- Python entrypoint (`bundle-docker-entrypoint.py`) для гибкой конфигурации модулей
- Модули собираются из исходников (не копируются из valkey-bundle)
- Поддержка передачи аргументов модулям через environment variables

**Включенные модули:**
- `libsearch.so` (1.0.2) - Vector search с поддержкой координатора
- `libjson.so` (1.0.2) - JSON support
- `libvalkey_bloom.so` (1.0.0) - Bloom filters
- `libvalkey_ldap.so` (1.0.0) - LDAP auth

### 2. Критическая конфигурация координатора

**В ConfigMap (`k8s/configmap.yaml`):**
```yaml
loadmodule "/usr/lib/valkey/libsearch.so" --use-coordinator

cluster-enabled yes
cluster-config-file nodes.conf
cluster-node-timeout 5000
```

**Важно:**
- Флаг `--use-coordinator` БЕЗ значения `yes` (модуль принимает boolean флаги)
- Не используется `--use-coordinator yes` (это НЕ работает)
- Cluster mode обязателен для работы координатора

### 3. StatefulSet конфигурация

**Ключевые параметры (`k8s/statefulset.yaml`):**
```yaml
replicas: 3  # Минимум 3 ноды для кластера

image: ghcr.io/kailas-cloud/valkey-bundle:9.0-coordinator
imagePullPolicy: Always

command: ["/usr/local/bin/valkey-server"]
args: ["/etc/valkey/valkey.conf"]

volumeMounts:
  - name: config
    mountPath: /etc/valkey
    readOnly: true
  - name: data
    mountPath: /data

volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      storageClassName: hcloud-volumes
      resources:
        requests:
          storage: 20Gi
```

**Важно:**
- Образ использует Python entrypoint, который автоматически находит и загружает модули
- Конфиг монтируется через ConfigMap в `/etc/valkey/`
- Persistent storage через Hetzner Cloud Volumes

## Как это работает

### Python Entrypoint Flow

1. **Запуск контейнера:**
   ```
   ENTRYPOINT ["bundle-docker-entrypoint"]
   CMD ["valkey-server"]
   ```

2. **Entrypoint обрабатывает:**
   ```python
   # 1. Находит все модули в /usr/lib/valkey/*.so
   modules = discover_modules('/usr/lib/valkey')
   
   # 2. Читает переменные окружения (опционально)
   SEARCH_MODULE_ARGS="--use-coordinator"
   
   # 3. Строит команду
   valkey-server /etc/valkey/valkey.conf \
     --loadmodule /usr/lib/valkey/libsearch.so --use-coordinator \
     --loadmodule /usr/lib/valkey/libjson.so \
     ...
   ```

3. **Конфиг из ConfigMap перезаписывает/дополняет:**
   - Базовые настройки (port, appendonly)
   - Cluster configuration
   - Может переопределить загрузку модулей

### Почему работает

**Комбинация:**
- ConfigMap явно указывает `loadmodule` с `--use-coordinator`
- StatefulSet монтирует этот конфиг в `/etc/valkey/valkey.conf`
- Python entrypoint запускает `valkey-server` с этим конфигом
- Cluster mode активирован
- Координатор включен для cross-shard search

## Деплой в k3s

### Команды

```bash
# Деплой всего стека
kubectl apply -k valkey/k8s/

# Проверка статуса
kubectl -n valkey get pods
kubectl -n valkey get pvc

# Проверка логов
kubectl -n valkey logs valkey-0

# Проверка конфига
kubectl -n valkey exec valkey-0 -- cat /etc/valkey/valkey.conf

# Проверка модулей
kubectl -n valkey exec valkey-0 -- valkey-cli MODULE LIST
```

### Проверка координатора

```bash
# Подключиться к любой ноде
kubectl -n valkey exec -it valkey-0 -- valkey-cli

# Создать индекс (координатор должен распределить по шардам)
FT.CREATE myidx ON HASH PREFIX 1 doc: SCHEMA title TEXT

# Проверить статус кластера
CLUSTER INFO
CLUSTER NODES

# Проверить настройки модуля
FT._LIST
```

## Что НЕ работало

### ❌ Неправильные попытки

1. **Аргумент модуля с значением:**
   ```yaml
   loadmodule "/usr/lib/valkey/libsearch.so" --use-coordinator yes
   # Модуль не парсит "yes" как boolean
   ```

2. **Environment переменные вместо конфига:**
   ```yaml
   env:
     - name: SEARCH_MODULE_ARGS
       value: "--use-coordinator yes"
   # Не работает без явной загрузки в конфиге
   ```

3. **Копирование модулей из valkey-bundle образа:**
   ```dockerfile
   COPY --from=valkey/valkey-bundle:9.0 /usr/lib/valkey/ /usr/lib/valkey/
   # Проблемы с версиями и зависимостями
   ```

### ✅ Что в итоге сработало

**ConfigMap с явной загрузкой модуля:**
```yaml
loadmodule "/usr/lib/valkey/libsearch.so" --use-coordinator
cluster-enabled yes
```

**Python entrypoint образа:**
- Автоматически находит модули
- Поддерживает переопределение через конфиг
- Правильно формирует команду запуска

**Образ из valkey-bundle:**
- Собран из исходников модулей (не копирование)
- Совместимость версий гарантирована
- Все зависимости включены

## Полезные команды

### Debugging

```bash
# Debug режим (в локальном Docker)
docker run -e DEBUG=1 \
  ghcr.io/kailas-cloud/valkey-bundle:9.0-coordinator

# Проверить модули в образе
docker run --entrypoint ls \
  ghcr.io/kailas-cloud/valkey-bundle:9.0-coordinator \
  /usr/lib/valkey/

# Проверить конфиг в pod
kubectl -n valkey exec valkey-0 -- \
  valkey-cli CONFIG GET loadmodule
```

### Мониторинг

```bash
# Метрики модуля
kubectl -n valkey exec valkey-0 -- \
  valkey-cli FT._LIST

# Использование памяти
kubectl -n valkey exec valkey-0 -- \
  valkey-cli INFO memory

# Статус кластера
kubectl -n valkey exec valkey-0 -- \
  valkey-cli CLUSTER INFO
```

## Итоговая конфигурация

### Структура файлов
```
valkey/
├── Dockerfile              # (не используется, для reference)
├── valkey.conf             # (не используется, для reference)
├── k8s/
│   ├── namespace.yaml      # Namespace "valkey"
│   ├── configmap.yaml      # ✅ Ключевой файл с координатором
│   ├── statefulset.yaml    # ✅ 3 реплики с PVC
│   ├── service.yaml        # ClusterIP сервис
│   └── kustomization.yaml  # Kustomize для деплоя
└── SETUP.md                # Эта документация
```

### ConfigMap (финальная версия)
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: valkey-config
  namespace: valkey
data:
  valkey.conf: |
    port 6379
    appendonly yes

    loadmodule "/usr/lib/valkey/libsearch.so" --use-coordinator

    cluster-enabled yes
    cluster-config-file nodes.conf
    cluster-node-timeout 5000

    save 60 1000
```

### StatefulSet (финальная версия)
- Образ: `ghcr.io/kailas-cloud/valkey-bundle:9.0-coordinator`
- Реплики: 3
- Storage: 20Gi per pod (Hetzner Cloud Volumes)
- Command: `valkey-server /etc/valkey/valkey.conf`
- Probes: liveness (TCP) + readiness (valkey-cli ping)

## Ссылки

- **valkey-bundle repo:** Сборка Docker образа с модулями
- **valkey repo:** K8s манифесты для деплоя
- **GHCR образ:** `ghcr.io/kailas-cloud/valkey-bundle:9.0-coordinator`
- **Valkey Search Docs:** https://valkey.io/topics/search/

## Заметки

- Координатор работает только в cluster mode
- Минимум 3 ноды для production кластера
- Python entrypoint позволяет динамическую конфигурацию модулей
- ConfigMap имеет приоритет над environment переменными
- Все модули загружаются автоматически из `/usr/lib/valkey/`
