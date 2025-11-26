#!/bin/bash
set -euo pipefail

echo "🔧 Creating default-secret-store ClusterSecretStore for External Secrets Operator..."

# Create a test ClusterSecretStore that uses Vault as backend
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: default-secret-store
spec:
  provider:
    vault:
      server: "http://vault.default.svc.cluster.local:8200"
      path: "secret"
      version: "v2"
      auth:
        appRole:
          path: "approle"
          roleRef:
            name: "vault-credentials"
            key: "role-id"
            namespace: "default"
          secretRef:
            name: "vault-credentials"
            key: "secret-id"
            namespace: "default"
EOF

echo "⏳ Waiting for ClusterSecretStore to be ready..."
if ! kubectl wait --for=condition=ready clustersecretstore default-secret-store --timeout=60s; then
    echo "❌ ClusterSecretStore failed to become ready."

    echo "🔍 Describing ClusterSecretStore:"
    kubectl describe clustersecretstore default-secret-store

    exit 1
fi

echo "✅ Test ClusterSecretStore created successfully"
kubectl get clustersecretstore