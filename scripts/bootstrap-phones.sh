#!/bin/bash
set -e

NUM_WORKER_CLUSTERS=$1
TOTAL_WORKER_NODES=18

if [ -z "$NUM_WORKER_CLUSTERS" ]; then
  echo "Usage: ./bootstrap-phones.sh <NUM_WORKER_CLUSTERS>"
  echo "Example for 3 member clusters: ./bootstrap-phones.sh 3"
  exit 1
fi

# Hardcoded arrays of the 18 available worker phones (pf-006 is reserved as Host CP)
PHONE_IPS=(10.0.0.17 10.0.0.18 10.0.0.19 10.0.0.20 10.0.0.21 10.0.0.22 10.0.0.23 10.0.0.24 10.0.0.26 10.0.0.27 10.0.0.29 10.0.0.31 10.0.0.34 10.0.0.41 10.0.0.42 10.0.0.43 10.0.0.45 10.0.0.46)
PHONE_NAMES=(pf-007 pf-008 pf-009 pf-010 pf-011 pf-012 pf-013 pf-014 pf-016 pf-017 pf-019 pf-021 pf-024 pf-031 pf-032 pf-033 pf-035 pf-036)

HOST_KUBECONFIG="/home/luffy/cluster-d.kubeconfig"

echo "[1/5] Carving out $NUM_WORKER_CLUSTERS Member Clusters from Cluster D..."
PHONE_INDEX=0

# Base calculation for uneven splits
BASE_NODES_PER_CLUSTER=$(( TOTAL_WORKER_NODES / NUM_WORKER_CLUSTERS ))
REMAINING_NODES=$(( TOTAL_WORKER_NODES % NUM_WORKER_CLUSTERS ))

for i in $(seq 1 $NUM_WORKER_CLUSTERS); do
    POD_CIDR="10.$((48 + i * 2)).0.0/16"
    SVC_CIDR="10.$((49 + i * 2)).0.0/16"
    
    # Calculate how many nodes this specific cluster gets
    CURRENT_CLUSTER_NODES=$BASE_NODES_PER_CLUSTER
    if [ "$REMAINING_NODES" -gt 0 ]; then
        CURRENT_CLUSTER_NODES=$((CURRENT_CLUSTER_NODES + 1))
        REMAINING_NODES=$((REMAINING_NODES - 1))
    fi

    SERVER_IP=${PHONE_IPS[$PHONE_INDEX]}
    SERVER_NAME=${PHONE_NAMES[$PHONE_INDEX]}
    echo "  -> Configuring Sub-Cluster $i Server ($SERVER_NAME at $SERVER_IP)..."
    echo "     (Cluster $i will have $CURRENT_CLUSTER_NODES total nodes)"

    # Drain and Delete from Host
    kubectl --kubeconfig=$HOST_KUBECONFIG drain $SERVER_NAME --ignore-daemonsets --delete-emptydir-data --force --grace-period=0 > /dev/null 2>&1 || true
    kubectl --kubeconfig=$HOST_KUBECONFIG delete node $SERVER_NAME > /dev/null 2>&1 || true

    # Reinstall as independent server
    sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$SERVER_IP 'echo 0000 | sudo -S /usr/local/bin/k3s-agent-uninstall.sh' > /dev/null 2>&1 || true
    sshpass -p 0000 ssh kalm@$SERVER_IP 'echo 0000 | sudo -S cp /userdata/cluster-d-assets/k3s-arm64 /usr/local/bin/k3s && echo 0000 | sudo -S chmod +x /usr/local/bin/k3s'
    sshpass -p 0000 ssh kalm@$SERVER_IP "echo 0000 | sudo -S sh -c 'IFACE=\$(ls /sys/class/net | grep enx | head -1); env INSTALL_K3S_SKIP_DOWNLOAD=true INSTALL_K3S_EXEC=\"server --flannel-iface=\$IFACE --node-ip=$SERVER_IP --flannel-backend=host-gw --cluster-cidr=$POD_CIDR --service-cidr=$SVC_CIDR --disable=traefik --node-name=$SERVER_NAME --tls-san=$SERVER_IP\" sh /userdata/cluster-d-assets/k3s-install.sh'" > /dev/null 2>&1
    sshpass -p 0000 ssh kalm@$SERVER_IP 'echo 0000 | sudo -S mkdir -p /etc/rancher/k3s && echo 0000 | sudo -S cp /userdata/cluster-d-assets/registries.yaml /etc/rancher/k3s/registries.yaml && echo 0000 | sudo -S systemctl restart k3s'
    
    # Extract Kubeconfig and Join Token
    sshpass -p 0000 ssh kalm@$SERVER_IP 'echo 0000 | sudo -S cat /etc/rancher/k3s/k3s.yaml' | sed "s|server: https://127.0.0.1:6443|server: https://$SERVER_IP:6443|" > "/home/luffy/clusters/worker-${i}.kubeconfig"
    JOIN_TOKEN=$(sshpass -p 0000 ssh kalm@$SERVER_IP 'echo 0000 | sudo -S cat /var/lib/rancher/k3s/server/node-token')
    PHONE_INDEX=$((PHONE_INDEX + 1))

    # Provision Agents (Iterate up to CURRENT_CLUSTER_NODES)
    for w in $(seq 2 $CURRENT_CLUSTER_NODES); do
        AGENT_IP=${PHONE_IPS[$PHONE_INDEX]}
        AGENT_NAME=${PHONE_NAMES[$PHONE_INDEX]}
        echo "    -> Joining Agent $AGENT_NAME to Sub-Cluster $i..."

        kubectl --kubeconfig=$HOST_KUBECONFIG drain $AGENT_NAME --ignore-daemonsets --delete-emptydir-data --force --grace-period=0 > /dev/null 2>&1 || true
        kubectl --kubeconfig=$HOST_KUBECONFIG delete node $AGENT_NAME > /dev/null 2>&1 || true

        sshpass -p 0000 ssh kalm@$AGENT_IP 'echo 0000 | sudo -S /usr/local/bin/k3s-agent-uninstall.sh' > /dev/null 2>&1 || true
        sshpass -p 0000 ssh kalm@$AGENT_IP 'echo 0000 | sudo -S cp /userdata/cluster-d-assets/k3s-arm64 /usr/local/bin/k3s && echo 0000 | sudo -S chmod +x /usr/local/bin/k3s'
        sshpass -p 0000 ssh kalm@$AGENT_IP "echo 0000 | sudo -S sh -c 'IFACE=\$(ls /sys/class/net | grep enx | head -1); env INSTALL_K3S_SKIP_DOWNLOAD=true INSTALL_K3S_EXEC=\"agent --flannel-iface=\$IFACE --node-ip=$AGENT_IP --node-name=$AGENT_NAME\" K3S_TOKEN=$JOIN_TOKEN K3S_URL=https://$SERVER_IP:6443 sh /userdata/cluster-d-assets/k3s-install.sh'" > /dev/null 2>&1
        sshpass -p 0000 ssh kalm@$AGENT_IP 'echo 0000 | sudo -S mkdir -p /etc/rancher/k3s && echo 0000 | sudo -S cp /userdata/cluster-d-assets/registries.yaml /etc/rancher/k3s/registries.yaml && echo 0000 | sudo -S systemctl restart k3s-agent'
        
        PHONE_INDEX=$((PHONE_INDEX + 1))
    done
done

echo "[2/5] Installing Karmada on Host Cluster (pf-006)..."
# Using the v1.9.0 release as a stable pin
kubectl --kubeconfig=$HOST_KUBECONFIG apply -f https://github.com/karmada-io/karmada/releases/download/v1.9.0/karmada.yaml > /dev/null 2>&1
echo "Waiting 60 seconds for Karmada API pods to stand up..."
sleep 60

echo "[3/5] Fetching Karmada Kubeconfig..."
# Karmada generates its own config inside a secret on the host cluster
kubectl --kubeconfig=$HOST_KUBECONFIG get secret karmada-kubeconfig -n karmada-system -o jsonpath={.data.karmada-kubeconfig} | base64 -d > /home/luffy/clusters/karmada-apiserver.config

echo "[4/5] Joining Member Clusters to Karmada..."
for i in $(seq 1 $NUM_WORKER_CLUSTERS); do
    echo "  -> Joining worker-$i..."
    karmadactl join worker-$i --kubeconfig="/home/luffy/clusters/karmada-apiserver.config" --cluster-kubeconfig="/home/luffy/clusters/worker-${i}.kubeconfig"
done

echo "[5/5] Deploying Central Observability Stack to Host (pf-006)..."

# Ensure Helm is installed on the jump host
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts > /dev/null 2>&1 || true
helm repo update > /dev/null 2>&1

kubectl --kubeconfig=$HOST_KUBECONFIG create namespace monitoring || true

# Install the core stack on the Host
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --kubeconfig=$HOST_KUBECONFIG \
  --namespace monitoring \
  --set grafana.adminPassword=admin \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=32000 \
  --wait > /dev/null 2>&1

# Install lightweight Prometheus on the Members (so the Host can scrape them)
for i in $(seq 1 $NUM_WORKER_CLUSTERS); do
    echo "  -> Deploying Prometheus to worker-$i..."
    kubectl --kubeconfig="/home/luffy/clusters/worker-${i}.kubeconfig" create namespace monitoring || true
    helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
      --kubeconfig="/home/luffy/clusters/worker-${i}.kubeconfig" \
      --namespace monitoring \
      --set grafana.enabled=false \
      --set prometheus.service.type=NodePort \
      --wait > /dev/null 2>&1
done

echo "  -> Wiring Data Sources..."
# Dynamically build the Grafana datasources.yaml config map
DS_FILE="/home/luffy/clusters/datasources.yaml"
cat <<EOF > "$DS_FILE"
apiVersion: v1
kind: ConfigMap
metadata:
  name: worker-datasources
  namespace: monitoring
  labels:
    grafana_datasource: "1"
data:
  datasources.yaml: |-
    apiVersion: 1
    datasources:
EOF

# Loop through members to grab their NodePorts and Server IPs
for i in $(seq 1 $NUM_WORKER_CLUSTERS); do
    WORKER_SERVER=$(grep "server:" /home/luffy/clusters/worker-${i}.kubeconfig | awk '{print $2}' | sed 's|https://||; s|:6443||')
    NODE_PORT=$(kubectl --kubeconfig="/home/luffy/clusters/worker-${i}.kubeconfig" get svc kube-prometheus-stack-prometheus -n monitoring -o jsonpath='{.spec.ports[0].nodePort}')
    cat <<EOF >> "$DS_FILE"
      - name: worker-$i
        type: prometheus
        url: http://${WORKER_SERVER}:${NODE_PORT}
        access: proxy
        isDefault: false
EOF
done

# Apply data sources to the Host
kubectl --kubeconfig=$HOST_KUBECONFIG apply -f "$DS_FILE" > /dev/null 2>&1

# Apply Tahseen's custom dashboards (assuming they are stored in a folder on the jump host)
echo "  -> Loading Dashboards..."
kubectl --kubeconfig=$HOST_KUBECONFIG create configmap custom-dashboards \
  --namespace monitoring \
  --from-file=/home/luffy/clusters/dashboards/ \
  --dry-run=client -o yaml | \
  kubectl --kubeconfig=$HOST_KUBECONFIG label --local -f - grafana_dashboard=1 -o yaml | \
  kubectl --kubeconfig=$HOST_KUBECONFIG apply -f - > /dev/null 2>&1

# Force Grafana to reload the configurations
kubectl --kubeconfig=$HOST_KUBECONFIG rollout restart deployment kube-prometheus-stack-grafana -n monitoring > /dev/null 2>&1

echo "Physical infrastructure provisioning complete. Switch to your laptop to deploy workloads."
