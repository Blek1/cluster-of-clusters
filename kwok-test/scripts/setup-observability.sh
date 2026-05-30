#!/bin/bash
# setup-observability.sh
# Follows the official Karmada monitoring doc exactly, adapted to our setup.
#
# Doc: https://karmada.io/docs/administrator/monitoring/use-prometheus-to-monitor-karmada-control-plane
#
# Steps:
#   1. Apply RBAC to kind-host-01 (where Prometheus runs)
#   2. Apply RBAC + Secret to karmada-apiserver (so Prometheus can scrape it)
#   3. Get bearer token from karmada-apiserver
#   4. Inject token into prometheus.yaml and apply it to kind-host-01
#   5. Deploy Grafana via Helm
#   6. Import dashboards from configs/dashboards/
set -e
KARMADA_CONTEXT="karmada-apiserver"
KARMADA_KUBECONFIG="$HOME/.karmada/karmada-apiserver.config"
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
OBSERV_DIR="${ROOT_DIR}/configs/observ"
HOST_CONTEXT="kind-host-01"
KARMADA_CONTEXT="karmada-apiserver"
NAMESPACE="monitor"
GRAFANA_PORT=3000
DASHBOARD_DIR="${ROOT_DIR}/configs/dashboards"


#  Step 1: RBAC on kind-host-01 
echo ""
echo "Step 1 Applying RBAC to ${HOST_CONTEXT}..."
kubectl --context "${HOST_CONTEXT}" apply -f "${OBSERV_DIR}/rbac.yaml"
echo "Done"

#  Step 2: RBAC + Secret on karmada-apiserver 
echo ""
echo "Step  Applying RBAC + Secret to ${KARMADA_CONTEXT}..."
kubectl --kubeconfig "${KARMADA_KUBECONFIG}" \
  --context "${KARMADA_CONTEXT}" apply -f "${OBSERV_DIR}/rbac.yaml"

kubectl --kubeconfig "${KARMADA_KUBECONFIG}" \
  --context "${KARMADA_CONTEXT}" apply -f "${OBSERV_DIR}/secret.yaml"
echo " Done"

#  Step 3: Get bearer token 
echo ""
echo "Step 3 Getting bearer token from ${KARMADA_CONTEXT}..."
sleep 3  # give secret time to populate
KARMADA_TOKEN=$(kubectl --kubeconfig "${KARMADA_KUBECONFIG}" \
  get secret prometheus \
  -o=jsonpath='{.data.token}' \
  -n "${NAMESPACE}" | base64 -d)

if [[ -z "${KARMADA_TOKEN}" ]]; then
  echo " Failed to get token — try running again in a few seconds"
  exit 1
fi
echo "✅ Token obtained"

#  Step 4: Inject token and deploy Prometheus 
echo ""
echo " Step 4 Deploying Prometheus to ${HOST_CONTEXT}..."

# Replace placeholder with real token in a temp copy
TMP_PROM=$(mktemp /tmp/prometheus-XXXX.yaml)
trap 'rm -f "${TMP_PROM}"' EXIT
sed "s/KARMADA_TOKEN_PLACEHOLDER/${KARMADA_TOKEN}/g" \
  "${OBSERV_DIR}/prometheus.yaml" > "${TMP_PROM}"

kubectl --context "${HOST_CONTEXT}" apply -f "${TMP_PROM}"

echo " Waiting for Prometheus to be ready..."
kubectl rollout status deployment/prometheus \
  --namespace "${NAMESPACE}" \
  --context "${HOST_CONTEXT}" \
  --timeout=120s
echo "✅ Prometheus running"

#  Step 5: Deploy Grafana via Helm 
echo ""
echo "Step 5 Deploying Grafana..."
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo update

helm upgrade --install grafana grafana/grafana \
  --kube-context "${HOST_CONTEXT}" \
  --namespace "${NAMESPACE}" \
  --set adminPassword=admin \
  --set service.type=ClusterIP \
  --timeout 5m \
  --wait

echo " Grafana running"

#  Step 6: Import dashboards 
echo ""
echo " Step 6 Port-forwarding Grafana to import dashboards..."
kubectl port-forward \
  --context "${HOST_CONTEXT}" \
  --namespace "${NAMESPACE}" \
  svc/grafana \
  "${GRAFANA_PORT}":80 &
PF_PID=$!
trap 'kill ${PF_PID} 2>/dev/null || true; rm -f "${TMP_PROM}"' EXIT
sleep 4

# Add Prometheus datasource
echo " Adding Prometheus datasource..."
curl -sf -X POST "http://localhost:${GRAFANA_PORT}/api/datasources" \
  -u "admin:admin" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Prometheus",
    "type": "prometheus",
    "url": "http://prometheus.monitor.svc.cluster.local:9090",
    "access": "proxy",
    "isDefault": true
  }' > /dev/null && echo "Datasource added" || echo " Datasource may already exist"

# Import each dashboard JSON
if [ -n "$(ls -A ${DASHBOARD_DIR}/*.json 2>/dev/null)" ]; then
  echo "Importing dashboards..."
  for f in "${DASHBOARD_DIR}"/*.json; do
    NAME=$(basename "$f")
    CODE=$(curl -s -o /dev/null -w "%{http_code}" \
      -X POST "http://localhost:${GRAFANA_PORT}/api/dashboards/import" \
      -u "admin:admin" \
      -H "Content-Type: application/json" \
      -d "{\"dashboard\": $(cat "$f"), \"overwrite\": true, \"folderId\": 0}")
    [[ "$CODE" == "200" ]] && echo "    $NAME" || echo "     $NAME (HTTP $CODE)"
  done
else
  echo "  No dashboards found in ${DASHBOARD_DIR} — skipping"
fi

# ── Done 
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ All done!"
echo ""
echo "  Grafana:  http://localhost:${GRAFANA_PORT}"
echo "  Login:    admin / admin"
echo ""
echo "  Re-open later:"
echo "  kubectl port-forward -n ${NAMESPACE} svc/grafana ${GRAFANA_PORT}:80 --context ${HOST_CONTEXT}"
echo ""
echo "  Prometheus:"
echo "  kubectl port-forward -n ${NAMESPACE} svc/prometheus 9090:9090 --context ${HOST_CONTEXT}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Press Ctrl+C to stop port-forward"
wait ${PF_PID}