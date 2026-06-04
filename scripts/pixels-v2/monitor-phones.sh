#!/usr/bin/env bash
#
# monitor-phones.sh <N>   (run on the jump host)
#
# Live dashboard, refreshing every few seconds, for watching a workload roll out
# across the topology. Ctrl-C to stop.

source "$(dirname "$0")/lib.sh"

N=${1:-}
[[ "$N" =~ ^[0-9]+$ ]] || die "usage: ./monitor-phones.sh <N>"
INTERVAL=${2:-3}

pods_per_node() {
  # KUBECONFIG arg=$1 — count nginx pods grouped by node.
  kubectl --kubeconfig="$1" get pods -l app=nginx -o wide --no-headers 2>/dev/null \
    | awk '{print $7}' | sort | uniq -c || echo "  (no pods yet)"
}

render() {
  clear
  echo "================================================================"
  echo " v2 TOPOLOGY MONITOR  |  $(date '+%H:%M:%S')  |  N=$N"
  echo "================================================================"

  if [ "$N" -eq 1 ]; then
    echo; echo "[ Cluster D nodes ]"
    kd get nodes --no-headers 2>/dev/null
    echo; echo "[ workload-nginx ]"
    kd get deployment workload-nginx 2>/dev/null || echo "  (not deployed)"
    echo; echo "[ pods per phone ]"
    pods_per_node "$HOST_KUBECONFIG"
    return
  fi

  echo; echo "[ Karmada clusters ]"
  kubectl --kubeconfig="$KARMADA_KUBECONFIG" get clusters 2>/dev/null || echo "  (control plane down)"
  echo; echo "[ federated workload ]"
  kubectl --kubeconfig="$KARMADA_KUBECONFIG" get deployment workload-nginx 2>/dev/null || echo "  (not deployed)"

  for i in $(seq 1 "$N"); do
    kubeconfig=$(member_kubeconfig_path "$i")
    echo; echo "---- $(member_cluster_name "$i") ----"
    [ -f "$kubeconfig" ] || { echo "  [missing kubeconfig]"; continue; }
    kubectl --kubeconfig="$kubeconfig" get nodes --no-headers 2>/dev/null | awk '{print "  node",$1,$2}'
    echo "  pods per phone:"; pods_per_node "$kubeconfig"
  done
}

while true; do render || true; sleep "$INTERVAL"; done
