# stress-testing

Simple stress tests for individual Kind clusters.

## Scripts

- **`simple-kind-stress.sh <action> <cluster> [mode] [replicas] [duration]`** — Run stress-ng pods on a Kind cluster
  - Actions: `run`, `status`, `cleanup`, `queries`
  - Modes: `cpu`, `memory`, `mixed`
- **`kind-stress-guide.md`** — Detailed guide for running stress tests

## Example

```bash
# Run mixed stress on worker-1 with 5 replicas for 5 minutes
./simple-kind-stress.sh run worker-1 mixed 5 300

# Check status
./simple-kind-stress.sh status worker-1

# Clean up
./simple-kind-stress.sh cleanup worker-1
```
