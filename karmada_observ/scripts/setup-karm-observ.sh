#!/bin/bash
set -e

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
KARMADA_KUBECONFIG="$HOME/.karmada/karmada-apiserver.config"

echo "Step 1 — Creating RBAC for Karmada Prometheus..."
kubectl apply --context kind-host-01 -f "${ROOT_DIR}/configs/karmada/rbac.yaml"
kubectl apply --kubeconfig=$KARMADA_KUBECONFIG -f "${ROOT_DIR}/configs/karmada/rbac.yaml"
echo "✅ RBAC applied to both contexts"

echo "Step 2 — Creating ServiceAccount Secret..."
kubectl apply --context kind-host-01 -f "${ROOT_DIR}/configs/karmada/secret.yaml"
kubectl apply --kubeconfig=$KARMADA_KUBECONFIG -f "${ROOT_DIR}/configs/karmada/secret.yaml"
echo "✅ Secrets created"

echo "Step 3 — Getting Karmada token..."
sleep 5
KARMADA_TOKEN=$(kubectl get secret prometheus \
  --kubeconfig=$KARMADA_KUBECONFIG \
  -n karmada-monitoring \
  -o jsonpath='{.data.token}' | base64 -d)

if [[ -z "$KARMADA_TOKEN" ]]; then
  echo "Error: Failed to get Karmada token" >&2
  exit 1
fi
echo "✅ Got Karmada token"

echo "Step 4 — Deploying Karmada Prometheus..."
sed "s/KARMADA_TOKEN_PLACEHOLDER/${KARMADA_TOKEN}/g" \
  "${ROOT_DIR}/configs/karmada/deployment.yaml" | \
  kubectl apply --context kind-host-01 -f -
echo "✅ Karmada Prometheus deployed"
echo "✅ Grafana datasource will auto-provision via kube-prometheus-stack"