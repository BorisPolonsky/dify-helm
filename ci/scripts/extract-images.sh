#!/bin/bash
set -euo pipefail

VALUES_FILE="${1:-values-eso.yaml}"
OUTPUT_FORMAT="${2:-github-actions}"

# Check if values file exists
if [[ ! -f "ci/values/$VALUES_FILE" ]]; then
    echo "Values file ci/values/$VALUES_FILE not found" >&2
    exit 1
fi

# Extract application images from the image section
API_REPO=$(grep -A1 "api:" "ci/values/$VALUES_FILE" | grep "repository:" | awk '{print $2}' | head -1)
API_TAG=$(grep -A2 "api:" "ci/values/$VALUES_FILE" | grep "tag:" | awk '{print $2}' | head -1 | tr -d '"')
API_IMAGE="$API_REPO:$API_TAG"

WEB_REPO=$(grep -A1 "web:" "ci/values/$VALUES_FILE" | grep "repository:" | awk '{print $2}' | head -1)
WEB_TAG=$(grep -A2 "web:" "ci/values/$VALUES_FILE" | grep "tag:" | awk '{print $2}' | head -1 | tr -d '"')
WEB_IMAGE="$WEB_REPO:$WEB_TAG"

SANDBOX_REPO=$(grep -A1 "sandbox:" "ci/values/$VALUES_FILE" | grep "repository:" | awk '{print $2}' | head -1)
SANDBOX_TAG=$(grep -A2 "sandbox:" "ci/values/$VALUES_FILE" | grep "tag:" | awk '{print $2}' | head -1 | tr -d '"')
SANDBOX_IMAGE="$SANDBOX_REPO:$SANDBOX_TAG"

PROXY_REPO=$(grep -A1 "proxy:" "ci/values/$VALUES_FILE" | grep "repository:" | awk '{print $2}' | head -1)
PROXY_TAG=$(grep -A2 "proxy:" "ci/values/$VALUES_FILE" | grep "tag:" | awk '{print $2}' | head -1 | tr -d '"')
PROXY_IMAGE="$PROXY_REPO:$PROXY_TAG"

SSRF_PROXY_REPO=$(grep -A1 "ssrfProxy:" "ci/values/$VALUES_FILE" | grep "repository:" | awk '{print $2}' | head -1)
SSRF_PROXY_TAG=$(grep -A2 "ssrfProxy:" "ci/values/$VALUES_FILE" | grep "tag:" | awk '{print $2}' | head -1 | tr -d '"')
SSRF_PROXY_IMAGE="$SSRF_PROXY_REPO:$SSRF_PROXY_TAG"

PLUGIN_DAEMON_REPO=$(grep -A1 "pluginDaemon:" "ci/values/$VALUES_FILE" | grep "repository:" | awk '{print $2}' | head -1)
PLUGIN_DAEMON_TAG=$(grep -A2 "pluginDaemon:" "ci/values/$VALUES_FILE" | grep "tag:" | awk '{print $2}' | head -1 | tr -d '"')
PLUGIN_DAEMON_IMAGE="$PLUGIN_DAEMON_REPO:$PLUGIN_DAEMON_TAG"

# Collect all Dify application images
DIFY_IMAGES=(
    "$API_IMAGE"
    "$WEB_IMAGE"
    "$SANDBOX_IMAGE"
    "$PROXY_IMAGE"
    "$SSRF_PROXY_IMAGE"
    "$PLUGIN_DAEMON_IMAGE"
)

# Common dependency images
DEPENDENCY_IMAGES=(
    "bitnami/postgresql:15.3.0-debian-11-r7"
    "bitnami/redis:7.0.11-debian-11-r12"
    "bitnami/redis-sentinel:7.0.11-debian-11-r10"
    "bitnami/redis-exporter:1.50.0-debian-11-r13"
    "bitnami/bitnami-shell:11-debian-11-r118"
)

# Common utility images
UTILITY_IMAGES=(
    "busybox:latest"
    "curlimages/curl:latest"
)

# Combine all images
ALL_IMAGES=("${DIFY_IMAGES[@]}" "${DEPENDENCY_IMAGES[@]}" "${UTILITY_IMAGES[@]}")

# Remove empty entries and duplicates
UNIQUE_IMAGES=($(printf '%s\n' "${ALL_IMAGES[@]}" | grep -v '^[[:space:]]*$' | sort -u))

case "$OUTPUT_FORMAT" in
    "github-actions")
        echo "${UNIQUE_IMAGES[*]}"
        ;;
    "list")
        printf '%s\n' "${UNIQUE_IMAGES[@]}"
        ;;
    "space-separated")
        echo "IMAGES_LIST=\"${UNIQUE_IMAGES[*]}\""
        ;;
    "cache-commands")
        for image in "${UNIQUE_IMAGES[@]}"; do
            echo "minikube image pull $image"
        done
        ;;
    *)
        echo "${UNIQUE_IMAGES[*]}"
        ;;
esac
