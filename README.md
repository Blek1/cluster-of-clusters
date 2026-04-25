# Cluster-of-Clusters

This repository contains the infrastructure-as-code, automation scripts, and configuration files for the UCSD CSE 145/237D Junkyard Project. 

The goal of this project is to experimentally determine the optimal architecture for scaling large networks of repurposed smartphones. We utilize Kubernetes in Docker (Kind) for rapid local topology simulation, Karmada for multi-cluster orchestration, and Admiralty for workload federation, before validating our findings on physical Pixel hardware.

## Prerequisites

### Standard Packages

Before cloning and running this project, ensure you have the following system-level tools installed and configured on your host machine. 

* **[Docker](https://docs.docker.com/get-docker/)**: The container runtime (Ensure the Docker daemon is actively running).
* **[kubectl](https://kubernetes.io/docs/tasks/tools/)**: The Kubernetes command-line tool.
* **[kind](https://kind.sigs.k8s.io/)**: For spinning up local Kubernetes clusters.
* **[Helm](https://helm.sh/docs/intro/install/)**: The Kubernetes package manager.
* **[uv](https://github.com/astral-sh/uv)**: A Python package and environment manager.

### Karmada CLI
Karmada is a specialized CNCF tool and is not hosted in standard package managers. You must manually download and install the binary to your system path.

Run the following commands in your terminal to install the latest AMD64 Linux release:
```bash
curl -s -L "[https://github.com/karmada-io/karmada/releases/latest/download/karmadactl-linux-amd64.tgz](https://github.com/karmada-io/karmada/releases/latest/download/karmadactl-linux-amd64.tgz)" | tar -xz
sudo mv karmadactl /usr/local/bin/
```

Verify installation by running `karmadactl version`

## Python Environment Setup

We use `uv` to manage our Python dependencies for automation and data visualization to prevent conflicts with system packages. 

Once you have cloned the repository, initialize your virtual environment and install the requirements:

```bash
# Sync virtual environment
uv sync
```

## Quick Start: Infrastructure Setup
This project uses a sequence of shell scripts to predictably tear down and rebuild the simulated multi-cluster environment. Open your terminal in the root of the repository and execute the scripts in the following order:

1. Create local clusters
```bash
./scripts/setup-clusters.sh
```

2. Initialize & Federate Karmada
```bash
./scripts/setup-karmada.sh
```

3. Setup Metric Observation
```bash
./scripts/setup-observability.sh
```

4. Grafana Dashboard
```bash
./scripts/setup-dashboards.sh
```

Once the scripts are up and running, you can access the Grafana UI locally:
```bash
kubectl --context=kind-worker-1 port-forward svc/kube-prometheus-stack-grafana 8080:80 -n monitoring
```

Navigate to `http://localhost:8080`, username `admin` and password `admin`

## Contributors
CSE 145/237D Junkyard Cluster of Clusters: Felicia, Blake, Tahseen, Andre, Afraz
