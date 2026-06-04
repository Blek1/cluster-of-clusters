#!/usr/bin/env bash
#
# reset-phones.sh   (run on the jump host)
#
# Fold every phone back into the 1x19 baseline Cluster D:
#   - karmadactl deinit (clean teardown — no finalizer surgery needed because v2
#     never wedged the control plane in the first place)
#   - unmount the etcd tmpfs and re-taint the host
#   - wipe each member phone and rejoin it to Cluster D as an agent of pf-006
#
# pf-006 was never reinstalled (it has been the Cluster D server throughout), so
# "baseline" just means: pf-006 server + the other 18 back as its agents.

source "$(dirname "$0")/lib.sh"

step 1 "Removing Karmada from host ($HOST_NAME)..."
if [ -f "$KARMADA_KUBECONFIG" ] || command -v karmadactl >/dev/null 2>&1; then
  karmadactl deinit --kubeconfig "$HOST_KUBECONFIG" --force >/dev/null 2>&1 || true
fi
ssh_root "$HOST_IP" 'mountpoint -q '"$ETCD_RAM_DIR"' && umount '"$ETCD_RAM_DIR"' || true'
kd taint nodes "$HOST_NAME" "reservation=${RESERVATION}:NoSchedule" --overwrite >/dev/null 2>&1 || true

step 2 "Fetching Cluster D join token from $HOST_NAME..."
TOKEN=$(get_node_token "$HOST_IP")
[ -n "$TOKEN" ] || die "could not read Cluster D node-token from $HOST_IP"

step 3 "Rejoining the 18 member phones to Cluster D as agents (in parallel)..."
restore_phone() {
  local name=$1 ip=$2 sw=$3
  k3s_install_agent "$name" "$ip" "$HOST_IP" "$TOKEN" >/dev/null 2>&1
  wait_node_ready "$HOST_KUBECONFIG" "$name" 240
  kd label node "$name" "reservation=${RESERVATION}" "switch=${sw}" image=original-debian --overwrite >/dev/null 2>&1 || true
  kd taint nodes "$name" "reservation=${RESERVATION}:NoSchedule" --overwrite >/dev/null 2>&1 || true
  log "[done] $name restored to Cluster D"
}

for i in "${!PHONE_NAMES[@]}"; do
  name=${PHONE_NAMES[$i]}
  [[ "$name" == "$HOST_NAME" ]] && continue
  restore_phone "$name" "${PHONE_IPS[$i]}" "${PHONE_SWITCH[$i]}" &
done
wait

step 4 "Baseline restored."
rm -f "$VAR_DIR"/member-*.kubeconfig
kd get nodes
