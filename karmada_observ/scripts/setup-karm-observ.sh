#!/bin/bash
set -e

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
KARMADA_KUBECONFIG="$HOME/.karmada/karmada-apiserver.config"
echo $ROOT_DIR
ls ${ROOT_DIR}/configs/karmada/
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
echo "✅ Prometheus deployed"


echo "Step 5 — Adding Karmada Prometheus as Grafana datasource..."
KARMADA_PROM_IP=$(docker inspect host-01-control-plane --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
KARMADA_PROM_PORT=$(kubectl --context kind-host-01 -n karmada-monitoring get svc prometheus -o jsonpath='{.spec.ports[0].nodePort}')

curl -s -X POST http://admin:a@localhost:3000/api/datasources \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"karmada-prometheus\",\"type\":\"prometheus\",\"url\":\"http://$KARMADA_PROM_IP:$KARMADA_PROM_PORT\",\"access\":\"proxy\",\"isDefault\":false}"
echo "✅ Karmada Prometheus added as Grafana datasource"