# Simple Kind Stress Test Guide

## Purpose

`simple-kind-stress.sh` is a small script for testing how a Kind Kubernetes cluster behaves under CPU or memory load.

It deploys stress-test Pods into a cluster, then we can watch the results in Grafana/Prometheus.

## Tools Used

- **Kind**: local Kubernetes clusters
- **kubectl**: sends commands to the cluster
- **stress-ng**: creates CPU and memory load inside Pods
- **Grafana/Prometheus**: shows cluster metrics

## Basic Usage

Run the script from the project folder:

```bash
./scripts/simple-kind-stress.sh run worker-1 mixed 5 300
```

This means:

- `worker-1`: cluster to test
- `mixed`: CPU + memory stress
- `5`: number of Pods
- `300`: run for 300 seconds

## Commands

### Run a stress test

```bash
./scripts/simple-kind-stress.sh run worker-1 mixed 5 300
```

Other modes:

```bash
./scripts/simple-kind-stress.sh run worker-1 cpu 5 300
./scripts/simple-kind-stress.sh run worker-1 memory 5 300
```

### Check status

```bash
./scripts/simple-kind-stress.sh status worker-1
```

Shows the stress Job and Pods in the `cse145-stress` namespace.

### Clean up

```bash
./scripts/simple-kind-stress.sh cleanup worker-1
```

Deletes the `cse145-stress` namespace and removes the test workload.

### Get Grafana queries

```bash
./scripts/simple-kind-stress.sh queries
```

Prints useful PromQL queries for checking CPU, memory, running Pods, and node pressure.

## Suggested Workflow

1. Open Grafana.
2. Take note of the cluster’s normal CPU and memory usage.
3. Run a stress test.
4. Watch the `cse145-stress` namespace in Grafana.
5. Record CPU usage, memory usage, Pod failures, or node pressure.
6. Run cleanup when finished.

## Example Experiment

```bash
./scripts/simple-kind-stress.sh run worker-1 mixed 10 300
./scripts/simple-kind-stress.sh status worker-1
./scripts/simple-kind-stress.sh cleanup worker-1
```

This tests how `worker-1` reacts to 10 mixed CPU/memory stress Pods for 5 minutes.

## Notes

This script is useful because it gives us a repeatable way to overload a cluster and compare behavior across different topologies, like one large cluster versus multiple smaller clusters.
