#!/usr/bin/env bash
#
# build-clusterd.sh   (run on the jump host)
#
# Build the 1x19 Cluster D baseline FROM SCRATCH, on /userdata, with zero
# hand-provisioned state. This is the cold-start entrypoint: it wipes all 19
# phones (including the pf-006 server), reinstalls pf-006 as a fresh Cluster D
# K3s server with its store on /userdata (K3S_DATA_DIR), refetches its kubeconfig,
# then rejoins the other 18 as agents. Everything every run depends on is created
# here by script — nothing is a one-time manual step that a later run could miss.
#
# Why rebuild pf-006 (docs.md sanctions this):
#   - Teardown is the documented recipe: "Stop k3s, wipe /var/lib/rancher/k3s/,
#     restart from clean state." A k3s reinstall is INSIDE the subdivide recipe,
#     not a "destructive move outside it" (those are reflash/adapter swaps that
#     need Raymond). So no sign-off is required.
#   - Putting the image store on /userdata is gotcha #6 ("root is only 3.9 GB;
#     image cache belongs on /userdata") and matches Raymond's buildah precedent.
#   - Rebuilding regenerates pf-006's cluster CA, so we refetch HOST_KUBECONFIG
#     here — which also permanently retires the stale-kubeconfig failure mode.
#
# After this: ./run-experiments.sh 1   (baseline)   OR   ./bootstrap-phones.sh N

source "$(dirname "$0")/lib.sh"

# label_and_taint NAME SWITCH — reapply Cluster D's reservation label + taint
# (docs.md: every baseline node carries reservation label + NoSchedule taint).
label_and_taint() {
  local name=$1 sw=$2
  kd label node "$name" "reservation=${RESERVATION}" "switch=${sw}" image=original-debian --overwrite >/dev/null 2>&1 || true
  kd taint nodes "$name" "reservation=${RESERVATION}:NoSchedule" --overwrite >/dev/null 2>&1 || true
}

step 1 "Wiping all ${#PHONE_NAMES[@]} phones (k3s uninstall + binary restore)..."
for i in "${!PHONE_NAMES[@]}"; do
  k3s_wipe "${PHONE_IPS[$i]}" >/dev/null 2>&1 &
done
wait
# Drop any leftover Karmada etcd tmpfs from a prior run so the next
# install-karmada starts etcd on a clean RAM mount (k3s_wipe doesn't touch it).
ssh_root "$HOST_IP" 'mountpoint -q '"$ETCD_RAM_DIR"' && umount '"$ETCD_RAM_DIR"' || true'
log "all phones wiped clean"

step 2 "Installing $HOST_NAME as the Cluster D server on /userdata (${HOST_POD_CIDR} / ${HOST_SVC_CIDR})..."
k3s_install_server "$HOST_NAME" "$HOST_IP" "$HOST_POD_CIDR" "$HOST_SVC_CIDR"

step 3 "Refetching the Cluster D kubeconfig (CA changed with the rebuild)..."
fetch_member_kubeconfig "$HOST_IP" "$HOST_KUBECONFIG"
wait_node_ready "$HOST_KUBECONFIG" "$HOST_NAME"
label_and_taint "$HOST_NAME" "$(switch_of "$HOST_NAME")"
log "Cluster D server up; kubeconfig -> $HOST_KUBECONFIG"

step 4 "Joining the other 18 phones as Cluster D agents (in parallel)..."
TOKEN=$(get_node_token "$HOST_IP")
[ -n "$TOKEN" ] || die "could not read Cluster D node-token from $HOST_IP"

join_agent() {
  local name=$1 ip=$2 sw=$3
  k3s_install_agent "$name" "$ip" "$HOST_IP" "$TOKEN" >/dev/null 2>&1
  wait_node_ready "$HOST_KUBECONFIG" "$name" 240
  label_and_taint "$name" "$sw"
  log "[done] $name joined"
}

for i in "${!PHONE_NAMES[@]}"; do
  name=${PHONE_NAMES[$i]}
  [[ "$name" == "$HOST_NAME" ]] && continue
  join_agent "$name" "${PHONE_IPS[$i]}" "${PHONE_SWITCH[$i]}" &
done
wait

step 5 "Cluster D baseline ready (1x19, images on /userdata)."
rm -f "$VAR_DIR"/member-*.kubeconfig    # stale member configs from any prior run
kd get nodes -L switch,reservation -o wide
log "Next: ./run-experiments.sh 1   (baseline)   or   ./bootstrap-phones.sh <N>"
