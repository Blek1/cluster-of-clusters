#!/bin/bash
set -e

for cmd in kubectl helm; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: '$cmd' is not installed. Check the README prerequisites."
        exit 1
    fi
done

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo "Installing Central Observability (Grafana + Prometheus) on karmada-host..."

kubectl config use-context kind-karmada-host
kubectl create namespace monitoring || true

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword=admin \
  --set grafana.image.tag=10.4.1 \
  --set prometheus.service.type=NodePort \
  --timeout 10m \
  --wait

for CLUSTER in kind-worker-1 kind-worker-2; do
  echo "Installing Headless Prometheus on $CLUSTER..."
  kubectl config use-context $CLUSTER
  kubectl create namespace monitoring || true

  helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --set grafana.enabled=false \
    --set prometheus.service.type=NodePort \
    --timeout 10m \
    --wait
done

echo "Log in to Grafana at http://localhost:8080 with admin/admin"
echo "Run for port forwarding: kubectl --context=kind-karmada-host port-forward svc/kube-prometheus-stack-grafana 8080:80 -n monitoring"

echo "Add these data source URLs in the UI for worker clusters"

for CLUSTER in 1 2; do
  IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' worker-${CLUSTER}-control-plane)
  PORT=$(kubectl --context=kind-worker-${CLUSTER} get svc kube-prometheus-stack-prometheus -n monitoring -o jsonpath='{.spec.ports[0].nodePort}')
  echo "Worker $CLUSTER URL: http://$IP:$PORT"
done
