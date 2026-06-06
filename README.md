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
  pixels-v1/              Physical Pixel phone experiments — v1 post-mortem
  pixels-v2/              Physical Pixel phone experiments — v2 (working federation)
  stress-testing/         Simple Kind workload stress tests
  kwok-testing/           KWOK + ClusterLoader2 stress framework
  experiments/            Misc experiments and prototypes

configs/
  kind/                   Kind cluster configs for the pipeline (host + worker-1 + worker-2)
  prometheus-grafana/     Grafana dashboard JSONs
  karmada/                Karmada manifests and configs (placeholder)
  automation/ansible/     Ansible automation (placeholder)

manifests/                Kubernetes workload and template manifests
docs/                     Meeting notes; docs/architecture/ is a placeholder
```

## Prerequisites

* [Docker](https://docs.docker.com/get-docker/) — container runtime
* [kubectl](https://kubernetes.io/docs/tasks/tools/) — Kubernetes CLI
* [kind](https://kind.sigs.k8s.io/) — local Kubernetes clusters
* [Helm](https://helm.sh/docs/intro/install/) — Kubernetes package manager
* [karmadactl](https://karmada.io/docs/) — Karmada CLI
* [kwokctl](https://kwok.sigs.k8s.io/) — KWOK cluster manager

## Quick Start (Kind + Karmada)

This brings up the three-cluster pipeline: a Karmada host cluster (`kind-karmada-host`)
plus two members (`kind-worker-1`, `kind-worker-2`), with a Prometheus/Grafana stack
on top. Make sure the [prerequisites](#prerequisites) are installed first.

Each script uses paths relative to its own location, so `cd` into the script's
directory (or call it by full path) before running.

```bash
# 1. Create the host + worker-1 + worker-2 Kind clusters from configs/kind/*.yaml
cd scripts/cluster-setup && ./setup.sh

# 2. Initialize the Karmada control plane on kind-karmada-host and join both workers
cd ../karmada-orchestration && ./setup-karmada.sh

# 3. Deploy kube-prometheus-stack (Prometheus + Grafana) on the host, scraping workers
cd ../observability && ./setup-observability.sh

# 4. Import the dashboards from configs/prometheus-grafana/dashboards/ into Grafana
./setup-dashboards.sh
```

**Verify the federation:**

```bash
kubectl --kubeconfig "$HOME/.karmada/karmada-apiserver.config" get clusters
```

**Access Grafana** (port-forward, then open <http://localhost:8080>, login `admin` / `admin`):

```bash
kubectl --context=kind-karmada-host port-forward \
  svc/kube-prometheus-stack-grafana 8080:80 -n monitoring
```

**Tear everything down** when finished:

```bash
scripts/cluster-setup/teardown.sh   # removes Kind + KWOK clusters and the Grafana container
```

### Other workflows

The pipeline above is the main path. Other directories under `scripts/` are
self-contained — see each one's README:

- `scripts/kwok-testing/` — KWOK + ClusterLoader2 control-plane benchmarking
- `scripts/topology-testing/` — end-to-end Kind topology experiments with rollout-latency measurement; the simulation half of the story validated on phones in `pixels-v2/`
- `scripts/stress-testing/` — stress-ng workloads against a single Kind cluster
- `scripts/pixels-v1/` — physical Pixel phone experiments: v1 post-mortem (where the multi-cluster control plane wouldn't stay up)
- `scripts/pixels-v2/` — physical Pixel phone experiments: v2, the working federation that removes v1's root causes
- `scripts/experiments/` — assorted prototypes and scratch setups

## Contributors

CSE 145/237D Junkyard Cluster of Clusters: Felicia, Blake, Tahseen, Afraz
