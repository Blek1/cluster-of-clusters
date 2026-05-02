#!/bin/bash
set -e

for cmd in kubectl karmadactl docker; do
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
karmadactl init --karmada-data="$KARMADA_DIR" --karmada-pki="$KARMADA_DIR/pki" --karmada-apiserver-advertise-address=127.0.0.1

echo "Waiting for Karmada API to be ready..."
sleep 100

echo "Generating temp kubeconfigs with mapped host ports..."
WORKER1_PORT=$(docker inspect worker-1-control-plane --format '{{(index (index .NetworkSettings.Ports "6443/tcp") 0).HostPort}}')
WORKER2_PORT=$(docker inspect worker-2-control-plane --format '{{(index (index .NetworkSettings.Ports "6443/tcp") 0).HostPort}}')

kubectl config view --context=kind-worker-1 --minify --flatten > /tmp/worker1.yaml
kubectl config set-cluster kind-worker-1 \
  --server="https://127.0.0.1:$WORKER1_PORT" \
  --kubeconfig=/tmp/worker1.yaml

kubectl config view --context=kind-worker-2 --minify --flatten > /tmp/worker2.yaml
kubectl config set-cluster kind-worker-2 \
  --server="https://127.0.0.1:$WORKER2_PORT" \
  --kubeconfig=/tmp/worker2.yaml

echo "Joining Worker 1 to Karmada..."
karmadactl join worker-1 \
  --kubeconfig="$KARMADA_KUBECONFIG" \
  --cluster-kubeconfig=/tmp/worker1.yaml \
  --cluster-context=kind-worker-1

echo "Joining Worker 2 to Karmada..."
karmadactl join worker-2 \
  --kubeconfig="$KARMADA_KUBECONFIG" \
  --cluster-kubeconfig=/tmp/worker2.yaml \
  --cluster-context=kind-worker-2

echo "Karmada Federation Complete! Verifying joined clusters:"
kubectl --kubeconfig="$KARMADA_KUBECONFIG" get clusters
