#!/usr/bin/env bash
set -e

ACTION=${1:-help}
CLUSTER=${2:-worker-1}
MODE=${3:-mixed}
REPLICAS=${4:-5}
DURATION=${5:-300}
NAMESPACE=cse145-stress
JOB=kind-stress
IMAGE=ghcr.io/colinianking/stress-ng:latest

if [[ "$CLUSTER" == kind-* ]]; then
  CONTEXT="$CLUSTER"
else
  CONTEXT="kind-$CLUSTER"
fi

if [[ "$ACTION" == "help" || "$ACTION" == "-h" || "$ACTION" == "--help" ]]; then
  echo "Usage:"
  echo "  ./simple-kind-stress.sh run worker-1 mixed 5 300"
  echo "  ./simple-kind-stress.sh status worker-1"
  echo "  ./simple-kind-stress.sh cleanup worker-1"
  echo "  ./simple-kind-stress.sh queries"
  echo ""
  echo "Modes: cpu, memory, mixed"
  exit 0
fi

if [[ "$ACTION" == "queries" ]]; then
  cat <<'EOF_QUERIES'
Running stress pods:
sum(kube_pod_status_phase{namespace="cse145-stress",phase="Running"})

CPU used by stress pods:
sum(rate(container_cpu_usage_seconds_total{namespace="cse145-stress",container!="",pod=~"kind-stress.*"}[1m]))

Memory used by stress pods:
sum(container_memory_working_set_bytes{namespace="cse145-stress",container!="",pod=~"kind-stress.*"})

Pods by phase:
sum(kube_pod_status_phase{namespace="cse145-stress"}) by (phase)

Node pressure:
kube_node_status_condition{condition=~"MemoryPressure|DiskPressure|PIDPressure",status="true"}
EOF_QUERIES
  exit 0
fi

kubectl config get-contexts "$CONTEXT" >/dev/null 2>&1 || {
  echo "Could not find kubectl context: $CONTEXT"
  echo "Run: kubectl config get-contexts"
  exit 1
}

if [[ "$ACTION" == "status" ]]; then
  kubectl --context "$CONTEXT" -n "$NAMESPACE" get job,pod -o wide
  exit 0
fi

if [[ "$ACTION" == "cleanup" ]]; then
  kubectl --context "$CONTEXT" delete namespace "$NAMESPACE" --ignore-not-found
  exit 0
fi

if [[ "$ACTION" != "run" ]]; then
  echo "Unknown action: $ACTION"
  echo "Use: run, status, cleanup, queries, or help"
  exit 1
fi

case "$MODE" in
  cpu)
    ARGS='["--cpu", "1", "--timeout", "'$DURATION's", "--metrics-brief"]'
    ;;
  memory)
    ARGS='["--vm", "1", "--vm-bytes", "256M", "--timeout", "'$DURATION's", "--metrics-brief"]'
    ;;
  mixed)
    ARGS='["--cpu", "1", "--vm", "1", "--vm-bytes", "128M", "--timeout", "'$DURATION's", "--metrics-brief"]'
    ;;
  *)
    echo "Unknown mode: $MODE"
    echo "Use: cpu, memory, or mixed"
    exit 1
    ;;
esac

kubectl --context "$CONTEXT" create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl --context "$CONTEXT" apply -f -
kubectl --context "$CONTEXT" -n "$NAMESPACE" delete job "$JOB" --ignore-not-found >/dev/null

cat <<EOF_YAML | kubectl --context "$CONTEXT" apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: $JOB
  namespace: $NAMESPACE
spec:
  completions: $REPLICAS
  parallelism: $REPLICAS
  backoffLimit: 0
  template:
    metadata:
      labels:
        app: $JOB
        stress-mode: $MODE
    spec:
      restartPolicy: Never
      containers:
        - name: stress
          image: $IMAGE
          imagePullPolicy: IfNotPresent
          args: $ARGS
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "1000m"
              memory: "512Mi"
EOF_YAML

echo "Started $MODE stress test on $CONTEXT"
echo "Replicas: $REPLICAS"
echo "Duration: ${DURATION}s"
echo "Check with: ./simple-kind-stress.sh status $CLUSTER"
