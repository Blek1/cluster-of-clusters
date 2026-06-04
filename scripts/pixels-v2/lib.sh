#!/usr/bin/env bash
#
# lib.sh — reusable primitives shared by the v2 jump-host scripts.
#
# v1 repeated the same ~6-line ssh/install incantation in every script, so the
# bootstrap and reset paths drifted apart. v2 puts each primitive here exactly
# once: the messy remote-sudo quoting lives in one place and is tested as a unit.
#
# Source this (not config.sh) from scripts:  source "$(dirname "$0")/lib.sh"

set -euo pipefail

_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./config.sh
source "${_LIB_DIR}/config.sh"

log()  { printf '  -> %s\n' "$*"; }
step() { printf '\n[%s] %s\n' "$1" "$2"; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# index_of NAME -> echoes the array index of a phone name, or returns 1.
index_of() {
  local target=$1 i
  for i in "${!PHONE_NAMES[@]}"; do
    [[ "${PHONE_NAMES[$i]}" == "$target" ]] && { echo "$i"; return 0; }
  done
  return 1
}

# ip_of NAME / switch_of NAME — convenience lookups.
ip_of()     { local i; i=$(index_of "$1") && echo "${PHONE_IPS[$i]}"; }
switch_of() { local i; i=$(index_of "$1") && echo "${PHONE_SWITCH[$i]}"; }

# ---------------------------------------------------------------------------
# SSH helpers (jump host -> phone). The phones only take password auth, so we
# use sshpass; sudo on the phone reads its password from stdin via `sudo -S`.
# ---------------------------------------------------------------------------

# ssh_phone IP CMD...  — run CMD on the phone as the kalm user.
ssh_phone() {
  local ip=$1; shift
  sshpass -p "$PHONE_PASS" ssh -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null "${PHONE_USER}@${ip}" "$@"
}

# ssh_root IP SCRIPT  — run a /bin/sh SCRIPT on the phone as root.
# SCRIPT runs remotely, so $(...) and $VAR inside it (escaped by the caller as
# \$) evaluate on the phone, not locally. PHONE_PASS expands locally — that is
# what feeds `sudo -S`.
ssh_root() {
  local ip=$1 script=$2
  ssh_phone "$ip" "echo ${PHONE_PASS} | sudo -S sh -c '${script}'"
}

# ---------------------------------------------------------------------------
# K3s primitives. Every honored hardware constraint from docs.md is expressed
# here once: host-gw backend (no VXLAN), per-phone enx flannel iface lookup,
# binary + registries.yaml re-copy after the self-deleting uninstall scripts.
# ---------------------------------------------------------------------------

# k3s_wipe IP — uninstall whichever k3s role is present and restore the binary.
# Both uninstall scripts wipe /usr/local/bin/k3s itself, so we always re-copy it
# from the durable /userdata asset afterward.
#
# We must also rm the custom data-dir by hand: --data-dir is passed inside
# INSTALL_K3S_EXEC, which the k3s-generated uninstall scripts don't see — they
# only clean the default /var/lib/rancher/k3s. Without this, a server's old node
# record (and its PodCIDR) survives into the next install, and if the phone is
# reused at a different member index its new --cluster-cidr won't match the stale
# CIDR, so node-ipam crash-loops the server ("cidr X is out the range of Y").
k3s_wipe() {
  local ip=$1
  ssh_root "$ip" '
    [ -x /usr/local/bin/k3s-uninstall.sh ] && /usr/local/bin/k3s-uninstall.sh || true
    [ -x /usr/local/bin/k3s-agent-uninstall.sh ] && /usr/local/bin/k3s-agent-uninstall.sh || true
    rm -rf '"$K3S_DATA_DIR"'
    cp '"$ASSETS"'/k3s-arm64 /usr/local/bin/k3s
    chmod +x /usr/local/bin/k3s
  '
}

# _apply_registries IP UNIT — restore registries.yaml (wiped by uninstall) and
# restart the given k3s unit so the local registry is usable again.
_apply_registries() {
  local ip=$1 unit=$2
  ssh_root "$ip" '
    mkdir -p /etc/rancher/k3s
    cp '"$ASSETS"'/registries.yaml /etc/rancher/k3s/registries.yaml
    systemctl restart '"$unit"'
  '
}

# k3s_install_server NAME IP POD_CIDR SVC_CIDR — fresh single-server install.
k3s_install_server() {
  local name=$1 ip=$2 pod=$3 svc=$4
  k3s_wipe "$ip"
  ssh_root "$ip" '
    IFACE=$(ls /sys/class/net | grep enx | head -1)
    env INSTALL_K3S_SKIP_DOWNLOAD=true \
      INSTALL_K3S_EXEC="server --flannel-iface=$IFACE --node-ip='"$ip"' \
        --flannel-backend=host-gw --cluster-cidr='"$pod"' --service-cidr='"$svc"' \
        --data-dir='"$K3S_DATA_DIR"' \
        --disable=traefik --node-name='"$name"' --tls-san='"$ip"'" \
      sh '"$ASSETS"'/k3s-install.sh
  '
  _apply_registries "$ip" k3s
}

# k3s_install_agent NAME IP SERVER_IP TOKEN — join a phone as an agent.
k3s_install_agent() {
  local name=$1 ip=$2 server_ip=$3 token=$4
  k3s_wipe "$ip"
  ssh_root "$ip" '
    IFACE=$(ls /sys/class/net | grep enx | head -1)
    env INSTALL_K3S_SKIP_DOWNLOAD=true \
      K3S_URL=https://'"$server_ip"':6443 K3S_TOKEN='"$token"' \
      INSTALL_K3S_EXEC="agent --flannel-iface=$IFACE --node-ip='"$ip"' --node-name='"$name"' \
        --data-dir='"$K3S_DATA_DIR"'" \
      sh '"$ASSETS"'/k3s-install.sh
  '
  _apply_registries "$ip" k3s-agent
}

# get_node_token SERVER_IP — print a server's agent join token. Lives under the
# custom --data-dir (K3S_DATA_DIR), not the default /var/lib/rancher/k3s.
get_node_token() {
  ssh_root "$1" 'cat '"$K3S_DATA_DIR"'/server/node-token'
}

# fetch_member_kubeconfig SERVER_IP OUTFILE — pull a server's kubeconfig to the
# jump host with the loopback server URL rewritten to the phone's LAN IP.
fetch_member_kubeconfig() {
  local server_ip=$1 out=$2
  ssh_root "$server_ip" 'cat /etc/rancher/k3s/k3s.yaml' \
    | sed "s|server: https://127.0.0.1:6443|server: https://${server_ip}:6443|" >"$out"
}

# ---------------------------------------------------------------------------
# Cluster D (host) helpers
# ---------------------------------------------------------------------------

kd() { kubectl --kubeconfig="$HOST_KUBECONFIG" "$@"; }

# drain_off_host NAME — remove a phone from Cluster D so it can be reinstalled.
drain_off_host() {
  local name=$1
  kd drain "$name" --ignore-daemonsets --delete-emptydir-data --force --grace-period=0 >/dev/null 2>&1 || true
  kd delete node "$name" --ignore-not-found >/dev/null 2>&1 || true
}

# wait_node_ready KUBECONFIG NAME [TIMEOUT] — block until a node registers Ready.
# docs.md gotcha #5: first registration takes a beat, so we poll rather than
# assume. Default 180s covers a cold phone install.
wait_node_ready() {
  local kubeconfig=$1 name=$2 timeout=${3:-180} waited=0
  until kubectl --kubeconfig="$kubeconfig" get node "$name" \
        -o jsonpath='{range .status.conditions[?(@.type=="Ready")]}{.status}{end}' 2>/dev/null \
        | grep -q True; do
    sleep 5; waited=$((waited + 5))
    [ "$waited" -ge "$timeout" ] && die "node $name not Ready after ${timeout}s"
  done
}

# member_kubeconfig_path I — path to member cluster i's kubeconfig on jump host.
member_kubeconfig_path() { echo "${VAR_DIR}/member-$1.kubeconfig"; }
member_cluster_name()    { echo "member-$1"; }
