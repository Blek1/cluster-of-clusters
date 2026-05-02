#!/bin/bash
# basic cluster of clusters
set -e

echo "Spinning up KIND Cluster 01..."
kind create cluster --name cluster-01 --config ./configs/kind/cluster-01-config.yaml

echo "==> Finished Cluster creation..."
kubectl get nodes
kubectl config get-contexts
