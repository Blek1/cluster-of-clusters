#!/bin/bash
# basic cluster of clusters
set -e

for cmd in docker kind kubectl; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: '$cmd' is not installed. Check the README prerequisites."
        exit 1
    fi
done

echo "Spinning up Karmada Host Cluster..."
kind create cluster --name karmada-host --config ./configs/kind/host-config.yaml

sleep 60

echo "Spinning up Worker Cluster 1..."
kind create cluster --name worker-1 --config ./configs/kind/worker1-config.yaml

sleep 60

echo "Spinning up Worker Cluster 2..."
kind create cluster --name worker-2 --config ./configs/kind/worker2-config.yaml

kubectl config get-contexts
