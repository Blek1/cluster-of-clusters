# Cluster of Clusters team — Pixel-Phone Handoff (Spring 2026)

**Team:** Felicia, Blake, Tahseen, Afraz, Andre (plus Parth's substrate)
**Phones:** 19 Pixel Folds reserved for your team — `cluster-of-clusters-until-2026-06-12`
**What this is for:** the **Hardware Porting to Pixel phones** phase of your Karmada-federation research (from your quarter plan slide).
**Issued:** 2026-05-25

You've already established the cross-cluster API/control-plane saturation story in kind+KWOK and published the **3-cluster threshold** rule. This handoff gives you the real hardware to validate it on. The pivot you signaled in your May 12 presentation — *"stressing and analyzing the Kubernetes control plane rather than workload execution"* — fits this hardware well: 19 Pixel Folds are exactly the right size to stand up the topology matrix you've been simulating, but on bare-metal Linux instead of Docker-in-Docker.

---

## You already have a working cluster — Cluster D

Your 19 phones are already standing up as a fresh K3s cluster, **Cluster D**, ready for you to use. You don't have to detach them from anything or rebuild from scratch.

| Field | Value |
|---|---|
| Cluster name | **Cluster D** |
| K3s server (control plane) | **pf-006** (10.0.0.16) |
| Workers | the other 18 phones |
| Pod CIDR | `10.48.0.0/16` |
| Service CIDR | `10.49.0.0/16` |
| Flannel backend | `host-gw` |
| Kubeconfig on jump host | **`/home/luffy/cluster-d.kubeconfig`** |
| Reservation label/taint | `reservation=cluster-of-clusters-until-2026-06-12` (label + `NoSchedule` taint, on every node) |

**Smoke-tested before delivery** — 19 Ready nodes, busybox workloads scheduled and landed cleanly, image pulls verified from Docker Hub (`docker.io/karmada/...`), ghcr.io (`ghcr.io/colinianking/stress-ng`), and the local registry (`10.0.0.1:30500`).

### Running kubectl — two options

**Option 1: from the jump host (simplest, always works):**

```bash
ssh straw-hat
KUBECONFIG=/home/luffy/cluster-d.kubeconfig kubectl get nodes -o wide   # all 19 Ready
```

**Option 2: from your laptop (better dev experience).** Two pieces:

1. Add a `LocalForward` to your `~/.ssh/config` straw-hat block so port 6443 on your laptop tunnels to the Cluster D server:

   ```
   Host straw-hat
       HostName 132.239.17.60
       User luffy
       LocalForward 6443 10.0.0.16:6443
       ServerAliveInterval 30
   ```

2. Download the **laptop-ready** kubeconfig (server already rewritten to `https://127.0.0.1:6443` and `tls-server-name: pf-006` already set):

   ```bash
   scp straw-hat:/home/luffy/cluster-d-laptop.kubeconfig ~/.kube/cluster-d.kubeconfig
   export KUBECONFIG=~/.kube/cluster-d.kubeconfig
   ```

3. **Keep your `ssh straw-hat` session open** while you use kubectl — the tunnel only exists while that SSH session is alive. Then `kubectl get nodes` from your laptop just works.

> If port 6443 collides with another tunnel (e.g., you also have Cluster B access on 6443), pick a different local port — change `LocalForward 6443` to `LocalForward 8443` and edit `~/.kube/cluster-d.kubeconfig` to use `https://127.0.0.1:8443`.

---

## Your 19 phones

| Phone | IP | Switch | Role in Cluster D |
|---|---|---|---|
| pf-006 | 10.0.0.16 | 1 | **K3s server (control plane)** |
| pf-007 | 10.0.0.17 | 1 | worker |
| pf-008 | 10.0.0.18 | 1 | worker |
| pf-009 | 10.0.0.19 | 1 | worker |
| pf-010 | 10.0.0.20 | 1 | worker |
| pf-011 | 10.0.0.21 | 1 | worker |
| pf-012 | 10.0.0.22 | 1 | worker |
| pf-013 | 10.0.0.23 | 1 | worker |
| pf-014 | 10.0.0.24 | 1 | worker |
| pf-016 | 10.0.0.26 | 1 | worker |
| pf-017 | 10.0.0.27 | 1 | worker |
| pf-019 | 10.0.0.29 | 1 | worker |
| pf-021 | 10.0.0.31 | 2 | worker |
| pf-024 | 10.0.0.34 | 2 | worker |
| pf-031 | 10.0.0.41 | 2 | worker |
| pf-032 | 10.0.0.42 | 2 | worker |
| pf-033 | 10.0.0.43 | 2 | worker |
| pf-035 | 10.0.0.45 | 2 | worker |
| pf-036 | 10.0.0.46 | 2 | worker |

**Hardware (each phone):** Google Pixel Fold (felix), Tensor G2, **12 GB LPDDR5 RAM**, 256 GB UFS storage, Mali-G710 GPU. Kernel `6.1.124-android14`, Debian 13 (trixie) root partition. Per-phone `kubectl describe node` shows `cpu: 8`, `memory: ~11.2Gi allocatable`, `ephemeral-storage: ~3.9 GB on /`, `~225 GB on /userdata`.

**Switch split:** 12 phones on switch 1, 7 on switch 2. Matters for the cross-cluster network-latency component of your experiments — phones on the same switch share an L2 broadcast domain; phones across switches go through one chained-switch hop.

---

## What's done for you vs. what you own

**Pre-staged and verified:**

- Cluster D is up: 19 Ready nodes, single K3s control plane on pf-006
- Reservation label + taint applied to all 19 (`reservation=cluster-of-clusters-until-2026-06-12:NoSchedule`)
- `registries.yaml` applied on every node — you can pull from `http://10.0.0.1:30500` without TLS errors (verified: 8.8s pull of a real image from Cluster D)
- **Durable subdivide assets pre-staged on every phone** at `/userdata/cluster-d-assets/`: the k3s binary (`k3s-arm64`), the install script (`k3s-install.sh`), and a copy of `registries.yaml`. `/userdata/` survives reboots, so these are there when you need them.
- Two kubeconfigs ready on the jump host:
  - `/home/luffy/cluster-d.kubeconfig` — for use ON the jump host (server URL `https://10.0.0.16:6443`)
  - `/home/luffy/cluster-d-laptop.kubeconfig` — for use FROM your laptop via SSH tunnel (server URL `https://127.0.0.1:6443`, `tls-server-name: pf-006`)
- **SSH access to the jump host (rolling intake):** send your public SSH key (ed25519 preferred) to Raymond — once added, you'll be able to `ssh luffy@132.239.17.60`. Keys are tagged with `cluster-of-clusters-until-2026-06-12` for clean revocation at end-of-grant. Until your key is in, every command below that starts with `ssh straw-hat` or `sshpass ssh kalm@...` will fail at the jump-host hop.
- `/etc/junkyard-image` on every phone returns the image cohort name (`original-debian`)
- External registries proven reachable through NAT: Docker Hub (`docker.io/karmada/*` pulled in ~4s), GHCR (`ghcr.io/colinianking/stress-ng` pulled in ~10s)
- Cluster pressure-tested: smoke pods schedule and run; the worker→server and server→worker conversion recipes (below) validated on real hardware

**You own:**

- Your experimental topology — keep Cluster D as one big cluster, or subdivide it (recipe below)
- Installing Karmada on whichever cluster you designate as karmada-host (control your version pin per Parth's `bootstrap-karmada.sh`)
- Your observability stack — your Grafana dashboards from `blake-dev`, Prometheus, Thanos
- All experimental tooling — `test-topology.sh`, KWOK scripts, Afraz's stress-test scripts (porting them from kind→K3s)

---

## The conceptual shift: kind → bare-metal phones

Your work to date has been on **kind** — Docker-in-Docker, multiple "kind clusters" coexisting on one host machine. Real phones break that mental model in important ways:

| Concept | In kind | On Pixel phones (Cluster D) |
|---|---|---|
| A "node" | A Docker container running the kubelet | A physical phone running k3s-agent |
| A "cluster" | A set of containers on one host machine + a Docker network | A set of phones + their LAN, plus one phone running k3s-server |
| Adding nodes | `kind create cluster --config <yaml>` re-renders the topology | Phones are already onboarded; you subdivide as needed (see below) |
| Network isolation between clusters | Per-cluster Docker network with isolated subnets | All phones share `10.0.0.0/24`; cluster isolation comes from per-cluster pod/service CIDRs |
| Cluster teardown | `kind delete cluster` | Stop k3s, wipe `/var/lib/rancher/k3s/`, restart from clean state (recipe below) |
| Federation control plane | Karmada on a separate kind cluster | Karmada on Cluster D (or a sub-cluster you carve out) |

**Parth's `bootstrap-karmada.sh` does not directly transfer.** It assumes kind. You'll need an analogous script for K3s-on-phones — but most of the logic (pinned Karmada commit, member-join sequence, kubeconfig wrangling, verification) carries over conceptually. The K3s install primitives below replace kind's.

---

## Suggested topology — validate the rule you published

Your May 12 finding was: **scheduling overhead becomes negligible after 3 clusters; the API SLI drops from 5s spikes (single cluster) to 100–800ms (2–3 clusters)**.

You start with **1 cluster × 19 nodes (Cluster D)**. From there, three natural directions:

**Option A — keep Cluster D as one big cluster (the 1×19 baseline):**
- This is what you have today. Run your stress workload against it as-is.
- Cluster B was validated at 7 nodes on phones; 19 is untested territory. You'll either confirm K3s scales fine on Pixel Fold or find the per-node ceiling — useful either way as a data point in your Final Report.

**Option B — clean 3-cluster split (validates your published rule directly):**
- Subdivide Cluster D into 3 clusters × 6 phones (+ 1 spare). Put the karmada-host cluster on switch 2 (pf-021, 024, 031, 032, 035, 036 — same L2 broadcast domain).
- Use the **subdivide recipe** below to carve out two sub-clusters of 6 from Cluster D.
- Member clusters: the two carved-out sub-clusters, 6 phones each on switch 1.

**Option C — mirror Parth's kind layout, scaled up:**
- 1 host cluster (Cluster D shrunk to 4 phones) + 3 member clusters × 5 phones = 19 phones total.
- Matches the 1-host + N-members shape from `bootstrap-karmada.sh` but with bigger members.
- Useful if you want to push the 3-cluster vs 4-cluster crossover question (your rule says "≥3"; does the 4th still help?).

> **Constraint to know:** a single K3s cluster on phones has been validated up to **7 nodes** (the Autograder team's Cluster B). 19 nodes single-cluster is untested. If your 1×19 baseline experiment hits a ceiling, that's its own finding.

---

## Subdividing your cluster — worker → server (carve out a sub-cluster)

This is the primitive you'll use to build Option B or Option C. It was validated end-to-end on pf-013 during pressure-testing.

**To turn a Cluster D worker (say `pf-013`) into the server of a new sub-cluster:**

```bash
# On the jump host, from the perspective of Cluster D:
KD=/home/luffy/cluster-d.kubeconfig

# 1. Drain the worker from Cluster D and delete its node object
kubectl --kubeconfig=$KD drain pf-013 --ignore-daemonsets --delete-emptydir-data --force --grace-period=0
kubectl --kubeconfig=$KD delete node pf-013

# 2. Uninstall k3s-agent on the phone
sshpass -p 0000 ssh kalm@10.0.0.23 'echo 0000 | sudo -S /usr/local/bin/k3s-agent-uninstall.sh'

# 3. Re-copy the k3s binary from the durable asset location (/usr/local/bin/k3s was deleted by uninstall)
sshpass -p 0000 ssh kalm@10.0.0.23 'echo 0000 | sudo -S cp /userdata/cluster-d-assets/k3s-arm64 /usr/local/bin/k3s && echo 0000 | sudo -S chmod +x /usr/local/bin/k3s'

# 4. Install k3s-server on the phone — NEW CIDRs (pick a clean range; see reserved table below)
sshpass -p 0000 ssh kalm@10.0.0.23 'echo 0000 | sudo -S env INSTALL_K3S_SKIP_DOWNLOAD=true \
  INSTALL_K3S_EXEC="server --flannel-iface=enx80691ab3551f --node-ip=10.0.0.23 \
    --flannel-backend=host-gw --cluster-cidr=10.50.0.0/16 --service-cidr=10.51.0.0/16 \
    --disable=traefik --node-name=pf-013 --tls-san=10.0.0.23" \
  sh /userdata/cluster-d-assets/k3s-install.sh'

# 5. Re-apply registries.yaml from the durable asset location (uninstall wiped /etc/rancher/k3s/)
sshpass -p 0000 ssh kalm@10.0.0.23 'echo 0000 | sudo -S mkdir -p /etc/rancher/k3s && \
  echo 0000 | sudo -S cp /userdata/cluster-d-assets/registries.yaml /etc/rancher/k3s/registries.yaml && \
  echo 0000 | sudo -S systemctl restart k3s'

# 6. Pull the new cluster's kubeconfig
sshpass -p 0000 ssh kalm@10.0.0.23 'echo 0000 | sudo -S cat /etc/rancher/k3s/k3s.yaml' \
  | sed 's|server: https://127.0.0.1:6443|server: https://10.0.0.23:6443|' \
  > /home/luffy/cluster-e.kubeconfig
```

You now have a new 1-node cluster on pf-013 (call it Cluster E). To add more workers, drain them from Cluster D the same way and then install **k3s-agent** on each, pointing at the new server (`K3S_URL=https://10.0.0.23:6443`, with the new server's token from `/var/lib/rancher/k3s/server/node-token`).

**Critical flags explained:**
- `--flannel-backend=host-gw` — **required**. Pixel Fold kernel lacks `CONFIG_VXLAN`. Default flannel uses VXLAN and will silently fail.
- `--cluster-cidr` / `--service-cidr` — **must be unique per cluster** to avoid IP collisions. See the reserved-CIDR table below.
- `--flannel-iface` — the Belkin USB-C-to-Ethernet interface name (different per phone). Look up with `ls /sys/class/net | grep enx | head -1` on the phone.
- `--tls-san=<server-ip>` — needed so the kubeconfig's server URL (10.0.0.x) is valid TLS-wise.

### Reserved CIDR table (to avoid IP collisions on the LAN)

| Cluster | Pod CIDR | Service CIDR |
|---|---|---|
| Cluster A (jump-host production) | 10.42.0.0/16 | 10.43.0.0/16 |
| Cluster B (Autograder team) | 10.45.0.0/16 | 10.46.0.0/16 |
| **Cluster D (yours, today)** | **10.48.0.0/16** | **10.49.0.0/16** |
| Your sub-cluster #1 (suggested) | 10.50.0.0/16 | 10.51.0.0/16 |
| Your sub-cluster #2 (suggested) | 10.52.0.0/16 | 10.53.0.0/16 |
| Your sub-cluster #3 (suggested) | 10.54.0.0/16 | 10.55.0.0/16 |

Use these CIDRs when carving out sub-clusters. Ping Raymond if you need more than 3 sub-clusters.

---

## Re-joining a sub-cluster back to Cluster D — server → worker

The reverse direction, also pressure-tested. To collapse a sub-cluster's server (e.g., pf-013) back into Cluster D as a worker:

```bash
# On the phone:
sshpass -p 0000 ssh kalm@10.0.0.23 'echo 0000 | sudo -S /usr/local/bin/k3s-uninstall.sh'  # NOT k3s-agent-uninstall
sshpass -p 0000 ssh kalm@10.0.0.23 'echo 0000 | sudo -S cp /userdata/cluster-d-assets/k3s-arm64 /usr/local/bin/k3s && echo 0000 | sudo -S chmod +x /usr/local/bin/k3s'

# Get Cluster D's join token from pf-006
TOKEN=$(sshpass -p 0000 ssh kalm@10.0.0.16 'echo 0000 | sudo -S cat /var/lib/rancher/k3s/server/node-token')

# Install k3s-agent pointing at pf-006
sshpass -p 0000 ssh kalm@10.0.0.23 "echo 0000 | sudo -S env INSTALL_K3S_SKIP_DOWNLOAD=true \
  INSTALL_K3S_EXEC=\"agent --flannel-iface=enx80691ab3551f --node-ip=10.0.0.23 --node-name=pf-013\" \
  K3S_TOKEN=$TOKEN K3S_URL=https://10.0.0.16:6443 \
  sh /userdata/cluster-d-assets/k3s-install.sh"

# Re-apply registries.yaml on the phone (uninstall wiped /etc/rancher/k3s/)
sshpass -p 0000 ssh kalm@10.0.0.23 'echo 0000 | sudo -S mkdir -p /etc/rancher/k3s && \
  echo 0000 | sudo -S cp /userdata/cluster-d-assets/registries.yaml /etc/rancher/k3s/registries.yaml && \
  echo 0000 | sudo -S systemctl restart k3s-agent'

# Re-apply Cluster D's reservation label + taint (run on the jump host)
KD=/home/luffy/cluster-d.kubeconfig
kubectl --kubeconfig=$KD label node pf-013 reservation=cluster-of-clusters-until-2026-06-12 switch=1 image=original-debian --overwrite
kubectl --kubeconfig=$KD taint nodes pf-013 reservation=cluster-of-clusters-until-2026-06-12:NoSchedule --overwrite
```

**Two different uninstall scripts to keep straight:**
- `/usr/local/bin/k3s-uninstall.sh` — for a **server** node
- `/usr/local/bin/k3s-agent-uninstall.sh` — for an **agent/worker** node

Both wipe everything in `/var/lib/rancher/k3s/`, `/etc/rancher/k3s/`, AND remove `/usr/local/bin/k3s` itself. You always need to re-copy the binary after either uninstall.

---

## K3s install gotchas we found during pressure-testing

These are things that bit us during setup; saves you the same:

1. **The uninstall scripts remove the binary at `/usr/local/bin/k3s`.** After uninstall, re-copy from **`/userdata/cluster-d-assets/k3s-arm64`** (we pre-staged it on every phone — `/userdata/` survives reboots, so it's there when you need it).
2. **`registries.yaml` gets wiped by uninstall.** Re-apply from `/userdata/cluster-d-assets/registries.yaml` after a fresh install, or the cluster can't pull from `10.0.0.1:30500`.
3. **Two different uninstall scripts.** `/usr/local/bin/k3s-uninstall.sh` for a **server** node, `/usr/local/bin/k3s-agent-uninstall.sh` for an **agent**. Wrong one errors out cleanly — just retry with the right script.
4. **The flannel-iface name varies per phone.** Look it up with `ls /sys/class/net | grep enx | head -1` — each phone's `enx*` encodes its Belkin USB-C adapter MAC. (If you want to see how the running k3s was configured, the flags are in the `ExecStart` line of `/etc/systemd/system/k3s.service` or `/etc/systemd/system/k3s-agent.service` — Cluster D was installed via `INSTALL_K3S_EXEC` env-var, not `/etc/rancher/k3s/config.yaml`, so that file does not exist on these phones.)
5. **Wait at least 15 seconds after k3s install before checking node status.** First registration with the API server takes a beat. `kubectl get nodes -w` to watch.

---

## Phone-specific gotchas (kernel/hardware constraints)

These are baked into the Pixel Fold kernel and image; nothing you can do about them, just need to know:

1. **`--flannel-backend=host-gw` is non-negotiable.** Pixel Fold kernel lacks VXLAN. Default flannel uses VXLAN; pod-to-pod cross-node traffic silently fails without `host-gw`.
2. **`iptables-legacy`, not nftables.** Kernel doesn't support nftables. K3s defaults are fine, but if you install anything else (buildah, custom networking), check `update-alternatives`.
3. **Mali GPU NULL-deref in containers** — `gpu_dvfs_kctx_init` from container-namespaced PIDs. Workaround: `hostPID: true` on GPU pods. **Not relevant to your stress-tests** (Afraz's stress-ng uses CPU+memory, no GPU).
4. **Pixel Fold containerd state corrupts on power loss.** UFS doesn't flush gracefully under UVLO. Symptom: pods can't start with `can't find shim for sandbox`. Fix: `/home/luffy/runbooks/recover-containerd-state.sh pf-XXX` from jump host.
5. **`--fastboot-ok=true` on Pixel devinfo** means `sudo reboot` drops to fastboot, not back to Linux. Manual fastboot-reboot recovery every time you reboot a phone. Talk to Raymond if you want it flipped.
6. **The phones have only 3.9 GB root partition.** Use `/userdata` (~225 GB) for any image cache, build context, or workload data >100 MB. Anything else triggers DiskPressure eviction.

---

## Operational primitives — what you have access to

| Need | Where |
|---|---|
| Cluster D kubeconfig (for jump-host kubectl) | `/home/luffy/cluster-d.kubeconfig` — server URL `https://10.0.0.16:6443` |
| Cluster D kubeconfig (for laptop kubectl via SSH tunnel) | `/home/luffy/cluster-d-laptop.kubeconfig` — server URL `https://127.0.0.1:6443`, `tls-server-name: pf-006` already set |
| SSH to jump host | `ssh luffy@132.239.17.60` (or `ssh straw-hat` with the alias) |
| SSH to a phone | `ssh kalm@10.0.0.XX` with `ProxyJump straw-hat` — `kalm` password is `0000` |
| Container registry | `http://10.0.0.1:30500` — push with `buildah push --tls-verify=false`, browse with `curl http://10.0.0.1:30500/v2/_catalog` |
| Cluster-D fleet view | `kubectl --kubeconfig=/home/luffy/cluster-d.kubeconfig get nodes -L switch,image,reservation -o wide` |
| Containerd recovery runbook | `/home/luffy/runbooks/recover-containerd-state.sh pf-XXX` (from jump host) |
| Cluster-B kubeconfig (reference) | `/home/luffy/cluster-b.kubeconfig` — useful to see what an established phone-K3s cluster looks like |
| Image build path | Build natively on a phone (NOT on your x86 laptop — qemu cross-compile silently corrupts arm64 images). `buildah build --network=host`. We can install buildah on one of your phones if you need a build host. |

---

## What we won't do for you (and why)

- **We won't write your bootstrap script for phone-K3s subdivision.** Different topologies need different bootstrap logic; the script lives in your repo. Use Parth's `bootstrap-karmada.sh` as a structural template; the K3s subdivide recipe above replaces kind primitives.
- **We won't pre-install Karmada.** You should control the version pin. Parth pinned commit `3424bc71...` for kind reproducibility — same idea on phones.
- **We won't set up your Grafana/Prometheus.** Your 4 dashboards on `blake-dev` (`k8s-control-plane.json`, `kubernetes-apiserver.json`, `kubernetes-cluster.json`, `node-exporter-full.json`) should land cleanly against Cluster D. Tahseen's Thanos investigation applies for cross-cluster federation.
- **We won't run experiments for you.** The phones are yours. How you use them is up to you.

---

## What good completion looks like

For the Final Report and the hardware-porting line item on your quarter plan, the deliverables that exist at quarter end probably want to look like:

- [ ] Cluster D used as-is (1×19) for a single-cluster baseline experiment
- [ ] At least one subdivision into ≥2 sub-clusters (proves the K3s subdivide path works on bare metal)
- [ ] Karmada installed on one of your clusters with at least one member joined
- [ ] At least one experimental run of your published topology rule on real hardware (1×N vs 3×(N/3) latency)
- [ ] A `bootstrap-phones.sh` (or equivalent) in your repo — the analog of Parth's `bootstrap-karmada.sh`, automating the subdivide recipe above
- [ ] One paragraph in the Final Report comparing kind-Karmada to phone-K3s-Karmada (kernel constraints, network topology, resource limits per node)

These map to your quarter-plan items 4–6 (KWOK refinement, automated testing pipeline, hardware porting). Hardware porting is the capstone; you don't need to finish it perfectly for the report — you need to *demonstrate the path*.

---

## Coordination with the cluster sysadmin (Raymond)

- **Before destructive moves on phones** outside the subdivide recipe (reflashing, swapping adapters, etc.): ping Raymond. He owns the fleet-level audit trail.
- **If a phone goes NotReady**: try `recover-containerd-state.sh` first. If it refuses (phone unreachable on ping), the phone needs physical attention — that's a Raymond task.
- **If you need a different image cohort** on some phones (e.g., a fresh rootfs for testing): that's image-authoring territory (Chris Crutchfield owns image builds). Raymond can route the request.
- **Audit trail**: every reservation change, every access grant gets logged in `cluster_access_management.md`. Your team's reservation was logged 2026-05-22; the Cluster D pre-build was logged 2026-05-25.

---

## Open coordination questions (for your team meeting before you dive in)

These are *your* decisions, not ours — but worth resolving early:

1. **Do you start with 1×19 or subdivide?** Cluster D as-is is the 1×19 baseline. If you go straight to a 3-cluster split, you'll use the subdivide recipe to carve out 2 sub-clusters from Cluster D.
2. **Where does Karmada-host live?** Cluster D itself (with all 19 nodes), or a small carved-out cluster (say 4 phones) with the rest as members? The host cluster's K3s server phone takes the most load — pick deliberately.
3. **Do you converge the dev branches before the hardware-port phase?** Right now `main` is empty scaffold + Afraz's stress guide; the actual work is on 4 dev branches. Reviewers cloning the team repo for the Final Report will see scaffold. Worth merging before you start the hardware port.
4. **What's Andre's contribution to this phase?** His Karmada-federation role from 4/27 has no public artifacts yet. With the hardware port being the most federation-flavored work left in the quarter, it's a natural fit if he's ready to ramp back up.

---

*Welcome packet issued by the cluster sysadmin (Raymond) on 2026-05-25 for the Cluster of Clusters team's Pixel-phone hardware-porting phase. Cluster D was pre-built and pressure-tested 2026-05-25 before this delivery — both worker→server and server→worker conversion paths were validated on real hardware. If anything here is wrong or unclear, tell Raymond — we'll fix the doc and the next research team gets a better one.*


# Cluster of Clusters — Welcome Packet Addendum (2026-05-26)

**Audience:** CofC team (Felicia, Blake, Tahseen, Afraz)
**Supplements:** `welcome_packets/cluster-of-clusters.md` (issued 2026-05-25)
**Why this exists:** Felicia requested two follow-up items after the original packet went out — CIDR slots for up to 5 sub-clusters, and an installed buildah build host for pushing images to the local registry. This addendum delivers both, with the operational recipes you'll need.

---

## Reserved CIDR table — now 5 sub-cluster slots

Use these CIDRs when carving out sub-clusters. The original packet had #1–#3; #4 and #5 are new, so you can push past your published 3-cluster threshold and test whether a 4th or 5th still helps the API SLI.

| Cluster | Pod CIDR | Service CIDR |
|---|---|---|
| Cluster A (jump-host production) | `10.42.0.0/16` | `10.43.0.0/16` |
| Cluster B (Autograder team) | `10.45.0.0/16` | `10.46.0.0/16` |
| **Cluster D (yours, today)** | **`10.48.0.0/16`** | **`10.49.0.0/16`** |
| Your sub-cluster #1 | `10.50.0.0/16` | `10.51.0.0/16` |
| Your sub-cluster #2 | `10.52.0.0/16` | `10.53.0.0/16` |
| Your sub-cluster #3 | `10.54.0.0/16` | `10.55.0.0/16` |
| **Your sub-cluster #4 (new)** | **`10.56.0.0/16`** | **`10.57.0.0/16`** |
| **Your sub-cluster #5 (new)** | **`10.58.0.0/16`** | **`10.59.0.0/16`** |

The new rows are inert until you pass them to `--cluster-cidr` / `--service-cidr` at install time. Ping me if you need more than 5.

---

## Build host: pf-007 (not pf-006)

`buildah 1.39.3` + `git` installed on **pf-007** (`10.0.0.17`).

**Why pf-007 instead of pf-006 as you asked:** pf-006 is the K3s control plane for Cluster D — the very thing your experiments are measuring. Co-locating heavy build I/O on it would leak noise into your own API-latency numbers. pf-007 is identical hardware, same switch as pf-006, one L2 hop to the registry; the only cost is one keystroke.

**Use `sudo buildah`** — image storage is configured at `/userdata/containers/storage` so the 3.9 GB root partition doesn't fill on big pulls.

---

## Pre-mirrored: nginx:alpine

`nginx:alpine` is already mirrored to `10.0.0.1:30500/nginx:alpine`. Validated end-to-end by deploying a test pod on Cluster D and pulling it from the registry — ~2.7 s pull, container started clean.

---

## Recipes

### Mirror more images from Docker Hub

```bash
ssh kalm@10.0.0.17   # password 0000, via ProxyJump straw-hat
sudo buildah pull docker://<image-ref>
sudo buildah tag <source-tag> 10.0.0.1:30500/<repo>:<tag>
sudo buildah push --tls-verify=false 10.0.0.1:30500/<repo>:<tag>
```

Verify it landed (from the jump host, since `curl` isn't on the phone):

```bash
curl http://10.0.0.1:30500/v2/_catalog
curl http://10.0.0.1:30500/v2/<repo>/tags/list
```

### Custom builds

```bash
ssh kalm@10.0.0.17
sudo buildah build --network=host -t 10.0.0.1:30500/<repo>:<tag> .
sudo buildah push --tls-verify=false 10.0.0.1:30500/<repo>:<tag>
```

**`--network=host` is non-negotiable** — the default netavark network backend fails on the Pixel Fold kernel.

### Large build contexts (>~500 MB)

`/tmp` is on the 3.9 GB root partition (~830 MB free). For large builds, redirect tmpdir to `/userdata`:

```bash
sudo mkdir -p /userdata/tmp   # one-time
sudo TMPDIR=/userdata/tmp buildah build --network=host -t 10.0.0.1:30500/<repo>:<tag> .
```

---

## Other small packet corrections (separate from your asks)

While shipping the items above, I made a couple of small corrections to the original packet:

- **Gotcha #4 about flannel-iface:** the original packet said you can read it from `/etc/rancher/k3s/config.yaml` — that file does not exist on Cluster D phones (the install used `INSTALL_K3S_EXEC` instead). Use `ls /sys/class/net | grep enx | head -1` to look it up — that path was already in the original as the fallback; the corrected version just leads with it and points at the systemd unit's `ExecStart` line if you want to see the running k3s flags.
- **Server→worker reverse recipe (re-joining a sub-cluster back to Cluster D):** the original ended with "Re-apply registries.yaml + reservation label/taint — same pattern as above." The corrected version spells that out as explicit lines (`mkdir -p /etc/rancher/k3s` + `cp` registries.yaml + `systemctl restart k3s-agent` on the phone, then `kubectl label` + `kubectl taint` from the jump host with the right values).

Neither affects what you're doing right now, but if you'd like an updated copy of the full welcome packet to replace the one you got 2026-05-25, ping me.

---

*Issued by the cluster sysadmin (Raymond) on 2026-05-26 in response to Felicia's 2026-05-26 follow-up requests. End-to-end-validated on Cluster D before delivery — see `cluster_access_management.md` 2026-05-26 audit entry.*

