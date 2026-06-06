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
> Felicia: "I'm Felicia — I ran our experiments on real Pixel phones."
> Blake: "I'm Blake — I built the monitoring and dashboards."
> Tahseen: "I'm Tahseen — I pushed the system to scale."
> Afraz: "I'm Afraz — I tested the cluster layouts."

**[TEXT]** Lower-third name + role as each person speaks.

**Transition:** Hard cut to the whiteboard.

---

## SCENE 2 — The Case  · 0:40–1:05 · **VO over live action**

**[SHOT]** A whiteboard. One person uncaps a marker and writes the question while
the others lean in, thinking, pointing. Film it as quiet action — no talking on camera
(the VO covers it). Get a clean close-up of the finished whiteboard too.

**[TEXT on whiteboard, handwritten, large]:**
> **When should ONE cluster split into MANY?**
> **→ and into how many?**

**[VO — Felicia]:**
> "We were handed a pile of phones you'd normally throw away — and one question. A single computer can only do so much before you need more. But splitting one big system into many isn't free. So when is it actually worth it — and how far do you go?"

**Transition:** The team stops, all turn and look toward the desk.

---

## SCENE 3 — The Suspect  · 1:05–1:25 · **VO + animation**

**[SHOT]** From behind/over the group as they turn to Felicia's Pixel sitting on the
desk. Then a slow **push-in (zoom) onto the phone** until it fills the frame. (Do a
slow manual move; the editor can also punch in.)

**[VO — Felicia]:**
> "It starts with this — a phone you'd leave in a drawer. Now picture eighteen of them, wired together, running real Kubernetes."

**[ANIMATION #1 — required]:** On the line "eighteen of them," the single phone
**multiplies** into a small grid/cluster of phones. This is the hero animation.

**Transition:** The animated cluster resolves → cut into the three-leads section.

---

## SCENE 4 — Three Leads  · 1:25–2:15 · **VO over screen-recordings**

**[SHOT]** No people needed — this rides on screen-recordings (captured in OBS). Show
a quick taste of each tier as it's named:
- **Kind:** terminal spinning up clusters on a laptop.
- **KWOK:** fast-scrolling terminal, node count climbing.
- **Pixels:** the real phone / a terminal connected to it.

**[TEXT]** As each appears: **"KIND — simulate"**, then **"KWOK — scale"**, then **"PIXELS — reality"**.

**[VO — Afraz, then Tahseen]:**
> (Afraz) "We couldn't test every possible layout on real hardware — so we investigated in three tiers. First, **Kind**: cheap virtual clusters on a laptop, so we could sweep dozens of layouts fast."
> (Tahseen) "Then **KWOK**, to push the control plane to thousands of fake nodes and find where it breaks. And finally — the real Pixels."

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
> "At small scale, one cluster actually wins — splitting just adds overhead. The split only starts to pay off as the system grows. **[FILL IN: state the threshold from the final chart.]**"

**Transition:** Push into the printed graph → dissolve to Scene 6.

---

## SCENE 6 — Evidence B: KWOK  · 2:45–3:10 · **VO over screen-recording**

**[SHOT]** OBS capture: fast terminal with the node count climbing, plus one Grafana
control-plane panel moving. Speed-ramp it so it feels alive.

**[TEXT]** "Tier 2 · Scale (KWOK)" + finding caption.

**[VO — Tahseen]:**
> "Then we asked the other direction: how big can a single cluster get before the control plane chokes? **[FILL IN: the ceiling — e.g. around 65 nodes, or the request-rate wall.]** That's the real reason to split — not size for its own sake, but the moment one brain can't keep up."

**Transition:** Hard cut on a spike in the graph.

---

## SCENE 7 — Evidence C: Pixels + the Disaster  · 3:10–3:55 · **VO over montage**

**[SHOT]** Playful-dramatic montage:
- Red error logs flashing by (screen-recording / scroll the v1 logs from the README).
- A beat on the real phone.
- A small dramatic moment for **`pf-006` failing** (the phone that literally died).
- Then the "fix" — calmer shot of the real phone running steadily.

**[TEXT]** "Tier 3 · Reality (Pixels)" → then "v1 ✗ → v2 ✓".

**[VO — Felicia]:**
> "Real hardware fought back. On the phones, the control-plane database hammered the cheap flash storage until it gave out — and Android's networking dropped packets mid-startup. Our first version never came together. So we rebuilt it: move the heavy data off the tiny system partition, and the control plane finally held. **[FILL IN: v2 result — or 'these results are still coming in.']**"

**Transition:** Slow dissolve back to the whiteboard.

---

## SCENE 8 — The Verdict  · 3:55–4:25 · **VO over live action**

**[SHOT]** Back at the whiteboard or the group together. Someone circles / writes the
answer. Calm, deliberate — this is the serious payoff. No talking on camera (VO covers).

**[TEXT, clean]:**
> **Split when the control plane saturates — not before.**
> **Then split into the fewest clusters that clear the bottleneck.**

**[VO — Blake]:**
> "So — when should one cluster become many? Only when a single control plane can't keep up. And how many? The fewest that clear the bottleneck — because every split has a cost. On junk hardware, that cost is exactly what decides the answer."

**Transition:** Camera pulls back from the desk.

---

## SCENE 9 — Outro  · 4:25–4:40 · **LIVE audio + animation**

**[SHOT]** **Zoom OUT** from the phone / animated cluster (mirrors Scene 3's zoom-in)
until the team is back in frame together. Optional playful button: a tiny "RIP pf-006"
card or blooper.

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
