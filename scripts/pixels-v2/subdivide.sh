#!/usr/bin/env bash
#
# subdivide.sh <N>   (run on the jump host)
#
# Carve the 18 member-pool phones (everything except the host pf-006) into N
# independent K3s clusters, each with its own reserved CIDR pair. The host phone
# is left untouched — install-karmada.sh turns it into the single-node control
# plane. Member kubeconfigs land in $VAR_DIR/member-<i>.kubeconfig.
#
# This does pure K3s topology work. It installs no Karmada — that is the next
# stage. Keeping the two separable is the whole point of the v2 decomposition:
# if a member server fails to come up you debug it here, in isolation.

source "$(dirname "$0")/lib.sh"

N=${1:-}
[[ "$N" =~ ^[0-9]+$ ]] || die "usage: ./subdivide.sh <N>   (number of member clusters, 2..${MAX_MEMBER_CLUSTERS})"

if [ "$N" -eq 1 ]; then
  die "N=1 is the baseline (Cluster D as-is, no federation). To restore it, run ./reset-phones.sh"
fi
[ "$N" -ge 2 ] && [ "$N" -le "$MAX_MEMBER_CLUSTERS" ] || die "N must be 2..${MAX_MEMBER_CLUSTERS} (only that many CIDR slots are reserved)"

mkdir -p "$VAR_DIR"

# Member pool = every phone except the host, in inventory order.
POOL_NAMES=(); POOL_IPS=()
for i in "${!PHONE_NAMES[@]}"; do
  [[ "${PHONE_NAMES[$i]}" == "$HOST_NAME" ]] && continue
  POOL_NAMES+=("${PHONE_NAMES[$i]}"); POOL_IPS+=("${PHONE_IPS[$i]}")
done
POOL_SIZE=${#POOL_NAMES[@]}

# Even split: the first (POOL_SIZE % N) clusters get one extra phone.
BASE=$((POOL_SIZE / N))
EXTRA=$((POOL_SIZE % N))
[ "$BASE" -ge 1 ] || die "N=$N too large for $POOL_SIZE pool phones"

step 1 "Carving $POOL_SIZE phones into $N member clusters (host $HOST_NAME excluded)..."

idx=0
for i in $(seq 1 "$N"); do
  size=$BASE; [ "$i" -le "$EXTRA" ] && size=$((BASE + 1))
  pod=$(member_pod_cidr "$i"); svc=$(member_svc_cidr "$i")
  cluster=$(member_cluster_name "$i")

  server_name=${POOL_NAMES[$idx]}; server_ip=${POOL_IPS[$idx]}
  step "2.$i" "$cluster: $size phones, server $server_name ($server_ip), CIDRs $pod / $svc"

  drain_off_host "$server_name"
  k3s_install_server "$server_name" "$server_ip" "$pod" "$svc"

  kubeconfig=$(member_kubeconfig_path "$i")
  fetch_member_kubeconfig "$server_ip" "$kubeconfig"
  wait_node_ready "$kubeconfig" "$server_name"
  token=$(get_node_token "$server_ip")
  log "$cluster server up; kubeconfig -> $kubeconfig"
  idx=$((idx + 1))

  for _ in $(seq 2 "$size"); do
    agent_name=${POOL_NAMES[$idx]}; agent_ip=${POOL_IPS[$idx]}
    log "joining agent $agent_name ($agent_ip) to $cluster"
    drain_off_host "$agent_name"
    k3s_install_agent "$agent_name" "$agent_ip" "$server_ip" "$token"
    wait_node_ready "$kubeconfig" "$agent_name"
    idx=$((idx + 1))
  done
done

step 3 "Subdivision complete: $N member clusters built."
log "Member kubeconfigs: ${VAR_DIR}/member-*.kubeconfig"
log "Next: ./install-karmada.sh   then   ./join-members.sh $N"
