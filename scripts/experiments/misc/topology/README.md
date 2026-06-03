# topology

Kind cluster configs and scripts for testing at different topology scales.

Each subdirectory contains cluster configs and setup scripts for a particular scale:

| Directory | Scale |
|---|---|
| `small/` | 1 cluster, 4 nodes |
| `medium/` | 2 clusters, 10 nodes each |
| `large/` | 1 cluster, 20 nodes |

Each has a `configs/kind/` directory with cluster YAMLs and a `scripts/` directory with `setup-clusters.sh` and `cleanup.sh`.
