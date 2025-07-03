# Dify Helm Chart - ExternalSecret Usage Guide

## Overview

Dify Helm Chart supports using [External Secrets Operator](https://external-secrets.io/) to replace traditional direct Secret creation. `ESO` can securely retrieve sensitive information from external secret management systems (such as AWS Secrets Manager, HashiCorp Vault, Azure Key Vault, etc.).

> **Note**: This document has been updated to reflect the current implementation with 6 ExternalSecret templates. The chart now supports comprehensive ExternalSecret integration for all Dify components including PostgreSQL and Redis.

## Usage Instructions

## Supported Secret Types

Currently, Dify Helm Chart supports 6 ExternalSecret types that can replace traditional Secret resources:

```text
# ExternalSecret Templates:
# Source: dify/templates/api-externalsecret.yaml
# Source: dify/templates/worker-externalsecret.yaml
# Source: dify/templates/sandbox-externalsecret.yaml
# Source: dify/templates/plugin-daemon-externalsecret.yaml
# Source: dify/templates/postgresql-externalsecret.yaml
# Source: dify/templates/redis-externalsecret.yaml
```

### 1. Dify Application Internal Secrets (4)

#### 1.1 API Secret

- **ExternalSecret Template**: `dify/templates/api-externalsecret.yaml`
- **Traditional Secret Template**: `dify/templates/api-secret.yaml`
- **Purpose**: Sensitive configuration for Dify API service
- **Fields**: SECRET_KEY, DB_USERNAME, DB_PASSWORD, REDIS_PASSWORD, third-party service keys, etc.

#### 1.2 Worker Secret

- **ExternalSecret Template**: `dify/templates/worker-externalsecret.yaml`
- **Traditional Secret Template**: `dify/templates/worker-secret.yaml`
- **Purpose**: Sensitive configuration for Dify Worker service
- **Fields**: SECRET_KEY, DB_USERNAME, DB_PASSWORD, REDIS_PASSWORD, vector database keys, etc.

#### 1.3 Sandbox Secret

- **ExternalSecret Template**: `dify/templates/sandbox-externalsecret.yaml`
- **Traditional Secret Template**: `dify/templates/sandbox-secret.yaml`
- **Purpose**: API key for Dify Sandbox service
- **Fields**: API_KEY

#### 1.4 Plugin Daemon Secret

- **ExternalSecret Template**: `dify/templates/plugin-daemon-externalsecret.yaml`
- **Traditional Secret Template**: `dify/templates/plugin-daemon-secret.yaml`
- **Purpose**: Sensitive configuration for Dify Plugin Daemon service
- **Fields**: DB_USERNAME, DB_PASSWORD, REDIS_PASSWORD, SERVER_KEY, DIFY_INNER_API_KEY

### 2. PostgreSQL Secret (2 scenarios)

- **ExternalSecret Template**: `dify/templates/postgresql-externalsecret.yaml`
- **Traditional Secret**: Managed by PostgreSQL subchart (`postgresql/templates/secrets.yaml`)

#### 2.1 Built-in PostgreSQL ExternalSecret

- **Purpose**: Key management when using the built-in PostgreSQL in Helm Chart
- **Fields**: postgres-password, replication-password

#### 2.2 External PostgreSQL Configuration

- **Purpose**: Provide database credentials to Dify applications when using external PostgreSQL instances through ExternalSecret
- **Configuration**: Configure DB_USERNAME, DB_PASSWORD in Dify application's ExternalSecret

### 3. Redis Secret (1 type)

- **ExternalSecret Template**: `dify/templates/redis-externalsecret.yaml`
- **Traditional Secret**: Managed by Redis subchart (`redis/templates/secret.yaml`)

#### 3.1 Redis ExternalSecret

- **Purpose**: When Redis authentication is enabled and passwords are managed through ExternalSecret
- **Fields**: redis-password

## Configuration Guide

### Prerequisites

1. **Install External Secrets Operator**

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace
```

2. **Create SecretStore or ClusterSecretStore**

```yaml
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: default
spec:
  vault:
    server: "https://vault.example.com"
    path: "secret"
    version: "v2"
    auth:
      # Authentication configuration...
```

### Basic Configuration

Enable ExternalSecret in `values.yaml`:

```yaml
externalSecret:
  enabled: true
  secretStore:
    name: "vault-backend"  # SecretStore name
    kind: "SecretStore"    # SecretStore or ClusterSecretStore
```

## Usage Scenarios

### Scenario 1: Full ExternalSecret Usage (Recommended)

**Applicable**: All sensitive information is stored in external secret management systems

```yaml
externalSecret:
  enabled: true
  secretStore:
    name: "vault-backend"
    kind: "SecretStore"

  # API service secrets
  api:
    enabled: true
    remoteRefs:
      SECRET_KEY:
        key: "dify/api"
        property: "secret_key"
      DB_USERNAME:
        key: "dify/database"
        property: "username"
      DB_PASSWORD:
        key: "dify/database"
        property: "password"
      REDIS_PASSWORD:
        key: "dify/redis"
        property: "password"
      WEAVIATE_API_KEY:
        key: "dify/weaviate"
        property: "api_key"

  # Worker service secrets
  worker:
    enabled: true
    remoteRefs:
      SECRET_KEY:
        key: "dify/api"
        property: "secret_key"
      DB_USERNAME:
        key: "dify/database"
        property: "username"
      DB_PASSWORD:
        key: "dify/database"
        property: "password"
      REDIS_PASSWORD:
        key: "dify/redis"
        property: "password"

  # Other services...
  sandbox:
    enabled: true
    remoteRefs:
      API_KEY:
        key: "dify/sandbox"
        property: "api_key"

  pluginDaemon:
    enabled: true
    remoteRefs:
      DB_USERNAME:
        key: "dify/database"
        property: "username"
      DB_PASSWORD:
        key: "dify/database"
        property: "password"
      SERVER_KEY:
        key: "dify/plugin-daemon"
        property: "server_key"
```

### Scenario 2: Built-in PostgreSQL + ExternalSecret

**Applicable**: Using Helm Chart's built-in PostgreSQL but want passwords from external systems

```yaml
# Enable built-in PostgreSQL
postgresql:
  enabled: true
  global:
    postgresql:
      auth:
        existingSecret: "dify-postgresql"  # Use Secret created by ExternalSecret

# Configure PostgreSQL ExternalSecret
externalSecret:
  enabled: true
  postgresql:
    enabled: true
    remoteRefs:
      postgres-password:
        key: "dify/postgresql"
        property: "postgres_password"
      replication-password:
        key: "dify/postgresql"
        property: "replication_password"
```

### Scenario 3: External PostgreSQL + ExternalSecret

**Applicable**: Using external PostgreSQL instances with database credentials managed through ExternalSecret

```yaml
# Disable built-in PostgreSQL
postgresql:
  enabled: false

# Enable external PostgreSQL
externalPostgres:
  enabled: true
  address: "postgres.example.com"
  port: 5432
  database:
    api: "dify"

# Database credentials provided to Dify applications through ExternalSecret
externalSecret:
  enabled: true
  api:
    enabled: true
    remoteRefs:
      DB_USERNAME:
        key: "dify/external-database"
        property: "username"
      DB_PASSWORD:
        key: "dify/external-database"
        property: "password"

  worker:
    enabled: true
    remoteRefs:
      DB_USERNAME:
        key: "dify/external-database"
        property: "username"
      DB_PASSWORD:
        key: "dify/external-database"
        property: "password"
```

### Scenario 4: Redis (built-in) + ExternalSecret

**Applicable**: Redis (built-in) authentication is enabled with passwords managed through ExternalSecret

```yaml
# Redis configuration
redis:
  auth:
    enabled: true
    password: ""                # Empty password
    existingSecret: "redis"     # Use Secret created by ExternalSecret

# Redis ExternalSecret
externalSecret:
  enabled: true
  redis:
    enabled: true
    remoteRefs:
      redis-password:
        key: "dify/redis"
        property: "redis_password"
```

## Migration Guide

### Migrating from Traditional Secrets to ExternalSecret

#### Step 1: Prepare External Secret Storage

Store existing sensitive information in external secret management systems:

```bash
# Example: Store secrets using Vault CLI
vault kv put secret/dify/api secret_key="your-secret-key"
vault kv put secret/dify/database username="postgres" password="your-db-password"
vault kv put secret/dify/redis password="your-redis-password"
```

#### Step 2: Update values.yaml

```yaml
# Disable sensitive information in traditional Secrets
api:
  secretKey: ""  # Clear, will be provided through ExternalSecret

# Enable ExternalSecret
externalSecret:
  enabled: true
  api:
    enabled: true
    remoteRefs:
      SECRET_KEY:
        key: "dify/api"
        property: "secret_key"
```

#### Step 3: Verify Configuration

```bash
# Check template rendering
helm template dify . --values values.yaml

# Deploy and check ExternalSecret status
kubectl get externalsecrets
kubectl describe externalsecret dify-api
```

## Configuration Reference

### ExternalSecret Field Description

Each ExternalSecret configuration supports the following fields:

```yaml
externalSecret:
  [service_name]:
    enabled: true              # Whether to enable ExternalSecret for this service
    refreshInterval: "15m"     # Refresh interval
    remoteRefs:               # Remote reference configuration
      [SECRET_KEY]:           # Field name in Secret
        key: "path/to/secret" # Path in external storage
        property: "field"     # Property name in external storage (optional)
```

### Supported Secret Fields

#### API/Worker ExternalSecret Supported Fields

- `SECRET_KEY` - Application secret key
- `CODE_EXECUTION_API_KEY` - Code execution API key
- `DB_USERNAME`, `DB_PASSWORD` - Database credentials
- `REDIS_USERNAME`, `REDIS_PASSWORD` - Redis credentials
- `CELERY_BROKER_URL` - Celery connection string
- `WEAVIATE_API_KEY` - Weaviate vector database key
- `QDRANT_API_KEY` - Qdrant vector database key
- `OPENSEARCH_USERNAME`, `OPENSEARCH_PASSWORD` - OpenSearch credentials
- `RESEND_API_KEY`, `RESEND_FROM_EMAIL` - Resend email service credentials
- `SENDGRID_API_KEY`, `SENDGRID_FROM_EMAIL` - SendGrid email service credentials
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` - AWS storage credentials
- `AZURE_BLOB_ACCOUNT_NAME`, `AZURE_BLOB_ACCOUNT_KEY` - Azure Blob storage credentials
- `GOOGLE_CLOUD_STORAGE_BUCKET` - Google Cloud storage configuration
- `PLUGIN_DAEMON_KEY`, `INNER_API_KEY_FOR_PLUGIN` - Plugin system keys

#### Sandbox ExternalSecret Supported Fields

- `API_KEY` - Sandbox API key

#### Plugin Daemon ExternalSecret Supported Fields

- `DB_USERNAME`, `DB_PASSWORD` - Database credentials
- `REDIS_USERNAME`, `REDIS_PASSWORD` - Redis credentials
- `SERVER_KEY` - Server key
- `DIFY_INNER_API_KEY` - Internal API key
- Storage-related keys (AWS, Azure, GCP, etc.)

#### PostgreSQL ExternalSecret Supported Fields

- `postgres-password` - PostgreSQL master password
- `replication-password` - Replication password

#### Redis ExternalSecret Supported Fields

- `redis-password` - Redis password

## Best Practices

### 1. Secret Organization

Recommend organizing external secrets by service:

```text
secret/
├── dify/
│   ├── api/              # API service related
│   │   ├── secret_key
│   │   └── ...
│   ├── database/         # Database related
│   │   ├── username
│   │   └── password
│   ├── redis/           # Redis related
│   │   └── password
│   ├── weaviate/        # Vector database related
│   │   └── api_key
│   └── mail/            # Email service related
│       └── resend_api_key
```

### 2. Environment Isolation

Use different secret paths for different environments:

```yaml
# Development environment
externalSecret:
  api:
    remoteRefs:
      SECRET_KEY:
        key: "dify/dev/api"
        property: "secret_key"

# Production environment
externalSecret:
  api:
    remoteRefs:
      SECRET_KEY:
        key: "dify/prod/api"
        property: "secret_key"
```

### 3. Principle of Least Privilege

Only configure fields that the application actually needs:

```yaml
# ✅ Recommended: Only configure necessary fields
externalSecret:
  api:
    enabled: true
    remoteRefs:
      SECRET_KEY:
        key: "dify/api"
        property: "secret_key"
      DB_PASSWORD:
        key: "dify/database"
        property: "password"

# ❌ Not recommended: Configure unused fields
externalSecret:
  api:
    enabled: true
    remoteRefs:
      SECRET_KEY:
        key: "dify/api"
        property: "secret_key"
      UNUSED_KEY:
        key: "dify/unused"
        property: "key"  # Unused field
```

### 4. Monitoring and Alerting

Monitor ExternalSecret status:

```bash
# Check ExternalSecret status
kubectl get externalsecrets -o wide

# View synchronization status
kubectl describe externalsecret dify-api

# Check generated Secret
kubectl get secret dify-api -o yaml
```

## Troubleshooting

### Common Issues

#### 1. ExternalSecret Does Not Create Secret

**Symptoms**: ExternalSecret resource exists but does not create corresponding Secret

**Troubleshooting Steps**:

```bash
# Check ExternalSecret status
kubectl describe externalsecret dify-api

# Check SecretStore configuration
kubectl describe secretstore vault-backend

# View External Secrets Operator logs
kubectl logs -n external-secrets-system deployment/external-secrets
```

#### 2. Incorrect Secret Fields

**Symptoms**: Secret is created but field names or values are incorrect

**Troubleshooting Steps**:

```bash
# Check generated Secret
kubectl get secret dify-api -o yaml

# Verify data in external storage
vault kv get secret/dify/api
```

#### 3. Permission Issues

**Symptoms**: ExternalSecret reports authentication or authorization errors

**Solutions**:

- Check SecretStore authentication configuration
- Verify external secret management system permission settings
- Confirm secret paths exist and are accessible

## Summary

ExternalSecret provides a secure and flexible way to manage sensitive information for Dify applications. By storing secrets in professional secret management systems, you can achieve:

- **Enhanced Security**: Sensitive information is no longer stored in plain text in configuration files
- **Centralized Management**: Unified management of secrets across all environments
- **Audit Trail**: Complete secret access logs
- **Automatic Rotation**: Support for automatic secret rotation and updates
- **Least Privilege**: Precise control over service access to secrets

It is recommended to fully adopt ExternalSecret in production environments to replace traditional Secret management methods.
