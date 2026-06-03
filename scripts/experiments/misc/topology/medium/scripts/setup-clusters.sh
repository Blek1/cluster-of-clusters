#!/bin/bash
# medium — 2x 10 node KIND clusters for resource limit testing
set -e

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CLUSTERS=("medium-01" "medium-02")
WORKER_MEMORY_LIMIT="1g"
CONTROL_PLANE_MEMORY_LIMIT="4g"
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
    /apiServerAddress:/ {
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

apply_memory_limits() {
  local cluster=$1
  echo "Applying memory limits to ${cluster} nodes..."

  # control plane gets 4g
  docker ps --format '{{.Names}}' | grep "^${cluster}-control-plane" | while read node; do
    echo "  Control plane: ${node} → ${CONTROL_PLANE_MEMORY_LIMIT}"
    docker update --memory="${CONTROL_PLANE_MEMORY_LIMIT}" --memory-swap="${CONTROL_PLANE_MEMORY_LIMIT}" "${node}"
  done

  # workers get 1g
  docker ps --format '{{.Names}}' | grep "^${cluster}-worker" | while read node; do
    echo "  Worker: ${node} → ${WORKER_MEMORY_LIMIT}"
    docker update --memory="${WORKER_MEMORY_LIMIT}" --memory-swap="${WORKER_MEMORY_LIMIT}" "${node}"
  done
}

# -- main ------------------------------------------------------------------------

resolve_host_ip
echo "Using host API server address: ${HOST_IPADDRESS}"
echo "Target topology: 2 clusters / 10 nodes each / ${CONTROL_PLANE_MEMORY_LIMIT} control-plane / ${WORKER_MEMORY_LIMIT} workers"

echo ""
echo "==> Spinning up medium KIND clusters..."
for CLUSTER in "${CLUSTERS[@]}"; do
  create_cluster "${CLUSTER}" "${ROOT_DIR}/configs/kind/cluster-config.yaml"
  apply_memory_limits "${CLUSTER}"
done

echo ""
echo "==> Waiting for all nodes to be Ready..."
for CLUSTER in "${CLUSTERS[@]}"; do
  echo "  Waiting on kind-${CLUSTER}..."
  kubectl wait --context "kind-${CLUSTER}" \
    --for=condition=Ready nodes --all --timeout=120s
done

echo ""
echo "==> Finished cluster creation..."
for CLUSTER in "${CLUSTERS[@]}"; do
  echo "--- kind-${CLUSTER} ---"
  kubectl get nodes --context "kind-${CLUSTER}"
  echo ""
done

kubectl config get-contexts

echo ""
echo "==> Docker memory usage per node:"
for CLUSTER in "${CLUSTERS[@]}"; do
  echo "--- ${CLUSTER} ---"
  docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}" \
    | grep "${CLUSTER}"
  echo ""
done