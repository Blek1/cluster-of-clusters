#!/bin/bash
set -e

NUM_WORKER_CLUSTERS=$1
if [ -z "$NUM_WORKER_CLUSTERS" ]; then
  echo "Usage: ./run-experiments.sh <NUM_WORKER_CLUSTERS>"
  exit 1
fi

MANIFEST="workload-test.yaml"

if [ "$NUM_WORKER_CLUSTERS" -eq 1 ]; then
    echo "[1/3] Setting KUBECONFIG for Baseline (Worker-1)..."
    export KUBECONFIG="/home/luffy/clusters/worker-1.kubeconfig"

    echo "[2/3] Generating 500-Pod Workload..."
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
      - image: 10.0.0.1:30500/nginx:alpine
        name: nginx
        resources:
          requests:
            cpu: "5m"
            memory: "10Mi"
EOF
else
    echo "[1/3] Setting KUBECONFIG for Karmada Federation..."
    export KUBECONFIG="/home/luffy/clusters/karmada-apiserver.config"

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

kubectl apply -f "$MANIFEST"
kubectl rollout status deployment/workload-nginx --timeout=15m

END_TIME=$(date +%s)
LATENCY=$(( END_TIME - START_TIME ))

echo "Cleaning up deployment..."
kubectl delete -f "$MANIFEST"

echo " EXPERIMENT COMPLETE!"
echo " Total Pod Rollout Latency: $LATENCY seconds"
