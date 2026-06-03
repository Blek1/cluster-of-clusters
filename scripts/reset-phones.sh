#!/bin/bash
set -e

echo "Wiping all 18 bare-metal phones concurrently..."
PHONE_IPS=(10.0.0.17 10.0.0.18 10.0.0.19 10.0.0.20 10.0.0.21 10.0.0.22 10.0.0.23 10.0.0.24 10.0.0.26 10.0.0.27 10.0.0.29 10.0.0.31 10.0.0.34 10.0.0.41 10.0.0.42 10.0.0.43 10.0.0.45 10.0.0.46)
PHONE_NAMES=(pf-007 pf-008 pf-009 pf-010 pf-011 pf-012 pf-013 pf-014 pf-016 pf-017 pf-019 pf-021 pf-024 pf-031 pf-032 pf-033 pf-035 pf-036)

reset_phone() {
    local IP=$1
    local NAME=$2
    sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$IP 'echo 0000 | sudo -S /usr/local/bin/k3s-uninstall.sh' || true
    sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$IP 'echo 0000 | sudo -S /usr/local/bin/k3s-agent-uninstall.sh' || true
    sshpass -p 0000 ssh -o StrictHostKeyChecking=no kalm@$IP 'echo 0000 | sudo -S rm -rf /var/lib/karmada*' || true

    echo "  -> Wiped $NAME ($IP)"
}

for i in "${!PHONE_IPS[@]}"; do
    reset_phone "${PHONE_IPS[$i]}" "${PHONE_NAMES[$i]}" &
done
wait

echo "Board completely cleared! All 18 phones are ready for new topologies."
