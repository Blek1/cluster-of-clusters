# kwok-test
This project is a stress testing framework for the Karmada control plane using KWOK (Kubernetes Without Kubelet) to simulate member cluster nodes and ClusterLoader2 to drive high volume workloads against a Karmada API server.

# Overview
ClusterLoader2 is pointed at the Karmada control plane to generate large volumes of Deployment and PropagationPolicy objects. Karmada propagates these to KWOK-backed member clusters, where fake nodes instantly mark pods as Running — enabling pure control-plane benchmarking without real compute.

## Repo Structure 
```
kwok-test/
├── bin/                        # Helper binaries 
├── configs/
│   └── clusterloader/          # ClusterLoader2 test configs
├── dashboards/                 # Grafana / monitoring dashboard definitions
├── kind/                       # kind cluster configs (host + member cluster bootstrap)
├── observ/                     # Observability stack (Prometheus, metrics scraping, etc.)
├── perf-tests/                 # kubernetes/perf-tests submodule (contains ClusterLoader2)
├── scripts/                    # Automation: cluster bootstrap, run tests, teardown
├── .gitignore
└── README.md
```

## Key Files 
| File | Purpose |
|------|---------|
| `configs/clusterloader/config.yaml` | Top-level test definition — namespace count, deployments per namespace, QPS |
| `configs/clusterloader/deployment.yaml` | Deployment object template used by ClusterLoader2 |
| `configs/clusterloader/policy.yaml` | PropagationPolicy template that controls which member clusters receive workloads |

| Script | Purpose |
|--------|---------|
| `scripts/setup-cluster.sh` | auto detects host IP, spins up `host-01` kind cluster, initializes Karmada via `karmadactl init`, creates `MEMBER_COUNT` member clusters with unique pod/service subnets, installs KWOK controller + 1000 fake nodes per member, then calls `setup-observability.sh` |
| `scripts/setup-observability.sh` | Deploys Prometheus to `kind-host-01` (fetches bearer token from Karmada apiserver, injects into prometheus config), deploys Grafana via Helm, imports dashboard JSONs from `configs/dashboards/` |
| `scripts/cluster-loader.sh` | Runs ClusterLoader2 against the Karmada apiserver using `configs/clusterloader/config.yaml`, prints deployment + ResourceBinding counts on completion, saves JUnit report to `perf-tests/clusterloader2/junit.xml` |
| `scripts/verify.sh` | Sanity checks full stack: kind clusters exist, Karmada control plane pods are Running, member clusters are Ready in Karmada, KWOK controller is Running in each member, fake nodes are present |
| `scripts/cleanup.sh` | Tears everything down: deletes all kind clusters removes KWOK clusters via `kwokctl`

### Run order

```bash
# 1. Bootstrap everything (host cluster, Karmada, member clusters, KWOK, observability)
MEMBER_COUNT=3 ./scripts/setup-cluster.sh
#  The IP address in host-config.yaml in line 20 needs to be dynamically changed, the host IP server address changes bewteen runs. The Host IP address is printed out at the start of the cluster setup script each time. 

# 2. Verify the stack is healthy before running load
./scripts/verify.sh

# 3. Run the ClusterLoader2 benchmark
./scripts/cluster-loader.sh

# 4. Tear down when done
./scripts/cleanup.sh
```

Observability is set up automatically at the end of `setup-cluster.sh`. To re-deploy it independently:

```bash
./scripts/setup-observability.sh
```

Grafana will be available at `http://localhost:3000` (admin / admin) while the port-forward is active. The IP address in host-config.yaml in line 20 needs to be dynamically changed, the host IP server address changes bewteen runs. The Host IP address is printed out at the start of the cluster setup script each time. 