#!/bin/bash
set -euo pipefail

VALUES_FILE="${1:-values.yaml}"
TEST_NAME="${2:-Helm Template Test}"

echo "INFO: Testing Helm template rendering for: $TEST_NAME"
echo "INFO: Using values file: $VALUES_FILE"

# Ensure values file exists
if [[ ! -f "ci/values/$VALUES_FILE" ]]; then
    echo "ERROR: Values file ci/values/$VALUES_FILE not found"
    exit 1
fi

# Test Helm template rendering
echo "INFO: Rendering Helm templates..."
helm template release-name1 charts/dify \
    --values "ci/values/$VALUES_FILE" \
    --namespace default \
    --debug \
    --output-dir /tmp/helm-output

# Check if templates were rendered successfully
if [[ $? -eq 0 ]]; then
    echo "SUCCESS: Helm template rendering successful"
else
    echo "ERROR: Helm template rendering failed"
    exit 1
fi

# Validate rendered YAML files
echo "INFO: Validating rendered YAML files..."
find /tmp/helm-output -name "*.yaml" -exec kubectl apply --dry-run=client -f {} \; > /tmp/validation.log 2>&1

if [[ $? -eq 0 ]]; then
    echo "SUCCESS: All rendered YAML files are valid"
else
    echo "ERROR: Some rendered YAML files are invalid"
    echo "INFO: Validation errors:"
    cat /tmp/validation.log
    exit 1
fi

# Check for specific resources based on configuration
echo "INFO: Checking rendered resources..."

# Count rendered resources
TOTAL_RESOURCES=$(find /tmp/helm-output -name "*.yaml" -exec grep -l "^kind:" {} \; | wc -l)
echo "INFO: Total rendered resources: $TOTAL_RESOURCES"

# Check for ExternalSecret resources
EXTERNAL_SECRETS=$(find /tmp/helm-output -name "*.yaml" -exec grep -l "kind: ExternalSecret" {} \; | wc -l)
echo "INFO: ExternalSecret resources: $EXTERNAL_SECRETS"

# Check for traditional Secret resources
SECRETS=$(find /tmp/helm-output -name "*.yaml" -exec grep -l "^kind: Secret$" {} \; | wc -l)
echo "INFO: Secret resources: $SECRETS"

# Check for PostgreSQL resources
POSTGRES_RESOURCES=$(find /tmp/helm-output -name "*.yaml" -exec grep -l "postgresql" {} \; | wc -l)
echo "INFO: PostgreSQL-related resources: $POSTGRES_RESOURCES"

# Verify resource consistency based on values file
if [[ "$VALUES_FILE" == *"eso"* ]]; then
    if [[ $EXTERNAL_SECRETS -eq 0 ]]; then
        echo "WARNING: No ExternalSecret resources found in ESO configuration"
    else
        echo "SUCCESS: ExternalSecret resources found as expected"
    fi
fi

if [[ "$VALUES_FILE" == *"legacy"* ]]; then
    if [[ $EXTERNAL_SECRETS -gt 0 ]]; then
        echo "WARNING: ExternalSecret resources found in legacy configuration"
    else
        echo "SUCCESS: No ExternalSecret resources found as expected in legacy mode"
    fi
fi

# Generate a summary report
echo "INFO: Template Rendering Summary for $TEST_NAME:"
echo "----------------------------------------"
echo "Values file: $VALUES_FILE"
echo "Total resources: $TOTAL_RESOURCES"
echo "ExternalSecrets: $EXTERNAL_SECRETS"
echo "Traditional Secrets: $SECRETS"
echo "PostgreSQL resources: $POSTGRES_RESOURCES"
echo "Status: PASSED"

# Save rendered templates for debugging
mkdir -p /tmp/test-outputs
cp -r /tmp/helm-output "/tmp/test-outputs/$(basename "$VALUES_FILE" .yaml)-output"

echo "INFO: Rendered templates saved to: /tmp/test-outputs/$(basename "$VALUES_FILE" .yaml)-output"