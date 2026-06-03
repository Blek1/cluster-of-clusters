# Overview of Execution
Our testing pipeline is executed directly on the bare-metal Pixel phones to evaluate Kubernetes and Karmada control plane latency on physical edge devices. 

Following "Option C" from the infrastructure handoff, we utilize an 18-phone physical topology. To prevent thermal throttling on the mobile processors, the Karmada control plane is distributed across a dedicated 3-node Host Cluster, leaving the remaining 15 phones to be divided into member worker clusters.

1. **The Environment Reset:** `reset-phones.sh` wipes the K3s installations from all 18 physical Pixel phones concurrently.
2. **The Infrastructure Bootstrap:** `bootstrap-phones.sh` creates the 3-phone Host Cluster, partitions the remaining 15 phones into sub-clusters using unique CIDRs, installs K3s with the `host-gw` flannel backend, deploys Karmada, and joins the worker clusters.
3. **The Experiment:** `run-experiments.sh` is executed directly on the jump host. It injects a 500-pod Nginx workload across the federation and tracks the exact rollout latency.

## Execution Steps

All scripts must be executed directly via SSH on the jump host (`straw-hat`).

1. SSH into the jump host:

2. Wipe the previous state:
   `./reset-phones.sh`
   *(Wait ~90 seconds for physical phones to reboot and settle)*

3. Bootstrap the federated topology (e.g., 3 worker clusters):
   `./bootstrap-phones.sh 3`

4. Verify the hardware is wiped and ready:
   `./check-phones.sh`

5. Verify the topology is healthy and all nodes are registered:
   `./verify-topology.sh 3`

6. Execute the experiment and track latency:
   `./run-experiments.sh 3`

*(Optional) You can leave `./monitor-phones.sh 3` running in a second SSH terminal to watch the live pod distribution during the rollout.*

## Topologies Tested (18 Physical Phones)
The jump host orchestrates the following distributions across the 18 phones:

1. **1 Cluster (Baseline):** 18 phones (Monolithic)
2. **2 Clusters:** 3 phones (Host) | 8 phones | 7 phones = 18 Total
3. **3 Clusters:** 3 phones (Host) | 5 phones | 5 phones | 5 phones = 18 Total
4. **4 Clusters:** 3 phones (Host) | 4 phones | 4 phones | 4 phones | 3 phones = 18 Total
5. **5 Clusters:** 3 phones (Host) | 3 phones | 3 phones | 3 phones | 3 phones | 3 phones = 18 Total
