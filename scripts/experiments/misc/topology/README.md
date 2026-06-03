# topology

Kind cluster configs and scripts for testing at different topology scales.

Each subdirectory contains cluster configs and setup scripts for a particular scale:

| Directory | Cluster(s) | Nodes | Memory limit |
|---|---|---|---|
| `small/` | `small-01` | 1 cluster, 4 nodes | 1g/node |
| `medium/` | `medium-01`, `medium-02` | 2 clusters, 10 nodes each | 4g control-plane / 1g worker |
| `large/` | `large-01` | 1 cluster, 20 nodes | 1g/node |

Each has a `configs/kind/` directory with the cluster YAML and a `scripts/` directory with `setup-clusters.sh` and `cleanup.sh`.
