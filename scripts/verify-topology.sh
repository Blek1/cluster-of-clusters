#!/bin/bash
set -e

NUM_WORKER_CLUSTERS=$1
if [ -z "$NUM_WORKER_CLUSTERS" ]; then
  echo "Usage: ./verify-topology.sh <NUM_WORKER_CLUSTERS>"
  exit 1
fi

if [ "$NUM_WORKER_CLUSTERS" -eq 1 ]; then
    echo "=== Verifying Baseline (1x18) ==="
    export KUBECONFIG=/home/luffy/clusters/worker-1.kubeconfig
    kubectl get nodes
else
    echo "=== Verifying Federated Topology ==="
    echo ""
    echo "[1] Checking Karmada Control Plane..."
    kubectl --kubeconfig="/home/luffy/clusters/karmada-apiserver.config" get clusters || echo "ERROR: Config not found."

    echo ""
    echo "[2] Checking Multi-Node Host Cluster (3 Phones)..."
    kubectl --kubeconfig="/home/luffy/clusters/host.kubeconfig" get nodes

    echo ""
    echo "[3] Checking Individual Member Clusters (15 Phones)..."
    for i in $(seq 1 $NUM_WORKER_CLUSTERS); do
        WORKER_KUBECONFIG="/home/luffy/clusters/worker-${i}.kubeconfig"
        echo "-> worker-$i nodes:"
        if [ -f "$WORKER_KUBECONFIG" ]; then
            kubectl --kubeconfig="$WORKER_KUBECONFIG" get nodes
        fi
        echo ""
    done
fi
