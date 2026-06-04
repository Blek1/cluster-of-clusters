#!/usr/bin/env bash
#
# verify-topology.sh <N>   (run on the jump host)
#
# Confirm the live layout matches the expected N-cluster topology before you
# trust any experiment numbers.

source "$(dirname "$0")/lib.sh"

N=${1:-}
[[ "$N" =~ ^[0-9]+$ ]] || die "usage: ./verify-topology.sh <N>"

if [ "$N" -eq 1 ]; then
  step 1 "Baseline (1x19): Cluster D"
  kd get nodes -o wide
  total=$(kd get nodes --no-headers 2>/dev/null | wc -l)
  log "nodes registered: ${total} / ${#PHONE_NAMES[@]}"
  exit 0
fi

step 1 "Karmada control plane ($HOST_NAME)"
[ -f "$KARMADA_KUBECONFIG" ] || die "no Karmada kubeconfig — run ./install-karmada.sh"
kubectl --kubeconfig="$KARMADA_KUBECONFIG" get clusters

step 2 "Host cluster (expect only $HOST_NAME)"
kd get nodes

for i in $(seq 1 "$N"); do
  kubeconfig=$(member_kubeconfig_path "$i")
  step "3.$i" "$(member_cluster_name "$i") nodes"
  if [ -f "$kubeconfig" ]; then
    kubectl --kubeconfig="$kubeconfig" get nodes -o wide
  else
    log "[MISSING] $kubeconfig"
  fi
done
