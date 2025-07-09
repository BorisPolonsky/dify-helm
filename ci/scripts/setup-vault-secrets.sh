#!/bin/bash
set -euo pipefail

echo "Setting up Vault secrets for testing..."

# Wait for Vault to be ready
echo "Waiting for Vault to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault --timeout=300s

# Get the Vault pod name
VAULT_POD=$(kubectl get pods -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

# Check if we found a Vault pod
if [ -z "$VAULT_POD" ]; then
    echo "Error: No Vault pod found with label app.kubernetes.io/name=vault"
    echo "Available pods:"
    kubectl get pods --all-namespaces | grep -i vault || echo "No Vault pods found"
    exit 1
fi

echo "Using Vault pod: $VAULT_POD"

echo "Initializing Vault with test secrets..."

# Check if KV secrets engine is already enabled, if not enable it
echo "Checking if KV secrets engine is enabled..."
if kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault secrets list | grep -q "secret/"; then
  echo "KV secrets engine already enabled at secret/"
else
  echo "Enabling KV secrets engine..."
  kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault secrets enable -path=secret kv-v2
fi

# Add secrets for Dify components
echo "Adding Dify API secrets..."
kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault kv put secret/dify/api \
  secret_key="sk-test123" \
  code_execution_api_key="dify-sandbox"

echo "Adding database secrets..."
kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault kv put secret/dify/database \
  username="postgres" \
  password="difyai123456"

echo "Adding Redis secrets..."
kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault kv put secret/dify/redis \
  username="" \
  password="difyai123456" \
  celery_broker_url="redis://:difyai123456@redis:6379/1" \
  redis_password="difyai123456"

echo "Adding Weaviate secrets..."
kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault kv put secret/dify/weaviate \
  api_key="WVF5YThaHlkYwhGUSmCRgsX3tD5ngdN8pkih"

echo "Adding mail secrets..."
kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault kv put secret/dify/mail \
  resend_api_key="test-key"

echo "Adding plugin daemon secrets..."
kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault kv put secret/dify/plugin-daemon \
  server_key="test-plugin-key" \
  dify_api_key="test-dify-api-key"

echo "Adding sandbox secrets..."
kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault kv put secret/dify/sandbox \
  api_key="dify-sandbox"

echo "Adding PostgreSQL secrets..."
kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault kv put secret/dify/postgresql \
  postgres_password="difyai123456" \
  replication_password="repl123456"

echo "Adding S3 secrets..."
kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault kv put secret/dify/s3 \
  access_key="minio-root" \
  secret_key="minio123456"

# Enable AppRole auth method for External Secrets Operator
echo "Checking if AppRole auth method is enabled..."
if kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault auth list | grep -q "approle/"; then
  echo "AppRole auth method already enabled"
else
  echo "Enabling AppRole auth method..."
  kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault auth enable approle
fi

# Create a policy for External Secrets Operator
echo "Creating/updating ESO policy..."
kubectl exec -i $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault policy write eso-policy - << EOF
path "secret/data/dify/*" {
  capabilities = ["read"]
}
EOF

# Create AppRole
echo "Creating/updating AppRole..."
kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault write auth/approle/role/eso-role \
  token_policies="eso-policy" \
  token_ttl=1h \
  token_max_ttl=4h

# Get role-id and secret-id
ROLE_ID=$(kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault read -field=role_id auth/approle/role/eso-role/role-id)
SECRET_ID=$(kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault write -field=secret_id -f auth/approle/role/eso-role/secret-id)

echo "Creating Kubernetes secret for Vault credentials..."
kubectl create secret generic vault-credentials \
  --from-literal=role-id="$ROLE_ID" \
  --from-literal=secret-id="$SECRET_ID" \
  --dry-run=client -o yaml | kubectl apply -f -

# Test Vault connectivity
echo "Testing Vault connectivity..."
VAULT_IP=$(kubectl get service vault -o jsonpath='{.spec.clusterIP}')
echo "Vault service IP: $VAULT_IP"

# Test if we can read secrets
kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault kv get secret/dify/api
echo "Testing S3 secrets..."
kubectl exec $VAULT_POD -- env VAULT_TOKEN=dev-only-token vault kv get secret/dify/s3

echo "Vault secrets setup completed successfully!"
echo "Vault available at: http://vault:8200"
echo "Root token: dev-only-token"
echo "AppRole credentials stored in 'vault-credentials' secret"