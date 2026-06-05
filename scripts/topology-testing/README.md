# topology-testing

Full end-to-end topology experiments on Kind. Each script creates clusters,
initializes Karmada, deploys observability, and runs a 500-pod Nginx workload
while measuring rollout latency — so you can compare latency across topologies.

## Scripts

Both take `<NUM_CLUSTERS> <TOTAL_WORKER_NODES>`.

- **`test-topology-456.sh`** — Recommended. Spreads nodes across clusters as evenly
  as possible, using all of them (e.g. `5 12` → `[3,3,2,2,2]`).
- **`test-topology.sh`** — Original. Splits by integer division, so it drops the
  remainder when `nodes` doesn't divide evenly by `clusters`. Use only for even splits.

## Example

```bash
# 3 clusters, 12 total worker nodes
./test-topology-456.sh 3 12
```

The rollout latency is printed at the end of the run (`Total Pod Rollout Latency: <N> seconds`).

Steps: dependency check → cleanup → provision clusters → init Karmada → deploy Prometheus/Grafana → auto-wire data sources → apply 500-pod workload → measure rollout latency.

## Results

500-pod Nginx rollout latency (seconds), by cluster count and total worker nodes:

| Clusters | 12 nodes | 24 nodes | 48 nodes |
|---|---|---|---|
| 1 | 83 | 101 | 106 |
| 2 | 102 | 109 | 122 |
| 3 | 91 | 93 | 168 |
| 4 | 92 | 96 | 135 |
| 5 | 133 | 147 | 186 |
| 6 | 97 | 130 | 186 |
