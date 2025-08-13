#!/bin/bash
set -euo pipefail

# Default mode - can be overridden by command line args
MODE="both"  # Options: setup, validate, both

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --setup-only)
            MODE="setup"
            shift
            ;;
        --validate-only)
            MODE="validate"
            shift
            ;;
        --help)
            echo "Usage: $0 [--setup-only|--validate-only|--help]"
            echo "  --setup-only     Only setup Vault secrets and configuration"
            echo "  --validate-only  Only validate existing Vault secrets"
            echo "  (no args)        Both setup and validate (default)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "🔧 Vault Setup and Validation Script"
echo "Mode: $MODE"
echo ""

# Initialize counters
SETUP_SUCCESS=0
SETUP_FAILED=0
VALIDATE_SUCCESS=0
VALIDATE_FAILED=0

# Function to get and validate Vault pod
get_vault_pod() {
    echo "📝 Getting Vault pod information..."
    
    # Get the Vault pod name
    VAULT_POD=$(kubectl get pods -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    # Check if we found a Vault pod
    if [ -z "$VAULT_POD" ]; then
        echo "❌ Error: No Vault pod found with label app.kubernetes.io/name=vault"
        echo "📋 Available pods:"
        kubectl get pods --all-namespaces | grep -i vault || echo "No Vault pods found"
        exit 1
    fi
    
    echo "✅ Using Vault pod: $VAULT_POD"
    return 0
}

# Function to check if a secret exists in Vault (for validation)
check_vault_secret() {
    local path=$1
    local property=$2
    
    if kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault kv get -field="$property" "secret/$path" >/dev/null 2>&1; then
        echo "✅ Found: secret/$path -> $property"
        ((VALIDATE_SUCCESS++))
        return 0
    else
        echo "❌ Missing: secret/$path -> $property"
        ((VALIDATE_FAILED++))
        return 1
    fi
}

# Function to setup a Vault secret
setup_vault_secret() {
    local description="$1"
    shift
    local vault_command="$@"
    
    echo "📝 $description..."
    if eval "$vault_command"; then
        echo "✅ $description completed"
        ((SETUP_SUCCESS++))
        return 0
    else
        echo "❌ $description failed"
        ((SETUP_FAILED++))
        return 1
    fi
}

# Wait for Vault to be ready if in setup mode
if [[ "$MODE" == "setup" || "$MODE" == "both" ]]; then
    echo "⏳ Waiting for Vault to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault --timeout=300s
fi

# Get Vault pod
get_vault_pod

# SETUP MODE
if [[ "$MODE" == "setup" || "$MODE" == "both" ]]; then
    echo ""
    echo "🚀 Starting Vault secrets setup..."
    echo "=================================="
    
    # Check if KV secrets engine is already enabled, if not enable it
    echo "🔧 Checking if KV secrets engine is enabled..."
    if kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault secrets list | grep -q "secret/"; then
        echo "✅ KV secrets engine already enabled at secret/"
    else
        setup_vault_secret "Enabling KV secrets engine" \
            "kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault secrets enable -path=secret kv-v2"
    fi
    
    # Setup all secrets
    setup_vault_secret "Adding Dify API secrets" \
        'kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault kv put secret/dify/api secret_key="sk-test123" code_execution_api_key="dify-sandbox"'
    
    setup_vault_secret "Adding database secrets" \
        'kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault kv put secret/dify/database username="postgres" password="difyai123456"'
    
    setup_vault_secret "Adding Redis secrets" \
        'kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault kv put secret/dify/redis username="" password="difyai123456" redis_password="difyai123456"'
    
    setup_vault_secret "Adding Weaviate secrets" \
        'kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault kv put secret/dify/weaviate api_key="WVF5YThaHlkYwhGUSmCRgsX3tD5ngdN8pkih"'
    
    setup_vault_secret "Adding mail secrets" \
        'kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault kv put secret/dify/mail resend_api_key="test-key"'
    
    setup_vault_secret "Adding plugin daemon secrets" \
        'kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault kv put secret/dify/plugin-daemon server_key="test-plugin-key" dify_api_key="test-dify-api-key"'
    
    setup_vault_secret "Adding sandbox secrets" \
        'kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault kv put secret/dify/sandbox api_key="dify-sandbox"'
    
    setup_vault_secret "Adding PostgreSQL secrets" \
        'kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault kv put secret/dify/postgresql postgres_password="difyai123456" replication_password="repl123456"'
    
    setup_vault_secret "Adding S3 secrets" \
        'kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault kv put secret/dify/s3 access_key="minio-root" secret_key="minio123456"'
    
    setup_vault_secret "Adding Elasticsearch secrets" \
        'kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault kv put secret/dify/elasticsearch elasticsearch_username="elastic" elasticsearch_password="elasticsearch123456"'
    
    setup_vault_secret "Adding OTEL secrets" \
        'kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault kv put secret/dify/otel api_key="test-otel-api-key"'
    
    # Setup AppRole authentication
    echo ""
    echo "🔐 Setting up AppRole authentication..."
    
    # Enable AppRole auth method for External Secrets Operator
    echo "🔧 Checking if AppRole auth method is enabled..."
    if kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault auth list | grep -q "approle/"; then
        echo "✅ AppRole auth method already enabled"
    else
        setup_vault_secret "Enabling AppRole auth method" \
            "kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault auth enable approle"
    fi
    
    # Create a policy for External Secrets Operator
    setup_vault_secret "Creating/updating ESO policy" \
        'kubectl exec -i $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault policy write eso-policy - << EOF
path "secret/data/dify/*" {
  capabilities = ["read"]
}
EOF'
    
    # Create AppRole
    setup_vault_secret "Creating/updating AppRole" \
        'kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault write auth/approle/role/eso-role token_policies="eso-policy" token_ttl=1h token_max_ttl=4h'
    
    # Get role-id and secret-id
    echo "🔑 Getting AppRole credentials..."
    ROLE_ID=$(kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault read -field=role_id auth/approle/role/eso-role/role-id)
    SECRET_ID=$(kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault write -field=secret_id -f auth/approle/role/eso-role/secret-id)
    
    setup_vault_secret "Creating Kubernetes secret for Vault credentials" \
        'kubectl create secret generic vault-credentials --from-literal=role-id="$ROLE_ID" --from-literal=secret-id="$SECRET_ID" --dry-run=client -o yaml | kubectl apply -f -'
    
    echo ""
    echo "📊 Setup Summary:"
    echo "✅ Successful operations: $SETUP_SUCCESS"
    echo "❌ Failed operations: $SETUP_FAILED"
fi

# VALIDATION MODE
if [[ "$MODE" == "validate" || "$MODE" == "both" ]]; then
    echo ""
    echo "🔍 Starting Vault secrets validation..."
    echo "======================================"
    
    # Validate all secrets used in values-eso.yaml
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
    
    # Check S3 secrets
    check_vault_secret "dify/s3" "access_key"
    check_vault_secret "dify/s3" "secret_key"
    
    # Check Elasticsearch secrets
    check_vault_secret "dify/elasticsearch" "elasticsearch_username"
    check_vault_secret "dify/elasticsearch" "elasticsearch_password"
    
    # Check OTEL secrets
    check_vault_secret "dify/otel" "api_key"
    
    echo ""
    echo "📊 Validation Summary:"
    echo "✅ Valid secrets: $VALIDATE_SUCCESS"
    echo "❌ Missing secrets: $VALIDATE_FAILED"
fi

# CONNECTIVITY TESTING
echo ""
echo "🧪 Testing Vault connectivity and secret retrieval..."
echo "=================================================="

# Test Vault connectivity
echo "🔗 Testing Vault connectivity..."
VAULT_IP=$(kubectl get service vault -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
if [[ -n "$VAULT_IP" ]]; then
    echo "✅ Vault service IP: $VAULT_IP"
else
    echo "⚠️ Could not get Vault service IP"
fi

# Test retrieving key secrets
echo ""
echo "🔑 Testing secret retrieval..."

test_secret_retrieval() {
    local description="$1"
    local path="$2" 
    local field="$3"
    
    echo "🔑 Testing $description:"
    if kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault kv get -field="$field" "secret/$path" >/dev/null 2>&1; then
        local value=$(kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault kv get -field="$field" "secret/$path")
        echo "✅ Retrieved successfully: ${value:0:10}... (first 10 chars)"
    else
        echo "❌ Failed to retrieve $description"
        return 1
    fi
}

test_secret_retrieval "API secret key" "dify/api" "secret_key"
test_secret_retrieval "database password" "dify/database" "password"
test_secret_retrieval "Redis password" "dify/redis" "redis_password"
test_secret_retrieval "S3 access key" "dify/s3" "access_key"
test_secret_retrieval "S3 secret key" "dify/s3" "secret_key"
test_secret_retrieval "Elasticsearch username" "dify/elasticsearch" "elasticsearch_username"
test_secret_retrieval "Elasticsearch password" "dify/elasticsearch" "elasticsearch_password"
test_secret_retrieval "OTEL API key" "dify/otel" "api_key"

# Final summary
echo ""
echo "🎉 Final Summary:"
echo "================"
if [[ "$MODE" == "setup" || "$MODE" == "both" ]]; then
    echo "🚀 Setup: $SETUP_SUCCESS successful, $SETUP_FAILED failed"
fi
if [[ "$MODE" == "validate" || "$MODE" == "both" ]]; then
    echo "🔍 Validation: $VALIDATE_SUCCESS valid, $VALIDATE_FAILED missing"
fi

echo ""
echo "ℹ️  Vault Information:"
echo "Vault available at: http://vault:8200"
echo "Root token: dev-only-token"
echo "AppRole credentials stored in 'vault-credentials' secret"

# Exit with appropriate code
TOTAL_FAILED=$((SETUP_FAILED + VALIDATE_FAILED))
if [[ $TOTAL_FAILED -eq 0 ]]; then
    echo "✅ All operations completed successfully!"
    exit 0
else
    echo "⚠️ Some operations failed. Check the output above for details."
    exit 1
fi