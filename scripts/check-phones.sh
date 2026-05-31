#!/bin/bash
export KUBECONFIG=/home/luffy/cluster-d-new.kubeconfig

echo "Checking node readiness..."
kubectl get nodes -L switch,image,reservation -o wide

echo ""
echo "Checking for crashed containerd states..."
NOT_READY=$(kubectl get nodes | grep NotReady | wc -l)
if [ "$NOT_READY" -gt 0 ]; then
    echo "WARNING: $NOT_READY nodes are NotReady."
    echo "Remember to run: /home/luffy/runbooks/recover-containerd-state.sh pf-XXX"
else
    echo "All nodes are Ready. The system is healthy."
fi
