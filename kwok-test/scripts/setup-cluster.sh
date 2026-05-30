#!/bin/bash
# basic cluster of clusters
set -e

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
KARMADA_DIR="$HOME/.karmada" 
KARMADA_KUBECONFIG="$KARMADA_DIR/karmada-apiserver.config"
HOST_KUBECONFIG="$HOME/.kube/config"
HOST_IPADDRESS="${HOST_IPADDRESS:-}"
NODE_MEMORY_LIMIT="1.5g"
TMP_CONFIG_DIR=$(mktemp -d)


trap 'rm -rf "${TMP_CONFIG_DIR}"' EXIT
sleeper() { 
  local seconds=${1:-30}  # default 30 if not passed
  for i in $(seq $seconds -1 1); do
    printf "\r⏳ Waiting... %2d seconds remaining" $i
    sleep 1
  done
  printf "\r✅ Done waiting!\n"
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
  # injects HOST_IPADDR into .yaml 
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

create_member_cluster() {
  local index=$1  # e.g. 1, 2, 3
  local name="member-0${index}"

  # Each member gets unique subnets by incrementing third octet
  # member-01: 10.220.1.0/16 pods, 10.120.1.0/16 services
  # member-02: 10.220.2.0/16 pods, 10.120.2.0/16 services

  local pod_subnet="10.220.${index}.0/16"
  local svc_subnet="10.120.${index}.0/16"

  # Write the config to a temp file
  local config="${TMP_CONFIG_DIR}/${name}.yaml"
  cat > "${config}" <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  podSubnet: "${pod_subnet}"
  serviceSubnet: "${svc_subnet}"
nodes:
  - role: control-plane
EOF

  # Inject host IP 
  render_kind_config "${config}" "${TMP_CONFIG_DIR}/${name}-rendered.yaml"

  echo "Creating member cluster: ${name} (pods: ${pod_subnet}, svcs: ${svc_subnet})"
  if kind get clusters 2>/dev/null | grep -qx "${name}"; then
    echo "Deleting existing cluster: ${name}"
    kind delete cluster --name "${name}"
  fi

  kind create cluster \
    --name "${name}" \
    --config "${TMP_CONFIG_DIR}/${name}-rendered.yaml"

  apply_memory_limit "${name}" "${NODE_MEMORY_LIMIT}"
}


echo "Cleaning up prior..."
${ROOT_DIR}/scripts/cleanup.sh
resolve_host_ip
echo "Using host API server address: ${HOST_IPADDRESS}"

echo "Spinning up HOST Karamda Cluster..."
create_cluster host-01 ${ROOT_DIR}/configs/kind/host-config.yaml

apply_memory_limit host-01 ${NODE_MEMORY_LIMIT}

kubectl get nodes
kubectl config get-contexts

echo "Waiting for Karmada API to be ready..."
sleeper 15

echo "Initializing Karmada on host-01..."
kubectl config use-context kind-host-01
karmadactl init \
    --karmada-data="$KARMADA_DIR" \
    --karmada-pki="$KARMADA_DIR/pki" \
    --karmada-apiserver-advertise-address=${HOST_IPADDRESS}

echo "==> Verifying joined clusters..."
sleeper 15
kubectl --kubeconfig=$HOME/.karmada/karmada-apiserver.config get clusters


echo "Spinning up MEMBER KIND Clusters..."
MEMBER_COUNT="${MEMBER_COUNT:-3}"
for i in $(seq 1 "${MEMBER_COUNT}"); do
  create_member_cluster "${i}"
done

echo "Joining members to Karmada..."
for i in $(seq 1 "${MEMBER_COUNT}"); do
  name="member-0${i}"
  echo "Joining ${name}..."
  karmadactl join "${name}" \
    --kubeconfig="${KARMADA_KUBECONFIG}" \
    --cluster-kubeconfig="${HOST_KUBECONFIG}" \
    --cluster-context="kind-${name}"
done

echo "Spinning up KWOK in each member..."
for i in $(seq 1 "${MEMBER_COUNT}"); do
  name="member-0${i}"
  kubectl config use-context "kind-${name}"

  # static — just apply it
  kubectl apply -f "${ROOT_DIR}/configs/kind/kwok-controller.yaml"

  # templated — loop and swap NODE_INDEX
  for n in $(seq 0 99); do
    sed "s/NODE_INDEX/${n}/g" \
      "${ROOT_DIR}/configs/kind/kwok-node-template.yaml" \
      | kubectl apply -f -
  done
done