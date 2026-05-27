#!/bin/bash
set -e

HOST_KUBECONFIG="/home/luffy/cluster-d.kubeconfig"

# The 18 worker phones
PHONE_IPS=(10.0.0.17 10.0.0.18 10.0.0.19 10.0.0.20 10.0.0.21 10.0.0.22 10.0.0.23 10.0.0.24 10.0.0.26 10.0.0.27 10.0.0.29 10.0.0.31 10.0.0.34 10.0.0.41 10.0.0.42 10.0.0.43 10.0.0.45 10.0.0.46)
PHONE_NAMES=(pf-007 pf-008 pf-009 pf-010 pf-011 pf-012 pf-013 pf-014 pf-016 pf-017 pf-019 pf-021 pf-024 pf-031 pf-032 pf-033 pf-035 pf-036)

echo "[1/3] Removing Karmada Federation from Host (pf-006)..."
# Wipe the Karmada control plane from Cluster D so the next test has a fresh state
kubectl --kubeconfig=$HOST_KUBECONFIG delete -f https://github.com/karmada-io/karmada/releases/download/v1.9.0/karmada.yaml --ignore-not-found=true > /dev/null 2>&1 || true
echo "Cleaning up Host observability stack..."
helm uninstall kube-prometheus-stack -n monitoring --kubeconfig=$HOST_KUBECONFIG > /dev/null 2>&1 || true
kubectl --kubeconfig=$HOST_KUBECONFIG delete namespace monitoring > /dev/null 2>&1 || true

echo "[2/3] Retrieving Cluster D Join Token..."
# Grab the master token from pf-006 so the workers can authenticate
JOIN_TOKEN=$(sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@10.0.0.16 'echo 0000 | sudo -S cat /var/lib/rancher/k3s/server/node-token')

echo "[3/3] Resetting all 18 worker phones back to Cluster D Agents..."
for i in "${!PHONE_IPS[@]}"; do
    IP=${PHONE_IPS[$i]}
    NAME=${PHONE_NAMES[$i]}
    echo "  -> Factory resetting $NAME ($IP) back to baseline..."

    # 1. Blindly execute both uninstalls to catch the phone regardless of if it was a server or an agent
    sshpass -p 0000 ssh kalm@$IP 'echo 0000 | sudo -S /usr/local/bin/k3s-uninstall.sh' > /dev/null 2>&1 || true
    sshpass -p 0000 ssh kalm@$IP 'echo 0000 | sudo -S /usr/local/bin/k3s-agent-uninstall.sh' > /dev/null 2>&1 || true

    # 2. Restore the binary
    sshpass -p 0000 ssh kalm@$IP 'echo 0000 | sudo -S cp /userdata/cluster-d-assets/k3s-arm64 /usr/local/bin/k3s && echo 0000 | sudo -S chmod +x /usr/local/bin/k3s'

    # 3. Reinstall as a standard K3s Agent pointing directly at pf-006 (10.0.0.16)
    sshpass -p 0000 ssh kalm@$IP "echo 0000 | sudo -S sh -c 'IFACE=\$(ls /sys/class/net | grep enx | head -1); env INSTALL_K3S_SKIP_DOWNLOAD=true INSTALL_K3S_EXEC=\"agent --flannel-iface=\$IFACE --node-ip=$IP --node-name=$NAME\" K3S_TOKEN=$JOIN_TOKEN K3S_URL=https://10.0.0.16:6443 sh /userdata/cluster-d-assets/k3s-install.sh'" > /dev/null 2>&1

    # 4. Restore the local registry routing
    sshpass -p 0000 ssh kalm@$IP 'echo 0000 | sudo -S mkdir -p /etc/rancher/k3s && echo 0000 | sudo -S cp /userdata/cluster-d-assets/registries.yaml /etc/rancher/k3s/registries.yaml && echo 0000 | sudo -S systemctl restart k3s-agent'

    # 5. Restore the hardware labels and taints required by the system administrator
    SWITCH_NUM=1
    if [[ "$NAME" > "pf-019" ]]; then SWITCH_NUM=2; fi # Switch 2 starts at pf-021
    
    # Wait for the node to register with the API before labeling
    sleep 15
    kubectl --kubeconfig=$HOST_KUBECONFIG label node $NAME reservation=cluster-of-clusters-until-2026-06-12 switch=$SWITCH_NUM image=original-debian --overwrite > /dev/null 2>&1 || true
    kubectl --kubeconfig=$HOST_KUBECONFIG taint nodes $NAME reservation=cluster-of-clusters-until-2026-06-12:NoSchedule --overwrite > /dev/null 2>&1 || true
done

echo "Reset complete! The 1x19 Monolith Baseline has been restored."
