#!/bin/bash
set -euo pipefail # stop script immediately if anything fails

CONFIGS_DIR="$(dirname "$0")/../configs/kind"

clusters=$(kind get clusters 2>/dev/null)

if [ -n "$clusters" ]; then # -n is for non empty string
    echo "kind cluster already running: $clusters"
    echo "Run teardown.sh first"
    exit 0
fi

echo "Creating kind clusters from $CONFIGS_DIR..."

for config in "$CONFIGS_DIR"/*.yaml; do
    cluster_name=$(grep '^name:' "$config" | awk '{print $2}')
    echo " ----------------------------------------------- " 
    echo "  -> Creating cluster '$cluster_name' from $(basename "$config"):"
    kind create cluster --config "$config"
done

echo "Done. Kind clusters created:"
kind get clusters
