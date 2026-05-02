#!/bin/bash

# KIND clusters
kind delete clusters --all 2>/dev/null || true

# Kill any port-forwards
pkill -f "kubectl port-forward" 2>/dev/null || true

# Kill any kubectl proxy
pkill -f "kubectl proxy" 2>/dev/null || true

# Kill any helm processes
pkill -f "helm" 2>/dev/null || true

echo "Done."
