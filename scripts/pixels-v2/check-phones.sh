#!/usr/bin/env bash
#
# check-phones.sh   (run on the jump host)
#
# Quick fleet health check against the baseline Cluster D view: which nodes are
# Ready, and a reminder of the containerd-recovery runbook for any that aren't
# (docs.md gotcha: Pixel Fold containerd state corrupts on power loss).

source "$(dirname "$0")/lib.sh"

step 1 "Cluster D node readiness"
kd get nodes -L switch,image,reservation -o wide

not_ready=$(kd get nodes --no-headers 2>/dev/null | grep -c NotReady || true)
if [ "${not_ready:-0}" -gt 0 ]; then
  printf '\nWARNING: %s node(s) NotReady.\n' "$not_ready"
  log "Recover containerd state: /home/luffy/runbooks/recover-containerd-state.sh pf-XXX"
  log "If a phone is unreachable on ping, it needs physical attention (ping Raymond)."
else
  printf '\nAll nodes Ready.\n'
fi
