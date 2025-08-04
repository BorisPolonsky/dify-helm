#!/bin/bash
set -euo pipefail

echo "INFO: Setting up external PostgreSQL DNS resolution..."

# Wait for PostgreSQL to be ready
echo "INFO: Waiting for external PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql --timeout=300s

# Test database connection
echo "INFO: Testing database connection..."
kubectl run postgres-test --rm --image=postgres:15 --restart=Never -- \
  psql -h external-postgres-postgresql -U postgres -d dify -c "\l" || echo "Connection test completed"

# Get the PostgreSQL service cluster IP
POSTGRES_IP=$(kubectl get service external-postgres-postgresql -o jsonpath='{.spec.clusterIP}')
echo "INFO: PostgreSQL service IP: $POSTGRES_IP"

# Update CoreDNS to simulate external hostname resolution
echo "INFO: Configuring CoreDNS for external PostgreSQL hostname..."
kubectl patch configmap coredns -n kube-system --type merge -p='{"data":{"Corefile":".:53 {\n    errors\n    health {\n       lameduck 5s\n    }\n    ready\n    kubernetes cluster.local in-addr.arpa ip6.arpa {\n       pods insecure\n       fallthrough in-addr.arpa ip6.arpa\n       ttl 30\n    }\n    hosts {\n       '$POSTGRES_IP' pg1.uat.internal.dify.ai\n       fallthrough\n    }\n    prometheus :9153\n    forward . /etc/resolv.conf {\n       max_concurrent 1000\n    }\n    cache 30\n    loop\n    reload\n    loadbalance\n}"}}'

# Restart CoreDNS to pick up the changes
echo "INFO: Restarting CoreDNS..."
kubectl rollout restart deployment/coredns -n kube-system
kubectl rollout status deployment/coredns -n kube-system --timeout=120s

# Test external hostname resolution
echo "INFO: Testing external hostname resolution..."
kubectl run dns-test --rm --image=busybox --restart=Never -- nslookup pg1.uat.internal.dify.ai || echo "DNS test completed"

echo "SUCCESS: External PostgreSQL DNS setup completed"
echo "INFO: PostgreSQL available at: pg1.uat.internal.dify.ai:5432"
echo "INFO: Internal service: external-postgres-postgresql:5432"