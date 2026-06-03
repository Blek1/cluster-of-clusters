# observability

Scripts for installing Prometheus/Grafana and importing dashboards.

## Scripts

- **`setup-observability.sh`** — Helm-install kube-prometheus-stack on host and headless Prometheus on workers
- **`setup-dashboards.sh`** — Import JSON dashboards from `../../configs/prometheus-grafana/dashboards/` as Grafana ConfigMaps

## Access

After setup, port-forward Grafana:
```bash
kubectl --context=kind-karmada-host port-forward svc/kube-prometheus-stack-grafana 8080:80 -n monitoring
```

Navigate to `http://localhost:8080` — login `admin` / `admin`.
