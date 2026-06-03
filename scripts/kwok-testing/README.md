# KWOK Testing

Stress testing framework for the Karmada control plane using KWOK (Kubernetes Without Kubelet) to simulate member cluster nodes and ClusterLoader2 to drive high volume workloads against a Karmada API server.

## Overview

ClusterLoader2 is pointed at the Karmada control plane to generate large volumes of Deployment and PropagationPolicy objects. Karmada propagates these to KWOK-backed member clusters, where fake nodes instantly mark pods as Running — enabling pure control-plane benchmarking without real compute.

## Repo Structure

```
kwok-testing/
├── configs/
│   ├── clusterloader/     # ClusterLoader2 configs
│   ├── dashboards/        # Grafana dashboards
│   ├── kind/              # Host + member cluster configs
│   └── observ/            # Prometheus configs
├── perf-tests/            # kubernetes/perf-tests submodule
├── scripts/               # Automation scripts
└── README.md
```

## Key Files

| File | Purpose |
|------|---------|
| `configs/clusterloader/config.yaml` | Test definition — namespace count, deployments, QPS |
| `configs/clusterloader/deployment.yaml` | Deployment template for CL2 |
| `configs/clusterloader/policy.yaml` | PropagationPolicy for workload dispatch |

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/setup-cluster.sh` | Bootstrap host cluster, Karmada, members + 1000 fake nodes each |
| `scripts/setup-observability.sh` | Deploy Prometheus + Grafana with dashboard imports |
| `scripts/cluster-loader.sh` | Run CL2 benchmark, print counts, save JUnit report |
| `scripts/verify.sh` | Health check: kind clusters, Karmada pods, member readiness, KWOK |
| `scripts/cleanup.sh` | Tear everything down |

## Run Order

```bash
# 1. Bootstrap everything
MEMBER_COUNT=3 ./scripts/setup-cluster.sh

# 2. Verify the stack
./scripts/verify.sh

# 3. Run the benchmark
./scripts/cluster-loader.sh

# 4. Tear down
./scripts/cleanup.sh
```

Observability is set up automatically by `setup-cluster.sh`. To redeploy independently:
```bash
./scripts/setup-observability.sh
```

Grafana is at `http://localhost:3000` (admin/admin) while port-forward is active.
