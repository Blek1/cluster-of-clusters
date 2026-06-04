# Karmada on Pixel-Phone Bare-Metal — Version 2

A clean re-architecture of the Pixel phone pipeline. v2 attempts to remove the root causes from v1 instead of patching the symptoms.

## Topology

```
N=1  baseline    Cluster D as-is: pf-006 server + 18 agents (19 nodes). No Karmada.

N>=2 federated   pf-006  ──────────────  Karmada control plane ONLY (etcd on tmpfs)
                   │  (host cluster = 1 node, so co-location is structural)
                   │  karmadactl join over the LAN (10.0.0.x, never the pod network)
                   ├─ member-1   ┐
                   ├─ member-2   │  18 phones split evenly, each its own K3s
                   └─ member-N   ┘  cluster with a unique reserved CIDR pair
```

Even splits of the 18-phone pool: `N=2 → 9,9` · `N=3 → 6,6,6` · `N=4 → 5,5,4,4` ·
`N=5 → 4,4,4,3,3`. CIDRs follow the reserved table in `docs.md`
(`member-i` → pod `10.(48+2i).0.0/16`, svc `10.(49+2i).0.0/16`).

## Topologies & Results

For N≥2, pf-006 is always the host (Karmada control plane only) and the other 18
phones are split evenly into the member clusters:

- **N=1 — baseline (no Karmada):** Cluster D, pf-006 server + 18 agents = 19 nodes.
- **N=2 — 1 host + 2 members:** pf-006 host · members of 9 and 9 phones.
- **N=3 — 1 host + 3 members:** pf-006 host · members of 6, 6, and 6 phones. *(validates the published 3-cluster rule)*
- **N=4 — 1 host + 4 members:** pf-006 host · members of 5, 5, 4, and 4 phones.
- **N=5 — 1 host + 5 members:** pf-006 host · members of 4, 4, 4, 3, and 3 phones.

### Results

Rollout latency = wall-clock time for `run-experiments.sh` to take the workload
Deployment to fully `Available`. Fill in after each run (default workload is 500
`nginx:alpine` pods; the script prints the latency at the end).

| Topology | Split | Workload (pods) | Rollout latency |
|---|---|---|---|---|---|
| Baseline | — | 500 | _TBD_ |
| 2 members | 9, 9 | 500 | _TBD_ |
| 3 members | 6, 6, 6 | 500 | _TBD_ |
| 4 members | 5, 5, 4, 4 | 500 | _TBD_ |
| 5 members | 4, 4, 4, 3, 3 | 500 | _TBD_ |

> Status: the v2 scripts have not yet been run end-to-end on the live fleet, so
> every latency above is a placeholder. Replace `_TBD_` as runs complete.

## Files

| File | Where | Purpose |
|---|---|---|
| `config.sh` | — | Single source of truth: fleet inventory, host, CIDR allocator, paths, registry. **Edit only here** if the fleet changes. |
| `lib.sh` | — | Reusable primitives: SSH/sudo wrappers, K3s install/wipe (all installs use `--data-dir /userdata/k3s`), kubeconfig + token fetch, readiness waits. Sourced by every jump-host script. |
| `build-clusterd.sh` | jump host | **Cold start.** Wipe all 19 phones and rebuild the 1×19 Cluster D baseline from scratch on `/userdata`, including pf-006, and refetch its kubeconfig. Fully scripted — no one-time manual state. |
| `subdivide.sh <N>` | jump host | Carve the 18-phone pool into N K3s clusters with unique CIDRs. K3s only — no Karmada. |
| `install-karmada.sh` | jump host | tmpfs etcd + single-node `karmadactl init` on pf-006. **The v1 pain point.** |
| `join-members.sh <N>` | jump host | `karmadactl join` each member cluster over the LAN. |
| `bootstrap-phones.sh <N>` | jump host | Thin orchestrator: subdivide → install-karmada → join-members. |
| `verify-topology.sh <N>` | jump host | Confirm the live layout matches the expected N. |
| `check-phones.sh` | jump host | Node readiness + containerd-recovery reminder. |
| `monitor-phones.sh <N>` | jump host | Live rollout dashboard. |
| `reset-phones.sh` | jump host | Fold everything back into the 1×19 baseline. |
| `run-experiments.sh <N> [REPLICAS]` | laptop | Inject the workload, time the rollout. |

## Usage

Get your SSH key onto the jump host first (see `docs.md`). Then, on the jump host:

```bash
cd scripts/pixels-v2

# Cold start: wipe all 19 phones and build a clean 1×19 Cluster D on /userdata.
# Do this once at the start of a campaign — every later run inherits this state.
./build-clusterd.sh

# Federated: 1 host + 3 member clusters (validates the published 3-cluster rule)
./bootstrap-phones.sh 3
./verify-topology.sh 3

# ...or drive the stages individually
./subdivide.sh 3 && ./install-karmada.sh && ./join-members.sh 3
```

On your laptop, with a tunnel open in another terminal:

```bash
ssh -L 6443:10.0.0.16:6443 -L 32443:10.0.0.16:32443 straw-hat   # leave open
./run-experiments.sh 3            # times the 500-pod rollout across 3 members
```

**Tear down** back to the 1×19 baseline when done:

```bash
./reset-phones.sh                 # on the jump host (lightweight; keeps pf-006)
```

`build-clusterd.sh` vs `reset-phones.sh`: both land you at the 1×19 baseline.
`build-clusterd.sh` is the **cold** path — it rebuilds pf-006 too and is what you
run for a guaranteed-clean campaign. `reset-phones.sh` is the **warm** path
between topology changes — it leaves pf-006 running, so it's faster.

## Challenges Encountered

Challenge hit during v2 (since solved):

### The DiskPressure Eviction of the Control Plane
The Karmada control plane half-deployed: `etcd`, `karmada-apiserver`,
`karmada-aggregated-apiserver`, and `kube-controller-manager` came up on pf-006,
but `karmada-scheduler`, `karmada-controller-manager`, and `karmada-webhook` sat
`Pending` forever.

* What happened: pulling the ~7 control-plane images filled pf-006's 3.9 GB root
  partition. The kubelet reacted by tainting the node `disk-pressure:NoSchedule`.
  The first components scheduled *before* the disk filled; everything created
  after the taint appeared had nowhere to go (`NODE <none>`).
* Cause (UFS / 3.9 GB root): the Pixel Fold root partition is only 3.9 GB
  (`docs.md` gotcha #6). The containerd image store defaults to
  `/var/lib/rancher/k3s` on that root, so a handful of image pulls crosses the
  kubelet's disk-pressure eviction threshold and the node stops accepting pods.
* The Proof (`karmadactl init` — components never roll out):
```bash
W0604 04:04:00.677392 2084649 deploy.go:558] wait for Deployment(karmada-system/karmada-scheduler) rollout: context deadline exceeded: expected 1 replicas, got 0 available replicas
W0604 04:14:00.751042 2084649 deploy.go:566] wait for Deployment(karmada-system/karmada-controller-manager) rollout: context deadline exceeded: client rate limiter Wait returned an error: context deadline exceeded
W0604 04:24:00.859139 2084649 deploy.go:577] wait for Deployment(karmada-system/karmada-webhook) rollout: context deadline exceeded: client rate limiter Wait returned an error: context deadline exceeded
```
* The Proof (the pods are unschedulable, and the taint is `disk-pressure`):
```bash
karmada-controller-manager-5dcdd456c9-5c5n2     0/1     Pending   0     21m   <none>   <none>
karmada-scheduler-9544c6758-24vdq               0/1     Pending   0     31m   <none>   <none>
karmada-webhook-9474bd74d-24szr                 0/1     Pending   0     11m   <none>   <none>

Warning  FailedScheduling  34m  default-scheduler  0/1 nodes are available: 1 node(s) had untolerated taint(s)...
Taints:  node.kubernetes.io/disk-pressure:NoSchedule
```
* The Proof (root is full at 97%, while `/userdata` sits idle at 1%):
```bash
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda30      3.9G  3.6G  139M  97% /
/dev/sda31      225G  628M  213G   1% /userdata
846M    /var/lib/rancher/k3s/agent/containerd
```

Solved by moving the K3s data dir — and with it the containerd image store — onto
`/userdata` (see `K3S_DATA_DIR` in `config.sh` and `build-clusterd.sh`).

