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
