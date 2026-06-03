# simple-docker

Standalone Docker Compose stack for basic Prometheus + Grafana monitoring with an Nginx proxy.

## Files

- `compose.yaml` — Docker Compose manifest
- `prometheus/prometheus.yml` — Prometheus scrape config
- `grafana/` — Grafana provisioning (datasources, dashboards)
- `nginx/nginx.conf` — Nginx reverse proxy config

## Usage

```bash
docker compose up
```
