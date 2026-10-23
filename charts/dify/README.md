# dify-helm
Deploy [langgenius/dify](https://github.com/langgenius/dify), an LLM-based chatbot app on Kubernetes with Helm chart.

## Prerequisites
- **Kubernetes**: 1.23+
- **Helm**: 3.12+

## Quick Start
```bash
# Add the Helm repository
helm repo add dify https://borispolonsky.github.io/dify-helm
helm repo update
helm install my-release dify/dify
```

## Customized Installation
Apply the `-f` option upon `helm install`/`helm upgrade` with your own `values.yaml`.
Fear not its extensive content as it is arranged in sections below:
1. Image: Adjust images of all Dify components
2. Dify Service: Customize configurations of each Dify component
3. Middleware: Specifies the configuration of built-in middlewares
4. External services: Substitute external services for built-in middlewares, data persistence and agent sandboxes

### Production Quick Reference

The default installation targets evaluation. For production, apply the following settings — shown in the same order as `values.yaml`, with priority (P0–P2) noted inline:

```yaml
# values.yaml (production skeleton, ordered as in values.yaml)
global:                                        # replace default credentials (P0)
  appSecretKey: "<openssl rand -base64 42>"    #   session signing / DB encryption
  internalApiKey: "<openssl rand -base64 42>"  #   covers sandbox / plugin daemon
# if keeping built-in middlewares: postgresql.global.postgresql.auth.postgresPassword,
# redis.auth.password — otherwise set credentials on the external services below

image:                                         # pin proxy/ssrfProxy tags (P2)
  proxy:
    tag: "1.27"
  ssrfProxy:
    tag: "6.10"

api:                                           # HA (P1) / resources (P2)
  replicas: 2
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      memory: 2Gi
worker:
  replicas: 2
web:
  replicas: 2

weaviate:                                      # external data services (P1)
  enabled: false

ingress:                                       # cluster entry (P1)
  enabled: false
httproute:                                     #   Gateway API instead of Ingress
  enabled: true
  parentRefs:
    - name: my-gateway
  hostnames:
    - dify.example.com

redis:
  enabled: false
externalRedis:
  enabled: true
  host: "redis.example"
  port: 6379
  password: "<your-redis-password>"

externalWeaviate:
  enabled: true
  endpoint:
    http: "http://weaviate.example:8080"
    grpc: "grpc://weaviate.example:50051"
  apiKey: "<your-weaviate-api-key>"
# same pattern: externalPostgres / externalMysql / externalQdrant / externalMilvus ...
```

Notes:
- `beat` must remain a single replica (Celery Beat singleton).
- Multiple API replicas require external object storage or a `ReadWriteMany` PVC for file uploads.
- TLS for the `httproute` entry is terminated at the referenced Gateway.
- For secrets via External Secrets Operator, see [ExternalSecret Support](#externalsecret-support) (advanced).

### 1. Use Alternative Images
You can specify custom images for different components:
```yaml
# values.yaml
image:
  api:
    repository: your-registry/dify-api
    tag: "your-tag"
    pullPolicy: IfNotPresent
  web:
    repository: your-registry/dify-web
    tag: "your-tag"
    pullPolicy: IfNotPresent
  sandbox:
    repository: your-registry/dify-sandbox
    tag: "your-tag"
    pullPolicy: IfNotPresent
  proxy:
    repository: your-registry/nginx
    tag: "your-tag"
    pullPolicy: IfNotPresent
  ssrfProxy:
    repository: your-registry/squid
    tag: "your-tag"
    pullPolicy: IfNotPresent
  pluginDaemon:
    repository: your-registry/dify-plugin-daemon
    tag: "your-tag"
    pullPolicy: IfNotPresent
  agentBackend:
    repository: your-registry/dify-agent-backend
    tag: "your-tag"
    pullPolicy: IfNotPresent
  localSandbox:
    repository: your-registry/dify-agent-local-sandbox
    tag: "your-tag"
    pullPolicy: IfNotPresent
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
or designate an existing `PersistentVolumeClaim`:
```yaml
# values.yaml
api:
  persistence:
    enabled: true
    persistentVolumeClaim:
      existingClaim: "your-pvc-name"
```
#### Environment Variables
This chart automatically manages environment variables for data persistence, service discovery and database connection etc. under the hood. To apply additional environment variables or override existing ones, refer to `extraEnv` section for each component:
```yaml
# values.yaml
...
api:
  extraEnv:
  # Direct value assignment
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
For a quickstart, the chart features built-in `Redis`, `PostgreSQL` and `Weaviate` that powers a self-contained `Dify` environment. These components are supplied by third-party Helm charts. To customize their settings, refer to the section name and the official documents:

Section | Document | Enabled by Default
----- | ----- | -----
`redis` | [bitnami/redis](https://github.com/bitnami/charts/tree/main/bitnami/redis) | `true`
`postgresql` |[bitnami/postgresql](https://github.com/bitnami/charts/tree/main/bitnami/postgresql) | `true`
`weaviate`| [weaviate](https://github.com/weaviate/weaviate-helm) | `true`

**Notice:** Built-in dependencies may not keep up to the versions in Dify's `docker-compose.yml` and will remain as is unless absolutely necessary. For more advanced, production-oriented setups, you may opt in external services instead. Refer to the next section for more details.

### 4. Opt in External Services
It's advised to use Redis, PostgreSQL and Weaviate from external providers over the built-in middlewares for production use regarding:
- enterprise-level maintainability,
- managing Redis and PostgreSQL independently of the Dify release,
- applying different upgrade cycles, and
- utilizing advanced configurations that are not available in the subcharts.

To opt in `Redis` from external providers for instance:
```yaml
# values.yaml
redis:
  enabled: false  # Disable built-in Redis

externalRedis:
  enabled: true
  host: "redis.example"
  port: 6379
  username: ""
  password: "difyai123456"
  useSSL: false
```
Refer to `external<Service>` sections in `values.yaml` for each component to be used.

#### External E2B sandbox (Agent runtime)

Default install keeps Agent runtime `local` with in-cluster `localSandbox` and does not set `DIFY_AGENT_E2B_*`. Workflow Code-node `sandbox` / `CODE_EXECUTION_*` is unrelated.

To use E2B Cloud instead, set `externalE2bSandbox.enabled: true`. Agent Backend stays running; the chart sets `DIFY_AGENT_RUNTIME_BACKEND=e2b` and `DIFY_AGENT_E2B_API_KEY` (not `E2B_API_KEY` / `E2B_API_TOKEN`) and omits `DIFY_AGENT_LOCAL_SANDBOX_*` even if `localSandbox.enabled` is still true. Recommend `localSandbox.enabled: false` so the unused sandbox is not deployed. Agent Backend needs egress to E2B. With ExternalSecret, provide `DIFY_AGENT_E2B_API_KEY` under `externalSecret.agentBackend.remoteRefs`.

```yaml
# values.yaml
localSandbox:
  enabled: false

externalE2bSandbox:
  enabled: true
  apiKey: "your-e2b-api-key"
```

## Advanced Topics
### Migrate Built-in Redis, PostgreSQL and Weaviate to Separate Releases

Step-by-step guides for migrating the built-in middlewares to standalone Helm releases while preserving data are maintained in [docs/migration.md](https://github.com/BorisPolonsky/dify-helm/blob/master/docs/migration.md).

### ExternalSecret Support

#### Background

In Kubernetes production environments, storing sensitive information (such as database passwords, API keys, etc.) directly in values.yaml is insecure. ExternalSecret addresses this issue through the [External Secrets Operator](https://external-secrets.io/), which can securely retrieve sensitive information from external secret management systems (such as AWS Secrets Manager, HashiCorp Vault, Azure Key Vault, etc.) and automatically create Kubernetes Secret resources.

Why ExternalSecret is needed:

- **Security**: Avoid storing plain text passwords in Git repositories or configuration files
- **Centralized Management**: Unified management of all sensitive information
- **Automatic Rotation**: Support for automatic key updates and rotation
- **Compliance**: Meet enterprise security and compliance requirements

#### Currently Supported External Components

When ExternalSecret is enabled, sensitive information for the following components can be retrieved from external secret stores:

##### Database Connections

- **PostgreSQL**: Database username, password
- **Redis**: Authentication password, username
- **Elasticsearch**: Username, password

##### Object Storage

- **AWS S3**: Access Key ID, Secret Access Key

##### Vector Databases

- **ElasticSearch**: Username, Password

##### Email Services

- **Resend**: API Key, sender email
- **SendGrid**: API Key, sender email

##### Other Services

- **Code Execution Service**: API Key
- **Plugin System**: Daemon Key, internal API Key
- **Application Core**: Secret Key
- **Agent Backend**: API token (shared with API/worker as `AGENT_BACKEND_API_TOKEN` / agent as `DIFY_AGENT_API_TOKEN`), server secret key, local sandbox auth token (`DIFY_AGENT_LOCAL_SANDBOX_AUTH_TOKEN`), E2B API key (`DIFY_AGENT_E2B_API_KEY` when `externalE2bSandbox.enabled`), Redis URL
- **Local Sandbox**: Shellctl auth token (shared with agent `DIFY_AGENT_LOCAL_SANDBOX_AUTH_TOKEN`)

Usage: Set `externalSecret.enabled: true` in values.yaml and configure the corresponding secretStore and remoteRefs parameters.
