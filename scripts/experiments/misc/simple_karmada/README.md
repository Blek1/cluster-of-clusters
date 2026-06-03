# simple-karmada

Simplified Karmada-on-Kind setup: one host cluster running the Karmada control
plane plus two member clusters, with an optional Prometheus/Grafana stack.

Topology: 3 clusters / 6 kind node containers (`host-01`, `cluster-01`, `cluster-02`).

## Scripts

- `setup-clusters.sh` — Create the `host-01`, `cluster-01`, `cluster-02` Kind clusters, init Karmada on `host-01`, and join the two members.
- `setup-observability.sh` — Install kube-prometheus-stack (Prometheus + Grafana) on `host-01`.
- `setup-redis.sh` — **Stub / not implemented** (placeholder for a future Redis workload).
- `cleanup.sh` — Delete the clusters and wipe Karmada state.

## Configs

- `configs/kind/` — `host-config.yaml`, `worker01-config.yaml`, `worker02-config.yaml`.

## Run order

```bash
./scripts/setup-clusters.sh       # clusters + Karmada
./scripts/setup-observability.sh  # Prometheus + Grafana on host-01
# ... experiment ...
./scripts/cleanup.sh
```

Grafana is reached via port-forward (admin/admin) — see the script output for the exact command.
