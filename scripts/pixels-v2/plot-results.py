#!/usr/bin/env python3
"""
plot-results.py — turn a sweep CSV into the two figures that tell the story.

Run where sweep-results.csv lives (the jump host, $VAR_DIR/sweep-results.csv):

    python3 plot-results.py [path/to/sweep-results.csv]

Reads the CSV produced by sweep.sh and writes two PNGs next to it:

  latency-vs-workload.png  — rollout latency vs workload size, one line per
       topology (log-x). This is the main figure: the lines cross at the split
       threshold, fan out as the federation win grows with load, and the
       federated lines stop where the workload no longer fits (FAIL).
  members-knee.png         — latency vs member-cluster count at the largest
       workload every federated topology survives. Isolates the diminishing
       returns past ~3 members, against the baseline as a reference line.

CSV note: sweep.sh's `split` column itself contains commas ("6,6,6"), so the
rows are not cleanly delimited (e.g. `3,6,6,6,500,1,11`). We parse by position
instead: first field = topology, last three = replicas, repeat, latency.
Requires matplotlib (`pip install matplotlib`).
"""

import os
import sys
from collections import defaultdict
from statistics import median

import matplotlib
matplotlib.use("Agg")  # headless: the jump host has no display
import matplotlib.pyplot as plt
import matplotlib.ticker


def topo_label(n):
    """1 -> baseline (no Karmada); N>=2 -> 'N members'."""
    return "baseline" if n <= 1 else f"{n} members"


def load(csv_path):
    """Return {(topology, replicas): latency_or_None}, medianed over repeats.

    latency is None when every repeat of that cell FAILed.
    """
    runs = defaultdict(list)  # (topo, replicas) -> [latency, ...] (FAILs dropped)
    seen = set()              # every (topo, replicas) cell, FAIL or not
    with open(csv_path) as fh:
        for raw in fh:
            line = raw.strip()
            if not line or line.startswith("topology,"):
                continue
            f = line.split(",")
            if len(f) < 5:
                continue  # malformed; skip
            # Parse by position so commas inside `split` don't shift the columns.
            topo = int(f[0])
            replicas = int(f[-3])
            latency = f[-1]
            seen.add((topo, replicas))
            if latency.upper() != "FAIL":
                runs[(topo, replicas)].append(float(latency))

    cells = {}
    for cell in seen:
        vals = runs.get(cell, [])
        cells[cell] = median(vals) if vals else None
    return cells


def plot_latency_vs_workload(cells, out_path):
    topos = sorted({t for (t, _) in cells})
    workloads = sorted({w for (_, w) in cells})

    fig, ax = plt.subplots(figsize=(8, 5))
    # baseline bold/dark; members on a sequential colormap so "more = cooler".
    member_topos = [t for t in topos if t > 1]
    cmap = plt.get_cmap("viridis")
    colors = {}
    for i, t in enumerate(member_topos):
        colors[t] = cmap(0.15 + 0.7 * (i / max(1, len(member_topos) - 1)))

    fails = []  # (workload, color) to mark with an x at the top
    ymax = 0
    for t in topos:
        xs, ys = [], []
        for w in workloads:
            lat = cells.get((t, w))
            if lat is None:
                if (t, w) in cells:  # cell exists but FAILed
                    fails.append((w, colors.get(t, "black")))
                continue
            xs.append(w)
            ys.append(lat)
            ymax = max(ymax, lat)
        if not xs:
            continue
        if t <= 1:
            ax.plot(xs, ys, "o-", color="black", lw=2.4, ms=7,
                    label=topo_label(t), zorder=5)
        else:
            ax.plot(xs, ys, "o-", color=colors[t], lw=1.8, ms=6,
                    label=topo_label(t))

    # Split threshold: smallest workload where any federated topology beats baseline.
    threshold = None
    for w in workloads:
        base = cells.get((1, w))
        if base is None:
            continue
        fed = [cells[(t, w)] for t in member_topos if cells.get((t, w)) is not None]
        if fed and min(fed) < base:
            threshold = w
            break
    if threshold is not None:
        ax.axvline(threshold, color="gray", ls="--", lw=1, zorder=0)
        ax.text(threshold, ymax * 0.97, " split threshold",
                color="gray", fontsize=9, va="top", ha="left")

    # Mark FAILed federated cells with an x near the top so the cliff is visible.
    if fails:
        fy = ymax * 1.06
        for w, c in fails:
            ax.plot(w, fy, marker="x", color=c, ms=9, mew=2.5, zorder=6)
        ax.plot([], [], marker="x", color="gray", ls="none", ms=9, mew=2.5,
                label="failed to schedule")

    ax.set_xscale("log")
    ax.set_xticks(workloads)
    ax.get_xaxis().set_major_formatter(matplotlib.ticker.ScalarFormatter())
    ax.set_xlabel("Workload (pods)")
    ax.set_ylabel("Rollout latency (s)")
    ax.set_title("Rollout latency vs workload size, by topology")
    ax.grid(True, which="both", ls=":", alpha=0.4)
    ax.legend(title="topology")
    fig.tight_layout()
    fig.savefig(out_path, dpi=150)
    print(f"wrote {out_path}")


def plot_members_knee(cells, out_path):
    member_topos = sorted({t for (t, _) in cells if t > 1})
    workloads = sorted({w for (_, w) in cells})

    # Pick the largest workload every member topology survives (most interesting knee).
    knee_w = None
    for w in reversed(workloads):
        if member_topos and all(cells.get((t, w)) is not None for t in member_topos):
            knee_w = w
            break
    if knee_w is None:
        print("members-knee: no workload survived by all member topologies; skipping")
        return

    xs = member_topos
    ys = [cells[(t, knee_w)] for t in xs]

    fig, ax = plt.subplots(figsize=(7, 5))
    ax.plot(xs, ys, "o-", color="#2b8cbe", lw=2, ms=8, label="federated")
    for x, y in zip(xs, ys):
        ax.annotate(f"{y:g}s", (x, y), textcoords="offset points",
                    xytext=(0, 8), ha="center", fontsize=9)

    base = cells.get((1, knee_w))
    if base is not None:
        ax.axhline(base, color="black", ls="--", lw=1.5,
                   label=f"baseline ({base:g}s)")

    ax.set_xticks(xs)
    ax.set_xlabel("Member clusters")
    ax.set_ylabel("Rollout latency (s)")
    ax.set_title(f"Diminishing returns past ~3 members ({knee_w} pods)")
    ax.grid(True, ls=":", alpha=0.4)
    ax.legend()
    fig.tight_layout()
    fig.savefig(out_path, dpi=150)
    print(f"wrote {out_path}")


def main():
    csv_path = (sys.argv[1] if len(sys.argv) > 1
                else os.environ.get("SWEEP_CSV", "sweep-results.csv"))
    if not os.path.isfile(csv_path):
        sys.exit(f"CSV not found: {csv_path}\n"
                 f"Pass the path as an argument or set $SWEEP_CSV "
                 f"(sweep.sh writes it to $VAR_DIR/sweep-results.csv).")

    cells = load(csv_path)
    if not cells:
        sys.exit(f"no data rows parsed from {csv_path}")

    out_dir = os.path.dirname(os.path.abspath(csv_path))
    plot_latency_vs_workload(cells, os.path.join(out_dir, "latency-vs-workload.png"))
    plot_members_knee(cells, os.path.join(out_dir, "members-knee.png"))


if __name__ == "__main__":
    main()
