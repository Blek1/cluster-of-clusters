#!/usr/bin/env bash
#
# sweep.sh   (run on the jump host)
#
# Workload x topology sweep. For each topology N in $TOPOLOGIES, build it once,
# then inject every workload size in $WORKLOADS and time the rollout. Results go
# to a CSV you can pivot straight into the README results grid.
#
# This lives on the JUMP HOST (not the laptop) on purpose: reshaping the topology
# (subdivide / install-karmada / join / reset) needs direct phone-subnet access,
# which only the jump host has (lib.sh ssh's straight at 10.0.0.x). It talks to
# the control planes through their real LAN kubeconfigs, so there is NO ssh
# tunnel, no scp, and no interactive prompt -- the whole grid runs unattended.
#
# It answers "when should one cluster split into several?": a single workload
# size can't, because parallelism always wins there. Sweeping the workload axis
# exposes the crossover -- the pod count at which the federated topologies first
# beat the 1x19 baseline is the split threshold.
#
# Knobs (env, or edit the defaults below):
#   TOPOLOGIES="1 2 3 4 5"            member-cluster counts to test (1 = baseline)
#   WORKLOADS="50 100 500 1000 2000"  replica counts injected at each topology
#   REPEATS=1                         runs per (N, W) cell; each is its own row
#   COLD=0                            1 = run build-clusterd.sh once before start
#
# Output CSV: $VAR_DIR/sweep-results.csv  (topology,split,replicas,repeat,latency_s)
#
#   ./sweep.sh                        # full default grid
#   WORKLOADS="100 1000" ./sweep.sh   # only two sizes
#   TOPOLOGIES="1 3 5" REPEATS=3 ./sweep.sh
#   COLD=1 ./sweep.sh                 # rebuild the baseline from scratch first

source "$(dirname "$0")/lib.sh"
D="$(dirname "$0")"

TOPOLOGIES="${TOPOLOGIES:-1 2 3 4 5}"
WORKLOADS="${WORKLOADS:-50 100 500 1000 2000}"
REPEATS="${REPEATS:-1}"
COLD="${COLD:-0}"

CSV="${VAR_DIR}/sweep-results.csv"

# split_label N -> even split of the 18-phone pool, e.g. "9,9" (N=1 -> baseline).
split_label() {
  local n=$1
  [ "$n" -le 1 ] && { echo "baseline-19"; return; }
  local pool=$(( ${#PHONE_NAMES[@]} - 1 )) base rem out="" i
  base=$(( pool / n )); rem=$(( pool % n ))
  for i in $(seq 1 "$n"); do
    if [ "$i" -le "$rem" ]; then out+="$((base + 1)),"; else out+="${base},"; fi
  done
  echo "${out%,}"
}

# kubeconfig_for N -> control plane to inject into (Cluster D for baseline, else
# the Karmada apiserver, which fans the workload out to the member clusters).
kubeconfig_for() {
  if [ "$1" -le 1 ]; then echo "$HOST_KUBECONFIG"; else echo "$KARMADA_KUBECONFIG"; fi
}

# wait_workload_gone KUBECONFIG -- best-effort wait for app=nginx pods to clear
# so a slow teardown can't bleed into the next cell's timing. Caps at 120s.
wait_workload_gone() {
  local kcfg=$1 waited=0
  until [ -z "$(kubectl --kubeconfig="$kcfg" get pods -l app=nginx -A --no-headers 2>/dev/null)" ]; do
    sleep 5; waited=$(( waited + 5 )); [ "$waited" -ge 120 ] && break
  done
}

# measure N REPLICAS -> echoes rollout latency in seconds, or "FAIL".
# Times from apply to a fully-rolled-out Deployment, then deletes the workload.
measure() {
  local n=$1 replicas=$2 kcfg manifest start latency
  kcfg="$(kubeconfig_for "$n")"
  manifest="$(mktemp -t cofc-sweep.XXXX.yaml)"
  workload_manifest "$n" "$replicas" "$manifest"
  start=$(date +%s)
  if kubectl --kubeconfig="$kcfg" apply -f "$manifest" >/dev/null 2>&1 \
     && kubectl --kubeconfig="$kcfg" rollout status deployment/workload-nginx --timeout=15m >/dev/null 2>&1; then
    latency=$(( $(date +%s) - start ))
  else
    latency="FAIL"
  fi
  kubectl --kubeconfig="$kcfg" delete -f "$manifest" >/dev/null 2>&1 || true
  rm -f "$manifest"
  sleep 10                       # let Karmada propagate the delete to members
  wait_workload_gone "$kcfg"
  echo "$latency"
}

# ---------------------------------------------------------------------------

printf 'topology,split,replicas,repeat,latency_s\n' >"$CSV"
log "Writing results to $CSV"
log "Grid: topologies=[$TOPOLOGIES] workloads=[$WORKLOADS] repeats=$REPEATS"

if [ "$COLD" = "1" ]; then
  step COLD "Rebuilding the 1x19 baseline from scratch before sweeping..."
  "$D/build-clusterd.sh"
fi

for N in $TOPOLOGIES; do
  split="$(split_label "$N")"
  step "N=$N" "Topology: $split"

  if [ "$N" -le 1 ]; then
    log "baseline -- assuming Cluster D is already up (use COLD=1 to rebuild it)"
  elif ! "$D/bootstrap-phones.sh" "$N"; then
    log "topology N=$N failed to build; recording nothing and moving on"
    "$D/reset-phones.sh" >/dev/null 2>&1 || true
    continue
  else
    "$D/verify-topology.sh" "$N" || log "verify-topology reported drift; continuing anyway"
  fi

  for W in $WORKLOADS; do
    for r in $(seq 1 "$REPEATS"); do
      step "N=$N W=$W" "run $r/$REPEATS ..."
      lat="$(measure "$N" "$W")"
      printf '%s,%s,%s,%s,%s\n' "$N" "$split" "$W" "$r" "$lat" >>"$CSV"
      log "==> N=$N split=$split replicas=$W run=$r latency=${lat}s"
    done
  done

  if [ "$N" -gt 1 ]; then
    step "N=$N" "Folding back to the 1x19 baseline..."
    "$D/reset-phones.sh"
  fi
done

step DONE "Sweep complete."
log "CSV: $CSV"
echo
column -s, -t "$CSV" 2>/dev/null || cat "$CSV"
