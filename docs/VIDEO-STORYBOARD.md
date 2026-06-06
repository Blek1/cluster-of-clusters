# Final Project Video — Storyboard ("The Investigation")

CSE 145/237D Junkyard *Cluster of Clusters*. Target length **~4:40** (hard cap 5:00).

**Concept:** A research *investigation*. The whiteboard holds "the case," the three
experiment tiers are "leads," metrics are "evidence" (printed and held to camera),
and the conclusion is "the verdict." Tone splits two ways:

- **Playful / engaging** — cold open, transitions, the phone-multiplying animation, the v1 failure montage. Upbeat music, snappier cuts, light humor.
- **Professional / rigorous** — the three evidence slots and the verdict. Music pulls back, cuts slow, on-screen text gets clean and precise, narration steadies.

**Visual grammar:** real phone (intimate) ↔ animation (scale/concept) ↔ acted scenes (story) ↔ screen-recordings + printed graphs (evidence).

**Speakers:** each member narrates the tier they owned. Assignments below are a
starting guess — **swap to match who actually did what.**

---

## Scene-by-scene

| # | Time | Visual / Action | On-screen text | Narration (speaker) | Transition |
|---|------|-----------------|----------------|---------------------|------------|
| 1 | 0:00–0:40 | **The team.** Four of you together in a study room, relaxed. One synced on-camera group line, then a quick beat per person (name + one-line role). | Lower-thirds: name + role per person | *(synced, group):* "We're team Cluster-of-Clusters, CSE 237D." Then each: "I'm Felicia — I ran the Pixel experiments." / "Blake — observability + dashboards." / "Tahseen — control-plane scaling." / "Afraz — topology testing." | Quick cut to whiteboard |
| 2 | 0:40–1:05 | **The case.** Whiteboard. Someone uncaps a marker and writes the question; team ponders, debates silently. | Big handwritten: **"When should ONE cluster split into MANY? → and into how many?"** | *(VO, Felicia):* "We were handed a pile of phones you'd normally throw away — and one question. A single computer can only do so much before you need more. But splitting one big cluster into many isn't free. So: when is it worth it, and how far do you go?" | Everyone turns to look at the desk |
| 3 | 1:05–1:25 | **The suspect.** All eyes turn to Felicia's Pixel on the desk. **Zoom IN** on the phone. | (none) | *(VO, Felicia):* "It starts with this — a phone you'd leave in a drawer. Now picture eighteen of them, wired together, running real Kubernetes." | **ANIMATION #1:** one phone multiplies into a cluster |
| 4 | 1:25–2:15 | **Three leads.** Establish the method as three ways to investigate, each with its own look. Quick and punchy. | Tags as each appears: **KIND — simulate**, **KWOK — scale**, **PIXELS — reality** | *(VO, Afraz then Tahseen):* "We couldn't test every layout on real hardware — so we investigated in three tiers. First, **Kind**: cheap virtual clusters on a laptop to sweep dozens of topologies. Then **KWOK**: push the control plane to thousands of fake nodes to find where it breaks. Finally, the **Pixels** — the real thing." | Push into first evidence |
| 5 | 2:15–2:45 | **Evidence A — Kind.** Screen-recording of a topology test running + **over-the-shoulder huddle** of the team watching it. Then **printed-graph reveal**: hold the latency-vs-clusters chart to camera, lower it. | "Tier 1 · Simulation (Kind)" + finding caption | *(VO, Afraz):* "At small scale, one cluster wins — splitting just adds overhead. The split only starts paying off as the system grows. **[FILL: state the threshold from final chart.]**" | Printed graph → push in → dissolve to next |
| 6 | 2:45–3:10 | **Evidence B — KWOK.** Fast-scrolling terminal, node count climbing, one control-plane Grafana panel. | "Tier 2 · Scale (KWOK)" + finding caption | *(VO, Tahseen):* "Then we asked: how big can one cluster get before the control plane chokes? **[FILL: the ceiling — e.g. ~65 nodes / the QPS wall.]** That's the real reason to split — not size for its own sake." | Hard cut on a spike |
| 7 | 3:10–3:55 | **Evidence C — Pixels + the disaster.** Playful-dramatic montage: red error logs flashing, etcd dying, a beat on **`pf-006` literally failing**. Then the v2 fix. End on the real phone running. | "Tier 3 · Reality (Pixels)" → "v1 ✗ → v2 ✓" | *(VO, Felicia):* "Real hardware fought back. On the phones, the control-plane database hammered the flash storage until it died — and Android's networking dropped packets mid-boot. v1 never federated. So we rebuilt it: move the data off the tiny root partition, and the control plane finally held. **[FILL: v2 result, or 'early results — ongoing'.]**" | Slow dissolve to whiteboard |
| 8 | 3:55–4:25 | **The verdict.** Back at the whiteboard/group. Someone circles the answer. Serious tone, clean text. | Clean: **"Split when the control plane saturates — not before. Then split into the fewest clusters that clear the bottleneck."** | *(VO, Blake):* "So — when should one cluster become many? Only when a single control plane can't keep up. And how many? The fewest that clear the bottleneck — because every split has a cost. On junk hardware, that cost is exactly what decides the answer." | Pull back from desk |
| 9 | 4:25–4:40 | **Outro.** **Zoom OUT** from the phone / animation rig (bookends Scene 3). Team together. Optional playful button (the dead phone gets a tiny "RIP pf-006"). | Credits: names · CSE 145/237D · "Junkyard: Cluster of Clusters" | *(synced, group):* "Cluster of Clusters. Thanks for watching." | Fade |

Narration totals ~330 words of VO + the synced group lines — comfortably under a 5-minute read with breathing room for music and visuals.

---

## The three "evidence slots" (fill these last — start everything else now)

The narrative spine above does **not** depend on final numbers. Build the rest of the
video now; drop these in when the data lands. Each slot = one sentence + one visual.

- **Slot A — Kind (simulation):** "one cluster wins small; split pays off as you grow." → latency-vs-clusters chart. *Data mostly in `scripts/topology-testing/README.md`.*
- **Slot B — KWOK (scale):** "the control plane is the ceiling — here's where one cluster tops out." → node-count / QPS wall. *Partly in `docs/notes/felicia/EXPERIMENTS.md` (~65 nodes); KWOK run pending.*
- **Slot C — Pixels (reality):** "federation isn't free on real hardware — and here's the fix." → v1 failure → v2 fix. **Already complete in `scripts/pixels-v1/README.md` + `scripts/pixels-v2/README.md`**, even if the v2 latency table is pending. If pending, narrate as "early results — ongoing"; that still scores.

If a slot isn't ready by the deadline: phrase as "early results suggest…" + "ongoing work." The rubric grades the *connection between goals and demo*, not the polish of every number.

---

## Shoot list (group/acting — film this week, no lab needed)

All of this is shootable with Felicia's phone + a study room. Film **video and audio
separately** (see audio plan).

- [ ] Group intro, four together (Scene 1) — one or two takes with synced audio.
- [ ] Whiteboard write + ponder (Scene 2). Write the question big and clean.
- [ ] The turn-to-the-desk + zoom-in on the Pixel (Scene 3). Do a slow manual push-in; you can also punch-in in editing.
- [ ] **Over-the-shoulder / huddle while a script runs** (Scene 5) — this is the real-data capture doubling as b-roll. Run any topology/sweep script and film people watching the terminal/dashboard.
- [ ] Printed-graph held to camera, lowered, optionally circled with a marker (Scenes 5/7).
- [ ] Whiteboard "verdict" circle (Scene 8).
- [ ] Zoom-out bookend + group outro line (Scene 9).
- [ ] Optional blooper / `pf-006` button.

## Screen-recording capture (OBS — also doubles as real demo evidence)

- [ ] Kind topology test running (`scripts/topology-testing/test-topology-456.sh`) — pods rolling out, rollout-latency line.
- [ ] Grafana dashboard with a live panel moving (`scripts/observability/`).
- [ ] KWOK node count climbing + ClusterLoader2 output (`scripts/kwok-testing/`).
- [ ] Pixel run terminal / `monitor-phones.sh` if reachable, plus the v1 error logs from the README for the failure montage.
- Speed-ramp long captures so motion stays lively under VO.

## Animation (keep minimal — 1 required, 1 optional)

- [ ] **#1 (required):** one phone → multiplies into a cluster (Scene 3). The hero beat.
- [ ] **#2 (optional, reuse #1):** clusters *splitting* 1→2→3→N during Scene 4, mirroring the research question. Reuse the same assets to save editor time.

## Audio plan (protects the 3 audio points)

- Record **voiceover separately** from video — each person alone in a quiet room, mic close to mouth, in **Audacity**. Lay VO over b-roll. This avoids the room-echo / uneven-level / wind hiccups the rubric penalizes.
- Keep one or two **synced** on-camera moments (group intro + outro) for warmth; everything else is clean VO.
- Normalize all VO to the same loudness in Audacity. One music bed; duck it under narration; pull it back in the serious sections (Scenes 5–8).

## Editing / tone checklist (protects the 2 visual points)

- Consistent visual tag per tier (Kind / KWOK / Pixels) so the audience tracks which lead they're on.
- Clean, readable on-screen text for every finding; legible font, on screen long enough to read.
- No abrupt cuts on the serious sections — let evidence breathe.
- Color-match shots; avoid shaky handheld (brace the phone or use any tripod/stack of books).
- Bookend the zoom-in (Scene 3) with the zoom-out (Scene 9).

## Deliverables

- Submit on **Canvas** + drop a copy in the class **Drive folder**.
- Keep it **under 5:00**. Export 1080p.
</content>
</invoke>
