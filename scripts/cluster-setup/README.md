# cluster-setup

Scripts for creating and tearing down Kind clusters.

## Scripts

- **`setup.sh`** — Creates the pipeline Kind clusters from `../../configs/kind/*.yaml` (host + worker-1 + worker-2)
- **`many-clusters.sh`** — Scale test: create 1 host + 50 one-node workers
- **`mega-cluster.sh`** — Scale test: create 1 control-plane + 70 workers in a single cluster
- **`teardown.sh`** — Destroys all Kind clusters, KWOK clusters, and Grafana containers
- **`cleanup.sh`** — Simple cleanup: `kind delete cluster --all` + wipe `~/.karmada`

## Usage

```bash
# Create the host + worker-1 + worker-2 clusters from configs
./setup.sh

# When done, tear everything down
./teardown.sh
```
