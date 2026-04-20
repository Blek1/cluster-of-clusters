#!/bin/bash
set -e

for cmd in kubectl karmadactl; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: '$cmd' is not installed. Check the README prerequisites."
        exit 1
    fi
done

echo "Initializing Karmada on the host cluster..."
kubectl config use-context kind-karmada-host
sudo karmadactl init --kubeconfig=$HOME/.kube/config

echo "Waiting for Karmada API to be ready..."
sleep 15

echo "Joining Worker 1 to Karmada..."
karmadactl join worker-1 --cluster-kubeconfig=$HOME/.kube/config --cluster-context=kind-worker-1

echo "Joining Worker 2 to Karmada..."
karmadactl join worker-2 --cluster-kubeconfig=$HOME/.kube/config --cluster-context=kind-worker-2

echo "Karmada Federation Complete! Verifying joined clusters:"
kubectl config use-context karmada-apiserver
kubectl get clusters
