#!/bin/bash
set -euo pipefail

echo "INFO: Setting up and validating Vault secrets for testing"

# Function to get and validate Vault pod
get_vault_pod() {
    echo "INFO: Getting Vault pod information..."

    # Get the Vault pod name
    VAULT_POD=$(kubectl get pods -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    # Check if we found a Vault pod
    if [ -z "$VAULT_POD" ]; then
        echo "ERROR: No Vault pod found with label app.kubernetes.io/name=vault"
        echo "INFO: Available pods:"
        kubectl get pods --all-namespaces | grep -i vault || echo "No Vault pods found"
        exit 1
    fi

    echo "INFO: Using Vault pod: $VAULT_POD"
    return 0
}

# Function to check if a secret exists in Vault (for validation)
check_vault_secret() {
    local path=$1
    local property=$2

    if kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault kv get -field="$property" "secret/$path" >/dev/null 2>&1; then
        echo "SUCCESS: Found secret/$path -> $property"
        return 0
    else
        echo "ERROR: Missing secret/$path -> $property"
        return 1
    fi
}

# Function to validate all secrets in batch
validate_all_secrets_batch() {
    echo "INFO: Validating all secrets in batch..."

    # Get all secrets in one kubectl exec call
    local secrets_data
    secrets_data=$(kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token sh << 'EOF'
set -euo pipefail
echo "=== BATCH_VALIDATION_START ==="

# Check all secret paths and properties (sh-compatible)
vault kv get -field="secret_key" "secret/dify/api" >/dev/null 2>&1 && echo "SUCCESS:dify/api:secret_key" || echo "ERROR:dify/api:secret_key"
vault kv get -field="api_key" "secret/dify/sandbox" >/dev/null 2>&1 && echo "SUCCESS:dify/sandbox:api_key" || echo "ERROR:dify/sandbox:api_key"
vault kv get -field="username" "secret/dify/database" >/dev/null 2>&1 && echo "SUCCESS:dify/database:username" || echo "ERROR:dify/database:username"
vault kv get -field="password" "secret/dify/database" >/dev/null 2>&1 && echo "SUCCESS:dify/database:password" || echo "ERROR:dify/database:password"
vault kv get -field="username" "secret/dify/redis" >/dev/null 2>&1 && echo "SUCCESS:dify/redis:username" || echo "ERROR:dify/redis:username"
vault kv get -field="password" "secret/dify/redis" >/dev/null 2>&1 && echo "SUCCESS:dify/redis:password" || echo "ERROR:dify/redis:password"
vault kv get -field="redis_password" "secret/dify/redis" >/dev/null 2>&1 && echo "SUCCESS:dify/redis:redis_password" || echo "ERROR:dify/redis:redis_password"
vault kv get -field="api_key" "secret/dify/weaviate" >/dev/null 2>&1 && echo "SUCCESS:dify/weaviate:api_key" || echo "ERROR:dify/weaviate:api_key"
vault kv get -field="resend_api_key" "secret/dify/mail" >/dev/null 2>&1 && echo "SUCCESS:dify/mail:resend_api_key" || echo "ERROR:dify/mail:resend_api_key"
vault kv get -field="server_key" "secret/dify/plugin-daemon" >/dev/null 2>&1 && echo "SUCCESS:dify/plugin-daemon:server_key" || echo "ERROR:dify/plugin-daemon:server_key"
vault kv get -field="dify_api_key" "secret/dify/plugin-daemon" >/dev/null 2>&1 && echo "SUCCESS:dify/plugin-daemon:dify_api_key" || echo "ERROR:dify/plugin-daemon:dify_api_key"
vault kv get -field="postgres_password" "secret/dify/postgresql" >/dev/null 2>&1 && echo "SUCCESS:dify/postgresql:postgres_password" || echo "ERROR:dify/postgresql:postgres_password"
vault kv get -field="replication_password" "secret/dify/postgresql" >/dev/null 2>&1 && echo "SUCCESS:dify/postgresql:replication_password" || echo "ERROR:dify/postgresql:replication_password"
vault kv get -field="access_key" "secret/dify/s3" >/dev/null 2>&1 && echo "SUCCESS:dify/s3:access_key" || echo "ERROR:dify/s3:access_key"
vault kv get -field="secret_key" "secret/dify/s3" >/dev/null 2>&1 && echo "SUCCESS:dify/s3:secret_key" || echo "ERROR:dify/s3:secret_key"
vault kv get -field="elasticsearch_username" "secret/dify/elasticsearch" >/dev/null 2>&1 && echo "SUCCESS:dify/elasticsearch:elasticsearch_username" || echo "ERROR:dify/elasticsearch:elasticsearch_username"
vault kv get -field="elasticsearch_password" "secret/dify/elasticsearch" >/dev/null 2>&1 && echo "SUCCESS:dify/elasticsearch:elasticsearch_password" || echo "ERROR:dify/elasticsearch:elasticsearch_password"
vault kv get -field="api_key" "secret/dify/otel" >/dev/null 2>&1 && echo "SUCCESS:dify/otel:api_key" || echo "ERROR:dify/otel:api_key"

echo "=== BATCH_VALIDATION_END ==="
EOF
)

    # Process the results
    while IFS= read -r line; do
        if [[ "$line" == "=== BATCH_VALIDATION_START ===" ]]; then
            continue
        elif [[ "$line" == "=== BATCH_VALIDATION_END ===" ]]; then
            break
        elif [[ "$line" =~ ^SUCCESS:(.+):(.+)$ ]]; then
            local path="${BASH_REMATCH[1]}"
            local property="${BASH_REMATCH[2]}"
            echo "SUCCESS: Found secret/$path -> $property"
        elif [[ "$line" =~ ^ERROR:(.+):(.+)$ ]]; then
            local path="${BASH_REMATCH[1]}"
            local property="${BASH_REMATCH[2]}"
            echo "ERROR: Missing secret/$path -> $property"
            return 1
        fi
    done <<< "$secrets_data"
}

# Function to setup a Vault secret
setup_vault_secret() {
    local description="$1"
    shift
    local vault_command="$@"

    echo "INFO: $description..."
    if eval "$vault_command"; then
        echo "SUCCESS: $description completed"
        return 0
    else
        echo "ERROR: $description failed"
        return 1
    fi
}

# Wait for Vault to be ready
echo "INFO: Waiting for Vault to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault --timeout=300s

# Get Vault pod
get_vault_pod

# SETUP PHASE
echo ""
echo "INFO: Starting Vault secrets setup..."
echo "===================================="

# Enable KV secrets engine (ignore if already exists)
echo "INFO: Ensuring KV secrets engine is enabled..."
kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault secrets enable -path=secret kv-v2 2>/dev/null || true
echo "INFO: KV secrets engine ready"

# Setup all secrets in batch
setup_vault_secret "Adding all Dify secrets in batch" \
    'kubectl exec -i $VAULT_POD -- env VAULT_TOKEN=dev-only-token sh << "EOF"
set -euo pipefail
echo "Setting up Dify API secrets..."
vault kv put secret/dify/api secret_key="sk-test123" code_execution_api_key="dify-sandbox"
echo "Setting up database secrets..."
vault kv put secret/dify/database username="postgres" password="difyai123456"
echo "Setting up Redis secrets..."
vault kv put secret/dify/redis username="" password="difyai123456" redis_password="difyai123456"
echo "Setting up Weaviate secrets..."
vault kv put secret/dify/weaviate api_key="WVF5YThaHlkYwhGUSmCRgsX3tD5ngdN8pkih"
echo "Setting up mail secrets..."
vault kv put secret/dify/mail resend_api_key="test-key"
echo "Setting up plugin daemon secrets..."
vault kv put secret/dify/plugin-daemon server_key="test-plugin-key" dify_api_key="test-dify-api-key"
echo "Setting up sandbox secrets..."
vault kv put secret/dify/sandbox api_key="dify-sandbox"
echo "Setting up PostgreSQL secrets..."
vault kv put secret/dify/postgresql postgres_password="difyai123456" replication_password="repl123456"
echo "Setting up S3 secrets..."
vault kv put secret/dify/s3 access_key="minio-root" secret_key="minio123456"
echo "Setting up Elasticsearch secrets..."
vault kv put secret/dify/elasticsearch elasticsearch_username="elastic" elasticsearch_password="elasticsearch123456"
echo "Setting up OTEL secrets..."
vault kv put secret/dify/otel api_key="test-otel-api-key"
echo "All secrets setup completed successfully"
EOF'

# Setup AppRole authentication
echo ""
echo "INFO: Setting up AppRole authentication..."

# Enable AppRole auth method for External Secrets Operator (ignore if already exists)
echo "INFO: Ensuring AppRole auth method is enabled..."
kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault auth enable approle 2>/dev/null || true
echo "INFO: AppRole auth method ready"

# Create a policy for External Secrets Operator (ignore if already exists)
echo "INFO: Creating/updating ESO policy..."
kubectl exec -i $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault policy write eso-policy - << 'EOF' 2>/dev/null || true
path "secret/data/dify/*" {
  capabilities = ["read"]
}
EOF
echo "INFO: ESO policy ready"

# Create AppRole (ignore if already exists)
echo "INFO: Creating/updating AppRole..."
kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault write auth/approle/role/eso-role token_policies="eso-policy" token_ttl=1h token_max_ttl=4h 2>/dev/null || true
echo "INFO: AppRole ready"

# Get role-id and secret-id
echo "INFO: Starting AppRole credentials retrieval..."
echo "INFO: Getting role-id..."
ROLE_ID=$(kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault read -field=role_id auth/approle/role/eso-role/role-id)
echo "INFO: Role ID retrieved: ${ROLE_ID:0:10}..."

echo "INFO: Getting secret-id..."
SECRET_ID=$(kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault write -field=secret_id -f auth/approle/role/eso-role/secret-id)
echo "INFO: Secret ID retrieved: ${SECRET_ID:0:10}..."

echo "INFO: AppRole credentials retrieval completed successfully"

setup_vault_secret "Creating Kubernetes secret for Vault credentials" \
    'kubectl create secret generic vault-credentials --from-literal=role-id="$ROLE_ID" --from-literal=secret-id="$SECRET_ID" --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true'

echo "INFO: Setup phase completed successfully"

# VALIDATION PHASE
echo ""
echo "INFO: ========================================="
echo "INFO: Starting Vault secrets validation phase..."
echo "INFO: ========================================="

# Validate all secrets used in values-eso.yaml
echo "INFO: Checking secrets used in values-eso.yaml..."

# Use batch validation instead of individual checks
echo "INFO: Starting batch validation of all secrets..."
validate_all_secrets_batch
echo "INFO: Batch validation completed"

echo "INFO: Validation phase completed successfully"

# Final summary
echo ""
echo "INFO: ========================================="
echo "INFO: Final Summary"
echo "INFO: ========================================="
echo "Vault available at: http://vault:8200"
echo "Root token: dev-only-token"
echo "AppRole credentials stored in 'vault-credentials' secret"

echo "SUCCESS: All operations completed successfully!"