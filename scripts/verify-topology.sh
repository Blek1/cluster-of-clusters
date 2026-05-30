#!/bin/bash
set -e

NUM_WORKER_CLUSTERS=$1

if [ -z "$NUM_WORKER_CLUSTERS" ]; then
  echo "Usage: ./verify-topology.sh <NUM_WORKER_CLUSTERS>"
  echo "Examples:"
  echo "  ./verify-topology.sh 1  (Verifies Baseline)"
  echo "  ./verify-topology.sh 2  (Verifies 1 Host + 2 Members)"
  exit 1
fi

if [ "$NUM_WORKER_CLUSTERS" -eq 1 ]; then
    echo "=== Verifying Baseline (1x19) ==="
    export KUBECONFIG=/home/luffy/cluster-d.kubeconfig
    
    echo "-> Checking Host Nodes..."
    kubectl get nodes
    
    TOTAL_NODES=$(kubectl get nodes --no-headers | wc -l)
    echo "Total Nodes Registered: $TOTAL_NODES / 19"
else
    echo "=== Verifying Federated Topology (1 Host + $NUM_WORKER_CLUSTERS Members) ==="
    
    echo ""
    echo "[1] Checking Karmada Control Plane..."
    # Use the Karmada config to see what clusters are successfully joined
    KARMADA_KUBECONFIG="/home/luffy/clusters/karmada-apiserver.config"
    if [ -f "$KARMADA_KUBECONFIG" ]; then
        kubectl --kubeconfig="$KARMADA_KUBECONFIG" get clusters
    else
        echo "ERROR: Karmada config not found. Did bootstrap complete?"
    fi

    echo ""
    echo "[2] Checking Individual Member Clusters..."
    for i in $(seq 1 $NUM_WORKER_CLUSTERS); do
        WORKER_KUBECONFIG="/home/luffy/clusters/worker-${i}.kubeconfig"
        echo "-> worker-$i nodes:"
        
        if [ -f "$WORKER_KUBECONFIG" ]; then
            kubectl --kubeconfig="$WORKER_KUBECONFIG" get nodes
        else
            echo "   [ERROR] Kubeconfig missing for worker-$i"
        fi
        echo ""
    done
    
    echo "[3] Checking Host Cluster (Remaining Nodes)..."
    kubectl --kubeconfig=/home/luffy/cluster-d.kubeconfig get nodes
fi
