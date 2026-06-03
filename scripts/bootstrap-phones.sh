#!/bin/bash
set -e

NUM_WORKER_CLUSTERS=$1
TOTAL_WORKER_NODES=17

if [ -z "$NUM_WORKER_CLUSTERS" ]; then
  echo "Usage: ./bootstrap-phones.sh <NUM_WORKER_CLUSTERS>"
  exit 1
fi

export HOST_KUBECONFIG="/home/luffy/cluster-d-new.kubeconfig"

if [ "$NUM_WORKER_CLUSTERS" -eq 1 ]; then
  echo "Topology: Baseline (1x18)"
  echo "Deploying Central Observability Stack (pf-008)..."

  kubectl --kubeconfig=$HOST_KUBECONFIG create namespace monitoring || true

  helm upgrade --install kube-prometheus-stack ./kube-prometheus-stack-*.tgz \
    --kubeconfig=$HOST_KUBECONFIG \
    --namespace monitoring \
    --set grafana.adminPassword=admin \
    --set grafana.service.type=NodePort \
    --set grafana.service.nodePort=32000 \
    --set prometheusOperator.admissionWebhooks.enabled=false \
    --set prometheusOperator.admissionWebhooks.patch.enabled=false

  echo "  -> Loading Dashboards..."
  sleep 10

  kubectl --kubeconfig=$HOST_KUBECONFIG create configmap custom-dashboards \
    --namespace monitoring \
    --from-file=/home/luffy/clusters/dashboards/ \
    --dry-run=client -o yaml | \
    kubectl --kubeconfig=$HOST_KUBECONFIG label --local -f - grafana_dashboard=1 -o yaml | \
    kubectl --kubeconfig=$HOST_KUBECONFIG apply -f - > /dev/null 2>&1 || true

  kubectl --kubeconfig=$HOST_KUBECONFIG rollout restart deployment kube-prometheus-stack-grafana -n monitoring > /dev/null 2>&1 || true

  echo "Observability provisioning complete. Proceed directly to local laptop: ./run-experiments.sh 1"
  exit 0
fi

# The 17 surviving worker phones
PHONE_IPS=(10.0.0.17 10.0.0.19 10.0.0.20 10.0.0.21 10.0.0.22 10.0.0.23 10.0.0.24 10.0.0.26 10.0.0.27 10.0.0.29 10.0.0.31 10.0.0.34 10.0.0.41 10.0.0.42 10.0.0.43 10.0.0.45 10.0.0.46)
PHONE_NAMES=(pf-007 pf-009 pf-010 pf-011 pf-012 pf-013 pf-014 pf-016 pf-017 pf-019 pf-021 pf-024 pf-031 pf-032 pf-033 pf-035 pf-036)

echo "[1/5] Carving out $NUM_WORKER_CLUSTERS Member Clusters from Cluster D..."

# Reserve 2 phones to stay in the Host Cluster to run the Karmada Control Plane
HOST_WORKER_NODES=2
AVAILABLE_MEMBER_NODES=$(( TOTAL_WORKER_NODES - HOST_WORKER_NODES ))

PHONE_INDEX=$HOST_WORKER_NODES
BASE_NODES_PER_CLUSTER=$(( AVAILABLE_MEMBER_NODES / NUM_WORKER_CLUSTERS ))
REMAINING_NODES=$(( AVAILABLE_MEMBER_NODES % NUM_WORKER_CLUSTERS ))

for i in $(seq 1 $NUM_WORKER_CLUSTERS); do
    POD_CIDR="10.$((48 + i * 2)).0.0/16"
    SVC_CIDR="10.$((49 + i * 2)).0.0/16"

    CURRENT_CLUSTER_NODES=$BASE_NODES_PER_CLUSTER
    if [ "$REMAINING_NODES" -gt 0 ]; then
        CURRENT_CLUSTER_NODES=$((CURRENT_CLUSTER_NODES + 1))
        REMAINING_NODES=$((REMAINING_NODES - 1))
    fi

    SERVER_IP=${PHONE_IPS[$PHONE_INDEX]}
    SERVER_NAME=${PHONE_NAMES[$PHONE_INDEX]}
    echo "  -> Configuring Sub-Cluster $i Server ($SERVER_NAME at $SERVER_IP)..."

    kubectl --kubeconfig=$HOST_KUBECONFIG drain $SERVER_NAME --ignore-daemonsets --delete-emptydir-data --force --grace-period=0 > /dev/null 2>&1 || true
    kubectl --kubeconfig=$HOST_KUBECONFIG delete node $SERVER_NAME > /dev/null 2>&1 || true

    sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$SERVER_IP 'echo 0000 | sudo -S /usr/local/bin/k3s-agent-uninstall.sh' > /dev/null 2>&1 || true
    sshpass -p 0000 ssh kalm@$SERVER_IP 'echo 0000 | sudo -S cp /userdata/cluster-d-assets/k3s-arm64 /usr/local/bin/k3s && echo 0000 | sudo -S chmod +x /usr/local/bin/k3s'
    sshpass -p 0000 ssh kalm@$SERVER_IP "echo 0000 | sudo -S sh -c 'IFACE=\$(ls /sys/class/net | grep enx | head -1); env INSTALL_K3S_SKIP_DOWNLOAD=true INSTALL_K3S_EXEC=\"server --flannel-iface=\$IFACE --node-ip=$SERVER_IP --flannel-backend=host-gw --cluster-cidr=$POD_CIDR --service-cidr=$SVC_CIDR --disable=traefik --node-name=$SERVER_NAME --tls-san=$SERVER_IP\" sh /userdata/cluster-d-assets/k3s-install.sh'" > /dev/null 2>&1
    sshpass -p 0000 ssh kalm@$SERVER_IP 'echo 0000 | sudo -S mkdir -p /etc/rancher/k3s && echo 0000 | sudo -S cp /userdata/cluster-d-assets/registries.yaml /etc/rancher/k3s/registries.yaml && echo 0000 | sudo -S systemctl restart k3s'

    sshpass -p 0000 ssh kalm@$SERVER_IP 'echo 0000 | sudo -S cat /etc/rancher/k3s/k3s.yaml' | sed "s|server: https://127.0.0.1:6443|server: https://$SERVER_IP:6443|" > "/home/luffy/clusters/worker-${i}.kubeconfig"
    JOIN_TOKEN=$(sshpass -p 0000 ssh kalm@$SERVER_IP 'echo 0000 | sudo -S cat /var/lib/rancher/k3s/server/node-token')
    PHONE_INDEX=$((PHONE_INDEX + 1))

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

echo "[2/5] Installing Karmada CLI and Control Plane..."
if ! command -v kubectl-karmada &> /dev/null; then
    echo "  -> Downloading and installing Karmada CLI..."
    curl -s https://raw.githubusercontent.com/karmada-io/karmada/master/hack/install-cli.sh | sudo bash -s kubectl-karmada
else
    echo "  -> Karmada CLI already detected. Skipping download!"
fi

echo "  -> Unlocking Host Worker nodes for Karmada scheduling..."
for i in $(seq 0 $((HOST_WORKER_NODES - 1))); do
    NODE_NAME=${PHONE_NAMES[$i]}
    kubectl --kubeconfig=$HOST_KUBECONFIG taint nodes $NODE_NAME reservation=cluster-of-clusters-until-2026-06-12:NoSchedule- > /dev/null 2>&1 || true
done

echo "  -> Initializing Karmada (with sudo for /etc/karmada directory)..."

# ACTIVE GARBAGE COLLECTION: Aggressively rip off finalizers if a ghost namespace is stuck!
while kubectl --kubeconfig=$HOST_KUBECONFIG get ns karmada-system > /dev/null 2>&1; do
    echo "  -> Actively purging ghost finalizers to force namespace deletion..."

    for crd in $(kubectl --kubeconfig=$HOST_KUBECONFIG get crd -o name 2>/dev/null | grep karmada || true); do
        kubectl --kubeconfig=$HOST_KUBECONFIG patch $crd -p '{"metadata":{"finalizers":[]}}' --type=merge > /dev/null 2>&1 || true
    done

    kubectl --kubeconfig=$HOST_KUBECONFIG get ns karmada-system -o json 2>/dev/null | sed 's/"kubernetes"//' | kubectl --kubeconfig=$HOST_KUBECONFIG replace --raw /api/v1/namespaces/karmada-system/finalize -f - > /dev/null 2>&1 || true

    sleep 3
done

# Safety wipe of old config files so the CLI doesn't get confused
sudo rm -rf /etc/karmada > /dev/null 2>&1 || true

echo "  -> Forcing Control Plane onto pf-007 to bypass network latency..."
# Cordon all other host nodes so the scheduler is physically trapped!
kubectl --kubeconfig=$HOST_KUBECONFIG cordon pf-008 > /dev/null 2>&1 || true
kubectl --kubeconfig=$HOST_KUBECONFIG cordon pf-009 > /dev/null 2>&1 || true

# Watchdog-1: Patch karmada-apiserver with DNS bypass and relaxed probes the
# moment it exists, so it becomes Ready before init's timeout expires.
(
    while ! kubectl --kubeconfig=$HOST_KUBECONFIG get deployment karmada-apiserver -n karmada-system > /dev/null 2>&1; do
        sleep 2
    done

    # Wait for ETCD to securely get an IP address
    while [ -z "$(kubectl --kubeconfig=$HOST_KUBECONFIG get pod etcd-0 -n karmada-system -o jsonpath='{.status.podIP}' 2>/dev/null)" ]; do
        sleep 2
    done
    ETCD_IP=$(kubectl --kubeconfig=$HOST_KUBECONFIG get pod etcd-0 -n karmada-system -o jsonpath='{.status.podIP}')

    echo "  -> [Watchdog-1] Applying DNS Bypass ($ETCD_IP) and CPU timeouts..."

    kubectl --kubeconfig=$HOST_KUBECONFIG patch deployment karmada-apiserver -n karmada-system -p '{"spec":{"strategy":{"$patch":"replace","type":"Recreate"},"template":{"spec":{"hostAliases":[{"ip":"'"$ETCD_IP"'","hostnames":["etcd-0.etcd.karmada-system.svc.cluster.local"]}],"nodeSelector":{"kubernetes.io/hostname":"pf-007"},"containers":[{"name":"karmada-apiserver","livenessProbe":{"initialDelaySeconds":120,"timeoutSeconds":30,"periodSeconds":20,"failureThreshold":10},"readinessProbe":{"initialDelaySeconds":120,"timeoutSeconds":30,"periodSeconds":20,"failureThreshold":10}}]}}}}' > /dev/null 2>&1 || true

    # Restart the apiserver pod so the new rules apply cleanly
    kubectl --kubeconfig=$HOST_KUBECONFIG delete pods -l app=karmada-apiserver -n karmada-system > /dev/null 2>&1 || true
) &

# ---> THE ACTUAL INSTALLATION COMMAND <---
sudo kubectl karmada init --kubeconfig=$HOST_KUBECONFIG || true

# Uncordon the cluster so it can breathe and accept other workloads again!
kubectl --kubeconfig=$HOST_KUBECONFIG uncordon pf-008 > /dev/null 2>&1 || true
kubectl --kubeconfig=$HOST_KUBECONFIG uncordon pf-009 > /dev/null 2>&1 || true

echo "  -> CLI finished/timed out. Waiting for Karmada API to fully boot (takes 2-3 minutes on phone hardware)..."

# Ensure the deployment exists before waiting on its condition
while ! kubectl --kubeconfig=$HOST_KUBECONFIG get deployment karmada-apiserver -n karmada-system > /dev/null 2>&1; do
    sleep 2
done

kubectl --kubeconfig=$HOST_KUBECONFIG wait --for=condition=available --timeout=300s deployment/karmada-apiserver -n karmada-system || true

# ---> FIXED DOUBLE-INIT: Clear NodePort conflict before second init <---
echo "  -> Resuming Karmada Installation to deploy CRDs and Controllers..."

# Re-cordon host workers: the second init may update Deployment specs, triggering
# new pods. We want them all on pf-007, not pf-008/009.
kubectl --kubeconfig=$HOST_KUBECONFIG cordon pf-008 > /dev/null 2>&1 || true
kubectl --kubeconfig=$HOST_KUBECONFIG cordon pf-009 > /dev/null 2>&1 || true

# Watchdog-2: Patch aggregated-apiserver immediately when it spawns
(
    while ! kubectl --kubeconfig=$HOST_KUBECONFIG get deployment karmada-aggregated-apiserver -n karmada-system > /dev/null 2>&1; do
        sleep 2
    done
    ETCD_IP=$(kubectl --kubeconfig=$HOST_KUBECONFIG get pod etcd-0 -n karmada-system -o jsonpath='{.status.podIP}' 2>/dev/null)
    echo "  -> [Watchdog-2] Patching aggregated-apiserver with DNS bypass and extended probes..."
    kubectl --kubeconfig=$HOST_KUBECONFIG patch deployment karmada-aggregated-apiserver -n karmada-system -p \
    '{"spec":{"strategy":{"$patch":"replace","type":"Recreate"},"template":{"spec":{"hostAliases":[{"ip":"'"$ETCD_IP"'","hostnames":["etcd-0.etcd.karmada-system.svc.cluster.local"]}],"nodeSelector":{"kubernetes.io/hostname":"pf-007"},"containers":[{"name":"karmada-aggregated-apiserver","livenessProbe":{"initialDelaySeconds":90,"timeoutSeconds":30,"periodSeconds":20,"failureThreshold":10},"readinessProbe":{"initialDelaySeconds":90,"timeoutSeconds":30,"periodSeconds":20,"failureThreshold":10}}]}}}}' \
    > /dev/null 2>&1 || true
    kubectl --kubeconfig=$HOST_KUBECONFIG delete pods -l app=karmada-aggregated-apiserver -n karmada-system > /dev/null 2>&1 || true
) &

# ---> THE IDEMPOTENT INIT LOOP <---
echo "  -> Brute-forcing Karmada Init until Controllers exist..."
while ! kubectl --kubeconfig=$HOST_KUBECONFIG get deployment karmada-controller-manager -n karmada-system > /dev/null 2>&1; do
    echo "  -> Running Karmada Init pass..."
    kubectl --kubeconfig=$HOST_KUBECONFIG delete svc karmada-apiserver -n karmada-system --ignore-not-found=true > /dev/null 2>&1 || true
    sleep 2
    sudo kubectl karmada init --kubeconfig=$HOST_KUBECONFIG || true
    
    # Wait for the slow mobile hardware to catch up before checking again
    sleep 30 
done
echo "  -> Controllers detected! Karmada Control Plane is fully installed."

# Uncordon after init loop completes
kubectl --kubeconfig=$HOST_KUBECONFIG uncordon pf-008 > /dev/null 2>&1 || true
kubectl --kubeconfig=$HOST_KUBECONFIG uncordon pf-009 > /dev/null 2>&1 || true

echo "  -> Re-securing APIServer patches..."
ETCD_IP=$(kubectl --kubeconfig=$HOST_KUBECONFIG get pod etcd-0 -n karmada-system -o jsonpath='{.status.podIP}' 2>/dev/null)

# Re-apply karmada-apiserver patches (second init may have reset the Deployment spec)
kubectl --kubeconfig=$HOST_KUBECONFIG patch deployment karmada-apiserver -n karmada-system -p '{"spec":{"strategy":{"$patch":"replace","type":"Recreate"},"template":{"spec":{"hostAliases":[{"ip":"'"$ETCD_IP"'","hostnames":["etcd-0.etcd.karmada-system.svc.cluster.local"]}],"nodeSelector":{"kubernetes.io/hostname":"pf-007"},"containers":[{"name":"karmada-apiserver","livenessProbe":{"initialDelaySeconds":120,"timeoutSeconds":30,"periodSeconds":20,"failureThreshold":10},"readinessProbe":{"initialDelaySeconds":120,"timeoutSeconds":30,"periodSeconds":20,"failureThreshold":10}}]}}}}' > /dev/null 2>&1 || true

# Lock down karmada-aggregated-apiserver permanently with the same settings.
# Uses 120s (vs the watchdog's 90s) since timing is no longer critical here.
kubectl --kubeconfig=$HOST_KUBECONFIG patch deployment karmada-aggregated-apiserver -n karmada-system -p \
'{"spec":{"strategy":{"$patch":"replace","type":"Recreate"},"template":{"spec":{"hostAliases":[{"ip":"'"$ETCD_IP"'","hostnames":["etcd-0.etcd.karmada-system.svc.cluster.local"]}],"nodeSelector":{"kubernetes.io/hostname":"pf-007"},"containers":[{"name":"karmada-aggregated-apiserver","livenessProbe":{"initialDelaySeconds":120,"timeoutSeconds":30,"periodSeconds":20,"failureThreshold":10},"readinessProbe":{"initialDelaySeconds":120,"timeoutSeconds":30,"periodSeconds":20,"failureThreshold":10}}]}}}}' \
> /dev/null 2>&1 || true

echo "Waiting for Karmada controllers and aggregated-apiserver to be ready..."
kubectl --kubeconfig=$HOST_KUBECONFIG wait --for=condition=available --timeout=300s \
    deployment/karmada-controller-manager \
    deployment/karmada-scheduler \
    deployment/karmada-aggregated-apiserver \
    -n karmada-system 2>/dev/null || true

echo "[3/5] Fetching Karmada Kubeconfig..."
sudo cp /etc/karmada/karmada-apiserver.config /home/luffy/clusters/karmada-apiserver.config
sudo chown $(whoami):$(whoami) /home/luffy/clusters/karmada-apiserver.config

echo "[4/5] Joining Member Clusters to Karmada..."
for i in $(seq 1 $NUM_WORKER_CLUSTERS); do
    echo "  -> Joining worker-$i..."
    kubectl --kubeconfig="/home/luffy/clusters/karmada-apiserver.config" delete cluster worker-$i --ignore-not-found=true > /dev/null 2>&1 || true
    kubectl karmada join worker-$i --kubeconfig="/home/luffy/clusters/karmada-apiserver.config" --cluster-kubeconfig="/home/luffy/clusters/worker-${i}.kubeconfig"
done

echo "[5/5] Deploying Central Observability Stack to Host (pf-008)..."
kubectl --kubeconfig=$HOST_KUBECONFIG create namespace monitoring || true
helm upgrade --install kube-prometheus-stack ./kube-prometheus-stack-*.tgz \
    --kubeconfig=$HOST_KUBECONFIG \
    --namespace monitoring \
    --set grafana.adminPassword=admin \
    --set grafana.service.type=NodePort \
    --set grafana.service.nodePort=32000 \
    --set prometheusOperator.admissionWebhooks.enabled=false \
    --set prometheusOperator.admissionWebhooks.patch.enabled=false

for i in $(seq 1 $NUM_WORKER_CLUSTERS); do
    echo "  -> Deploying Prometheus to worker-$i..."
    kubectl --kubeconfig="/home/luffy/clusters/worker-${i}.kubeconfig" create namespace monitoring || true
    helm upgrade --install kube-prometheus-stack ./kube-prometheus-stack-*.tgz \
      --kubeconfig="/home/luffy/clusters/worker-${i}.kubeconfig" \
      --namespace monitoring \
      --set grafana.enabled=false \
      --set prometheus.service.type=NodePort \
      --set prometheusOperator.admissionWebhooks.enabled=false \
      --set prometheusOperator.admissionWebhooks.patch.enabled=false
done

echo "  -> Wiring Data Sources..."
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

kubectl --kubeconfig=$HOST_KUBECONFIG apply -f "$DS_FILE" > /dev/null 2>&1

echo "  -> Loading Dashboards..."
sleep 10

kubectl --kubeconfig=$HOST_KUBECONFIG create configmap custom-dashboards \
  --namespace monitoring \
  --from-file=/home/luffy/clusters/dashboards/ \
  --dry-run=client -o yaml | \
  kubectl --kubeconfig=$HOST_KUBECONFIG label --local -f - grafana_dashboard=1 -o yaml | \
  kubectl --kubeconfig=$HOST_KUBECONFIG apply -f - > /dev/null 2>&1 || true

kubectl --kubeconfig=$HOST_KUBECONFIG rollout restart deployment kube-prometheus-stack-grafana -n monitoring > /dev/null 2>&1 || true

echo "Physical infrastructure provisioning complete. Switch to your laptop to deploy workloads: ./run-experiments.sh $NUM_WORKER_CLUSTERS."
