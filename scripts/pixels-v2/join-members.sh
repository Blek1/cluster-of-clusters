#!/usr/bin/env bash
#
# join-members.sh <N>   (run on the jump host)
#
# Register the N member clusters built by subdivide.sh with the Karmada control
# plane installed by install-karmada.sh. Karmada reaches each member's apiserver
# over the LAN (10.0.0.x:6443) — plain L3, never the flannel pod network — so
# there is no host-gw dependency in the join path.

source "$(dirname "$0")/lib.sh"

N=${1:-}
[[ "$N" =~ ^[0-9]+$ ]] && [ "$N" -ge 2 ] && [ "$N" -le "$MAX_MEMBER_CLUSTERS" ] \
  || die "usage: ./join-members.sh <N>   (2..${MAX_MEMBER_CLUSTERS})"
[ -f "$KARMADA_KUBECONFIG" ] || die "no Karmada kubeconfig at $KARMADA_KUBECONFIG — run ./install-karmada.sh first"

step 1 "Joining $N member clusters to Karmada..."
for i in $(seq 1 "$N"); do
  cluster=$(member_cluster_name "$i")
  kubeconfig=$(member_kubeconfig_path "$i")
  [ -f "$kubeconfig" ] || die "missing $kubeconfig — did ./subdivide.sh $N complete?"

  log "joining $cluster"
  # Idempotent: drop any stale registration, then join.
  # The Karmada apiserver config is the GLOBAL --kubeconfig flag (there is no
  # --karmada-kubeconfig); --cluster-kubeconfig points at the member's config.
  karmadactl unjoin "$cluster" --kubeconfig "$KARMADA_KUBECONFIG" \
    --cluster-kubeconfig "$kubeconfig" >/dev/null 2>&1 || true
  karmadactl join "$cluster" \
    --kubeconfig "$KARMADA_KUBECONFIG" \
    --cluster-kubeconfig "$kubeconfig"
done

step 2 "Waiting for member clusters to report Ready..."
kubectl --kubeconfig="$KARMADA_KUBECONFIG" wait --for=condition=Ready \
  --timeout=300s clusters --all || true
kubectl --kubeconfig="$KARMADA_KUBECONFIG" get clusters

step 3 "Federation complete. Verify with: ./verify-topology.sh $N"
