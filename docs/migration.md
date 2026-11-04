# Migrate Built-in Middlewares to Separate Releases

These guides cover migrating the built-in Redis, PostgreSQL and Weaviate to standalone Helm releases within the same cluster while preserving existing data.

> **Important**: Always back up your data before performing any migration, and test the process in a non-production environment first.

## Migrate Built-in Redis and PostgreSQL

### Prerequisite

This guide assumes the replication architecture of built-in Redis and PostgreSQL (the default configuration). For setups like Redis in Sentinel mode, user would have to come up with their own solutions.

Add the Bitnami Helm repository:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

Set the following environment variables according to your deployment:

```bash
export RELEASE_NAME="your-release-name"    # Helm release name (e.g., 'my-dify' from 'helm install my-dify dify/dify')
export NAMESPACE="your-namespace"          # Deployment namespace
export CHART_VERSION=$(helm list -n $NAMESPACE | grep $RELEASE_NAME | awk '{print $9}')  # Chart version of dify-helm
```

### Backup Configuration and Data

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

### Update Redis and PostgreSQL Configurations

First, identify the existing PVCs that are used by the built-in databases:

```bash
kubectl get pvc -n $NAMESPACE
```

For example:
- Redis: `redis-data-my-release-redis-master-0`, `redis-data-my-release-redis-replicas-0`, etc.
- PostgreSQL: `data-my-release-postgresql-primary-0`, `data-my-release-postgresql-read-0`

Next, create `redis-values.yaml` and `postgresql-values.yaml` that inherit the original settings and modify `<role>.persistence.existingClaim` or `fullnameOverride` to re-use existing PVCs.

For Redis:

For single master setup (default)
```yaml
# redis-values.yaml
# Inherit all original settings from your backup, modify existingClaim to re-use the previously created PVCs
master:
  count: 1
  persistence:
    existingClaim: "redis-data-my-release-redis-master-0"  # Applies only if only 1 master is configured.
replica:
  replicaCount: 3
  persistence:
    existingClaim: ""  # Replicas will sync data from master
```

Or use the following approach as altnernative:

```yaml
# redis-values.yaml
# Inherit all original settings from your backup, modify fullnameOverride to re-use the previously created PVCs
## @param fullnameOverride String to fully override common.names.fullname
##
fullnameOverride: "my-release-redis" # Override as ${RELEASE_NAME}-redis to match exisiting PVCs by name.
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
    existingClaim: "data-my-release-postgresql-read-0"  # Applies only if only 1 read replica is configured. Leave it empty to allow read replicas to sync from priamry if more than 1 read replica is configured.
```

Or use the following approach:

```yaml
# postgresql-values.yaml
# Inherit all original settings from your backup, add/modify fullnameOverride to re-use the previously created PVCs
## @param fullnameOverride String to fully override common.names.fullname
##
fullnameOverride: "my-release-postgresql" # Override as ${RELEASE_NAME}-postgresql to match exisiting PVCs by name.
```

**Noteice:** When reusing existing PVCs, the configured password in the new release will be ignored as the database retains the password from the original installation. Store your credentials in a secure vault rather than relying on the Secret created in the new release.

### Disable built-in Redis and PostgreSQL

Before shutting down built-in databases, confirm that the PVCs for `Redis` and `PostgreSQL` will persist (e.g., via the `helm.sh/resource-policy: keep` annotation) after the uninstallation process. You may also check the reclaim policy of PVs if applicable (e.g. Use `Retain` to prevent data loss in case the bound PVCs were deleted upon migration, which would end up deleting the PV itself if the policy were `Delete`).
Shutdown the built-in databases to ensure no processes are accessing the PVCs:

Disable built-in databases by setting `redis.enabled=false` and `postgresql=false` based on your original `values.yaml`:
```bash
helm upgrade $RELEASE_NAME dify/dify -n $NAMESPACE \
  --version $CHART_VERSION \
  -f values-with-redis-and-pg-disabled.yaml
```

Wait until Redis and PostgreSQL pods terminate:

```bash
kubectl get pods -n $NAMESPACE -w
```

### Deploy Redis and PostgreSQL with exisiting PVCs

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

Verify that pods are running correctly:

```bash
# Check Redis pods
kubectl get pods -n $NAMESPACE | grep my-redis

# Check PostgreSQL pods
kubectl get pods -n $NAMESPACE | grep my-postgresql

# Test connectivity if needed
```

### Update Dify Configuration

Update your Dify release regarding external Redis and PostgreSQL:

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
  password: "🔒env_secret_1🔓"  # Use the same password as your previous deployment

externalPostgres:
  enabled: true
  username: "postgres"
  password: "🔒env_secret_1🔓"  # Use the same password as your previous deployment
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

## Migrate from Built-in Weaviate as Separate Release

### Prerequisite

This guide assumes the default configuration of built-in Weaviate.

Add the Weaviate Helm repository:

```bash
helm repo add weaviate https://weaviate.github.io/weaviate-helm
helm repo update
```

Set the following environment variables according to your deployment:

```bash
export RELEASE_NAME="your-release-name"    # Helm release name (e.g., 'my-dify' from 'helm install my-dify dify/dify')
export NAMESPACE="your-namespace"          # Deployment namespace
export CHART_VERSION=$(helm list -n $NAMESPACE | grep $RELEASE_NAME | awk '{print $9}')  # Chart version of dify-helm
export WEAVIATE_CHART_VERSION="17.8.3"     # Check the Chart.yaml for the exact version of the Weaviate Helm chart
```

### Backup Authentication Info of Weaviate

```bash
# Backup your current values
helm get values $RELEASE_NAME -n $NAMESPACE > dify-backup-values.yaml

# Backup ConfigMaps and Secrets (Recommended)
kubectl get configmap -n $NAMESPACE -o yaml > dify-configmaps-backup.yaml
kubectl get secret -n $NAMESPACE -o yaml > dify-secrets-backup.yaml
```

**Note**: Backing up ConfigMaps and Secrets is optional but recommended to avoid losing your original authentication configurations.

### Re-deploy Weaviate as a Separate Release

Shutdown the built-in Weaviate to ensure no processes are accessing the PVCs to avoid data corruption. Set `weaviate.enabled=false`, then

```bash
helm upgrade $RELEASE_NAME dify/dify -n $NAMESPACE \
  --version $CHART_VERSION \
  -f values-with-weaviate-disabled.yaml
```

Wait until Weaviate pods to terminate:

```bash
kubectl get pods -n $NAMESPACE -w
```

Extract the whole `.Values.weaviate` section and save as `weaviate-values.yaml` to keep your current configurations. The `.Values.weaviate` should be un-nested as `.Values`.

PVC names come from `storage.name` (default `weaviate-data`), so the first replica uses `weaviate-data-weaviate-0`. `storage.fullnameOverride` is no longer used. Keep `storage.name` in the extracted values so the standalone release reuses the existing volume.

Re-deploy Weaviate with the following command:

```bash
# Install standalone Weaviate
helm install my-weaviate weaviate/weaviate \
  --version $WEAVIATE_CHART_VERSION \
  -n $NAMESPACE \
  -f weaviate-values.yaml
```

Verify that Weaviate is running correctly:

```bash
# Check Weaviate pods
kubectl get pods -n $NAMESPACE | grep weaviate
# Test connectivity if needed
```

### Update Dify Service

Update Dify configurartions to use external Weaviate service instead of the built-in one:

```yaml
# dify-external-weaviate-values.yaml
weaviate:
  enabled: false

externalWeaviate:
  enabled: true
  endpoint:
    http: "http://weaviate:80"  # Endpoint for HTTP(s). Refer to service from `kubectl get svc -n $NAMESPACE | grep weaviate`
    grpc: "grpc://weaviate:50051"  # Endpoint for gRPC(s). Refer to service from `kubectl get svc -n $NAMESPACE | grep weaviate-grpc`
  apiKey: "your-api-key" # The first key in the original `.Values.weaviate.authentication.apikey.allowed_keys` by default
```

```bash
helm upgrade $RELEASE_NAME dify/dify -n $NAMESPACE -f dify-external-weaviate-values.yaml
```
