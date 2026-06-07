# Karmada on Pixel-Phone Bare-Metal — Version 2

A clean re-architecture of the Pixel phone pipeline. v2 removes the root causes from v1 instead of patching the symptoms.

## From v1

v1 ([post-mortem](../pixels-v1/README.md)) never got a multi-cluster control plane
to stay up. It hit two hardware bottlenecks, and v2's architecture removes each at
the source rather than patching it:

- **etcd vs UFS flash (v1 Scenario A):** the Pixel's UFS storage couldn't keep up
  with etcd's fsync-heavy write-ahead log, so the kubelet kept killing the
  apiserver. v2 puts etcd on a tmpfs (RAM) mount, so those writes never touch
  flash — see `ETCD_RAM_DIR` in `config.sh`.
- **host-gw cross-node races (v1 Scenario B):** splitting etcd and the apiserver
  across phones sent their traffic over the host-gw fabric, which black-holed
  packets during cold-boot CPU spikes (Android kernels lack VXLAN). v2 co-locates
  the entire control plane on one host node (pf-006), so there is no cross-node
  control-plane traffic to race.

The result is the stable federation v1 couldn't reach: every topology below runs
Karmada to completion. The one challenge v2 *did* hit (DiskPressure) was new, and
is written up under [Challenges Encountered](#challenges-encountered).

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
- **N=3 — 1 host + 3 members:** pf-006 host · members of 6, 6, and 6 phones. *(3 clusters is where federation overhead is overcome)*
- **N=4 — 1 host + 4 members:** pf-006 host · members of 5, 5, 4, and 4 phones.
- **N=5 — 1 host + 5 members:** pf-006 host · members of 4, 4, 4, 3, and 3 phones.

### Results

Rollout latency (s) across workload sizes, to locate the split threshold — the
pod count where the federated rows first beat the baseline.

| Topology | 50 | 100 | 500 | 1000 | 1500 | 2000 |
|---|---|---|---|---|---|---|
| Baseline  | 11 | 7 | 27 | 53 | 78 | 105 |
| 2 members | 12 | 4 | 15 | 27 | 40 | FAIL |
| 3 members | 11 | 4 | 11 | 18 | 27 | FAIL |
| 4 members | 11 | 4 | 9 | 15 | 21 | FAIL |
| 5 members | 11 | 4 | 8 | 13 | 18 | FAIL |

**Analysis.** Federation on hardware is not strictly better or worse than one big cluster, it just seems to trade latency for capacity. Splitting turns one cluster's serial
scheduling (everything through a single apiserver/scheduler) into parallel scheduling across N independent control planes on separate hardware. The data shows three things:

- ≤100 pods — don't split. Nothing to parallelize, so federation overhead
  makes it slightly worse (50 pods: baseline 11 vs 2-member 12).
- 500–1500 pods — split; ~3 members is enough. The win is large and grows
  with load (1500 pods: 78 → 18, ≈4.3×), but adding members has sharply
  diminishing returns — at 500 pods, 2→3→4→5 members buys 15 → 11 → 9 → 8. Most
  of the gain is in by ~3 clusters, matching what we saw in the Kind experiments
  (`scripts/topology-testing/`), where latency dropped from 2 to 3 clusters as
  federation overcame its overhead.
- 2000 pods — splitting breaks the workload. The baseline still finishes
  (105 s), but every federated split fails: subdividing shrank each member
  below the capacity the job needs (likely the ~110-pod/node kubelet cap), so the
  divided replicas can't all schedule.

Design rule: split when the workload is big enough to amortize federation
overhead (>~100 pods here) but small enough to fit comfortably within the reduced
per-member capacity. ~3 members is the efficient default; more buys little.

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
| `run-experiments.sh <N> [REPLICAS]` | laptop | Inject one workload, time the rollout (interactive; needs the tunnel). |
| `sweep.sh` | jump host | **Unattended workload×topology sweep.** Build each `N`, inject every workload size, write latencies to a CSV. No tunnel needed. |
| `plot-results.py` | jump host | Turn `sweep-results.csv` into two figures: latency-vs-workload (the split threshold) and the members knee. Needs `matplotlib`. |

## Usage

Get your SSH key onto the jump host first (see `docs.md`). Then, on the jump host:

```bash
cd scripts/pixels-v2

# Cold start: wipe all 19 phones and build a clean 1×19 Cluster D on /userdata.
# Do this once at the start of a campaign — every later run inherits this state.
./build-clusterd.sh

# Federated: 1 host + 3 member clusters (3 clusters is where federation overhead is overcome)
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

### Sweeping workloads across topologies

`sweep.sh` (jump host, no tunnel) builds each topology and injects every workload
size, writing `clusters-v2/sweep-results.csv`:

```bash
./sweep.sh                                          # 1..5 × 50/100/500/1000/2000 pods
TOPOLOGIES="1 3 5" WORKLOADS="100 1000" REPEATS=3 ./sweep.sh
```

Then plot the CSV (writes `latency-vs-workload.png` and `members-knee.png` beside it):

```bash
python3 plot-results.py "$VAR_DIR/sweep-results.csv"   # pip install matplotlib if missing
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

## Future Work

The results above are bounded by a 19-phone fleet, so both axes of the sweep stop
early — the workload axis hits the per-member capacity cliff at 2000 pods, and the
topology axis tops out at 5 members. The fleet is expected to grow toward thousands of
phones, which lifts both ceilings and opens the more interesting questions.

- Scaling the fleet: With orders of magnitude more nodes, the
  capacity cliff moves far out, so the sweet-spot and failure regimes can be
  mapped properly instead of inferred from limited experimentation. It also tests whether
  the "~3 members captures most of the gain" rule holds at scale or whether the
  knee shifts as clusters get larger. `config.sh` is the only file that needs to change,
  everything downstream is already fleet-size-agnostic, but the
  reserved-CIDR table (`MAX_MEMBER_CLUSTERS=5`) and the parallel-wipe/join fan-out
  will need revisiting for thousands of nodes.
- Push the workload: At scale, re-run with 5k–50k+
  pods and larger per-pod footprints to find where the baseline cluster
  finally becomes the bottleneck.
- Vary the topology shape: The splits here are even
  (`9,9` … `4,4,4,3,3`). Real federations are lopsided — test skewed splits,
  heterogeneous member sizes, and placement policies beyond `Divided`/`Weighted`.

