# karmada-observ

Observability stack for Karmada: Prometheus scraping the Karmada control-plane
metrics, plus Grafana dashboards for API-server and member-cluster insights. Built
on the same 3-cluster Kind topology as `simple-karmada` (`host-01` + two members).

## Scripts

- `setup-clusters.sh` — Create the Kind clusters, init Karmada on `host-01`, and join the members.
- `setup-karm-observ.sh` — Apply Karmada RBAC + ServiceAccount secret, then deploy Prometheus pointed at the Karmada control plane with the Grafana dashboards.
- `setup-kube-observ.sh` — Install kube-prometheus-stack for Kubernetes cluster-level monitoring on `host-01`.
- `setup-redis.sh` — **Stub / not implemented** (placeholder for a future Redis workload).
- `cleanup.sh` — Delete the clusters and wipe Karmada state.

## Configs

- `configs/kind/` — Host + worker cluster configs.
- `configs/karmada/` — Karmada RBAC, ServiceAccount secret, and Prometheus deployment manifests.
- `configs/dashboards/` — Grafana dashboard JSONs (`api-server-insights`, `member-cluster-insights`).

## Run order

```bash
./scripts/setup-clusters.sh      # clusters + Karmada
./scripts/setup-kube-observ.sh   # Kubernetes-level monitoring
./scripts/setup-karm-observ.sh   # Karmada control-plane monitoring + dashboards
# ... experiment ...
./scripts/cleanup.sh
```

Grafana is reached at `http://localhost:3000` (admin/admin) while a port-forward is active.
