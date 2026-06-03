# manifests

Standalone Kubernetes manifests used across the experiments.

## Contents

| File | Purpose |
|---|---|
| `kwok/node-template.yaml` | KWOK fake-node template. `${NODE_ID}` is substituted (e.g. via `envsubst`) to mint uniquely-named fake nodes for KWOK scaling tests. |
| `tests/workload.yaml` | The benchmark workload — a 500-replica `nginx:alpine` Deployment (`5m` CPU / `10Mi` mem requests) used to measure rollout latency across topologies. |

## Usage

```bash
# Mint a fake node from the template
NODE_ID=1 envsubst < manifests/kwok/node-template.yaml | kubectl apply -f -

# Apply the 500-pod benchmark workload
kubectl apply -f manifests/tests/workload.yaml
```
