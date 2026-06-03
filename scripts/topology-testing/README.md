# topology-testing

Full end-to-end topology experiments on Kind. Each script creates clusters, initializes Karmada, deploys observability, and runs a 500-pod Nginx workload while measuring rollout latency.

## Scripts

- **`test-topology.sh <clusters> <nodes>`** — Original topology test
- **`test-topology-456.sh <clusters> <nodes>`** — Variant with improved node distribution

## Example

```bash
# Test 3 clusters with 12 total worker nodes
./test-topology.sh 3 12
```

Steps: dependency check → cleanup → provision clusters → init Karmada → deploy Prometheus/Grafana → auto-wire data sources → apply 500-pod workload → measure rollout latency.
