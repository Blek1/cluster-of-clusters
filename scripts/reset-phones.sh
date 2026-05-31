#!/bin/bash
set -e

export HOST_KUBECONFIG="/home/luffy/cluster-d-new.kubeconfig"

# The 17 surviving worker phones (pf-008 is now the host, pf-006 is dead)
PHONE_IPS=(10.0.0.17 10.0.0.19 10.0.0.20 10.0.0.21 10.0.0.22 10.0.0.23 10.0.0.24 10.0.0.26 10.0.0.27 10.0.0.29 10.0.0.31 10.0.0.34 10.0.0.41 10.0.0.42 10.0.0.43 10.0.0.45 10.0.0.46)
PHONE_NAMES=(pf-007 pf-009 pf-010 pf-011 pf-012 pf-013 pf-014 pf-016 pf-017 pf-019 pf-021 pf-024 pf-031 pf-032 pf-033 pf-035 pf-036)

echo "[1/3] Removing Karmada Federation from Host..."

timeout 15 kubectl karmada deinit --kubeconfig=$HOST_KUBECONFIG --force > /dev/null 2>&1 || true

for crd in $(kubectl --kubeconfig=$HOST_KUBECONFIG get crd -o name 2>/dev/null | grep karmada || true); do
    kubectl --kubeconfig=$HOST_KUBECONFIG patch $crd -p '{"metadata":{"finalizers":[]}}' --type=merge > /dev/null 2>&1 || true
done
kubectl --kubeconfig=$HOST_KUBECONFIG get ns karmada-system -o json 2>/dev/null | sed 's/"kubernetes"//' | kubectl --kubeconfig=$HOST_KUBECONFIG replace --raw /api/v1/namespaces/karmada-system/finalize -f - > /dev/null 2>&1 || true
timeout 10 kubectl --kubeconfig=$HOST_KUBECONFIG delete namespace karmada-system --force --grace-period=0 --ignore-not-found=true --wait=false > /dev/null 2>&1 || true

echo "Cleaning up Host observability stack..."
helm uninstall kube-prometheus-stack -n monitoring --kubeconfig=$HOST_KUBECONFIG > /dev/null 2>&1 || true

for crd in $(kubectl --kubeconfig=$HOST_KUBECONFIG get crd -o name 2>/dev/null | grep -E 'coreos|monitoring' || true); do
    kubectl --kubeconfig=$HOST_KUBECONFIG patch $crd -p '{"metadata":{"finalizers":[]}}' --type=merge > /dev/null 2>&1 || true
done

kubectl --kubeconfig=$HOST_KUBECONFIG get ns monitoring -o json 2>/dev/null | sed 's/"kubernetes"//' | kubectl --kubeconfig=$HOST_KUBECONFIG replace --raw /api/v1/namespaces/monitoring/finalize -f - > /dev/null 2>&1 || true
timeout 10 kubectl --kubeconfig=$HOST_KUBECONFIG delete namespace monitoring --force --grace-period=0 --ignore-not-found=true --wait=false > /dev/null 2>&1 || true

echo "[2/3] Retrieving Cluster D Join Token from new host (pf-008)..."
export JOIN_TOKEN=$(sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@10.0.0.18 'echo 0000 | sudo -S cat /var/lib/rancher/k3s/server/node-token')

echo "[3/3] Resetting all 17 worker phones back to Cluster D Agents concurrently..."

reset_phone() {
    local IP=$1
    local NAME=$2

    sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$IP 'echo 0000 | sudo -S /usr/local/bin/k3s-uninstall.sh' > /dev/null 2>&1 || true
    sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$IP 'echo 0000 | sudo -S /usr/local/bin/k3s-agent-uninstall.sh' > /dev/null 2>&1 || true
    sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$IP 'echo 0000 | sudo -S cp /userdata/cluster-d-assets/k3s-arm64 /usr/local/bin/k3s && echo 0000 | sudo -S chmod +x /usr/local/bin/k3s' > /dev/null 2>&1

    # Point directly at pf-008 (10.0.0.18)
    sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$IP "echo 0000 | sudo -S sh -c 'IFACE=\$(ls /sys/class/net | grep enx | head -1); env INSTALL_K3S_SKIP_DOWNLOAD=true INSTALL_K3S_EXEC=\"agent --flannel-iface=\$IFACE --node-ip=$IP --node-name=$NAME\" K3S_TOKEN=$JOIN_TOKEN K3S_URL=https://10.0.0.18:6443 sh /userdata/cluster-d-assets/k3s-install.sh'" > /dev/null 2>&1

    sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$IP 'echo 0000 | sudo -S mkdir -p /etc/rancher/k3s && echo 0000 | sudo -S cp /userdata/cluster-d-assets/registries.yaml /etc/rancher/k3s/registries.yaml && echo 0000 | sudo -S systemctl restart k3s-agent' > /dev/null 2>&1

    local SWITCH_NUM=1
    if [[ "$NAME" > "pf-019" ]]; then SWITCH_NUM=2; fi

    while ! kubectl --kubeconfig=$HOST_KUBECONFIG get node $NAME > /dev/null 2>&1; do
        sleep 2
    done

    kubectl --kubeconfig=$HOST_KUBECONFIG label node $NAME reservation=cluster-of-clusters-until-2026-06-12 switch=$SWITCH_NUM image=original-debian --overwrite > /dev/null 2>&1 || true
    kubectl --kubeconfig=$HOST_KUBECONFIG taint nodes $NAME reservation=cluster-of-clusters-until-2026-06-12:NoSchedule --overwrite > /dev/null 2>&1 || true

    echo "  -> [DONE] $NAME ($IP) successfully restored to Baseline!"
}

for i in "${!PHONE_IPS[@]}"; do
    IP=${PHONE_IPS[$i]}
    NAME=${PHONE_NAMES[$i]}
    echo "  -> Initiating factory reset protocol for $NAME ($IP)..."
    reset_phone "$IP" "$NAME" &
done

echo ""
echo "All 17 reset commands sent. Waiting for phones to wipe, reboot, and rejoin (this takes a minute or two)..."
wait
echo ""
echo "Reset complete! The 1x18 Baseline has been restored."
