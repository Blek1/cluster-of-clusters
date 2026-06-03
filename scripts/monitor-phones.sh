#!/bin/bash
set -e

NUM_WORKER_CLUSTERS=$1
if [ -z "$NUM_WORKER_CLUSTERS" ]; then
  echo "Usage: ./monitor-phones.sh <NUM_WORKER_CLUSTERS>"
  exit 1
fi

print_dashboard() {
    clear
    echo "================================================================="
    echo " LIVE EXPERIMENT MONITOR: 500 NGINX PODS "
    echo " Time: $(date '+%H:%M:%S')"
    echo "================================================================="
    echo ""

    if [ "$NUM_WORKER_CLUSTERS" -eq 1 ]; then
        export KUBECONFIG="/home/luffy/clusters/worker-1.kubeconfig"
        echo "[ OVERALL ROLLOUT STATUS ]"
        kubectl get deployment workload-nginx || echo "Waiting for workload..."
        echo ""
        echo "[ POD DISTRIBUTION PER PHONE ]"
        kubectl get pods -l app=nginx -o wide | awk '{print $7}' | grep -v "NODE" | sort | uniq -c || echo "No pods scheduled yet."
    else
        export KUBECONFIG=/home/luffy/clusters/karmada-apiserver.config
        echo "[ OVERALL KARMADA ROLLOUT STATUS ]"
        kubectl get deployment workload-nginx || echo "Waiting for workload..."
        echo ""

        for i in $(seq 1 $NUM_WORKER_CLUSTERS); do
            WORKER_KUBECONFIG="/home/luffy/clusters/worker-${i}.kubeconfig"
            echo "========================================"
            echo " WORKER-$i SUB-CLUSTER "
            echo "========================================"
            if [ -f "$WORKER_KUBECONFIG" ]; then
                kubectl --kubeconfig="$WORKER_KUBECONFIG" get pods -l app=nginx -o wide | awk '{print $7}' | grep -v "NODE" | sort | uniq -c || echo "No pods scheduled yet."
            fi
            echo ""
        done
    fi
}

while true; do
    print_dashboard
    sleep 2
done
