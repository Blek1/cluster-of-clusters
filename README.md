# Benchmarking 

USE = utilization, saturation, errors 

Utilization  → CPU %, memory %  
Saturation   → pods being throttled, OOM pressure
Errors       → node not ready, kubelet errors


Utilization  → how much of each cluster's capacity is used?
Saturation   → is Karmada delaying propagation?
Errors       → clusters showing NotReady, join failures
(https://karmada.io/blog/2022/10/26/test-report/)
Federation Layer Benchmarking Questions to Answer: 

Utilization:
What is the baseline resource utilization across all 3 clusters at idle?
How does utilization distribute when a workload is deployed via Karmada vs directly to a cluster?
Is resource usage evenly distributed across worker nodes within each cluster?

Saturation:
At what utilization % does pod scheduling latency start increasing?
How long does it take Karmada to detect a cluster is under pressure?
Does adding more parallelism help or does it saturate the API server first?

Errors:
What happens to inflight workloads when a member cluster goes down?
Does Karmada failover automatically or does it require manual intervention?

Federation specific:
What is Karmada's propagation latency at low vs high load?
If cluster-01 and cluster-02 have different resource capacities, does Karmada weight distribution accordingly?
What is the overhead of Karmada itself, how much CPU/memory does the control plane consume?


## SLOs and SLIs 

Kubernetes Official SLOs (hard guarantees):
API mutating call latency (create, update, delete) ≤ 1s at 99th percentile
API read-only call latency ≤ 1s (single resource) or ≤ 30s (namespace/cluster scope) at 99th percentile
Pod startup latency ≤ 5s at 99th percentile (stateless pods, excludes image pull)

Kubernetes WIP SLIs (measured but no hard guarantee yet):
Stateful pod startup latency
Load balancer programming latency
DNS programming latency
In-cluster network latency (pod-to-pod ping)
DNS lookup latency
TCP first packet latency
Network throughput

Karmada SLIs/SLOs (2022 report):
Karmada measures scalability across 3 dimensions:

Number of clusters
Number of API objects/resources on the control plane
Size of individual clusters

The specific SLIs Karmada tracks:

Resource distribution latency — how long from applying a workload to Karmada until it appears on member clusters
API server request latency on the Karmada control plane
Control plane resource usage (CPU/memory of karmada-apiserver, karmada-controller-manager, karmada-scheduler)
Cluster sync latency — how long for member cluster status to reflect in Karmada


** Why isn't CPU/node consumption measure? ** 

They are precise and well-defined
It's extremely important to ensure that both users and us have exactly the same understanding of what we guarantee.
They are consistent with each other
This is mostly about using the same terminology, same concepts, etc.
They are user-oriented
First, the SLOs we provide need to be things users really care about. Second, they need to be understandable for people not familiar with the system internals (e.g. their formulation can't depend on some arcane knowledge or implementation details of the system).
They are testable
Ideally, SLIs/SLOs should be measurable in all running clusters, but if measuring some metrics isn't possible or would be extremely expensive (e.g. in terms of resource overhead for the system), benchmarks sometimes may be enough. That means that not every SLO may be translatable to SLA (Service Level Agreement).

Machine agnostic really 


## Final Metrics 

Layer 1 — Node metrics:

CPU utilization %
Memory utilization %
Network throughput (bytes in/out per second)
Network packet loss/error rate
Disk I/O (read/write bytes per second)
Disk latency

Layer 2 — Cluster metrics: (pod also kinda done in here) 

Pod startup latency (P99)
API server request latency (P99)
Pods pending vs running ratio
Container restart rate
Scheduling throughput (pods/sec)

Layer 3 — Karmada metrics:

End-to-end scheduling latency (P99)
Propagation latency to member clusters (P99)
Scheduling success rate
Unschedulable bindings count
Karmada control plane CPU/memory overhead
Member cluster ready state


