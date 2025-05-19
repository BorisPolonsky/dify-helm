# dify-helm
Deploy [langgenius/dify](https://github.com/langgenius/dify), an LLM based chat bot app on kubernetes with helm chart.
## Quick Start
```bash
# Add the Helm repository
helm repo add dify https://borispolonsky.github.io/dify-helm
helm repo update
helm install my-release dify/dify
```

## Customized Installation
Apply the `-f` option upon `helm install` with your own `values.yaml` file. Fear not the extensive content as they can be broken down in three sections:
1. `dify` components
2. Built-in middlewares (`redis`, `postgresql` and `weaviate`)
1. External services (external database, object storage, etc.)

### 1. Dify components
#### Apply Custom Images
You can specify custom images for different components:
```yaml
# values.yaml
images:
  api:
    repository: your-registry/dify-api
    tag: your-tag
    pullPolicy: IfNotPresent
  worker:
    repository: your-registry/dify-worker
    tag: your-tag
    pullPolicy: IfNotPresent
  sandbox:
    repository: your-registry/dify-sandbox
```

#### Environment Variables
This chart automatically supplies envrionment variables for service discovery and authentication under the hood. To apply additional environment variables or override existing, refer to `extraEnv` section for each component:
```yaml
# values.yaml
...
api:
  extraEnv:
  # The direct approach
  - name: LANG
    value: "C.UTF-8"
  # Use existing configmaps
  - name: MY_CONFIG
    valueFrom:
      configMapKeyRef:
        name: my-config
        key: MY_CONFIG
  # Use existing secrets
  - name: MY_SECRET
    valueFrom:
      secretKeyRef:
        name: my-secret
        key: MY_SECRET
```

### 2. Built-in middlewares
Built-in `Redis` and `PostgreSQL` and `weaviate` are supplied by third-party helm charts. To customize these components, refer to the documents of the corresponding helm charts.
- [bitnami/redis](https://github.com/bitnami/charts/tree/main/bitnami/redis)
- [bitnami/postgresql](https://github.com/bitnami/charts/tree/main/bitnami/postgresql)
- [weaviate](https://github.com/weaviate/weaviate-helm)

Note that these components are optional and can be disabled by setting `enabled: false` in the corresponding section of `values.yaml`. For example, to disable the built-in `Redis`:
```yaml
# values.yaml
redis:
  enabled: false  # Disable built-in Redis
```
### 3. External services
External services like `Redis`, `PostgreSQL`, vector database, object storage etc., are arraged in sections in `external<ServiceName>` pattern. For example, to customize the `Redis` service:
```yaml
externalRedis:
  enabled: true
  host: "redis.example"
  port: 6379
  username: ""
  password: "difyai123456"
  useSSL: false
```

