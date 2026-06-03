#!/bin/bash
set -e

NUM_WORKER_CLUSTERS=$1
if [ -z "$NUM_WORKER_CLUSTERS" ]; then
  echo "Usage: ./bootstrap-phones.sh <NUM_WORKER_CLUSTERS>"
  exit 1
fi

PHONE_IPS=(10.0.0.17 10.0.0.18 10.0.0.19 10.0.0.20 10.0.0.21 10.0.0.22 10.0.0.23 10.0.0.24 10.0.0.26 10.0.0.27 10.0.0.29 10.0.0.31 10.0.0.34 10.0.0.41 10.0.0.42 10.0.0.43 10.0.0.45 10.0.0.46)
PHONE_NAMES=(pf-007 pf-008 pf-009 pf-010 pf-011 pf-012 pf-013 pf-014 pf-016 pf-017 pf-019 pf-021 pf-024 pf-031 pf-032 pf-033 pf-035 pf-036)

mkdir -p /home/luffy/clusters

if [ "$NUM_WORKER_CLUSTERS" -eq 1 ]; then
    echo "Topology: Baseline (1x18). Creating single cluster..."
    SERVER_IP=${PHONE_IPS[0]}
    SERVER_NAME=${PHONE_NAMES[0]}

    sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$SERVER_IP 'echo 0000 | sudo -S cp /userdata/cluster-d-assets/k3s-arm64 /usr/local/bin/k3s && echo 0000 | sudo -S chmod +x /usr/local/bin/k3s'
    sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$SERVER_IP "echo 0000 | sudo -S sh -c 'IFACE=\$(ls /sys/class/net | grep enx | head -1); env INSTALL_K3S_SKIP_DOWNLOAD=true INSTALL_K3S_EXEC=\"server --flannel-iface=\$IFACE --node-ip=$SERVER_IP --flannel-backend=host-gw --cluster-cidr=10.48.0.0/16 --service-cidr=10.49.0.0/16 --disable=traefik --node-name=$SERVER_NAME --tls-san=$SERVER_IP\" sh /userdata/cluster-d-assets/k3s-install.sh'"
    sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$SERVER_IP 'echo 0000 | sudo -S mkdir -p /etc/rancher/k3s && echo 0000 | sudo -S cp /userdata/cluster-d-assets/registries.yaml /etc/rancher/k3s/registries.yaml && echo 0000 | sudo -S systemctl restart k3s'

    sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$SERVER_IP 'echo 0000 | sudo -S cat /etc/rancher/k3s/k3s.yaml' | sed "s|server: https://127.0.0.1:6443|server: https://$SERVER_IP:6443|" > "/home/luffy/clusters/worker-1.kubeconfig"
    JOIN_TOKEN=$(sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$SERVER_IP 'echo 0000 | sudo -S cat /var/lib/rancher/k3s/server/node-token')

    for i in $(seq 1 17); do
        AGENT_IP=${PHONE_IPS[$i]}
        AGENT_NAME=${PHONE_NAMES[$i]}
        sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$AGENT_IP 'echo 0000 | sudo -S cp /userdata/cluster-d-assets/k3s-arm64 /usr/local/bin/k3s && echo 0000 | sudo -S chmod +x /usr/local/bin/k3s'
        sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$AGENT_IP "echo 0000 | sudo -S sh -c 'IFACE=\$(ls /sys/class/net | grep enx | head -1); env INSTALL_K3S_SKIP_DOWNLOAD=true INSTALL_K3S_EXEC=\"agent --flannel-iface=\$IFACE --node-ip=$AGENT_IP --node-name=$AGENT_NAME\" K3S_TOKEN=$JOIN_TOKEN K3S_URL=https://$SERVER_IP:6443 sh /userdata/cluster-d-assets/k3s-install.sh'"
        sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$AGENT_IP 'echo 0000 | sudo -S mkdir -p /etc/rancher/k3s && echo 0000 | sudo -S cp /userdata/cluster-d-assets/registries.yaml /etc/rancher/k3s/registries.yaml && echo 0000 | sudo -S systemctl restart k3s-agent'
    done
    export HOST_KUBECONFIG="/home/luffy/clusters/worker-1.kubeconfig"
else
    echo "[1/4] Building 3-Node Host Cluster for Control Plane..."
    HOST_SERVER_IP=${PHONE_IPS[0]}
    HOST_SERVER_NAME=${PHONE_NAMES[0]}

    sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$HOST_SERVER_IP 'echo 0000 | sudo -S cp /userdata/cluster-d-assets/k3s-arm64 /usr/local/bin/k3s && echo 0000 | sudo -S chmod +x /usr/local/bin/k3s'
    sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$HOST_SERVER_IP "echo 0000 | sudo -S sh -c 'IFACE=\$(ls /sys/class/net | grep enx | head -1); env INSTALL_K3S_SKIP_DOWNLOAD=true INSTALL_K3S_EXEC=\"server --flannel-iface=\$IFACE --node-ip=$HOST_SERVER_IP --flannel-backend=host-gw --cluster-cidr=10.48.0.0/16 --service-cidr=10.49.0.0/16 --disable=traefik --node-name=$HOST_SERVER_NAME --tls-san=$HOST_SERVER_IP\" sh /userdata/cluster-d-assets/k3s-install.sh'"
    sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$HOST_SERVER_IP 'echo 0000 | sudo -S mkdir -p /etc/rancher/k3s && echo 0000 | sudo -S cp /userdata/cluster-d-assets/registries.yaml /etc/rancher/k3s/registries.yaml && echo 0000 | sudo -S systemctl restart k3s'

    sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$HOST_SERVER_IP 'echo 0000 | sudo -S cat /etc/rancher/k3s/k3s.yaml' | sed "s|server: https://127.0.0.1:6443|server: https://$HOST_SERVER_IP:6443|" > "/home/luffy/clusters/host.kubeconfig"
    export HOST_KUBECONFIG="/home/luffy/clusters/host.kubeconfig"
    JOIN_TOKEN=$(sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$HOST_SERVER_IP 'echo 0000 | sudo -S cat /var/lib/rancher/k3s/server/node-token')

    for i in 1 2; do
        AGENT_IP=${PHONE_IPS[$i]}
        AGENT_NAME=${PHONE_NAMES[$i]}
        sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$AGENT_IP 'echo 0000 | sudo -S cp /userdata/cluster-d-assets/k3s-arm64 /usr/local/bin/k3s && echo 0000 | sudo -S chmod +x /usr/local/bin/k3s'
        sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$AGENT_IP "echo 0000 | sudo -S sh -c 'IFACE=\$(ls /sys/class/net | grep enx | head -1); env INSTALL_K3S_SKIP_DOWNLOAD=true INSTALL_K3S_EXEC=\"agent --flannel-iface=\$IFACE --node-ip=$AGENT_IP --node-name=$AGENT_NAME\" K3S_TOKEN=$JOIN_TOKEN K3S_URL=https://$HOST_SERVER_IP:6443 sh /userdata/cluster-d-assets/k3s-install.sh'"
        sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$AGENT_IP 'echo 0000 | sudo -S mkdir -p /etc/rancher/k3s && echo 0000 | sudo -S cp /userdata/cluster-d-assets/registries.yaml /etc/rancher/k3s/registries.yaml && echo 0000 | sudo -S systemctl restart k3s-agent'
    done

    echo "[2/4] Carving out $NUM_WORKER_CLUSTERS Member Clusters..."
    TOTAL_MEMBER_PHONES=15
    PHONE_INDEX=3
    BASE_NODES_PER_CLUSTER=$(( TOTAL_MEMBER_PHONES / NUM_WORKER_CLUSTERS ))
    REMAINING_NODES=$(( TOTAL_MEMBER_PHONES % NUM_WORKER_CLUSTERS ))

    for i in $(seq 1 $NUM_WORKER_CLUSTERS); do
        POD_CIDR="10.$((48 + i * 2)).0.0/16"
        SVC_CIDR="10.$((49 + i * 2)).0.0/16"
        CURRENT_CLUSTER_NODES=$BASE_NODES_PER_CLUSTER
        if [ "$REMAINING_NODES" -gt 0 ]; then CURRENT_CLUSTER_NODES=$((CURRENT_CLUSTER_NODES + 1)); REMAINING_NODES=$((REMAINING_NODES - 1)); fi
        SERVER_IP=${PHONE_IPS[$PHONE_INDEX]}
        SERVER_NAME=${PHONE_NAMES[$PHONE_INDEX]}
        sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$SERVER_IP 'echo 0000 | sudo -S cp /userdata/cluster-d-assets/k3s-arm64 /usr/local/bin/k3s && echo 0000 | sudo -S chmod +x /usr/local/bin/k3s'
        sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$SERVER_IP "echo 0000 | sudo -S sh -c 'IFACE=\$(ls /sys/class/net | grep enx | head -1); env INSTALL_K3S_SKIP_DOWNLOAD=true INSTALL_K3S_EXEC=\"server --flannel-iface=\$IFACE --node-ip=$SERVER_IP --flannel-backend=host-gw --cluster-cidr=$POD_CIDR --service-cidr=$SVC_CIDR --disable=traefik --node-name=$SERVER_NAME --tls-san=$SERVER_IP\" sh /userdata/cluster-d-assets/k3s-install.sh'"
        sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$SERVER_IP 'echo 0000 | sudo -S mkdir -p /etc/rancher/k3s && echo 0000 | sudo -S cp /userdata/cluster-d-assets/registries.yaml /etc/rancher/k3s/registries.yaml && echo 0000 | sudo -S systemctl restart k3s'
        sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$SERVER_IP 'echo 0000 | sudo -S cat /etc/rancher/k3s/k3s.yaml' | sed "s|server: https://127.0.0.1:6443|server: https://$SERVER_IP:6443|" > "/home/luffy/clusters/worker-${i}.kubeconfig"
        MEMBER_JOIN_TOKEN=$(sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$SERVER_IP 'echo 0000 | sudo -S cat /var/lib/rancher/k3s/server/node-token')
        PHONE_INDEX=$((PHONE_INDEX + 1))
        for w in $(seq 2 $CURRENT_CLUSTER_NODES); do
            AGENT_IP=${PHONE_IPS[$PHONE_INDEX]}
            AGENT_NAME=${PHONE_NAMES[$PHONE_INDEX]}
            sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$AGENT_IP 'echo 0000 | sudo -S cp /userdata/cluster-d-assets/k3s-arm64 /usr/local/bin/k3s && echo 0000 | sudo -S chmod +x /usr/local/bin/k3s'
            sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$AGENT_IP "echo 0000 | sudo -S sh -c 'IFACE=\$(ls /sys/class/net | grep enx | head -1); env INSTALL_K3S_SKIP_DOWNLOAD=true INSTALL_K3S_EXEC=\"agent --flannel-iface=\$IFACE --node-ip=$AGENT_IP --node-name=$AGENT_NAME\" K3S_TOKEN=$MEMBER_JOIN_TOKEN K3S_URL=https://$SERVER_IP:6443 sh /userdata/cluster-d-assets/k3s-install.sh'"
            sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$AGENT_IP 'echo 0000 | sudo -S mkdir -p /etc/rancher/k3s && echo 0000 | sudo -S cp /userdata/cluster-d-assets/registries.yaml /etc/rancher/k3s/registries.yaml && echo 0000 | sudo -S systemctl restart k3s-agent'
            PHONE_INDEX=$((PHONE_INDEX + 1))
        done
    done

    echo "  -> Patching CoreDNS to bypass jump host blackhole..."
    while ! kubectl --kubeconfig=$HOST_KUBECONFIG get configmap coredns -n kube-system; do sleep 2; done

    kubectl --kubeconfig=$HOST_KUBECONFIG patch configmap coredns -n kube-system --type merge -p '{"data":{"Corefile":".:53 {\n    errors\n    health\n    ready\n    kubernetes cluster.local in-addr.arpa ip6.arpa {\n       pods insecure\n       fallthrough in-addr.arpa ip6.arpa\n       ttl 30\n    }\n    prometheus :9153\n    forward . 8.8.8.8 8.8.4.4\n    cache 30\n    loop\n    reload\n    loadbalance\n}\n"}}'

    kubectl --kubeconfig=$HOST_KUBECONFIG rollout restart deployment coredns -n kube-system
    sleep 5 

    echo "[3/4] Initializing Karmada Control Plane (Pre-Flight Mode)..."

    echo "  -> Downloading and applying Karmada CRDs..."
    wget -q https://github.com/karmada-io/karmada/releases/download/v1.17.2/crds.tar.gz -O /tmp/crds.tar.gz
    mkdir -p /tmp/karmada-crds
    tar -xzf /tmp/crds.tar.gz -C /tmp/karmada-crds
    kubectl --kubeconfig=$HOST_KUBECONFIG apply -R -f /tmp/karmada-crds/ || true

    (
        while ! kubectl --kubeconfig=$HOST_KUBECONFIG get deployment karmada-apiserver -n karmada-system 2>/dev/null; do sleep 2; done
        while [ -z "$(kubectl --kubeconfig=$HOST_KUBECONFIG get pod etcd-0 -n karmada-system -o jsonpath='{.status.podIP}' 2>/dev/null)" ]; do sleep 2; done
        ETCD_IP=$(kubectl --kubeconfig=$HOST_KUBECONFIG get pod etcd-0 -n karmada-system -o jsonpath='{.status.podIP}' 2>/dev/null)

        # UPDATED: Removed podAffinity to stop the CPU trap, bumped probes to 300s/60s
        kubectl --kubeconfig=$HOST_KUBECONFIG patch deployment karmada-apiserver -n karmada-system -p \
        '{"spec":{"strategy":{"$patch":"replace","type":"Recreate"},"template":{"spec":{"hostAliases":[{"ip":"'"$ETCD_IP"'","hostnames":["etcd-0.etcd.karmada-system.svc.cluster.local"]}],"containers":[{"name":"karmada-apiserver","livenessProbe":{"initialDelaySeconds":300,"timeoutSeconds":60,"periodSeconds":30,"failureThreshold":20},"readinessProbe":{"initialDelaySeconds":300,"timeoutSeconds":60,"periodSeconds":30,"failureThreshold":20}}]}}}}' || true
    ) &

    (
        while ! kubectl --kubeconfig=$HOST_KUBECONFIG get deployment karmada-aggregated-apiserver -n karmada-system 2>/dev/null; do sleep 2; done
        ETCD_IP=$(kubectl --kubeconfig=$HOST_KUBECONFIG get pod etcd-0 -n karmada-system -o jsonpath='{.status.podIP}' 2>/dev/null)

        # UPDATED: Removed podAffinity to stop the CPU trap, bumped probes to 300s/60s
        kubectl --kubeconfig=$HOST_KUBECONFIG patch deployment karmada-aggregated-apiserver -n karmada-system -p \
        '{"spec":{"strategy":{"$patch":"replace","type":"Recreate"},"template":{"spec":{"hostAliases":[{"ip":"'"$ETCD_IP"'","hostnames":["etcd-0.etcd.karmada-system.svc.cluster.local"]}],"containers":[{"name":"karmada-aggregated-apiserver","livenessProbe":{"initialDelaySeconds":300,"timeoutSeconds":60,"periodSeconds":30,"failureThreshold":20},"readinessProbe":{"initialDelaySeconds":300,"timeoutSeconds":60,"periodSeconds":30,"failureThreshold":20}}]}}}}' || true
    ) &

    for DEP in karmada-controller-manager karmada-scheduler; do
        kubectl --kubeconfig=$HOST_KUBECONFIG patch deployment $DEP -n karmada-system -p \
        '{"spec":{"template":{"spec":{"affinity":{"podAntiAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":[{"labelSelector":{"matchLabels":{"app":"etcd"}},"topologyKey":"kubernetes.io/hostname"}]}}}}}}' || true
    done

    echo "  -> Cleaning up any lingering services from previous runs..."
    kubectl --kubeconfig=$HOST_KUBECONFIG delete svc karmada-apiserver karmada-aggregated-apiserver -n karmada-system --ignore-not-found=true

    echo "  -> Running Karmada Init (Stage 1: API Server)..."
    sudo kubectl karmada init --kubeconfig=$HOST_KUBECONFIG || true

    echo "  -> Waiting for API Server to pass hardware health checks (approx 3-4 mins)..."
    sleep 10
    kubectl --kubeconfig=$HOST_KUBECONFIG wait --for=condition=Ready pod -l app=karmada-apiserver -n karmada-system --timeout=15m

    echo "  -> Running Karmada Init (Stage 2: Controllers)..."
    sudo kubectl karmada init --kubeconfig=$HOST_KUBECONFIG || true

    echo "  -> Waiting for Karmada Controller Manager to boot..."
    kubectl --kubeconfig=$HOST_KUBECONFIG wait --for=condition=Available deployment/karmada-controller-manager -n karmada-system --timeout=5m

    sudo cp /etc/karmada/karmada-apiserver.config /home/luffy/clusters/karmada-apiserver.config
    sudo chown $(whoami):$(whoami) /home/luffy/clusters/karmada-apiserver.config
    for i in $(seq 1 $NUM_WORKER_CLUSTERS); do
        echo "  -> Joining worker-$i..."
        kubectl karmada join worker-$i --kubeconfig="/home/luffy/clusters/karmada-apiserver.config" --cluster-kubeconfig="/home/luffy/clusters/worker-${i}.kubeconfig"
    done
fi

echo "[4/4] Deploying Observability Stack..."
OBSERVABILITY_HOST=$HOST_KUBECONFIG
if [ "$NUM_WORKER_CLUSTERS" -eq 1 ]; then OBSERVABILITY_HOST="/home/luffy/clusters/worker-1.kubeconfig"; fi
kubectl --kubeconfig=$OBSERVABILITY_HOST create namespace monitoring || true
helm upgrade --install kube-prometheus-stack ./kube-prometheus-stack-*.tgz --kubeconfig=$OBSERVABILITY_HOST --namespace monitoring --set grafana.adminPassword=admin --set grafana.service.type=NodePort --set grafana.service.nodePort=32000 --set prometheusOperator.admissionWebhooks.enabled=false --set prometheusOperator.admissionWebhooks.patch.enabled=false

for i in $(seq 1 ${NUM_WORKER_CLUSTERS:-1}); do
    WORKER_CONF="/home/luffy/clusters/worker-${i}.kubeconfig"
    kubectl --kubeconfig=$WORKER_CONF create namespace monitoring || true
    helm upgrade --install kube-prometheus-stack ./kube-prometheus-stack-*.tgz --kubeconfig=$WORKER_CONF --namespace monitoring --set grafana.enabled=false --set prometheus.service.type=NodePort --set prometheusOperator.admissionWebhooks.enabled=false --set prometheusOperator.admissionWebhooks.patch.enabled=false
done

echo "Topology Complete! Run: ./run-experiments.sh $NUM_WORKER_CLUSTERS"
