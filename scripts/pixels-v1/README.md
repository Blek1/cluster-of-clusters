# Karmada on Mobile Bare-Metal: Version 1 Post-Mortem

## Overview of Architecture
This repository contains the Version 1 pipeline for deploying a distributed Kubernetes (K3s) and Karmada control plane across a bare-metal cluster of 19 (originally but later 18) Pixel Fold devices. 

Our testing pipeline is split into two phases:

1. The Jump Host Script: `bootstrap-phones.sh` is responsible for state destruction and recreation. It uses `sshpass` to log into each individual Pixel Fold, carves them out of the host cluster, re-installs K3s using unique CIDR blocks, and installs Karmada. This must run on the jump host because local laptops do not have direct routing to the `10.0.0.X` phone subnet.
2. The Laptop Script: `run-experiments.sh` is responsible for workload injection and latency tracking. It pulls the newly generated Karmada configuration file from the jump host, applies a 500-pod Nginx manifest with dynamically generated `PropagationPolicies`, and times the rollout loop.

## Execution Steps

1. SSH into the jump host, ensuring port forwarding for the main K3s port and the Karmada API port:
   ```bash
   ssh -L 6443:10.0.0.16:6443 -L 32443:10.0.0.16:32443 straw-hat
2. Run the bootstrap script on the jump host to carve out your desired number of member clusters (e.g., 3 clusters):
   ```bash
   ./bootstrap-phones.sh 3
3. Leave that terminal open. In a new local terminal on your laptop, execute the experiment:
   ```bash
   ./run-experiments.sh 3

## Script Directory

All `<N>` arguments represent the number of worker (member) clusters to carve from the phone pool.

| Script | Execution Environment | Purpose |
|---|---|---|
| `bootstrap-phones.sh <N>` | jump host | Carves `N` member clusters out of the phone pool, reinstalls K3s with unique CIDR blocks, and installs Karmada. |
| `run-experiments.sh <N>` | laptop | Pulls the Karmada config from the jump host, applies the 500-pod Nginx workload + generated PropagationPolicy, and times the rollout. |
| `verify-topology.sh <N>` | jump host | Checks that the live cluster/phone layout matches the expected `N`-cluster topology. |
| `check-phones.sh` | jump host | Quick health check for node readiness and crashed `containerd` states. |
| `monitor-phones.sh <N>` | jump host | Live dashboard of phone/cluster status, refreshing every 2 seconds. |
| `reset-phones.sh` | jump host | Tears down the Karmada federation and host observability stack, folding the phones back into the baseline cluster. |

## Intended Topologies Tested (19-Node Board)

With the full 19-phone board active, the automation dynamically slices the 16 available worker nodes into relatively even sub-clusters. The first 3 phones (`pf-006`, `pf-007`, `pf-008`) are strictly reserved as the Host Control Plane.

* 1 Cluster (Baseline): 19 nodes (Large K3s cluster, no Karmada federation).
* 2 Clusters (1 Host + 2 Members): 3 phones (Host) | 8 phones | 8 phones = 19 Total
* 3 Clusters (1 Host + 3 Members): 3 phones (Host) | 6 phones | 5 phones | 5 phones = 19 Total
* 4 Clusters (1 Host + 4 Members): 3 phones (Host) | 4 phones | 4 phones | 4 phones | 4 phones = 19 Total
* 5 Clusters (1 Host + 5 Members): 3 phones (Host) | 4 phones | 3 phones | 3 phones | 3 phones | 3 phones = 19 Total

## Version 1 Findings & Architectural Challenges

This v1 release represents our initial attempt to orchestrate a multi-cluster federation on mobile hardware.

### Successes & Hardware Casualties
* Baseline Deployment: Deploying a single baseline cluster across the board worked perfectly. We successfully injected heavy workloads (500 Nginx pods) and validated the underlying K3s architecture over the physical USB-C networking.
* Hardware Dependencies: During our experiments, one of our control plane devices (`pf-006`) experienced a hardware failure and temporarily died. It is unknown whether this impacted or had any effect on the challenges experienced below.

### The Federation Bottleneck
Attempting to deploy the Karmada Control plane across 2+ clusters introduced a critical challenge. We were seemingly forced to choose between a compute limitation or a network limitation.

#### Scenario A: Co-Location (Possible Resource Limitation)
When we pinned the Karmada API server and the ETCD database to the exact same physical phone to ensure network stability, the API server would run for roughly 8 minutes before being assassinated by the `kubelet`.

* The Logs: `Liveness probe failed: GET /livez timed out... Client.Timeout exceeded while awaiting headers.`
* Possible Cause 1 (UFS I/O): Pixel Folds utilize UFS (Universal Flash Storage), which struggles with the concurrent, high-frequency writes required by ETCD's Write-Ahead Log (`fsync` operations). 
* Possible Cause 2 (Software): As ETCD stalled waiting on the physical disk, the API server's Go runtime spawned thousands of goroutines to handle the backlog. The Tensor G2 processor became entirely saturated with context-switching, preventing the API server from responding to the 30-second `GET /livez` health check in time.

#### Scenario B: Physical Separation (Possible Network Limitation)
To relieve the pressure on the ETCD node, we moved the API server to a different phone. This may have solved the compute starvation, but introduced a network crash before that could be confirmed. The API server died within 20 seconds of booting.

* The Logs: `dial tcp 10.48.0.5:2379: i/o timeout` followed by `context deadline exceeded`.
* Possible Cause 1 (host-gw): Android Linux kernels do not support VXLAN encapsulation. We were forced to use Flannel's `host-gw` backend, which rewrites static IP routes directly into the kernel. 
* Possible Cause 2 (Race Conditions): `host-gw` requires millisecond-perfect route consistency. During the massive CPU spikes of the cluster's cold boot, the API server container was starting and firing TCP packets milliseconds before the Flannel daemon could secure CPU time to finish writing the cross-node routes into the kernel. The local kernel, unaware of the route, black-holed the packets.
* Another Issue (Secondary Race Conditions): We also encountered initialization race conditions when trying to bypass CoreDNS bottlenecks. The API server executed aggressively enough to query DNS before the I/O-starved `kubelet` could inject static `/etc/hosts` aliases, causing immediate lookup cancellations.

### The V1 Conclusion (The Resolution)
Ultimately, Version 1 of this architecture highlighted the challenges and limitations of running enterprise orchestration tools on mobile hardware.

As of this writing, a stable multi-cluster Karmada federation has not been successfully established. While we attempted various patches (such as CoreDNS bypasses and extending probe timeouts to 300 seconds), the underlying hardware bottlenecks proved too unstable for a reliable control plane.

Rather than continuing to apply workarounds, our next step is to wipe the slate clean. We plan to step back, reset the board, and fundamentally re-evaluate the constraints before architecting Version 2.

### Extensive Error Logs

Disclaimer: Everything discussed here are just assumptions based on logs, nothing is known for sure at this time.

Note: By the time these extensive logs were gathered, the Karmada API Server was able to start up for Scenario A, but the Aggregated Karmada API Server was failing. The only difference between the experiments was that for these logs, pf-006 was back online so it hosted etcd, karmada-apiserver, and karmada-aggregated-apiserver, whereas the challenges above happened on pf-007. There were no clear errors indicating that the challenges with karmada-apiserver was due to it being on pf-007, but it is undeniable that it worked once pf-006 was added back.

### Scenario A
Topology: `karmada-apiserver`, `karmada-aggregated-apiserver`, and `etcd-0` forced onto a single phone (`pf-006`)

#### Log 1: UFS Flash Storage Exhaustion
* Source: kubelet-journal.log
* What happened: The Kubernetes node agent (Kubelet) attempts to execute a routine health probe inside the `etcd-0` container. However, the Pixel Fold's UFS (Universal Flash Storage) controller is completely saturated by the API servers trying to sync their caches. 
* The Proof:
```bash
Jun 03 18:55:17 PF-006 k3s[108114]: E0603 18:55:17.322808  108114 prober.go:260] "Unable to write all bytes from execInContainer" err="short write" expectedBytes=10858 actualBytes=10240 pod="karmada-system/etcd-0" containerName="etcd"
Jun 03 18:56:17 PF-006 k3s[108114]: E0603 18:56:17.324005  108114 prober.go:260] "Unable to write all bytes from execInContainer" err="short write" expectedBytes=10858 actualBytes=10240 pod="karmada-system/etcd-0" containerName="etcd"
Jun 03 18:58:17 PF-006 k3s[108114]: E0603 18:58:17.350141  108114 prober.go:260] "Unable to write all bytes from execInContainer" err="short write" expectedBytes=13672 actualBytes=10240 pod="karmada-system/etcd-0" containerName="etcd"
```

#### Log 2: CPU Starvation & UDP Packet Drops
* Source: aggregated-apiserver-current.log
* What happened: Because the main API server is aggressively chewing up the Tensor G2 CPU and UFS disk, the karmada-aggregated-apiserver boots into a completely starved environment. When it tries to resolve the IP of the main API server via CoreDNS (10.49.0.10:53), the Linux kernel drops the UDP packet entirely because the processing queues are full, instantly returning connection refused and causing the pod to Exit Code: 1.
* The Proof:
```bash
E0603 18:58:44.763974       1 run.go:72] "command failed" err="unable to load configmap based request-header-client-ca-file: Get \"[https://karmada-apiserver.karmada-system.svc.cluster.local:5443/api/v1/namespaces/kube-system/configmaps/extension-apiserver-authentication](https://karmada-apiserver.karmada-system.svc.cluster.local:5443/api/v1/namespaces/kube-system/configmaps/extension-apiserver-authentication)\": dial tcp: lookup karmada-apiserver.karmada-system.svc.cluster.local on 10.49.0.10:53: read udp 10.48.0.7:48744->10.49.0.10:53: read: connection refused"
```

#### Log 3: The TCP Timeout Cascade
* Source: apiserver-current.log
* What happened: Because the Aggregated API server is trapped in a CrashLoopBackOff due to the UDP drop, the Main API server eventually times out waiting for it to register its APIServices. This proves that the system failure is an internal HTTP timeout, not an orchestration crash.
* The Proof:
```bash
E0603 18:59:40.401713       1 remote_available_controller.go:448] "Unhandled Error" err="v1alpha1.cluster.karmada.io failed with: failing or missing response from [https://karmada-aggregated-apiserver.karmada-system.svc:443/apis/cluster.karmada.io/v1alpha1](https://karmada-aggregated-apiserver.karmada-system.svc:443/apis/cluster.karmada.io/v1alpha1): Get \"[https://karmada-aggregated-apiserver.karmada-system.svc:443/apis/cluster.karmada.io/v1alpha1](https://karmada-aggregated-apiserver.karmada-system.svc:443/apis/cluster.karmada.io/v1alpha1)\": net/http: request canceled while waiting for connection (Client.Timeout exceeded while awaiting headers)" logger="UnhandledError"
```

### Scenario B
Topology: `karmada-apiserver` forced onto a separate physical phone (pf-008) from `etcd-0` (pf-006) to relieve local CPU/IO pressure.

#### Log 1: Flannel host-gw Route Convergence Drops
* Source: apiserver-previous.log
* What happened: Because Android kernels lack VXLAN support, K3s relies on host-gw (static kernel routing). During the heavy CPU spike of the cold boot, the API server container spawns on pf-008 and fires a TCP connection to etcd on pf-006. It might have done this milliseconds before the Flannel daemon can secure CPU time to physically write the cross-node route into the Linux kernel. The kernel instantly drops the unroutable packet. Exactly 20 seconds later (the hardcoded Go gRPC timeout window), the library throws a fatal i/o timeout and intentionally crashes the pod.
* The Proof:
```bash
W0603 21:31:00.000774       1 logging.go:55] [core] [Channel #2 SubChannel #4]grpc: addrConn.createTransport failed to connect to {Addr: "etcd-0.etcd.karmada-system.svc.cluster.local:2379", ServerName: "etcd-0.etcd.karmada-system.svc.cluster.local:2379", }. Err: connection error: desc = "transport: Error while dialing: dial tcp 10.48.0.5:2379: i/o timeout"
W0603 21:31:00.015252       1 logging.go:55] [core] [Channel #5 SubChannel #6]grpc: addrConn.createTransport failed to connect to {Addr: "etcd-0.etcd.karmada-system.svc.cluster.local:2379", ServerName: "etcd-0.etcd.karmada-system.svc.cluster.local:2379", }. Err: connection error: desc = "transport: Error while dialing: dial tcp 10.48.0.5:2379: i/o timeout"
F0603 21:31:00.015877       1 instance.go:225] Error creating leases: error creating storage factory: context deadline exceeded
```

#### Log 2: The hostAliases Race Condition
* Source: apiserver-previous.log
* What happened: To bypass CoreDNS bottlenecks across the physical switch, we injected ETCD's static IP directly into the API server's /etc/hosts file via a hostAliases patch. However, because the Kubelet is severely bottlenecked by slow mobile disk I/O, the highly optimized Go application executes its dial tcp command before the Kubelet can finish writing the file to the local disk. The Go client falls back to a standard DNS lookup, which gets cancelled by the over-stressed network.
* The Proof:
```bash
W0603 21:31:00.000507       1 logging.go:55] [core] [Channel #1 SubChannel #3]grpc: addrConn.createTransport failed to connect to {Addr: "etcd-0.etcd.karmada-system.svc.cluster.local:2379", ServerName: "etcd-0.etcd.karmada-system.svc.cluster.local:2379", }. Err: connection error: desc = "transport: Error while dialing: dial tcp 10.48.0.5:2379: operation was canceled"
```

#### Log 3: Fail-Fast Architecture
* Source: apiserver-describe.txt
* What happened: Because the API server is designed to be completely stateless, it cannot function without its database. When the network drops the connection to etcd, the pod intentionally commits suicide (Exit Code: 255) and enters a CrashLoopBackOff, preventing the cluster from passing health checks.
* The Proof:
```bash
Warning  Unhealthy  9m33s (x3 over 11m)    kubelet            Liveness probe failed: Get "https://10.48.3.3:5443/livez": dial tcp 10.48.3.3:5443: connect: no route to host
  Warning  Unhealthy  6m14s (x2 over 9m54s)  kubelet            Liveness probe failed: Get "https://10.48.3.3:5443/livez": net/http: request canceled while waiting for connection (Client.Timeout exceeded while awaiting headers)
  Warning  BackOff    79s (x39 over 11m)     kubelet            Back-off restarting failed container karmada-apiserver in pod karmada-apiserver-d754d8bf7-td8x9
```

### Non-Factors
During our investigation, we tried to rule out several common assumptions to isolate the true bottlenecks causing the issues.

#### Log 1: Memory Exhaustion
* Source: OS-level free -m metrics and kernel OOM logs.
* What happened: A standard assumption in edge computing is that mobile devices will fail to run Kubernetes control planes due to severe RAM constraints. We captured the exact memory footprint of the Android kernel at the moment the API Server crashed.
* The Proof: Out of the Pixel Fold's 12GB of RAM, only 1.6GB was actively being used. Nearly 9GB of RAM was completely free and available. The Linux OOMKiller (Out of Memory Killer) was never invoked.
```bash
total        used        free      shared  buff/cache   available
Mem:           11448        1626        8719           4        1592        9821
Swap:              0           0           0
```

#### Log 2: Network Configuration & IPAM
* Source: kubelet-journal.log
* What happened: We had to rule out whether node corruption, misconfigured IPAM (IP Address Management), or a failed K3s agent registration was causing the network drops before the load spiked.
* The Proof: We captured the Kubelet initialization logs at the exact moment the control plane booted. The logs show that pf-006 successfully registered with the cloud provider, Flannel successfully bound to the physical enx USB-C interface, and the PodCIDRs were perfectly allocated. The baseline network configuration was completely healthy.
```bash
Jun 03 18:48:35 PF-006 k3s[108114]: I0603 18:48:35.065628  108114 node_controller.go:474] Successfully initialized node pf-006 with cloud provider
Jun 03 18:48:35 PF-006 k3s[108114]: I0603 18:48:35.066673  108114 event.go:389] "Event occurred" object="pf-006" fieldPath="" kind="Node" apiVersion="v1" type="Normal" reason="Synced" message="Node synced successfully"
Jun 03 18:48:36 PF-006 k3s[108114]: I0603 18:48:36.705658  108114 range_allocator.go:428] "Set node PodCIDR" logger="node-ipam-controller" node="pf-006" podCIDRs=["10.48.0.0/24"]
Jun 03 18:48:38 PF-006 k3s[108114]: time="2026-06-03T18:48:38Z" level=info msg="Flannel found PodCIDR assigned for node pf-006"
Jun 03 18:48:38 PF-006 k3s[108114]: time="2026-06-03T18:48:38Z" level=info msg="The interface enx80691ab34e05 with ipv4 address 10.0.0.16 will be used by flannel"
```

