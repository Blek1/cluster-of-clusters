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

kubectl config use-context kind-worker-1
kubectl create namespace monitoring || true

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword=admin \
  --set grafana.image.tag=10.4.1 \
  --timeout 10m \
  --wait

echo "Log in to Grafana at http://localhost:8080 with admin/admin"
echo "Run for port forwarding: kubectl --context=kind-worker-1 port-forward svc/kube-prometheus-stack-grafana 8080:80 -n monitoring"

