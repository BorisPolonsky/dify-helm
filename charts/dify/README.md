# dify-helm
Deploy [langgenius/dify](https://github.com/langgenius/dify), an LLM-based chatbot app on Kubernetes with Helm chart.
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
4. External services: Substitute external services for built-in data persistence
 
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
Built-in `Redis`, `PostgreSQL`, and `weaviate` allow users to spin up a self-contained `Dify` environment for a quick start. These components are supplied by third party helm charts. To customize built-in middlewares, refer to the section name and the official documents:

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
*Note: Built-in Redis, PostgreSQL, and Weaviate are for development/testing only and may not keep up to the versions in Dify's `docker-compose.yml`. For production, use external Redis/PostgreSQL instances (as noted in the next section).*

### 4. Opt in External Services
It's advised to utilize services from enterprise-level providers over the built-in middlewares for production use. To take over built-in `Redis` for instance:
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

## Migration from Built-in Redis and PostgreSQL to Standalone Releases

This guide explains how to migrate from the built-in Redis and PostgreSQL deployments to standalone deployments while preserving your data.

This approach is useful for:
- Managing Redis and PostgreSQL independently from the Dify release
- Applying different upgrade cycles for the database components
- Utilizing more advanced configurations not available in the subcharts

#### Migration Steps

Set the following environment variables according to your deployment:

```bash
export RELEASE_NAME="your-release-name"    # Helm release name (e.g., 'my-dify' from 'helm install my-dify dify/dify')
export NAMESPACE="your-namespace"          # Deployment namespace
```

#### 1. Backup Configuration and Data

```bash
# Backup your current values
helm get values $RELEASE_NAME -n $NAMESPACE > dify-backup-values.yaml

# Backup important ConfigMaps and Secrets (recommended)
kubectl get configmap -n $NAMESPACE -o yaml > dify-configmaps-backup.yaml
kubectl get secret -n $NAMESPACE -o yaml > dify-secrets-backup.yaml

# Optionally backup PVC data (depends on your backup solution)
# This step is recommended but optional depending on your backup strategy
```

**Important**: Make sure you back up the ConfigMap and Secret, especially when you're using the default randomly generated passwords from the built-in PostgreSQL and Redis charts, as the authentication information stored inside won't persist after migration.

#### 2. Disable Built-in Databases

After backing up authentication credentials, proceed with disabling the built-in databases to ensure no processes are accessing the PVCs:

```bash
# Get the current chart version to ensure consistency
export CHART_VERSION=$(helm list -n $NAMESPACE | grep $RELEASE_NAME | awk '{print $9}')

# Disable built-in databases while keeping the rest of the deployment running
helm upgrade $RELEASE_NAME dify/dify -n $NAMESPACE \
  --version $CHART_VERSION \
  --set redis.enabled=false \
  --set postgresql.enabled=false
```

Wait for the database pods to terminate:

```bash
kubectl get pods -n $NAMESPACE -w
```

Press Ctrl+C when the Redis and PostgreSQL pods are terminated.

**Note**: Running database instances simultaneously with the standalone databases pointing to the same PVCs will result in data corruption.

#### 3. Identify Existing PVCs

```bash
kubectl get pvc -n $NAMESPACE
```

Look for PVCs with names similar to:
- `redis-data-*` for Redis
- `data-*` for PostgreSQL

For example:
- Redis: `redis-data-my-release-redis-master-0`, `redis-data-my-release-redis-replicas-0`, etc.
- PostgreSQL: `data-my-release-postgresql-primary-0`, `data-my-release-postgresql-read-0`

If the reclaim policy is `Delete`, you may need to change the underlying PV's reclaim policy to `Retain` to prevent data loss.

#### 4. Create Values Files for Redis and PostgreSQL

Create values files that inherit the original settings and modify the existingClaims for persistence:

For Redis:

```
# redis-values.yaml
# Inherit all original settings from your backup, modify existingClaims to re-use the previously created PVCs
redis:
  master:
    persistence:
      existingClaim: "redis-data-my-release-redis-master-0"
  replica:
    replicaCount: 3
    persistence:
      existingClaim: ""  # Replicas will create new PVCs and sync data from master
```

Note: Adjust the PVC names according to your actual deployment names. Only the master node reuses the existing PVC, while replicas will create new PVCs and synchronize data from the master.

For PostgreSQL:

```yaml
# postgresql-values.yaml
# Inherit all original settings from your backup, modify existingClaims to re-use the previously created PVCs
primary:
  persistence:
    existingClaim: "data-my-release-postgresql-primary-0"
  
readReplicas:
  replicaCount: 1
  persistence:
    existingClaim: "data-my-release-postgresql-read-0"
```

Note: Adjust the PVC names according to your actual deployment names. This approach preserves all original database configurations while only changing the persistence layer to use existing claims.

**Note**: When reusing existing PVCs, the configured password in the new release will be ignored as the database retains the password from the original installation. Store your credentials in a secure vault rather than relying on the Secret created in the new release.

#### 5. Deploy Standalone Redis and PostgreSQL

```bash
# Install standalone Redis
helm install my-redis bitnami/redis \
  --version 16.13.2 \
  -n $NAMESPACE \
  -f redis-values.yaml

# Install standalone PostgreSQL  
helm install my-postgresql bitnami/postgresql \
  --version 12.5.6 \
  -n $NAMESPACE \
  -f postgresql-values.yaml
```

#### 6. Verify Database Deployments

```bash
# Check Redis pods
kubectl get pods -n $NAMESPACE | grep my-redis

# Check PostgreSQL pods
kubectl get pods -n $NAMESPACE | grep my-postgresql

# Test connectivity if needed
```

#### 7. Switch to External Redis and PostgreSQL

Update your Dify deployment to disable built-in Redis and PostgreSQL and use the external services:

```yaml
# dify-external-db-values.yaml
redis:
  enabled: false

postgresql:
  enabled: false

externalRedis:
  enabled: true
  host: "my-redis-master"  # Service name of the new Redis deployment
  port: 6379
  password: "difyai123456"  # Use the same password as your previous deployment

externalPostgres:
  enabled: true
  username: "postgres"
  password: "difyai123456"  # Use the same password as your previous deployment
  address: "my-postgresql"  # Service name of the new PostgreSQL deployment
  port: 5432
  database:
    api: "dify"
    pluginDaemon: "dify_plugin"
```

Upgrade your Dify deployment to use the external services:

```bash
helm upgrade $RELEASE_NAME dify/dify -n $NAMESPACE -f dify-external-db-values.yaml
```

### Important Notes

- Make sure to use the same passwords and usernames for the standalone deployments as were used in the built-in versions to avoid authentication issues.
- The `existingClaim` approach works because it tells the new chart deployments to use the existing persistent volumes rather than creating new ones.
- Always backup your data before performing this migration.
- Test this process in a non-production environment first to ensure you understand the steps and potential issues.