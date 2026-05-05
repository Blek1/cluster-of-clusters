#!/bin/bash
set -e

NUM_CLUSTERS=50 # 45 max so far
CONFIG_DIR="../configs/kind"

mkdir -p "$CONFIG_DIR"

echo "Spinning up Karmada Host (Brain)..."
kind create cluster --name karmada-host

for i in $(seq 1 $NUM_CLUSTERS); do
    echo " Spinning up 1-Node Worker Cluster: $i"
    
    cat <<EOF > "$CONFIG_DIR/cluster-${i}-config.yaml"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  podSubnet: 10.$((200 + i)).0.0/16
  serviceSubnet: 10.$((100 + i)).0.0/16
nodes:
  - role: control-plane
EOF

    kind create cluster --name cluster-$i --config "$CONFIG_DIR/cluster-${i}-config.yaml"
done

echo "Testing Complete! Total clusters:"
kubectl config get-contexts
