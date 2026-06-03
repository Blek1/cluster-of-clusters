#!/bin/bash
set -e

NUM_WORKERS=70 # 65 max so far
CONFIG_FILE="../configs/kind/mega-cluster.yaml"
LOG_DIR="./logs/mega-cluster"

echo "Generating Mega Cluster with 1 Control Plane & $NUM_WORKERS Workers..."

mkdir -p ../configs/kind
mkdir -p "$LOG_DIR"

cat <<EOF > "$CONFIG_FILE"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
EOF

for i in $(seq 1 $NUM_WORKERS); do
  echo "  - role: worker" >> "$CONFIG_FILE"
done

echo "Spinning up Mega Cluster... (This will take a few minutes)"
if kind create cluster --name mega-cluster --config "$CONFIG_FILE" --retain -v 4; then
    echo " SUCCESS! Mega Cluster is UP."
    kubectl get nodes
else
    echo " CRASH DETECTED. Initiating post-mortem diagnostics..."
    echo "Exporting node logs to $LOG_DIR..."
    kind export logs "$LOG_DIR" --name mega-cluster
    echo "Diagnostic extraction complete."
    echo "The broken containers have been left alive for inspection."
    echo "Check the '$LOG_DIR' folder to see the kubelet and systemd logs."
    echo "Run './teardown.sh' when you are ready to clean up."
    exit 1
fi
