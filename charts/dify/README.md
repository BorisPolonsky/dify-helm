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

## Migrate from Built-in Redis and PostgreSQL to Separate Releases

This guide explains how to migrate from the built-in Redis and PostgreSQL deployments to separate releases while preserving your data.

This approach is useful for:
- Managing Redis and PostgreSQL independently from the Dify release
- Applying different upgrade cycles for the database components
- Utilizing more advanced configurations not available in the subcharts

This section assumes the replication architecture of built-in Redis and PostgreSQL given the default configurations. For non-default setups (e.g., Redis in Sentinel mode), you will need to implement a custom migration solution.

#### Preparation

Set the following environment variables according to your deployment:

```bash
export RELEASE_NAME="your-release-name"    # Helm release name (e.g., 'my-dify' from 'helm install my-dify dify/dify')
export NAMESPACE="your-namespace"          # Deployment namespace
export CHART_VERSION=$(helm list -n $NAMESPACE | grep $RELEASE_NAME | awk '{print $9}')  # Chart version of dify-helm
```

#### Backup Configuration and Data

```bash
# Backup your current values
helm get values $RELEASE_NAME -n $NAMESPACE > dify-backup-values.yaml

# Backup ConfigMaps and Secrets (Recommended)
# If authentication data is out of sync with Redis/PostgreSQL ConfigMaps and Secrets, use your own backup solution.
kubectl get configmap -n $NAMESPACE -o yaml > dify-configmaps-backup.yaml
kubectl get secret -n $NAMESPACE -o yaml > dify-secrets-backup.yaml

# Optionally backup PVC data (depends on your backup solution)
# This step is recommended but optional depending on your backup strategy
```

**Important**: Back up ConfigMaps and Secrets, especially when randomly generated passwords were used (e.g., the default behavior of built-in PostgreSQL replica setups) as they won't persist after migration.

#### Configure Redis and PostgreSQL to reuse existing PVCs

First, identify the existing PVCs that are used by the built-in databases:

```bash
kubectl get pvc -n $NAMESPACE
```

For example:
- Redis: `redis-data-my-release-redis-master-0`, `redis-data-my-release-redis-replicas-0`, etc.
- PostgreSQL: `data-my-release-postgresql-primary-0`, `data-my-release-postgresql-read-0`

Before shutting down built-in databases (basically an uninstallation process of built-in dependencies), confirm that the PVCs will persist (e.g., via `helm.sh/resource-policy: keep` annotation). Also check the reclaim policy of PVs: if it's `Delete`, you may need to change the underlying PV's reclaim policy to `Retain` to prevent data loss in case the bound PVC were accidentally deleted upon migration, which would end up deleting the PV itself.


Next, create values files that inherit the original settings and modify the existingClaims for persistence:

For Redis:

```yaml
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

**Note**: When reusing existing PVCs, the configured password in the new release will be ignored as the database retains the password from the original installation. Store your credentials in a secure vault rather than relying on the Secret created in the new release.

#### Re-deploy Redis and PostgreSQL as Separate Releases

Shutdown the built-in databases to ensure no processes are accessing the PVCs:

**Note**: Running built-in database instances simultaneously with the separatly deployed ones while sharing the same PVCs will result in data corruption.

Modify your values.yaml and disable built-in databases by setting the redis.enabled=false, then
```bash

helm upgrade $RELEASE_NAME dify/dify -n $NAMESPACE \
  --version $CHART_VERSION \
  -f values-with-redis-and-pg-disabled.yaml
```

Wait until Redis and PostgreSQL pods to terminate:

```bash
kubectl get pods -n $NAMESPACE -w
```

Once the built-in databases are fully shut down, re-deploy Redis and PostgreSQL as separate releases:

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

Verify that the new database deployments are running correctly:

```bash
# Check Redis pods
kubectl get pods -n $NAMESPACE | grep my-redis

# Check PostgreSQL pods
kubectl get pods -n $NAMESPACE | grep my-postgresql

# Test connectivity if needed
```

### 5. Restore Dify Service

Update your Dify deployment to use external Redis and PostgreSQL services instead of the built-in ones:

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

```bash
helm upgrade $RELEASE_NAME dify/dify -n $NAMESPACE -f dify-external-db-values.yaml
```

### Important Notes
- Make sure to use the same passwords and usernames for the standalone deployments as were used in the built-in versions to avoid authentication issues.
- Always backup your data before performing this migration.
- Test this process in a non-production environment first to ensure you understand the steps and potential issues.