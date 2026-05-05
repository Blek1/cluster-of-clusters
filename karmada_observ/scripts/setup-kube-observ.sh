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

# host-01 — full stack with Grafana
echo "Installing full observability stack on host-01..."
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --kube-context kind-host-01 \
  --namespace monitoring \
  --create-namespace \
  --set grafana.adminPassword=a \
  --set prometheus.service.type=NodePort \
  --timeout 10m

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

# get worker Prometheus IPs and ports
CLUSTER01_IP=$(docker inspect cluster-01-control-plane --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
CLUSTER02_IP=$(docker inspect cluster-02-control-plane --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
CLUSTER01_PROM_PORT=$(kubectl --context kind-cluster-01 -n monitoring get svc kube-prometheus-stack-prometheus -o jsonpath='{.spec.ports[0].nodePort}')
CLUSTER02_PROM_PORT=$(kubectl --context kind-cluster-02 -n monitoring get svc kube-prometheus-stack-prometheus -o jsonpath='{.spec.ports[0].nodePort}')

echo "cluster-01 Prometheus: $CLUSTER01_IP:$CLUSTER01_PROM_PORT"
echo "cluster-02 Prometheus: $CLUSTER02_IP:$CLUSTER02_PROM_PORT"

# add worker Prometheus as datasources in host-01 Grafana
echo "Waiting for Grafana to be ready..."
kubectl wait --context kind-host-01 -n monitoring \
  --for=condition=Ready pod \
  -l app.kubernetes.io/name=grafana \
  --timeout=120s

kubectl --context kind-host-01 port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80 &
PF_PID=$!
sleep 5

# IP:PORT where Grafana can query cluster01 prom  
curl -s -X POST http://admin:a@localhost:3000/api/datasources \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"cluster-01-prometheus\",\"type\":\"prometheus\",\"url\":\"http://$CLUSTER01_IP:$CLUSTER01_PROM_PORT\",\"access\":\"proxy\",\"isDefault\":false}"

curl -s -X POST http://admin:a@localhost:3000/api/datasources \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"cluster-02-prometheus\",\"type\":\"prometheus\",\"url\":\"http://$CLUSTER02_IP:$CLUSTER02_PROM_PORT\",\"access\":\"proxy\",\"isDefault\":false}"


# sleep 1
kill $PF_PID

read -p "Setup observability of karmada? [y/N] " answer
  if [[ "${answer}" =~ ^[Yy]$ ]]; then
    ${ROOT_DIR}/scripts/setup-karm-observ.sh
  else
  echo ""
  echo "To check node Host Node status" 
  echo "kubectl get pods -n monitoring --context kind-host-01"

  echo "Done. To open Grafana:"
  echo "kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80 --context kind-host-01"
  echo "Then visit http://localhost:3000 — login: admin / a"
  fi
fi