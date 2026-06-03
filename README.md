# cluster-of-clusters

Infrastructure-as-code, automation scripts, and configurations for the UCSD CSE 145/237D Junkyard Project.

The goal is to experimentally determine the optimal architecture for scaling large networks of repurposed smartphones. We use Kubernetes in Docker (Kind) for rapid local topology simulation, Karmada for multi-cluster orchestration, and KWOK for scaling, before validating findings on physical Pixel hardware.

## Repository Layout

```
scripts/
  cluster-setup/          Kind cluster creation and teardown
  karmada-orchestration/  Karmada control plane and KWOK fake-node setup
  observability/          Prometheus/Grafana monitoring and dashboards
  topology-testing/       Kind-based topology experiments
  physical-pixels/        Physical Pixel phone experiments
  stress-testing/         Simple Kind workload stress tests
  kwok-testing/           KWOK + ClusterLoader2 stress framework
  experiments/            Misc experiments and prototypes

configs/
  kind/                   Kind cluster configuration files
  prometheus-grafana/     Dashboard JSONs
  karmada/                Karmada manifests and configs

manifests/                Kubernetes workload and template manifests
docs/                     Meeting notes and architecture docs
```

## Prerequisites

* [Docker](https://docs.docker.com/get-docker/) — container runtime
* [kubectl](https://kubernetes.io/docs/tasks/tools/) — Kubernetes CLI
* [kind](https://kind.sigs.k8s.io/) — local Kubernetes clusters
* [Helm](https://helm.sh/docs/intro/install/) — Kubernetes package manager
* [karmadactl](https://karmada.io/docs/) — Karmada CLI
* [kwokctl](https://kwok.sigs.k8s.io/) — KWOK cluster manager

## Quick Start (Kind + Karmada)

Run in order from `scripts/` subdirectories:

1. `scripts/cluster-setup/setup.sh` — create clusters from `configs/kind/*.yaml`
2. `scripts/karmada-orchestration/setup-karmada.sh` — init Karmada, join workers
3. `scripts/observability/setup-observability.sh` — deploy Prometheus/Grafana
4. `scripts/observability/setup-dashboards.sh` — import dashboards

## Contributors

CSE 145/237D Junkyard Cluster of Clusters: Felicia, Blake, Tahseen, Afraz
