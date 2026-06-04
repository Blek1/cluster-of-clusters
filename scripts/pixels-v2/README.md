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

## Files

| File | Where | Purpose |
|---|---|---|
| `config.sh` | — | Single source of truth: fleet inventory, host, CIDR allocator, paths, registry. **Edit only here** if the fleet changes. |
| `lib.sh` | — | Reusable primitives: SSH/sudo wrappers, K3s install/wipe, kubeconfig + token fetch, readiness waits. Sourced by every jump-host script. |
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
./reset-phones.sh                 # on the jump host
```
