# cluster-setup

Scripts for creating and tearing down Kind clusters.

## Scripts

- **`setup.sh`** — Creates all Kind clusters from `../../configs/kind/*.yaml`
- **`setup-clusters.sh`** — Explicit 3-cluster variant (host + worker 1 + worker 2)
- **`many-clusters.sh`** — Scale test: create 1 host + 50 one-node workers
- **`mega-cluster.sh`** — Scale test: create 1 control-plane + 70 workers in a single cluster
- **`teardown.sh`** — Destroys all Kind clusters, KWOK clusters, and Grafana containers
- **`cleanup.sh`** — Simple cleanup: `kind delete cluster --all` + wipe `~/.karmada`

## Usage

```bash
# Create all clusters from configs
./setup.sh

# Or create the explicit 3-cluster setup
./setup-clusters.sh

# When done, tear everything down
./teardown.sh
```
