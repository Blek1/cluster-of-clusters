#!/bin/bash
set -euo pipefail # stop script immediately if anything fails so i know if some clusters are deleted while others aren't

# kind clusters
clusters=$(kind get clusters 2>/dev/null)

if [ -z "$clusters" ]; then
    echo "No kind clusters running."
else
    echo "Deleting kind clusters: $clusters"

    for cluster in $clusters; do
        echo " ----------------------------------------------- " 
        echo "Deleting $cluster..."
        kind delete cluster --name "$cluster"
    done

    echo "Done. All kind clusters removed."
fi

# kwok clusters
kwok_clusters=$(kwokctl get clusters 2>/dev/null)

if [ -z "$kwok_clusters" ]; then
    echo "No kwok clusters running."
else
    echo "Deleting kwok clusters: $kwok_clusters"

    for cluster in $kwok_clusters; do
        echo " ----------------------------------------------- "
        echo "Deleting $cluster..."
        kwokctl delete cluster --name "$cluster"
    done

    echo "Done. All kwok clusters removed."
fi

# grafana 
if docker ps -a --format '{{.Names}}' | grep -q "^grafana$"; then
    echo " ----------------------------------------------- "
    echo "Removing Grafana container..."
    docker rm -f grafana
    echo "Done. Grafana container removed."
fi