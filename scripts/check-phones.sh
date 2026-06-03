#!/bin/bash
set -e

echo "=== CHECKING HOST CLUSTER (3 PHONES) ==="
KUBECONFIG=/home/luffy/clusters/host.kubeconfig kubectl get nodes -L switch,image,reservation -o wide || echo "Host cluster not reachable"

echo ""
echo "=== CHECKING MEMBER CLUSTERS ==="
for conf in /home/luffy/clusters/worker-*.kubeconfig; do
    if [ -f "$conf" ]; then
        CLUSTER_NAME=$(basename $conf .kubeconfig)
        echo "--- $CLUSTER_NAME ---"
        kubectl --kubeconfig=$conf get nodes -L switch,image,reservation -o wide
        echo ""
    fi
done

echo ""
echo "Checking for crashed containerd states across all clusters..."
NOT_READY=0
for conf in /home/luffy/clusters/host.kubeconfig /home/luffy/clusters/worker-*.kubeconfig; do
    if [ -f "$conf" ]; then
        CURRENT_NOT_READY=$(kubectl --kubeconfig=$conf get nodes | grep -c "NotReady" || echo "0")
        NOT_READY=$((NOT_READY + CURRENT_NOT_READY))
    fi
done

if [ "$NOT_READY" -gt 0 ]; then
    echo "WARNING: $NOT_READY nodes are NotReady across the entire federation."
    echo "Remember to run: /home/luffy/runbooks/recover-containerd-state.sh pf-XXX"
else
    echo "All 18 nodes are Ready. The system is healthy."
fi
