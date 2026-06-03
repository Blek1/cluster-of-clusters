# karmada-orchestration

Scripts for Karmada federation and KWOK fake-node simulation.

Two separate workflows live here:

1. **`setup-karmada.sh`** — For the Kind + Karmada pipeline. Initializes the Karmada control plane on `kind-karmada-host` and joins `worker-1` and `worker-2`. Run this after `cluster-setup/setup.sh`.

2. **`setup-kwok.sh`** — Standalone KWOK cluster for node simulation testing. Spins up a KWOK cluster with Grafana + Prometheus dashboards, independent of the Kind pipeline.
   - `setup-kwok.sh 50` — create 50 fake nodes
   - `setup-kwok.sh --scale 100` — add nodes to existing cluster

