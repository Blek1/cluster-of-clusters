#!/usr/bin/env bash
#
# config.sh — single source of truth for the Pixel-phone fleet (v2).
#
# Every v2 script sources lib.sh, which sources this file. Nothing here runs
# anything; it only declares facts about the hardware and where artifacts live.
# If the fleet changes (a phone dies, the host moves, CIDRs are re-issued), this
# is the ONLY place you edit.
#
# All values come from the 2026-05-25 welcome packet + 2026-05-26 addendum
# (see ./docs.md). They are intentionally not duplicated inside any other script.

# ---------------------------------------------------------------------------
# Fleet inventory
# ---------------------------------------------------------------------------
# Index-aligned arrays: PHONE_NAMES[i] lives at PHONE_IPS[i] on switch
# PHONE_SWITCH[i]. Order is the carve order — earlier phones get used first.
# pf-006 is the Cluster D K3s server (our Karmada host); it is listed first and
# is NOT part of the member pool (see HOST_NAME below).
PHONE_NAMES=(pf-006 pf-007 pf-008 pf-009 pf-010 pf-011 pf-012 pf-013 pf-014 pf-016 pf-017 pf-019 pf-021 pf-024 pf-031 pf-032 pf-033 pf-035 pf-036)
PHONE_IPS=(10.0.0.16 10.0.0.17 10.0.0.18 10.0.0.19 10.0.0.20 10.0.0.21 10.0.0.22 10.0.0.23 10.0.0.24 10.0.0.26 10.0.0.27 10.0.0.29 10.0.0.31 10.0.0.34 10.0.0.41 10.0.0.42 10.0.0.43 10.0.0.45 10.0.0.46)
PHONE_SWITCH=(1 1 1 1 1 1 1 1 1 1 1 1 2 2 2 2 2 2 2)

# ---------------------------------------------------------------------------
# Roles
# ---------------------------------------------------------------------------
# The Karmada host cluster is a SINGLE phone (see README — "co-locate the whole
# control plane on one dedicated node"). pf-006 is that host AND the Cluster D
# baseline server. build-clusterd.sh rebuilds it from scratch onto /userdata
# (see K3S_DATA_DIR) so the run carries no one-time hand-provisioned state. Every
# other phone is a member-pool phone, carved into N clusters by subdivide.sh.
HOST_NAME="pf-006"
HOST_IP="10.0.0.16"

# ---------------------------------------------------------------------------
# Access (per docs.md — phones reachable only from the jump host)
# ---------------------------------------------------------------------------
PHONE_USER="kalm"
PHONE_PASS="0000"          # documented fleet password; used via sshpass + sudo -S
ASSETS="/userdata/cluster-d-assets"   # durable per-phone assets (survive reboot)

# K3s stores its ENTIRE data dir (containerd image cache, kubelet, server state)
# here instead of the default /var/lib/rancher/k3s. This is the structural fix
# for the DiskPressure that black-holed the Karmada control plane: docs.md
# gotcha #6 says the phone root partition is only 3.9 GB and any image cache
# belongs on /userdata (~225 GB). Raymond set the same precedent for buildah
# (/userdata/containers/storage). Passed to every install as --data-dir; the
# server node-token therefore lives under ${K3S_DATA_DIR}/server, not /var/lib.
K3S_DATA_DIR="/userdata/k3s"

# Local registry (images already mirrored here, e.g. nginx:alpine).
REGISTRY="10.0.0.1:30500"
WORKLOAD_IMAGE="${REGISTRY}/nginx:alpine"

# Reservation label + taint applied to every baseline node.
RESERVATION="cluster-of-clusters-until-2026-06-12"

# ---------------------------------------------------------------------------
# Cluster D (the baseline host cluster) — kubeconfig on the jump host
# ---------------------------------------------------------------------------
HOST_KUBECONFIG="/home/luffy/cluster-d.kubeconfig"   # server: https://10.0.0.16:6443

# Where v2 writes everything it generates on the jump host (member kubeconfigs,
# Karmada data/PKI, karmada-apiserver.config). Kept separate from v1's
# /home/luffy/clusters so the two iterations never clobber each other.
#
# This is an ABSOLUTE jump-host path on purpose: run-experiments.sh runs on the
# laptop and reuses these same values as the remote scp source, so they must not
# depend on the laptop's $HOME. The jump-host scripts run as luffy, so this is
# also where they create the files locally.
VAR_DIR="/home/luffy/clusters-v2"
KARMADA_DATA_DIR="${VAR_DIR}/karmada"
KARMADA_KUBECONFIG="${KARMADA_DATA_DIR}/karmada-apiserver.config"

# RAM-backed etcd: tmpfs mount on the host phone that Karmada's etcd hostPaths
# into. This is the root-cause fix for v1's UFS fsync stalls (see README).
ETCD_RAM_DIR="/karmada-etcd-ram"
ETCD_RAM_SIZE="2G"          # etcd needs <100MB; 2G cap is safe vs ~9GB free RAM

# Karmada version pin. The welcome packet stresses controlling your own pin
# (Parth pinned a commit for kind). Confirm the tag exists before a real run:
#   curl -s https://api.github.com/repos/karmada-io/karmada/releases | grep tag_name
KARMADA_VERSION="${KARMADA_VERSION:-v1.14.2}"

# ---------------------------------------------------------------------------
# CIDR allocation — reserved table from docs.md (addendum, 5 sub-cluster slots)
# ---------------------------------------------------------------------------
# Cluster D's own reserved CIDRs (reserved table, docs.md). build-clusterd.sh
# installs the pf-006 baseline server with these; members use member_*_cidr.
HOST_POD_CIDR="10.48.0.0/16"
HOST_SVC_CIDR="10.49.0.0/16"
# Cluster D (host) is 10.48.0.0/16 / 10.49.0.0/16. Member i (1-based) gets
# pod=10.(48+2i).0.0/16, svc=10.(49+2i).0.0/16 -> #1=10.50/10.51 ... #5=10.58/10.59.
# This formula reproduces the official reserved table; do not invent new ranges.
member_pod_cidr() { echo "10.$((48 + 2 * $1)).0.0/16"; }
member_svc_cidr() { echo "10.$((49 + 2 * $1)).0.0/16"; }
MAX_MEMBER_CLUSTERS=5      # only 5 CIDR slots are reserved; ask Raymond for more
