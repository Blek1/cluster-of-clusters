#!/bin/bash
set -e

NUM_WORKER_CLUSTERS=$1

if [ -z "$NUM_WORKER_CLUSTERS" ]; then
  echo "Usage: ./run-experiments.sh <NUM_WORKER_CLUSTERS>"
  echo "Examples:"
  echo "  ./run-experiments.sh 1  (Runs Baseline)"
  echo "  ./run-experiments.sh 2  (Runs 500 pods across 2 member clusters)"
  exit 1
fi

MANIFEST="workload-test.yaml"

if [ "$NUM_WORKER_CLUSTERS" -eq 1 ]; then
    echo "[1/3] Syncing Monolith config via SSH..."
    mkdir -p ~/.kube
    scp strawhat:/home/luffy/cluster-d.kubeconfig ~/.kube/cluster-d.kubeconfig > /dev/null 2>&1

    export KUBECONFIG=~/.kube/cluster-d.kubeconfig
    sed -i 's|server: .*|server: https://127.0.0.1:6443|' ~/.kube/cluster-d.kubeconfig || true

    echo "[2/3] Generating 500-Pod Workload (No Propagation Policy)..."
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
      tolerations:
        - key: "reservation"
          operator: "Equal"
          value: "cluster-of-clusters-until-2026-06-12"
          effect: "NoSchedule"
      containers:
      - image: 10.0.0.1:30500/nginx:alpine
        name: nginx
        resources:
          requests:
            cpu: "5m"
            memory: "10Mi"
EOF

else
    echo "[1/3] Syncing Karmada configs via SSH for $NUM_WORKER_CLUSTERS Member Clusters..."
    mkdir -p ~/.kube
    scp strawhat:/home/luffy/clusters/karmada-apiserver.config ~/.kube/karmada-apiserver.config #> /dev/null 2>&1

    export KUBECONFIG=~/.kube/karmada-apiserver.config
    sed -i 's|server: https://10.0.0.16:32443|server: https://127.0.0.1:32443|' ~/.kube/karmada-apiserver.config || true

    echo "[2/3] Generating 500-Pod Workload with Propagation Policy..."
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
      tolerations:
        - key: "reservation"
          operator: "Equal"
          value: "cluster-of-clusters-until-2026-06-12"
          effect: "NoSchedule"
      containers:
      - image: 10.0.0.1:30500/nginx:alpine
        name: nginx
        resources:
          requests:
            cpu: "5m"
            memory: "10Mi"
---
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
    for i in $(seq 1 $NUM_WORKER_CLUSTERS); do echo "        - worker-$i" >> "$MANIFEST"; done
    cat <<EOF >> "$MANIFEST"
    replicaScheduling:
      replicaDivisionPreference: Weighted
      replicaSchedulingType: Divided
EOF
fi

echo ""
echo "=================================================================="
echo " WORKLOAD READY FOR DEPLOYMENT "
echo "=================================================================="
read -p "Press [Enter] to inject the workload and start the timer..."

echo ""
echo "[3/3] Tracking Rollout Latency..."
START_TIME=$(date +%s)

# Apply and track exactly when the timer starts
kubectl apply -f "$MANIFEST"
kubectl rollout status deployment/workload-nginx --timeout=15m

END_TIME=$(date +%s)
LATENCY=$(( END_TIME - START_TIME ))

# Cleanup the test workload automatically
echo "Cleaning up deployment..."
kubectl delete -f "$MANIFEST" > /dev/null 2>&1

echo " EXPERIMENT COMPLETE!"
if [ "$NUM_WORKER_CLUSTERS" -eq 1 ]; then
    echo " Total Pod Rollout Latency for Baseline (1x19): $LATENCY seconds"
else
    echo " Total Pod Rollout Latency for $NUM_WORKER_CLUSTERS member clusters: $LATENCY seconds"
fi
