#!/bin/bash
set -e

for cmd in kubectl karmadactl; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: '$cmd' is not installed. Check the README prerequisites."
        exit 1
    fi
done

KARMADA_DIR="$HOME/.karmada"
KARMADA_KUBECONFIG="$KARMADA_DIR/karmada-apiserver.config"
HOST_KUBECONFIG="$HOME/.kube/config"

echo "Initializing Karmada on the host cluster..."
kubectl config use-context kind-karmada-host
karmadactl init --karmada-data="$KARMADA_DIR" --karmada-pki="$KARMADA_DIR/pki"
# sudo karmadactl init --kubeconfig=$HOME/.kube/config


echo "Waiting for Karmada API to be ready..."
sleep 60

echo "Joining Worker 1 to Karmada..."
# karmadactl join worker-1 --cluster-kubeconfig=$HOME/.kube/config --cluster-context=kind-worker-1
karmadactl join worker-1 \
  --karmada-kubeconfig="$KARMADA_KUBECONFIG" \
  --cluster-kubeconfig="$HOST_KUBECONFIG" \
  --cluster-context=kind-worker-1

# echo "Joining Worker 2 to Karmada..."
# karmadactl join worker-2 --cluster-kubeconfig=$HOME/.kube/config --cluster-context=kind-worker-2

echo "Karmada Federation Complete! Verifying joined clusters:"
# kubectl get clusters
kubectl --kubeconfig="$KARMADA_KUBECONFIG" get clusters
