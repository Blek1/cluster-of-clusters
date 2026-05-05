#!/bin/bash
set -e

for cmd in kubectl helm; do
  command -v "$cmd" &>/dev/null || {
    echo "Missing: $cmd"
    exit 1
  }
done

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# worker clusters — Prometheus only, no Grafana, no alertmanager
for CLUSTER in cluster-01 cluster-02; do
  echo "Installing Prometheus on kind-${CLUSTER}..."
  helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
    --kube-context kind-${CLUSTER} \
    --namespace monitoring \
    --create-namespace \
    --set grafana.enabled=false \
    --set alertmanager.enabled=false \
    --set prometheus.service.type=NodePort \
    --timeout 10m
done
# should be replaced by THANOS or prometheus federation scripts 
# get worker Prometheus IPs and ports
CLUSTER01_IP=$(docker inspect cluster-01-control-plane --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
CLUSTER02_IP=$(docker inspect cluster-02-control-plane --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
CLUSTER01_PROM_PORT=$(kubectl --context kind-cluster-01 -n monitoring get svc kube-prometheus-stack-prometheus -o jsonpath='{.spec.ports[?(@.name=="http-web")].nodePort}')
CLUSTER02_PROM_PORT=$(kubectl --context kind-cluster-02 -n monitoring get svc kube-prometheus-stack-prometheus -o jsonpath='{.spec.ports[?(@.name=="http-web")].nodePort}')

echo "cluster-01 Prometheus: $CLUSTER01_IP:$CLUSTER01_PROM_PORT"
echo "cluster-02 Prometheus: $CLUSTER02_IP:$CLUSTER02_PROM_PORT"

# host-01 — full stack with Grafana + provisioned datasources
echo "Installing full observability stack on host-01..."
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --kube-context kind-host-01 \
  --namespace monitoring \
  --create-namespace \
  --set grafana.adminPassword=a \
  --set prometheus.service.type=NodePort \
  --timeout 10m \
  --set-json "grafana.additionalDataSources=[
    {\"name\":\"cluster-01-prometheus\",\"type\":\"prometheus\",\"url\":\"http://$CLUSTER01_IP:$CLUSTER01_PROM_PORT\",\"access\":\"proxy\",\"isDefault\":false},
    {\"name\":\"cluster-02-prometheus\",\"type\":\"prometheus\",\"url\":\"http://$CLUSTER02_IP:$CLUSTER02_PROM_PORT\",\"access\":\"proxy\",\"isDefault\":false},
    {\"name\":\"karmada-prometheus\",\"type\":\"prometheus\",\"url\":\"http://prometheus.karmada-monitoring.svc:9090\",\"access\":\"proxy\",\"isDefault\":false}
  ]"

read -p "Setup observability of karmada? [y/N] " answer
if [[ "${answer}" =~ ^[Yy]$ ]]; then
  ${ROOT_DIR}/scripts/setup-karm-observ.sh
fi

echo ""
echo "To check node Host Node status:"
echo "kubectl get pods -n monitoring --context kind-host-01"
echo ""
echo "To open Grafana:"
echo "kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80 --context kind-host-01"
echo "Then visit http://localhost:3000 — login: admin / a"