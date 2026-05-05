#!/bin/bash
set -e

NODES=${1:-20} # take in node count or use default (20 nodes)

SCALE=false
if [ "${1}" == "--scale" ]; then
    SCALE=true
    NODES=${2:-20}
fi

NODE_TEMPLATE="$(dirname "$0")/../manifests/kwok/node-template.yaml"
DASHBOARD_SRC_DIR="$(dirname "$0")/../configs/prometheus-grafana/dashboards"

for cmd in kwokctl kubectl docker; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: '$cmd' is not installed. Check the README prerequisites."
        exit 1
    fi
done

if [ "$SCALE" = false ]; then
    if kwokctl get clusters 2>/dev/null | grep -q "^kwok$"; then
        echo "Error: kwok cluster is already running."
        echo "To add more nodes:    ./scripts/setup-kwok.sh --scale <# of nodes>"
        echo "To start fresh:       ./scripts/teardown.sh && ./scripts/setup-kwok.sh"
        exit 1
    fi

    echo "Spinning up KWOK cluster..."
    kwokctl create cluster --name kwok --prometheus-port 9090
    kwokctl get kubeconfig --name kwok >> ~/.kube/config

    echo "Starting Grafana..."


    DOCKER_GATEWAY=$(docker network inspect bridge --format='{{range .IPAM.Config}}{{.Gateway}}{{end}}')
    
    
    GRAFANA_PROVISIONING=$(mktemp -d)
    mkdir -p $GRAFANA_PROVISIONING/datasources
    mkdir -p $GRAFANA_PROVISIONING/dashboards
    mkdir -p $GRAFANA_PROVISIONING/dashboards/json

    printf 'apiVersion: 1\ndatasources:\n  - name: Prometheus\n    type: prometheus\n    access: proxy\n    url: http://%s:9090\n    isDefault: true\n' "$DOCKER_GATEWAY" > $GRAFANA_PROVISIONING/datasources/prometheus.yaml

    cat > $GRAFANA_PROVISIONING/dashboards/default.yaml << 'DASHBOARDCFG'
apiVersion: 1
providers:
  - name: kwok
    type: file
    options:
      path: /var/lib/grafana/dashboards
DASHBOARDCFG

    for src in \
        "$DASHBOARD_SRC_DIR/k8s-control-plane.json" \
        "$DASHBOARD_SRC_DIR/kubernetes-apiserver.json"; do
        dest="$GRAFANA_PROVISIONING/dashboards/json/$(basename $src)"
        cp "$src" "$dest"
        sed -i 's/"\${DS_PROMETHEUS}"/"Prometheus"/g; s/"\$datasource"/"Prometheus"/g' "$dest"
    done

    docker run -d -p 3000:3000 --name grafana \
        -v $GRAFANA_PROVISIONING/datasources:/etc/grafana/provisioning/datasources \
        -v $GRAFANA_PROVISIONING/dashboards:/etc/grafana/provisioning/dashboards \
        -v $GRAFANA_PROVISIONING/dashboards/json:/var/lib/grafana/dashboards \
        grafana/grafana
fi

kubectl config use-context kwok-kwok

EXISTING=$(kubectl get nodes -l type=kwok --no-headers 2>/dev/null | wc -l | tr -d ' ')
echo "Creating nodes $((EXISTING + 1)) to $NODES..."

if [ "$NODES" -lt "$EXISTING" ]; then
    echo "Scaling down from $EXISTING to $NODES nodes..."
    for i in $(seq $((NODES + 1)) $EXISTING); do
        NODE_ID=$(printf "%04d" $i)
        kubectl delete node "kwok-node-$NODE_ID" --ignore-not-found
    done
elif [ "$NODES" -gt "$EXISTING" ]; then
    echo "Creating nodes $((EXISTING + 1)) to $NODES..."
    for i in $(seq $((EXISTING + 1)) $NODES); do
        NODE_ID=$(printf "%04d" $i)
        sed "s/\${NODE_ID}/$NODE_ID/g" $NODE_TEMPLATE | kubectl apply -f -
    done
else
    echo "Already at $NODES nodes. Nothing to do."
fi

kubectl config get-contexts

echo "Done. Total nodes: $(kubectl get nodes -l type=kwok --no-headers | wc -l | tr -d ' ')"
echo "Prometheus: http://localhost:9090"
echo "Grafana:    http://localhost:3000  (admin/admin)"