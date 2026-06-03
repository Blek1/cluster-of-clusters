#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
STATE_DIR="${ROOT_DIR}/.state"
KUBECONFIG_DIR="${STATE_DIR}/kubeconfig"
HOST_KUBECONFIG="${KUBECONFIG_DIR}/karmada.config"
MEMBERS_KUBECONFIG="${KUBECONFIG_DIR}/members.config"

GRAFANA_PORT="${GRAFANA_PORT:-3000}"
NAMESPACE="monitoring"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

need_cmd helm
need_cmd kubectl

echo "==> Adding Helm repos"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# ── Step 1: Install Prometheus only (no Grafana) on member1 and member2 ──────
install_prometheus_only() {
  local context=$1
  local kubeconfig=$2

  echo ""
  echo "==> Installing Prometheus (no Grafana) on cluster: ${context}"

  helm upgrade --install prometheus-stack \
    prometheus-community/kube-prometheus-stack \
    --kubeconfig "${kubeconfig}" \
    --kube-context "${context}" \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    --set grafana.enabled=false \
    --set prometheus.service.type=ClusterIP \
    --wait

  echo "==> Prometheus installed on ${context}"
}

install_prometheus_only "member1" "${MEMBERS_KUBECONFIG}"
install_prometheus_only "member2" "${MEMBERS_KUBECONFIG}"

# ── Step 2: Get Prometheus ClusterIPs from each member cluster ────────────────
echo ""
echo "==> Fetching Prometheus service IPs"

MEMBER1_PROMETHEUS_IP=$(kubectl --kubeconfig "${MEMBERS_KUBECONFIG}" --context member1 \
  get svc -n "${NAMESPACE}" prometheus-stack-kube-prom-prometheus \
  -o jsonpath='{.spec.clusterIP}')

MEMBER2_PROMETHEUS_IP=$(kubectl --kubeconfig "${MEMBERS_KUBECONFIG}" --context member2 \
  get svc -n "${NAMESPACE}" prometheus-stack-kube-prom-prometheus \
  -o jsonpath='{.spec.clusterIP}')

echo "member1 Prometheus IP: ${MEMBER1_PROMETHEUS_IP}"
echo "member2 Prometheus IP: ${MEMBER2_PROMETHEUS_IP}"

# ── Step 3: Install Grafana on host with both members as datasources ──────────
echo ""
echo "==> Installing central Grafana on karmada-host"

helm upgrade --install grafana grafana/grafana \
  --kubeconfig "${HOST_KUBECONFIG}" \
  --kube-context karmada-host \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --set adminPassword=admin \
  --set "datasources.datasources\.yaml.apiVersion=1" \
  --set "datasources.datasources\.yaml.datasources[0].name=member1" \
  --set "datasources.datasources\.yaml.datasources[0].type=prometheus" \
  --set "datasources.datasources\.yaml.datasources[0].url=http://${MEMBER1_PROMETHEUS_IP}:9090" \
  --set "datasources.datasources\.yaml.datasources[0].access=proxy" \
  --set "datasources.datasources\.yaml.datasources[0].isDefault=true" \
  --set "datasources.datasources\.yaml.datasources[1].name=member2" \
  --set "datasources.datasources\.yaml.datasources[1].type=prometheus" \
  --set "datasources.datasources\.yaml.datasources[1].url=http://${MEMBER2_PROMETHEUS_IP}:9090" \
  --set "datasources.datasources\.yaml.datasources[1].access=proxy" \
  --wait

echo ""
echo "==> Done! Central Grafana is on karmada-host watching both member clusters."
echo ""
echo "To open Grafana, run:"
echo "  kubectl --kubeconfig ${HOST_KUBECONFIG} --context karmada-host \\"
echo "    port-forward -n ${NAMESPACE} svc/grafana ${GRAFANA_PORT}:80"
echo ""
echo "Then open: http://localhost:${GRAFANA_PORT}"
echo "Login: admin / admin"
echo ""
echo "Both member1 and member2 will appear as Prometheus datasources."
