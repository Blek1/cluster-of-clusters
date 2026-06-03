#!/bin/bash
# large-01 20 node KIND cluster for resource limit testing
set -e

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CLUSTER_NAME="large-01"
NODE_MEMORY_LIMIT="1g"
TMP_CONFIG_DIR=$(mktemp -d)
HOST_IPADDRESS="${HOST_IPADDRESS:-}"

trap 'rm -rf "${TMP_CONFIG_DIR}"' EXIT

sleeper() {
  local seconds=${1:-30}
  for i in $(seq $seconds -1 1); do
    printf "\r⏳ Waiting... %2d seconds remaining" $i
    sleep 1
  done
  printf "\r✅ Done waiting!                    \n"
}

resolve_host_ip() {
  if [[ -n "${HOST_IPADDRESS}" ]]; then
    return 0
  fi

  HOST_IPADDRESS=$(
    python3 - <<'PY'
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
try:
    s.connect(("8.8.8.8", 80))
    print(s.getsockname()[0])
except Exception:
    pass
finally:
    s.close()
PY
  )

  if [[ -z "${HOST_IPADDRESS}" ]]; then
    echo "Unable to determine HOST_IPADDRESS automatically. Set HOST_IPADDRESS explicitly." >&2
    exit 1
  fi
}

render_kind_config() {
  local src=$1
  local dst=$2
  awk -v host_ip="${HOST_IPADDRESS}" '
    /^networking:/ {
      print $0
      print "  apiServerAddress: \"" host_ip "\""
      next
    }
    { print $0 }
  ' "${src}" >"${dst}"
}

create_cluster() {
  local name=$1
  local config=$2

  if kind get clusters 2>/dev/null | grep -qx "${name}"; then
    echo "Deleting existing cluster before rebuild: ${name}"
    kind delete cluster --name "${name}"
  fi

  render_kind_config "${config}" "${TMP_CONFIG_DIR}/${name}.yaml"

  echo "Creating kind cluster: ${name}"
  kind create cluster \
    --name "${name}" \
    --config "${TMP_CONFIG_DIR}/${name}.yaml"
}

apply_memory_limit() {
  local cluster=$1
  local limit=$2
  echo "Applying memory limit ${limit} to ${cluster} nodes..."
  docker ps --format '{{.Names}}' | grep "^${cluster}-" | while read node; do
    docker update --memory="${limit}" --memory-swap="${limit}" "${node}"
  done
}

# ── main ───────────────────────────────────────────────────────────────────────

echo "Cleaning up prior..."
${ROOT_DIR}/scripts/cleanup.sh
resolve_host_ip
echo "Using host API server address: ${HOST_IPADDRESS}"
echo "Target topology: 1 cluster / 20 kind node containers / ${NODE_MEMORY_LIMIT} mem per node"


echo "Spinning up KIND cluster: ${CLUSTER_NAME}..."
create_cluster ${CLUSTER_NAME} ${ROOT_DIR}/configs/kind/cluster-config.yaml

apply_memory_limit ${CLUSTER_NAME} ${NODE_MEMORY_LIMIT}

echo "==> Waiting for all nodes to be Ready..."
kubectl wait --context "kind-${CLUSTER_NAME}" \
  --for=condition=Ready nodes --all --timeout=120s

echo "==> Finished cluster creation..."
kubectl get nodes --context kind-${CLUSTER_NAME}
kubectl config get-contexts


echo "==> Docker memory usage per node:"
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}" \
  | grep "${CLUSTER_NAME}"


# ── observability ──────────────────────────────────────────────────────────────

echo "Installing Prometheus + Grafana on ${CLUSTER_NAME}..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --kube-context "kind-${CLUSTER_NAME}" \
  --namespace monitoring \
  --create-namespace \
  --set grafana.adminPassword=admin \
  --set prometheus.service.type=NodePort \
  --timeout 10m \
  --wait

echo ""
echo "==> To open Grafana:"
echo "kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80 --context kind-${CLUSTER_NAME}"
echo "Then visit http://localhost:3000 — login: admin / admin"