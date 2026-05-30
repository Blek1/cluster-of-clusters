#!/bin/bash
echo "=== Cleanup ==="

# KIND clusters
kind delete clusters --all 2>/dev/null || true

# Kill any port-forwards
pkill -f "kubectl port-forward" 2>/dev/null || true

# Kill any kubectl proxy
pkill -f "kubectl proxy" 2>/dev/null || true

# Kill any helm processes
pkill -f "helm" 2>/dev/null || true

# Delete all KWOK member clusters
echo "--- Deleting KWOK clusters ---"
kwokctl get clusters | xargs -I {} kwokctl delete cluster --name {}

# Delete karmada host kind cluster
echo "--- Deleting karmada-host kind cluster ---"
kind delete cluster --name karmada-host

echo "Done."
