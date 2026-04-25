#!/bin/bash
set -e

if ! command -v kubectl &> /dev/null; then
    echo "Error: 'kubectl' is not installed. Check the README prerequisites."
    exit 1
fi

DASHBOARD_DIR="../configs/prometheus-grafana/dashboards"
mkdir -p "$DASHBOARD_DIR"

kubectl config use-context kind-worker-1

for file in "$DASHBOARD_DIR"/*.json; do
  [ -e "$file" ] || { echo "No dashboards found to import."; exit 0; }
  
  FILENAME=$(basename "$file" .json)
  CM_NAME="grafana-dashboard-$(echo $FILENAME | tr '[:upper:]' '[:lower:]' | tr '_' '-')"

  kubectl delete configmap "$CM_NAME" --namespace monitoring --ignore-not-found
  
  kubectl create configmap "$CM_NAME" \
    --from-file="$FILENAME.json=$file" \
    --namespace monitoring \
    
  kubectl label configmap "$CM_NAME" grafana_dashboard="1" --namespace monitoring --overwrite
done
