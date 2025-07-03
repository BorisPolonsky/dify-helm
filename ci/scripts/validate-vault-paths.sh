#!/bin/bash
set -euo pipefail

echo "🔍 Validating Vault secret paths against values.yaml configuration..."

# Get the Vault pod name
VAULT_POD=$(kubectl get pods -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

# Check if we found a Vault pod
if [ -z "$VAULT_POD" ]; then
    echo "❌ Error: No Vault pod found with label app.kubernetes.io/name=vault"
    echo "📋 Available pods:"
    kubectl get pods --all-namespaces | grep -i vault || echo "No Vault pods found"
    exit 1
fi

echo "📝 Using Vault pod: $VAULT_POD"

# Function to check if a secret exists in Vault
check_vault_secret() {
    local path=$1
    local property=$2

    if kubectl exec $VAULT_POD -- vault kv get -field="$property" "secret/$path" >/dev/null 2>&1; then
        echo "✅ Found: secret/$path -> $property"
        return 0
    else
        echo "❌ Missing: secret/$path -> $property"
        return 1
    fi
}

echo "📝 Checking secrets used in values-eso.yaml..."

# Check API secrets
check_vault_secret "dify/api" "secret_key"
check_vault_secret "dify/sandbox" "api_key"  # Used for CODE_EXECUTION_API_KEY

# Check database secrets
check_vault_secret "dify/database" "username"
check_vault_secret "dify/database" "password"

# Check Redis secrets
check_vault_secret "dify/redis" "username"
check_vault_secret "dify/redis" "password"
check_vault_secret "dify/redis" "celery_broker_url"
check_vault_secret "dify/redis" "redis_password"

# Check Weaviate secrets
check_vault_secret "dify/weaviate" "api_key"

# Check Mail secrets
check_vault_secret "dify/mail" "resend_api_key"

# Check Plugin Daemon secrets
check_vault_secret "dify/plugin-daemon" "server_key"
check_vault_secret "dify/plugin-daemon" "dify_api_key"

# Check Sandbox secrets
check_vault_secret "dify/sandbox" "api_key"

# Check PostgreSQL secrets (for built-in PostgreSQL)
check_vault_secret "dify/postgresql" "postgres_password"
check_vault_secret "dify/postgresql" "replication_password"

echo ""
echo "🧪 Testing secret retrieval..."

# Test retrieving a few key secrets
echo "🔑 Testing API secret key retrieval:"
kubectl exec $VAULT_POD -- vault kv get -field=secret_key secret/dify/api

echo "🔑 Testing database password retrieval:"
kubectl exec $VAULT_POD -- vault kv get -field=password secret/dify/database

echo "🔑 Testing Redis password retrieval:"
kubectl exec $VAULT_POD -- vault kv get -field=redis_password secret/dify/redis

echo "✅ All secret paths validated successfully!"
