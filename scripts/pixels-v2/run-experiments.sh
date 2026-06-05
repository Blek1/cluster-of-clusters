#!/usr/bin/env bash
#
# run-experiments.sh <N> [REPLICAS]   (run on your LAPTOP)
#
# Inject the workload and time how long it takes to fully roll out — the latency
# number that tests the published "3-cluster threshold" rule (1xN vs Nx(.../N)).
#
#   N=1  : apply the deployment straight to Cluster D.
#   N>=2 : apply deployment + PropagationPolicy to the Karmada apiserver, which
#          spreads replicas across the N member clusters.
#
# Prerequisite — keep an SSH tunnel open in another terminal so the laptop can
# reach the phone subnet (the kubeconfigs below point at 127.0.0.1):
#
#     ssh -L 6443:10.0.0.16:6443 -L 32443:10.0.0.16:32443 straw-hat
#
set -euo pipefail
_DIR="$(cd "$(dirname "$0")" && pwd)"
# Reuse shared constants only (image / reservation). Remote paths are spelled
# out explicitly below because $HOME differs between laptop and jump host.
# shellcheck source=./config.sh
source "${_DIR}/config.sh"

N=${1:-}; REPLICAS=${2:-500}
[[ "$N" =~ ^[0-9]+$ ]] || { echo "usage: ./run-experiments.sh <N> [REPLICAS]"; exit 1; }

JUMP="straw-hat"
# Remote (jump-host) sources come straight from config.sh — both are absolute
# /home/luffy paths there, so there is a single source of truth for them.
REMOTE_CLUSTERD="$HOST_KUBECONFIG"
REMOTE_KARMADA="$KARMADA_KUBECONFIG"
LOCAL_KUBECONFIG="${HOME}/.kube/clusters-v2-run.kubeconfig"
MANIFEST="$(mktemp -t cofc-workload.XXXX.yaml)"
mkdir -p "${HOME}/.kube"

# --- pull the right kubeconfig and point it at the local tunnel -------------
if [ "$N" -eq 1 ]; then
  echo "[1/3] Fetching Cluster D kubeconfig via $JUMP..."
  scp "$JUMP:$REMOTE_CLUSTERD" "$LOCAL_KUBECONFIG" >/dev/null
  sed -i.bak 's|server: https://[0-9.]*:6443|server: https://127.0.0.1:6443|' "$LOCAL_KUBECONFIG"
else
  echo "[1/3] Fetching Karmada kubeconfig via $JUMP..."
  scp "$JUMP:$REMOTE_KARMADA" "$LOCAL_KUBECONFIG" >/dev/null
  sed -i.bak 's|server: https://[0-9.]*:32443|server: https://127.0.0.1:32443|' "$LOCAL_KUBECONFIG"
fi
rm -f "${LOCAL_KUBECONFIG}.bak"
export KUBECONFIG="$LOCAL_KUBECONFIG"

# --- generate the workload --------------------------------------------------
echo "[2/3] Generating ${REPLICAS}-pod workload (N=$N)..."
cat >"$MANIFEST" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: workload-nginx
spec:
  replicas: ${REPLICAS}
  selector:
    matchLabels: { app: nginx }
  template:
    metadata:
      labels: { app: nginx }
    spec:
      tolerations:
        - key: "reservation"
          operator: "Equal"
          value: "${RESERVATION}"
          effect: "NoSchedule"
      containers:
        - name: nginx
          image: ${WORKLOAD_IMAGE}
          resources:
            requests: { cpu: "5m", memory: "10Mi" }
EOF

if [ "$N" -ge 2 ]; then
  cat >>"$MANIFEST" <<EOF
---
apiVersion: policy.karmada.io/v1alpha1
kind: PropagationPolicy
metadata:
  name: workload-propagation
spec:
  resourceSelectors:
    - apiVersion: apps/v1
      kind: Deployment
      name: workload-nginx
  placement:
    clusterAffinity:
      clusterNames:
EOF
  for i in $(seq 1 "$N"); do echo "        - member-$i" >>"$MANIFEST"; done
  cat >>"$MANIFEST" <<EOF
    replicaScheduling:
      replicaDivisionPreference: Weighted
      replicaSchedulingType: Divided
EOF
fi

# --- inject and time --------------------------------------------------------
echo
read -r -p "Press [Enter] to inject the workload and start the timer..."
echo "[3/3] Applying and timing rollout..."
start=$(date +%s)
kubectl apply -f "$MANIFEST"
kubectl rollout status deployment/workload-nginx --timeout=15m
latency=$(( $(date +%s) - start ))

echo "Cleaning up..."
kubectl delete -f "$MANIFEST" >/dev/null 2>&1 || true
rm -f "$MANIFEST"

echo
echo "================================================================"
if [ "$N" -eq 1 ]; then
  echo " RESULT  baseline 1x19  |  ${REPLICAS} pods  |  rollout = ${latency}s"
else
  echo " RESULT  ${N} member clusters  |  ${REPLICAS} pods  |  rollout = ${latency}s"
fi
echo "================================================================"
