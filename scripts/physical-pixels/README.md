# Overview of Execution
Our testing pipeline is split into two phases to account for the physical networking constraints of the Pixel phones.

1. The Jump Host Script: bootstrap-phones.sh is responsible for state destruction and recreation. It uses sshpass to log into each individual Pixel Fold, carves them out of the host cluster, re-installs K3s using unique CIDR blocks, and installs Karmada. This must run on the jump host because our laptops do not have direct routing to the 10.0.0.X phone subnet.

2. The Laptop Script: run-experiments.sh is responsible for workload injection and latency tracking. It pulls the newly generated Karmada configuration file from the jump host, applies our 500-pod Nginx manifest with the dynamically generated PropagationPolicy, and times the rollout loop.

## Execution Steps

1. SSH into the jump host, ensuring you forward the main K3s port and the Karmada API port:
    ssh -L 6443:10.0.0.16:6443 -L 32443:10.0.0.16:32443 straw-hat

2. Run the bootstrap script on the jump host:
    ./bootstrap-phones.sh 3

3. Leave that terminal open. In a new local terminal on your laptop, execute the experiment:
    ./run-experiments.sh 3

## Scripts

All `<N>` arguments are the number of worker (member) clusters to carve from the phone pool.

| Script | Runs on | Purpose |
|---|---|---|
| `bootstrap-phones.sh <N>` | jump host | Carve `N` member clusters out of the phone pool, reinstall K3s with unique CIDR blocks, and install Karmada (phase 1). |
| `run-experiments.sh <N>` | laptop | Pull the Karmada config from the jump host, apply the 500-pod Nginx workload + generated PropagationPolicy, and time the rollout (phase 2). |
| `verify-topology.sh <N>` | jump host | Check that the live cluster/phone layout matches the expected `N`-cluster topology. |
| `check-phones.sh` | jump host | Quick health check — node readiness and crashed `containerd` states. |
| `monitor-phones.sh <N>` | jump host | Live dashboard of phone/cluster status, refreshing every 2 seconds. |
| `reset-phones.sh` | jump host | Tear down the Karmada federation and host observability stack and fold the phones back into the baseline cluster. |

## Topologies Tested
1. 1 Cluster (Baseline): 18 nodes
2. 2 Clusters (1 Host + 2 Members): 3 phones (Host) | 8 phones | 7 phones = 18 Total
3. 3 Clusters (1 Host + 3 Members): 3 phones (Host) | 5 phones | 5 phones | 5 phones = 18 Total
4. 4 Clusters (1 Host + 4 Members): 3 phones (Host) | 4 phones | 4 phones | 4 phones | 3 phones = 18 Total
5. 5 Clusters (1 Host + 5 Members): 3 phones (Host) | 3 phones | 3 phones | 3 phones | 3 phones | 3 phones = 18 Total
6. 6 Clusters (1 Host + 6 Members): 3 phones (Host) | 3 phones | 3 phones | 3 phones | 2 phones | 2 phones | 2 phones = 18 Total
