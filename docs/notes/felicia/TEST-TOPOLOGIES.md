## Topologies Tested

Small Scale (12 Nodes):
- Topology A: 1 Cluster of 12 Nodes
- Topology B: 2 Clusters of 6 Nodes
- Topology C: 3 Clusters of 4 Nodes

Medium Scale (24 Nodes):
- Topology A: 1 Cluster of 24 Nodes
- Topology B: 2 Clusters of 12 Nodes
- Topology C: 3 Clusters of 8 Nodes

Large Scale (48 Nodes):
- Topology A: 1 Cluster of 48 Nodes
- Topology B: 2 Clusters of 24 Nodes
- Topology C: 3 Clusters of 16 Nodes

## Metrics Collected
- Latency for workload to be finished across cluster of clusters - tells us the efficiency of each topology setup
- Kubernetes / API Server - looks at control plane
- Kubernetes / Compute Resources / Namespace (Pods) - watch how pod workload is being handled
- Kubernetes / Computer Resources / Cluster - CPU usage overview
- Other interesting metrics
