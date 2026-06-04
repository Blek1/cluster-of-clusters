#!/usr/bin/env bash
#
# bootstrap-phones.sh <N>   (run on the jump host)
#
# Thin orchestrator — the familiar v1 entrypoint name, but it only sequences the
# three single-purpose stages so each stays independently runnable/debuggable:
#
#     subdivide.sh <N>  ->  install-karmada.sh  ->  join-members.sh <N>
#
#   N=1  : baseline (Cluster D as-is, 19 nodes, no Karmada). Nothing to build —
#          use ./reset-phones.sh to guarantee the board is in baseline shape.
#   N>=2 : 1 host (pf-006, control plane only) + N member clusters.

source "$(dirname "$0")/lib.sh"

N=${1:-}
[[ "$N" =~ ^[0-9]+$ ]] || die "usage: ./bootstrap-phones.sh <N>   (1=baseline, 2..${MAX_MEMBER_CLUSTERS}=federated)"

if [ "$N" -eq 1 ]; then
  step 0 "N=1 baseline: no federation to build."
  log "Cluster D (19 nodes) is the baseline. Run ./reset-phones.sh to restore it,"
  log "then run the workload from your laptop: ./run-experiments.sh 1"
  exit 0
fi

D="$(dirname "$0")"
"$D/subdivide.sh" "$N"
"$D/install-karmada.sh"
"$D/join-members.sh" "$N"

step DONE "Bootstrapped 1 host + $N member clusters."
log "Verify:  ./verify-topology.sh $N"
log "Run it:  (on your laptop)  ./run-experiments.sh $N"
