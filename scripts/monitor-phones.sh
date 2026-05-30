#!/bin/bash

NUM_WORKER_CLUSTERS=$1

if [ -z "$NUM_WORKER_CLUSTERS" ]; then
  echo "Usage: ./monitor-phones.sh <NUM_WORKER_CLUSTERS>"
  echo "Examples:"
  echo "  ./monitor-phones.sh 1  (Monitors Baseline)"
  echo "  ./monitor-phones.sh 2  (Monitors 1 Host + 2 Members)"
  exit 1
fi

# Function to clear screen and print the dashboard
print_dashboard() {
    clear
    echo "================================================================="
    echo " LIVE EXPERIMENT MONITOR: 500 NGINX PODS "
    echo " Time: $(date '+%H:%M:%S')"
    echo "================================================================="
    echo ""

    if [ "$NUM_WORKER_CLUSTERS" -eq 1 ]; then
        export KUBECONFIG=/home/luffy/cluster-d.kubeconfig
        
        echo "[ PHYSICAL PHONE HEALTH ]"
        kubectl get nodes | grep -v "master"
        echo ""
        
        echo "[ OVERALL ROLLOUT STATUS ]"
        kubectl get deployment workload-nginx 2>/dev/null || echo "Waiting for workload to be injected..."
        echo ""
        
        echo "[ POD DISTRIBUTION PER PHONE ]"
        echo "(Number of Pods | Phone Name)"
        kubectl get pods -l app=nginx -o wide 2>/dev/null | awk '{print $7}' | grep -v "NODE" | sort | uniq -c || echo "No pods scheduled yet."
        
    else
        export KUBECONFIG=/home/luffy/clusters/karmada-apiserver.config
        echo "[ OVERALL KARMADA ROLLOUT STATUS ]"
        kubectl get deployment workload-nginx 2>/dev/null || echo "Waiting for workload to be injected..."
        echo ""

        for i in $(seq 1 $NUM_WORKER_CLUSTERS); do
            WORKER_KUBECONFIG="/home/luffy/clusters/worker-${i}.kubeconfig"
            echo "========================================"
            echo " WORKER-$i SUB-CLUSTER "
            echo "========================================"
            
            if [ -f "$WORKER_KUBECONFIG" ]; then
                echo "-> Phone Hardware Health:"
                kubectl --kubeconfig="$WORKER_KUBECONFIG" get nodes | grep -v "master"
                
                echo ""
                echo "-> Pod Distribution Per Phone:"
                kubectl --kubeconfig="$WORKER_KUBECONFIG" get pods -l app=nginx -o wide 2>/dev/null | awk '{print $7}' | grep -v "NODE" | sort | uniq -c || echo "No pods scheduled yet."
            else
                echo "[ERROR] Kubeconfig missing for worker-$i"
            fi
            echo ""
        done
    fi
}

# Infinite loop to refresh the dashboard every 2 seconds
while true; do
    print_dashboard
    sleep 2
done
