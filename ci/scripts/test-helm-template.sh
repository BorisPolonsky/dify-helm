#!/bin/bash
set -euo pipefail

VALUES_FILE="${1:-values.yaml}"
TEST_NAME="${2:-Helm Template Test}"

echo "🧪 Testing Helm template rendering for: $TEST_NAME"
echo "📄 Using values file: $VALUES_FILE"

# Ensure values file exists
if [[ ! -f "ci/values/$VALUES_FILE" ]]; then
    echo "❌ Values file ci/values/$VALUES_FILE not found"
    exit 1
fi

# Test Helm template rendering
echo "🔧 Rendering Helm templates..."
helm template release-name1 charts/dify \
    --values "ci/values/$VALUES_FILE" \
    --namespace default \
    --debug \
    --output-dir /tmp/helm-output

# Check if templates were rendered successfully
if [[ $? -eq 0 ]]; then
    echo "✅ Helm template rendering successful"
else
    echo "❌ Helm template rendering failed"
    exit 1
fi

# Validate rendered YAML files
echo "🔍 Validating rendered YAML files..."
find /tmp/helm-output -name "*.yaml" -exec kubectl apply --dry-run=client -f {} \; > /tmp/validation.log 2>&1

if [[ $? -eq 0 ]]; then
    echo "✅ All rendered YAML files are valid"
else
    echo "❌ Some rendered YAML files are invalid"
    echo "📋 Validation errors:"
    cat /tmp/validation.log
    exit 1
fi

# Check for specific resources based on configuration
echo "🔍 Checking rendered resources..."

# Count rendered resources
TOTAL_RESOURCES=$(find /tmp/helm-output -name "*.yaml" -exec grep -l "^kind:" {} \; | wc -l)
echo "📊 Total rendered resources: $TOTAL_RESOURCES"

# Check for ExternalSecret resources
EXTERNAL_SECRETS=$(find /tmp/helm-output -name "*.yaml" -exec grep -l "kind: ExternalSecret" {} \; | wc -l)
echo "🔐 ExternalSecret resources: $EXTERNAL_SECRETS"

# Check for traditional Secret resources
SECRETS=$(find /tmp/helm-output -name "*.yaml" -exec grep -l "^kind: Secret$" {} \; | wc -l)
echo "🔑 Secret resources: $SECRETS"

# Check for PostgreSQL resources
POSTGRES_RESOURCES=$(find /tmp/helm-output -name "*.yaml" -exec grep -l "postgresql" {} \; | wc -l)
echo "🐘 PostgreSQL-related resources: $POSTGRES_RESOURCES"

# Verify resource consistency based on values file
if [[ "$VALUES_FILE" == *"eso"* ]]; then
    if [[ $EXTERNAL_SECRETS -eq 0 ]]; then
        echo "⚠️  Warning: No ExternalSecret resources found in ESO configuration"
    else
        echo "✅ ExternalSecret resources found as expected"
    fi
fi

if [[ "$VALUES_FILE" == *"legacy"* ]]; then
    if [[ $EXTERNAL_SECRETS -gt 0 ]]; then
        echo "⚠️  Warning: ExternalSecret resources found in legacy configuration"
    else
        echo "✅ No ExternalSecret resources found as expected in legacy mode"
    fi
fi

# Generate a summary report
echo "📋 Template Rendering Summary for $TEST_NAME:"
echo "----------------------------------------"
echo "Values file: $VALUES_FILE"
echo "Total resources: $TOTAL_RESOURCES"
echo "ExternalSecrets: $EXTERNAL_SECRETS"
echo "Traditional Secrets: $SECRETS"
echo "PostgreSQL resources: $POSTGRES_RESOURCES"
echo "Status: ✅ PASSED"

# Save rendered templates for debugging
mkdir -p /tmp/test-outputs
cp -r /tmp/helm-output "/tmp/test-outputs/$(basename "$VALUES_FILE" .yaml)-output"

echo "📁 Rendered templates saved to: /tmp/test-outputs/$(basename "$VALUES_FILE" .yaml)-output"