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
Apply the `-f` option upon `helm install`/`helm upgrade` with your own `values.yaml`.
Fear not its extensive content as they are arranged in sections below:
1. Image: Adjust images of all Dify components
2. Dify Service: Customize configurations of each Dify components
3. Middleware: Specifies the configuration of built-in middlewares
4. External services: Subtitute external services for built-in data persistence
 
### 1. Adjust Images
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

### 2. Customize Dify Components
#### Data persistence
To customize built-in data persistence, set `enabled: true` in the `persistence` section of `values.yaml` and specify the storage class and size, for instance:
```yaml
# values.yaml
api:
  persistence:
    enabled: true
    storageClass: your-storage-class
    accessMode: ReadWriteMany
    size: 10Gi

```
or desginate an existing `PersistentVolumeClaim`:
```yaml
# values.yaml
api:
  persistence:
    enabled: true
    persistentVolumeClaim:
      existingClaim: "your-pvc-name"
```
#### Environment Variables
This chart automatically manages envrionment variables for data persistence, service discovery and database connection etc. under the hood. To apply additional environment variables or override existing ones, refer to `extraEnv` section for each component:
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

### 3. Working with Built-in Middlewares
Built-in `Redis` and `PostgreSQL` and `weaviate` allows users to spool up a self-contained `Dify` enviroment for a quick start. These components are supplied by third party helm charts. To customize built-in middlewares, refer to the section name and the official documents:

| Section | Document |
----- | --- |
`redis` | [bitnami/redis](https://github.com/bitnami/charts/tree/main/bitnami/redis)
`postgresql` |[bitnami/postgresql](https://github.com/bitnami/charts/tree/main/bitnami/postgresql)
`weaviate`| [weaviate](https://github.com/weaviate/weaviate-helm)

To disable them, set `enabled: false` in the corresponding section of `values.yaml` and apply external service providers:
```yaml
# values.yaml
redis:
  enabled: false  # Disable built-in Redis
```


### 4. Opt in External Services
It's advised to utilize services from enterprise level providers over the built-in middlewares for production use. To take over built-in `Redis` for instance:
```yaml
# values.yaml
externalRedis:
  enabled: true
  host: "redis.example"
  port: 6379
  username: ""
  password: "difyai123456"
  useSSL: false
```
Refer to `external<Service>` sections for more details. 
