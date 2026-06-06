# Video Shoot Script — step-by-step run sheet

Follow this top to bottom. For each scene you get: **what to film**, **audio type**
(LIVE = recorded on camera in the moment · VO = voiceover recorded separately in
Audacity and laid over later), the **exact words** to say, the **on-screen text**,
and the **transition** into the next scene.

**Two recording passes:**
1. **Film pass** — shoot all the video (some scenes capture LIVE audio too).
2. **VO pass** — afterwards, each person reads their VO lines alone in a quiet room, mic close to mouth, into Audacity. Editor lays VO over the footage.

Legend: **[LIVE]** = say it on camera, mic rolling · **[VO]** = record later, no need to say it while filming · **[TEXT]** = on-screen caption · **[SHOT]** = what the camera does.

Speaker names are a starting guess — **reassign to whoever owned each tier.**

Total target: **~4:40** (hard cap 5:00).

---

## SCENE 1 — The Team  · 0:00–0:40 · **LIVE audio**

**[SHOT]** All four of you together in a study room, relaxed, facing camera. Static
shot on a tripod (or phone braced on books). Good even lighting, no window glare behind you.

**[LIVE — group, together, looking at camera]:**
> "Hi — we're the Cluster of Clusters team, CSE 237D."

**Then each person, one at a time (small step forward or just a beat):**
> Felicia: "I'm Felicia — I ran our experiments on the physical Pixel cluster."
> Blake: "I'm Blake — I built the monitoring and dashboards."
> Tahseen: "I'm Tahseen — I pushed the system to scale."
> Afraz: "I'm Afraz — I tested the cluster layouts."

**[TEXT]** Lower-third name + role as each person speaks.

**Transition:** Hard cut to the whiteboard.

---

## SCENE 2 — The Question  · 0:40–1:05 · **VO over live action**

**[SHOT]** A whiteboard. One person uncaps a marker and writes the question while
the others lean in, thinking, pointing. Film it as quiet action — no talking on camera
(the VO covers it). Get a clean close-up of the finished whiteboard too.

**[TEXT on whiteboard, handwritten, large]:**
> **When should ONE cluster split into MANY?**
> **→ and into how many?**

**[VO — Felicia]:**
> "Our project looks at a core question in distributed systems: when should a single Kubernetes cluster be split into several smaller ones — and into how many? One cluster can only handle so much before its control plane becomes a bottleneck. But splitting has its own cost. We set out to find where that trade-off tips."

**Transition:** The team stops, all turn and look toward the desk.

---

## SCENE 3 — The Hardware  · 1:05–1:25 · **VO + animation**

**[SHOT]** From behind/over the group as they turn to Felicia's Pixel sitting on the
desk. Then a slow **push-in (zoom) onto the phone** until it fills the frame. (Do a
slow manual move; the editor can also punch in.)

**[VO — Felicia]:**
> "We run these experiments on a cluster of Pixel phones — low-power, low-cost hardware that's a realistic stand-in for edge devices. Picture eighteen of them running Kubernetes together."

**[ANIMATION #1 — required]:** On the line "eighteen of them," the single phone
**multiplies** into a small grid/cluster of phones. This is the hero animation.

**Transition:** The animated cluster resolves → cut into the three-leads section.

---

## SCENE 4 — Three Lines of Investigation  · 1:25–2:15 · **VO over screen-recordings**

**[SHOT]** No people needed — this rides on screen-recordings (captured in OBS). Show
a quick taste of each tier as it's named:
- **Kind:** terminal spinning up clusters on a laptop.
- **KWOK:** fast-scrolling terminal, node count climbing.
- **Pixels:** the real phone / a terminal connected to it.

**[TEXT]** As each appears: **"KIND — simulate"**, then **"KWOK — scale"**, then **"PIXELS — reality"**.

**[VO — Afraz, then Tahseen]:**
> (Afraz) "Testing every layout on physical hardware isn't practical, so we investigated in three tiers. First, **Kind** — lightweight virtual clusters on a laptop — to compare many layouts quickly."
> (Tahseen) "Then **KWOK**, to simulate thousands of nodes and find the control plane's limits. And finally, the physical Pixel cluster."

**Transition:** Push into the first piece of evidence.

---

## SCENE 5 — Evidence A: Kind  · 2:15–2:45 · **VO + LIVE-ish b-roll**

**[SHOT]** Two parts:
1. **Over-the-shoulder huddle** — the team gathered around a laptop while a topology
   script actually runs (`scripts/topology-testing/test-topology-456.sh`). Film people
   watching, pointing, reacting. *(This is your real-data capture AND your group b-roll.)*
2. **Printed-graph reveal** — someone holds the printed latency-vs-clusters chart up to
   camera, then lowers it. Optional: circle the key point with a marker on camera.

**[TEXT]** "Tier 1 · Simulation (Kind)" + a caption with the finding.

**[VO — Afraz]:**
> "At small scale, a single cluster performs best — splitting only adds overhead. The benefit appears as the system grows larger. **[FILL IN: state the threshold from the final chart.]**"

**Transition:** Push into the printed graph → dissolve to Scene 6.

---

## SCENE 6 — Evidence B: KWOK  · 2:45–3:10 · **VO over screen-recording**

**[SHOT]** OBS capture: fast terminal with the node count climbing, plus one Grafana
control-plane panel moving. Speed-ramp it so it feels alive.

**[TEXT]** "Tier 2 · Scale (KWOK)" + finding caption.

**[VO — Tahseen]:**
> "We also looked at the upper limit: how large a single cluster can grow before the control plane becomes the bottleneck. **[FILL IN: the ceiling — e.g. around 65 nodes, or the request-rate limit.]** That's the real trigger for splitting — not size alone, but the point where one control plane can't keep up."

**Transition:** Hard cut on a spike in the graph.

---

## SCENE 7 — Evidence C: Pixels (Hardware Limits)  · 3:10–3:55 · **VO over screen-recording**

**[SHOT]** Two parts, calm and factual:
- The v1 error logs scrolling (screen-recording / the v1 logs from the README).
- Then the stable v2 run — the real phone / a terminal showing the control plane staying up.

**[TEXT]** "Tier 3 · Reality (Pixels)" → then "v1 → v2".

**[VO — Felicia]:**
> "Physical hardware introduced constraints the simulations didn't. The control-plane database was bottlenecked by the phones' flash-storage I/O, and the networking stack dropped packets during startup. Our first version couldn't sustain the federation, so we re-architected it — moving the data store off the constrained system partition let the control plane stabilize. **[FILL IN: v2 result — or 'these results are still coming in.']**"

**Transition:** Slow dissolve back to the whiteboard.

---

## SCENE 8 — The Verdict  · 3:55–4:25 · **VO over live action**

**[SHOT]** Back at the whiteboard or the group together. Someone circles / writes the
answer. Calm, deliberate — this is the serious payoff. No talking on camera (VO covers).

**[TEXT, clean]:**
> **Split when the control plane saturates — not before.**
> **Then split into the fewest clusters that clear the bottleneck.**

**[VO — Blake]:**
> "So — when should one cluster become many? Only when a single control plane can't keep up. And how many? The fewest that clear the bottleneck — because every split adds overhead. On constrained hardware, that overhead is what decides the answer."

**Transition:** Camera pulls back from the desk.

---

## SCENE 9 — Outro  · 4:25–4:40 · **LIVE audio + animation**

**[SHOT]** **Zoom OUT** from the phone / animated cluster (mirrors Scene 3's zoom-in)
until the team is back in frame together. Optional light blooper at the very end.

**[LIVE — group, together]:**
> "Cluster of Clusters. Thanks for watching!"

**[TEXT]** Credits: all four names · CSE 145/237D · "Junkyard: Cluster of Clusters"

**Transition:** Fade to black.

---

## Quick reference — what's LIVE vs VO

| Scene | Audio | Who speaks |
|-------|-------|-----------|
| 1 Team | **LIVE** | group + each person |
| 2 Case | VO | Felicia |
| 3 Suspect | VO | Felicia |
| 4 Leads | VO | Afraz, Tahseen |
| 5 Kind | VO | Afraz |
| 6 KWOK | VO | Tahseen |
| 7 Pixels | VO | Felicia |
| 8 Verdict | VO | Blake |
| 9 Outro | **LIVE** | group |

## Before you hit record

- **Props:** whiteboard + markers, Felicia's Pixel, a printed graph (matte paper, big/simple, one highlighted point), laptop with a script ready to run, tripod or something to brace the phone.
- **Film video and audio separately** — only Scenes 1 and 9 need on-camera sound. Everything else is silent acting + VO added later.
- **VO pass:** each person records their lines alone, quiet room, mic close, in Audacity. Normalize everyone to the same loudness.
- Three **[FILL IN]** spots (Scenes 5, 6, 7) wait on final data — record placeholder VO now, re-record those three lines when numbers land. If a number isn't ready by the deadline, say "early results suggest…" — that still scores.
- Keep it **under 5:00**, export 1080p, submit on **Canvas** + drop a copy in the **Drive folder**.
</content>
