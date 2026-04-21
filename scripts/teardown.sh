#!/bin/bash
set -euo pipefail # stop script immediately if anything fails so i know if some clusters are deleted while others aren't

clusters=$(kind get clusters 2>/dev/null)

if [ -z "$clusters" ]; then # -z is for empty string
    echo "No kind clusters running."
    exit 0
fi

echo "Deleting kind clusters: $clusters"

for cluster in $clusters; do
    echo " ----------------------------------------------- " 
    echo "  -> Deleting $cluster..."
    kind delete cluster --name "$cluster"
done

echo "Done. All kind clusters removed."