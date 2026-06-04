#!/usr/bin/env bash
#
# install-karmada.sh   (run on the jump host)
#
# Stand up the Karmada control plane on the single host phone (pf-006).
#
# This is the script v1 could never get stable. v2 removes the two root causes
# v1 documented instead of patching their symptoms:
#
#   1. UFS fsync stalls killed etcd.  -> etcd's data dir lives on a tmpfs mount
#      (ETCD_RAM_DIR). fsync hits RAM, not flash, so the WAL never stalls. No
#      unsafe-no-fsync flag, no 300s probe patches, no watchdog needed.
#
#   2. host-gw cold-boot route races black-holed apiserver<->etcd traffic.
#      -> the host cluster is a SINGLE node, so every control-plane pod is
#      co-located on pf-006 and all internal traffic is node-local. It never
#      touches cross-node host-gw routing, so there is nothing to race. (v1 ran
#      a 3-node host and fought the scheduler with cordons to force co-location;
#      a 1-node host makes co-location structural.)
#
# Prerequisite: subdivide.sh has already drained pf-006's agents into member
# clusters, so Cluster D is now just pf-006 — a clean single-node host cluster.

source "$(dirname "$0")/lib.sh"

mkdir -p "$VAR_DIR"

# --- karmadactl, pinned -----------------------------------------------------
if ! command -v karmadactl >/dev/null 2>&1; then
  step 1 "Installing karmadactl ${KARMADA_VERSION}..."
  curl -fsSL https://raw.githubusercontent.com/karmada-io/karmada/master/hack/install-cli.sh \
    | sudo bash -s karmadactl "$KARMADA_VERSION"
else
  step 1 "karmadactl present: $(karmadactl version 2>/dev/null | head -1 || echo unknown)"
fi

# --- host node must be schedulable -----------------------------------------
# Cluster D ships every node with a NoSchedule reservation taint. The host has
# to accept the control-plane pods, so remove its taint (this is required, not a
# trick — a tainted single node would leave every Karmada pod Pending).
step 2 "Preparing host node $HOST_NAME..."
kd taint nodes "$HOST_NAME" "reservation=${RESERVATION}:NoSchedule-" >/dev/null 2>&1 || true
kd uncordon "$HOST_NAME" >/dev/null 2>&1 || true
kd get nodes

# --- RAM-backed etcd --------------------------------------------------------
step 3 "Mounting tmpfs for etcd at ${ETCD_RAM_DIR} on ${HOST_NAME}..."
ssh_root "$HOST_IP" '
  mkdir -p '"$ETCD_RAM_DIR"'
  mountpoint -q '"$ETCD_RAM_DIR"' || mount -t tmpfs -o size='"$ETCD_RAM_SIZE"' tmpfs '"$ETCD_RAM_DIR"'
'
log "etcd will hostPath into tmpfs (lost on host reboot — snapshot if you need durability)"

# --- init -------------------------------------------------------------------
# All control-plane components land on the one host node automatically (it is
# the only schedulable node). etcd hostPaths into the tmpfs dir above.
# --wait-component-ready-timeout is the *supported* knob for slow hardware; it
# replaces v1's brute-force re-init loop. Phone cold-boot is slow but healthy.
step 4 "Running karmadactl init (this takes a few minutes on phone hardware)..."
rm -rf "$KARMADA_DATA_DIR"
mkdir -p "$KARMADA_DATA_DIR"
karmadactl init \
  --kubeconfig "$HOST_KUBECONFIG" \
  --karmada-apiserver-advertise-address "$HOST_IP" \
  --etcd-storage-mode hostPath \
  --etcd-data "$ETCD_RAM_DIR" \
  --wait-component-ready-timeout 600 \
  --karmada-data "$KARMADA_DATA_DIR" \
  --karmada-pki "$KARMADA_DATA_DIR/pki"

[ -f "$KARMADA_KUBECONFIG" ] || die "karmadactl init finished but $KARMADA_KUBECONFIG is missing"

# --- readiness gate ---------------------------------------------------------
# karmadactl init prints its success banner even when components time out (it
# did exactly that when pf-006 hit DiskPressure and scheduler/controller-manager/
# webhook stayed Pending). Don't trust the banner: block until every component is
# actually Available, and on failure dump the node taints + pending pods so the
# real cause is visible immediately instead of after a failed join.
step 5 "Verifying all karmada-system components are Available..."
if ! kd -n karmada-system wait --for=condition=Available --timeout=300s deploy --all; then
  log "Control-plane components did not all become Available. Diagnostics:"
  kd describe node "$HOST_NAME" | grep -iA2 'Taints:' || true
  kd -n karmada-system get pods -o wide || true
  kd -n karmada-system get events --sort-by=.lastTimestamp 2>/dev/null | tail -15 || true
  die "Karmada control plane incomplete (see above). Images now live on ${K3S_DATA_DIR} (/userdata) so root DiskPressure should be gone — if a disk-pressure taint still shows, check 'df -h /userdata' on $HOST_NAME."
fi

step 6 "Karmada control plane ready."
log "Karmada API: https://${HOST_IP}:32443"
log "kubeconfig:  $KARMADA_KUBECONFIG"
log "Next: ./join-members.sh <N>"
