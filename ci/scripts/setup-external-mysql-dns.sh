#!/bin/bash
set -euo pipefail

echo "INFO: Setting up external MySQL DNS resolution..."

# Wait for MySQL to be ready
echo "INFO: Waiting for external MySQL to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=mysql --timeout=300s

# Test database connection
echo "INFO: Testing database connection..."
kubectl run mysql-test --image=bitnamilegacy/mysql:8.0.37-debian-12-r2 --restart=Never --rm -i -- \
  mysql -h external-mysql -u root -pdifyai123456 -e "SHOW DATABASES;" || echo "Connection test completed"

# Get the MySQL service cluster IP
MYSQL_IP=$(kubectl get service external-mysql -o jsonpath='{.spec.clusterIP}')
echo "INFO: MySQL service IP: $MYSQL_IP"

# Update CoreDNS to simulate external hostname resolution
echo "INFO: Configuring CoreDNS for external MySQL hostname..."
kubectl patch configmap coredns -n kube-system --type merge -p='{"data":{"Corefile":".:53 {\n    errors\n    health {\n       lameduck 5s\n    }\n    ready\n    kubernetes cluster.local in-addr.arpa ip6.arpa {\n       pods insecure\n       fallthrough in-addr.arpa ip6.arpa\n       ttl 30\n    }\n    hosts {\n       '$MYSQL_IP' mysql1.uat.internal.dify.ai\n       fallthrough\n    }\n    prometheus :9153\n    forward . /etc/resolv.conf {\n       max_concurrent 1000\n    }\n    cache 30\n    loop\n    reload\n    loadbalance\n}"}}'

# Restart CoreDNS to pick up the changes
echo "INFO: Restarting CoreDNS..."
kubectl rollout restart deployment/coredns -n kube-system
kubectl rollout status deployment/coredns -n kube-system --timeout=120s

# Test external hostname resolution
echo "INFO: Testing external hostname resolution..."
kubectl run dns-test --rm --image=busybox --restart=Never -- nslookup mysql1.uat.internal.dify.ai || echo "DNS test completed"

echo "SUCCESS: External MySQL DNS setup completed"
echo "INFO: MySQL available at: mysql1.uat.internal.dify.ai:3306"
echo "INFO: Internal service: external-mysql:3306"

