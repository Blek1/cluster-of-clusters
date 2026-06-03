#!/bin/bash
set -e

NUM_CLUSTERS=$1
TOTAL_NODES=$2

if [ -z "$NUM_CLUSTERS" ] || [ -z "$TOTAL_NODES" ]; then
  echo "Usage: ./test-topology.sh <NUM_CLUSTERS> <TOTAL_WORKER_NODES>"
  echo "Example: ./test-topology.sh 3 12"
  exit 1
fi

NODES_PER_CLUSTER=$(( TOTAL_NODES / NUM_CLUSTERS ))

echo "Initiating Topology Run"
echo "Topology: $NUM_CLUSTERS Cluster(s) with $TOTAL_NODES Total Nodes ($NODES_PER_CLUSTER per cluster)"

echo "[0/8] Checking required dependencies..."
DEPENDENCIES=("docker" "kind" "kubectl" "helm" "karmadactl")

for cmd in "${DEPENDENCIES[@]}"; do
    if ! command -v "$cmd" > /dev/null 2>&1; then
        echo "FATAL ERROR: Required dependency '$cmd' is not installed or not in PATH."
        exit 1
    fi
done

echo "[1/8] Cleaning up previous infrastructure..."
kind delete clusters --all > /dev/null 2>&1 || true
docker network prune -f > /dev/null 2>&1
rm -rf "$HOME/.karmada" ../../configs/kind/*.yaml ../../configs/manifests/tests/*.yaml ../../configs/karmada/*.yaml ../../configs/prometheus-grafana/*.yaml

mkdir -p ../../configs/kind
mkdir -p ../../configs/karmada
mkdir -p ../../configs/prometheus-grafana
mkdir -p ../../manifests/tests

echo "[2/8] Provisioning Kubernetes Architecture..."
if [ "$NUM_CLUSTERS" -eq 1 ]; then
    cat <<EOF > "../../configs/kind/single-config.yaml"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
EOF
    for i in $(seq 1 $TOTAL_NODES); do echo "  - role: worker" >> "../../configs/kind/single-config.yaml"; done
    kind create cluster --name single-cluster --config ../../configs/kind/single-config.yaml
    HOST_CONTEXT="kind-single-cluster"
else
    kind create cluster --name karmada-host
    HOST_CONTEXT="kind-karmada-host"

    for i in $(seq 1 $NUM_CLUSTERS); do
        cat <<EOF > "../../configs/kind/worker-${i}-config.yaml"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  podSubnet: 10.21${i}.0.0/16
  serviceSubnet: 10.11${i}.0.0/16
nodes:
  - role: control-plane
EOF
        for w in $(seq 1 $NODES_PER_CLUSTER); do echo "  - role: worker" >> "../../configs/kind/worker-${i}-config.yaml"; done
        kind create cluster --name worker-$i --config "../../configs/kind/worker-${i}-config.yaml"
    done
fi

if [ "$NUM_CLUSTERS" -gt 1 ]; then
    echo "[3/8] Initializing Karmada Federation..."
    KARMADA_DIR="$HOME/.karmada"
    kubectl config use-context $HOST_CONTEXT
    karmadactl init --karmada-data="$KARMADA_DIR" --karmada-pki="$KARMADA_DIR/pki" #> /dev/null 2>&1
    sleep 30 # buffer for api
    for i in $(seq 1 $NUM_CLUSTERS); do
        # extract internal docker IP of the worker cluster
        WORKER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' worker-${i}-control-plane)

        # isolate kubeconfig for this worker
        kubectl config view --context=kind-worker-$i --minify --flatten > "/tmp/worker-${i}-raw.kubeconfig"

        # translate laptop's localhost IP into the internal Docker network IP
        sed -e "s|127.0.0.1:[0-9]*|$WORKER_IP:6443|g" -e "s|0.0.0.0:[0-9]*|$WORKER_IP:6443|g" "/tmp/worker-${i}-raw.kubeconfig" > "/tmp/worker-${i}.kubeconfig"

        # join karmada using the translated internal config
        karmadactl join worker-$i --kubeconfig="$KARMADA_DIR/karmada-apiserver.config" --cluster-kubeconfig="/tmp/worker-${i}.kubeconfig" --cluster-context=kind-worker-$i #> /dev/null 2>&1
    done
else
    echo "[3/8] Single cluster... Bypassing Karmada Federation..."
fi

echo "[4/8] Deploying Central Observability Stack..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts > /dev/null 2>&1
helm repo update > /dev/null 2>&1

kubectl config use-context $HOST_CONTEXT
kubectl create namespace monitoring || true

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --set grafana.adminPassword=admin --set grafana.image.tag=10.4.1 \
  --set prometheus.service.type=NodePort --timeout 10m --wait > /dev/null 2>&1

if [ "$NUM_CLUSTERS" -gt 1 ]; then
    for i in $(seq 1 $NUM_CLUSTERS); do
        kubectl config use-context kind-worker-$i
        kubectl create namespace monitoring || true
        helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
          --namespace monitoring --set grafana.enabled=false \
          --set prometheus.service.type=NodePort --timeout 10m --wait > /dev/null 2>&1
    done
fi

if [ "$NUM_CLUSTERS" -gt 1 ]; then
    echo "[5/8] Deploying Teammate's Secure Karmada Prometheus..."

    # write rbac and secret config
    cat <<EOF > "../../configs/karmada/rbac.yaml"
apiVersion: v1
kind: Namespace
metadata:
  name: karmada-monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources: ["nodes", "nodes/proxy", "services", "endpoints", "pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["extensions"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
- apiGroups: ["cluster.karmada.io"]
  resources: ["*"]
  verbs: ["*"]
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
  namespace: karmada-monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: prometheus
  namespace: karmada-monitoring
---
apiVersion: v1
kind: Secret
type: kubernetes.io/service-account-token
metadata:
  name: prometheus
  namespace: karmada-monitoring
  annotations:
    kubernetes.io/service-account.name: "prometheus"
EOF

    # apply rbac to both host cluster and internal karmada cluster
    kubectl apply --context $HOST_CONTEXT -f "../../configs/karmada/rbac.yaml" > /dev/null 2>&1
    kubectl apply --kubeconfig="$KARMADA_DIR/karmada-apiserver.config" -f "../../configs/karmada/rbac.yaml" > /dev/null 2>&1

    echo "Waiting for Karmada API to generate token..."
    sleep 5
    KARMADA_TOKEN=$(kubectl get secret prometheus --kubeconfig="$KARMADA_DIR/karmada-apiserver.config" -n karmada-monitoring -o jsonpath='{.data.token}' | base64 -d)

    # write deploy yaml
    cat <<EOF > "../../configs/karmada/deploy.yaml"
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: karmada-monitoring
data:
  prometheus.yml: |-
    global:
      scrape_interval: 15s
    scrape_configs:
    - job_name: 'karmada-scheduler'
      kubernetes_sd_configs: [{role: pod}]
      scheme: http
      tls_config: {insecure_skip_verify: true}
      relabel_configs:
      - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_pod_label_app]
        action: keep
        regex: karmada-system;karmada-scheduler
      - target_label: __address__
        source_labels: [__meta_kubernetes_pod_ip]
        regex: '(.*)'
        replacement: '\${1}:8080'
        action: replace
    - job_name: 'karmada-controller-manager'
      kubernetes_sd_configs: [{role: pod}]
      scheme: http
      tls_config: {insecure_skip_verify: true}
      relabel_configs:
      - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_pod_label_app]
        action: keep
        regex: karmada-system;karmada-controller-manager
      - target_label: __address__
        source_labels: [__meta_kubernetes_pod_ip]
        regex: '(.*)'
        replacement: '\${1}:8080'
        action: replace
    - job_name: 'karmada-apiserver'
      kubernetes_sd_configs: [{role: endpoints}]
      scheme: https
      tls_config: {insecure_skip_verify: true}
      bearer_token: KARMADA_TOKEN_PLACEHOLDER
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_label_app]
        action: keep
        regex: karmada-apiserver
      - target_label: __address__
        replacement: karmada-apiserver.karmada-system.svc:5443
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: karmada-monitoring
spec:
  ports:
  - name: prometheus
    protocol: TCP
    port: 9090
    targetPort: 9090
  selector:
    app: prometheus
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: karmada-monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      serviceAccountName: prometheus
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        args:
        - "--config.file=/etc/prometheus/prometheus.yml"
        ports:
        - containerPort: 9090
        volumeMounts:
        - mountPath: "/etc/prometheus"
          name: prometheus-config
      volumes:
      - name: prometheus-config
        configMap:
          name: prometheus-config
EOF

    # inject token and deploy to the host
    sed "s/KARMADA_TOKEN_PLACEHOLDER/${KARMADA_TOKEN}/g" "../../configs/karmada/deploy.yaml" | kubectl apply --context $HOST_CONTEXT -f - > /dev/null 2>&1

    echo "[6/8] Auto-Wiring All Data Sources & Dashboards..."
    DS_FILE="../../configs/karmada/datasources.yaml"
    cat <<EOF > "$DS_FILE"
apiVersion: v1
kind: ConfigMap
metadata:
  name: worker-datasources
  namespace: monitoring
  labels:
    grafana_datasource: "1"
data:
  datasources.yaml: |-
    apiVersion: 1
    datasources:
      - name: karmada-prometheus
        type: prometheus
        url: http://prometheus.karmada-monitoring.svc:9090
        access: proxy
        isDefault: false
EOF

    for i in $(seq 1 $NUM_CLUSTERS); do
        WORKER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' worker-${i}-control-plane)
        NODE_PORT=$(kubectl --context=kind-worker-$i get svc kube-prometheus-stack-prometheus -n monitoring -o jsonpath='{.spec.ports[0].nodePort}')
        cat <<EOF >> "$DS_FILE"
      - name: worker-$i
        type: prometheus
        url: http://${WORKER_IP}:${NODE_PORT}
        access: proxy
        isDefault: false
EOF
    done

    kubectl --context=$HOST_CONTEXT apply -f "$DS_FILE" > /dev/null 2>&1
    
    # echo "Downloading Karmada dashboards..."
    # curl -sL https://raw.githubusercontent.com/karmada-io/karmada/master/artifacts/grafana/karmada-apiserver-dashboard.json -o ../../configs/prometheus-grafana/apiserver.json
    # curl -sL https://raw.githubusercontent.com/karmada-io/karmada/master/artifacts/grafana/karmada-controller-manager-dashboard.json -o ../../configs/prometheus-grafana/controller.json
    # curl -sL https://raw.githubusercontent.com/karmada-io/karmada/master/artifacts/grafana/karmada-scheduler-dashboard.json -o ../../configs/prometheus-grafana/scheduler.json
    # these don't really seem to work?

    # inject local dashboards into grafana
    kubectl --context=$HOST_CONTEXT create configmap karmada-dashboards \
      --namespace monitoring \
      --from-file=../../configs/prometheus-grafana/ \
      --dry-run=client -o yaml | \
      kubectl --context=$HOST_CONTEXT label --local -f - \
      grafana_dashboard=1 -o yaml | \
      kubectl --context=$HOST_CONTEXT apply -f - > /dev/null 2>&1

    echo "Syncing Grafana filesystem..."
    kubectl --context=$HOST_CONTEXT rollout restart deployment kube-prometheus-stack-grafana -n monitoring > /dev/null 2>&1
    kubectl --context=$HOST_CONTEXT rollout status deployment kube-prometheus-stack-grafana -n monitoring --timeout=60s > /dev/null 2>&1

fi

echo "Infrastructure Ready... Observability Deployed..."
echo "Before unleashing the workload, open a second terminal and run:"
echo "kubectl --context=$HOST_CONTEXT port-forward svc/kube-prometheus-stack-grafana 8080:80 -n monitoring"
echo ""
echo "Note: Inside Grafana, look in the 'General' folder for Karmada dashboards."
read -p "Log into Grafana (admin/admin), prepare your dashboards, and press [Enter] to launch the pods..."

echo "[7/8] Generating and Applying 500-Pod Workload..."
MANIFEST="../../manifests/tests/workload.yaml"

cat <<EOF > "$MANIFEST"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: workload-nginx
spec:
  replicas: 500
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - image: nginx:alpine
        name: nginx
        resources:
          requests:
            cpu: "5m"
            memory: "10Mi"
EOF

if [ "$NUM_CLUSTERS" -gt 1 ]; then
    echo "---" >> "$MANIFEST"
    cat <<EOF >> "$MANIFEST"
apiVersion: policy.karmada.io/v1alpha1
kind: PropagationPolicy
metadata:
  name: workload-propagation
spec:
  resourceSelectors:
    - apiVersion: apps/v1
      kind: Deployment
      name: workload-nginx
  placement:
    clusterAffinity:
      clusterNames:
EOF
    for i in $(seq 1 $NUM_CLUSTERS); do echo "        - worker-$i" >> "$MANIFEST"; done
    cat <<EOF >> "$MANIFEST"
    replicaScheduling:
      replicaDivisionPreference: Weighted
      replicaSchedulingType: Divided
EOF
    kubectl --kubeconfig="$KARMADA_DIR/karmada-apiserver.config" apply -f "$MANIFEST"
else
    kubectl --context=$HOST_CONTEXT apply -f "$MANIFEST"
fi

echo "[8/8] Tracking Rollout Latency..."
START_TIME=$(date +%s)

if [ "$NUM_CLUSTERS" -eq 1 ]; then
    kubectl --context=$HOST_CONTEXT rollout status deployment/workload-nginx --timeout=15m
else
    # wait for all worker clusters to finish
    for i in $(seq 1 $NUM_CLUSTERS); do
        (
            # wait for karmada to propagate deployment to worker
            while ! kubectl --context=kind-worker-$i get deployment workload-nginx > /dev/null 2>&1; do
                sleep 1
            done

            # once it exists, track the actual pod rollout
            kubectl --context=kind-worker-$i rollout status deployment/workload-nginx --timeout=15m
        ) &
    done
    wait # hold until all background rollout watches finish
fi

END_TIME=$(date +%s)
LATENCY=$(( END_TIME - START_TIME ))

echo " EXPERIMENT COMPLETE!"
echo " Total Pod Rollout Latency: $LATENCY seconds"
