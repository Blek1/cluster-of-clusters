# karmada-observ

Observability stack for Karmada: Prometheus scraping Karmada control plane metrics, Grafana dashboards for API server and member cluster insights.

## Scripts

- `setup-clusters.sh` — Bootstrap Kind clusters
- `setup-karm-observ.sh` — Deploy Karmada-specific Prometheus + Grafana
- `setup-kube-observ.sh` — Deploy Kubernetes cluster-level monitoring
- `setup-redis.sh` — Redis deployment helper
- `cleanup.sh` — Teardown

## Configs

- `configs/kind/` — Host + worker cluster configs
- `configs/karmada/` — Karmada RBAC, deployment, secret manifests
- `configs/dashboards/` — Grafana dashboard JSONs
