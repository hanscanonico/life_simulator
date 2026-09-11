# Design record

Dated entries that revise `docs/DESIGN.md`. Newest last.

- 2026-09-10 — Initial design of record written (Soup substrate, observables, sweep
  order, Rails + Rust architecture, mini-pc deployment).
- 2026-09-10 — First results: on 128×128 for 20 000 epochs, no run at mutation rates
  2^-16 and 2^-15 transitioned (compress_ratio ≈ 0.91, op_density ≈ 0.13, no replicator).
  Before reading any sweep as a negative result, a **positive control** must show the
  engine reproduces the published BFF emergence at all: experiment `bff-control`
  (2^17 tapes as a 512×256 torus, radius 0 = well-mixed, 64-byte tapes, 8192 steps,
  50 000 epochs, mutation 0 and default, 3 seeds each, sparse snapshots). Queued in
  production; runs behind sweeps 1–3 until run priority lands. If it never transitions,
  suspect the interpreter or the pairing rule, not the hypothesis.
- 2026-09-10 — Snapshot retention: full-world snapshots at every `snapshot_every` are
  kept only while a run is live (they are its resume point); terminal runs keep the
  first, the last, every 10th and the one nearest the transition.
- 2026-09-11 — Sweep 1 (mutation rate) finished: 100 runs, 128×128, 20 000 epochs, five
  transitioned (rate 2^-13 at epochs 5030 and 7000, 2^-12 at 15560, 2^-9 at 10670, 2^-8
  at 18080). The engine does reproduce spontaneous emergence of self-replicators from a
  random soup with no fitness function. The **window hypothesis of §1.3 item 1 is treated
  as not supported at this scale**: emergence appeared at four rates spread over five
  octaves, about one seed in ten wherever it appeared, with no peak between them and no
  upper error threshold inside the swept range. Only a lower cutoff is hinted at — 0 of 40
  runs at rates ≤ 2^-14 against 5 of 60 at ≥ 2^-13, one-sided Fisher p ≈ 0.073, a split
  chosen after seeing the data — so it is suggestive, not established. With 95 of 100 runs
  censored at 20 000 epochs the sweep measured censoring more than rate; `mutation-rate-long`
  (60 000 epochs at 2^-14…2^-11), `world-size` and the `bff-control` positive control are
  what will turn one-seed-in-ten into a number. Later sweeps hold the rate at 2^-13
  (`Lab::EMERGENT_MUTATION_RATE`) because that is where emergence was first seen, not
  because it is optimal. The `replicator_count` detector fired in only three of the five
  transitioned runs and ends at zero in all five, so `transition_epoch` remains a
  tape-statistics signature rather than a census of copiers; `bff-control` is still the
  gate on reading any flat arm as a negative result.
- 2026-09-11 — Sweep 3 (neighbourhood radius) finished: 40 runs, 128×128, 20 000 epochs,
  mutation 2^-12, radii 1, 2, 4 and 0 (well-mixed), ten seeds each. Six transitioned —
  radius 1 at 15 560, radius 2 at 12 330, radius 4 at 5 910 and 11 250, well-mixed at
  11 030 and 12 400. The **speed half of §1.3 item 3 is treated as not supported**: the
  well-mixed arm, with no locality at all, transitioned as often as the best local arm and
  the tightest arm did worst. The resolution is the caveat — 2 of 10 against 1 of 10 is a
  one-sided Fisher p = 0.5, and ten seeds cannot reach p < 0.05 until an arm shows 4
  transitions where another shows none — so this rules out a large effect, not a small one.
  Reported alongside it, and not over-read: among the runs that never transitioned the final
  compress_ratio falls monotonically with a cell's reach (0.951, 0.901, 0.860 at radii 1, 2
  and 4) with the well-mixed arm at 0.859, the end of that trend rather than an exception to
  it, and entropy_bits orders the arms the same way. It is a statement about the
  pre-emergence soup. One of the six transitions does not hold: the radius-2 run climbs back
  above the 0.6 line after roughly two thousand epochs and ends where the censored runs are,
  so a transition in the §1.2 sense is a state a world can leave. Determinism is confirmed
  in passing: radius 1 is the engine's default, so that arm repeats the mutation-rate
  sweep's 2^-12 arm and the world-size sweep's 128² arm, and all ten seeds reproduce digit
  for digit across the three experiments — the `(params, seed)` guarantee of §1.1, checked
  rather than asserted, and a reminder that the arm is not an independent sample. The
  **diversity half of item 3 — does locality keep a world diverse after emergence — is left
  open**: it is a question about the transitioned runs' distinct_tapes and top_share series
  and six runs over four arms are too thin to answer it. The survival/hazard section of the
  sweep page is the lens for the speed question once more seeds exist.
- 2026-09-11 — **§1.3 item 2, world size, read as a per-cell hazard.** 40 runs at the
  engine defaults (mutation_rate 2^-12, radius 1, 20 000 epochs, 10 seeds per arm):
  transitions 0/10 at 32², 0/10 at 64², 1/10 at 128² (seed 9, epoch 15 560) and 3/10 at
  256² (seed 5 at 4 730, seed 1 at 15 800, seed 3 at 19 550). **Emergence gets more likely
  as the world gets bigger**, and the reading recorded is a hazard per cell-epoch rather
  than per world: scaled from the single 128² event, a constant per-cell hazard predicts
  0.06, 0.26, 1 and 3.7 events against the observed 0, 0, 1 and 3, while a constant
  per-world hazard would put about 2 of the 4 events in the two smallest arms, where none
  fell — a coincidence of probability ≈ 0.13, so that rival is disfavoured and not
  excluded. Pooled hazard 2.5e-10 per cell-epoch (exact Poisson 95% 0.7e-10–6.4e-10) on 4
  events and 1.6e10 cell-epochs at risk; 128² alone 3.1e-10, 256² alone 2.5e-10. **Four
  events cannot measure the exponent**, so the sign is claimed and linearity is not. The
  earliest transition of the whole programme so far, epoch 4 730, is a 256² run. Only 256²
  has a replicator census behind its flags (3 of 3); the single 128² flag is another
  collapse with a census of zero. Size does not move the pre-emergence soup: censored runs
  end at compress_ratio 0.93–0.96 in every arm, unlike the radius sweep, whose floor moved
  0.951 → 0.859. The 128² arm is all defaults, so it repeats the mutation-rate 2^-12 arm
  and the radius-1 arm digit for digit — a `(params, seed)` check and a reminder that
  10 of the 40 runs are not an independent sample. Held at **partial**: two 256² runs are
  resuming from snapshots after a deploy (their transitions are already recorded and fell
  before the epochs they have reached, so the counts and the hazard do not depend on them),
  and every arm is heavily censored at 20 000 epochs. The direct extension is the
  `bff-control` 2^17-cell soup; the survival/hazard section of the sweep page is the lens.
- 2026-09-11 — **`mutation-rate-long`, the 60 000-epoch re-run of §1.3 item 1, read as
  rare rather than slow.** The four rates around sweep 1's transitions (2^-14…2^-11) on
  the same 128×128 world, 10 seeds each, 60 000 epochs, snapshot_every 500; a run repeats
  its sweep-1 counterpart byte for byte to epoch 20 000, so the two sweeps are nested and
  the overlap is not counted twice. 37 of 40 terminal at the time of writing, the other 3
  already past their transitions and their census peaks. Eight runs flagged, six
  census-confirmed (0/10, 2/10, 3/10, 1/10 from 2^-14 up; 15% overall): 2^-13 seed 1 at
  5 030 (peak census 867) and seed 5 at 7 000 (108); 2^-12 seed 9 at 15 560 (57), seed 10
  at 21 540 (123) and seed 2 at 47 820 (105); 2^-11 seed 10 at 42 730 (36). **Sweep 1's
  reading is confirmed and its count was low**: three of the six confirmed transitions
  land after epoch 20 000, and 3 events in the first 20 000 epochs against 3 more in the
  next 40 000 is a roughly constant hazard per epoch — rare, not a slow start. The 2^-12
  seed 9 run, which three earlier sweeps all recorded as flagged with an empty census,
  counts its first replicating cell at 26 140 and peaks at 57: **that class of
  disagreement can be a budget artefact**. The 2^-14 arm is still census-silent at three
  times the budget, so sweep 1's hinted lower cutoff is not a censoring artefact — but 10
  seeds bound a hazard rather than abolishing it. Two flagged runs keep an empty census
  (2^-14 seed 3 at 39 320, final compress_ratio 0.900; 2^-12 seed 5 at 43 220, final
  0.951), and 2^-12 seed 10 shows **emergence is a state a world can leave**: census peak
  123 at 28 100, then back to compress_ratio 0.952 with all 16 384 tapes distinct by
  60 000. The window of item 1 stays **not supported**: 0, 2, 3 and 1 of 10 has a floor
  and no resolvable peak. Held at **partial** while runs remain on the clock; the write-up
  reads its denominator from the database at render time.
- 2026-09-11 — **`alphabet_size` added to §1.2, and the transition criterion guarded
  against alphabet collapse.** Production run 183 (`bff-control`, 2^17 cells, radius 0,
  `mutation_rate` 0, seed 3) was flagged at epoch 7 400 on `compress_ratio` 0.143 while
  nothing replicated: only `+` and `-` can mint a byte value, so with no mutation the byte
  alphabet is a one-way coalescent, and a well-mixed world has no refuges — 256 distinct
  values fell to 31 by epoch 8 000 and to 2 (`{` and `.`) by 12 000, which is why
  `op_density` reads exactly 1.0 and `copy_rate` 0. Low byte entropy compresses like a
  colony does. So the world reports `alphabet_size` (distinct byte values, 1–256, read off
  the histogram `op_density` and `entropy_bits` already share), and a sample counts towards
  a transition only if `compress_ratio < 0.6` **and** `op_density <= 0.9` **and**
  `alphabet_size >= 16`; the hold of 3 further samples is unchanged. The engine's tracker
  stays the single authority — Rails re-reads stored samples by the same rule, with only
  the `op_density` half available on samples recorded before the observable existed.
  Stored `transition_epoch` values are left alone: `rake lab:transition_audit` lists the
  runs whose transition the guard would no longer accept, for a human to decide on.
- 2026-09-11 — **`max-steps`, §1.3 item 4, read as non-monotone in the interaction budget.**
  Four budgets two octaves apart (2^8, 2^10, 2^13, 2^16) on a 128×128 world at mutation
  rate 2^-13, 10 seeds each, 20 000 epochs, all 40 terminal. Emergence appears in one
  arm only: 8 192 steps, 2 of 10 seeds — seed 1 at epoch 5 030 (first cell 4 890,
  census peak 867 at 5 080, copy_rate peak 0.0474, entropy floor 4.85 bits, final
  compress_ratio 0.26) and seed 5 at 7 000 (first cell 7 030, census peak 108 at 9 580,
  final compress_ratio 0.054, 2 406 distinct tapes). **The floor reading of item 4 is
  not supported**: 65 536 steps, eight times the compute of the only arm that works,
  produces nothing, and 256 and 1 024 are not part-way to a collapse but untouched soup
  (entropy never below 7.77 against a 7.94 baseline, final compress_ratio 0.921–0.984,
  16 379–16 384 of 16 384 tapes distinct). Single-cell copy_rate blips (6.1e-05, one
  copying interaction in the epoch's 16 384) appear in 12 of the 38 silent runs and
  never yield a replicator, but they are **not evenly spread**: 1, 2, 4 and 5 runs from
  the narrowest arm to the widest.
  Detector and census **agree in every arm** — zero disagreements, unlike sweeps 1 and
  2. The 8 192 arm is the engine's default budget, so it repeats the `mutation-rate`
  and `mutation-rate-long` 2^-13 arms epoch for epoch and peak for peak — a third
  determinism check, and a caveat: 30 runs of new evidence and 10 of a repeat, with the
  only events in the repeated arm. Statistics are thin: each 0/10 arm bounds its rate
  only to ≈0–26% (one-sided 95% Clopper–Pearson 0.259) and 2/10 against 0/10 is Fisher
  one-sided p = 0.24, so the peak is located to within a factor of 64. **The budget is
  spent, not merely bought.** Throughput measured from the sample stream (epochs
  between two writes over the seconds between them, gaps over 300 s dropped, covering
  18 000–19 900 epochs of each run) is 74.4, 62.6, 29.5 and 6.0 epochs/s from the
  narrowest arm to the widest, under a comparable shared load of ~12, 12, 10 and 12
  runs in flight — an epoch at 65 536 costs ~12× an epoch at 256, and the marginal
  price is near constant at 3.3, 2.5 and 2.3 µs per extra step per epoch, which is what
  interactions cut off by the ceiling look like. The two transitioned runs are their
  arm's slowest and each slowed at its own crossing (31.0 → 14.7 and 32.5 → 2.6
  epochs/s) under *lower* concurrency than before it. Proposed, not committed: a finer
  grid 2 048–32 768 at 20 seeds. Held at **partial** — not for outstanding runs but
  because every arm is censored at 20 000 epochs and the `bff-control` census is
  unresolved; the write-up reads its denominator from the database at render time.
- 2026-09-11 — **The evolution programme: §1 extended past emergence into four rungs.**
  §1's question stops at "does a self-replicator appear". Every sweep so far answers it,
  and the answer is yes but rare. What the instrument is for from here is the ladder above
  that event, and this entry locks the rungs, the observable that makes each one
  measurable, and the sweep that can refute each one. **Intelligence is the direction of
  travel, not a deliverable**: nothing below is a claim that the soup will compute
  anything, only that each rung is the next thing that can be measured.
  1. **Persistence** — a colony that does not collapse. Already refutable with what the
     engine records: `replicator_count` over the samples after a transition, its
     **census peak** (that maximum, and the first epoch reaching it), and whether its
     samples keep qualifying by §1.2 — `compress_ratio` under 0.6 with both collapse
     guards clear, so that an alphabet that coalesced never reads as a colony that
     held. A **relapse** — a transitioned world climbing back to a random soup — is not
     hypothetical: the radius sweep's radius-2 run and `mutation-rate-long`'s 2^-12
     seed 10 (census peak 123 at 28 100, all 16 384 tapes distinct again by 60 000)
     both did it. The gap is that nothing measures how long a colony held: Rails
     derives the census peak from stored samples (`Findings::ShowPage`) and re-reads
     the engine's transition rule by it (`Runs::TransitionEpochService`), and that is
     all. **Persistence** as a per-run observable — how many epochs a run held a
     non-zero census and a qualifying sample — is not yet in the engine, and by §2 the
     engine has to be the one that measures it. Sweep: `persistence`, the transitioned
     parameter points (128², 2^-13) at 20 seeds and a budget several times 60 000.
     Hypothesis: **the hazard of relapse is constant per epoch** — a colony is never
     established, it is only lucky so far. Refuted if the relapse hazard falls with
     colony age.
  2. **Heredity with variation** — lineages that share ancestry and drift apart. A
     **lineage** is a set of tapes descended by copying from one ancestor; its **lineage
     id** is the FNV-1a hash of the tape's instruction skeleton, which the engine already
     computes in `render.rs` to colour a cell and which no observable records. The **modal
     tape** is the single most common tape in the world — `top_share` reports its share
     and nothing reports its identity outside a snapshot. Both are cheap to promote from a
     rendering detail to recorded observables; neither exists as one today, and a
     skeleton hash is an approximation of descent, not descent itself. Sweep:
     `lineage-diversity`, which is the diversity half of §1.3 item 3 left open on
     2026-09-11, re-run at the emergent rate with enough seeds to have transitions in
     every arm. Hypothesis: **after a transition a world stays polyphyletic, and the
     number of surviving lineage ids grows with a cell's reach shrinking** — locality
     keeps lineages apart. Refuted if every transitioned world collapses to one lineage id
     whatever the radius.
  3. **Adaptation** — later replicators outcompeting earlier ones. Observables: the
     turnover of the modal tape and of the dominant lineage id, `copy_rate` (already
     recorded, §1.2), and **copy cost**, the mean interpreter steps an interaction spends
     before a byte-exact copy lands. Copy cost is new. The `max-steps` entry of 2026-09-11
     showed the budget is spent rather than merely bought (~12× the wall time from 2^8 to
     2^16 steps), so steps are the substrate's only currency and a cheaper copier is what
     "fitter" can mean here without smuggling in a fitness function. Sweeps:
     `adaptation`, reading copy cost along the epochs after a transition — hypothesis:
     **copy cost of the dominant lineage falls over a run**, refuted if it is flat or
     rises; and `instruction-cost`, the first substrate bet — an optional per-instruction
     price parameter, **default 0, which is today's substrate exactly** — hypothesis: **a
     positive instruction cost steepens that fall**, refuted if costed arms trace the same
     copy-cost curve as the free arm.
  4. **Open-ended evolution** — complexity that keeps rising instead of plateauing. The
     observable is the **complexity of the dominant replicator**: the length of the
     instruction skeleton of the modal tape, which is bounded above by `tape_len` and so
     cannot rise forever in today's substrate. That bound is the point. Two more substrate
     bets, both optional parameters that are **off by default**: **environmental
     structure** (the torus stops being uniform — a region's step budget or mutation rate
     differs from its neighbour's) and **room to grow** (`tape_len` read as a ceiling a
     tape may grow towards rather than a fixed length). Sweeps `environmental-structure`
     and `room-to-grow`. Hypothesis: **at a fixed tape length in a uniform world the
     complexity of the dominant replicator plateaus within a few thousand epochs of the
     transition**, and each bet raises the plateau. Refuted if complexity keeps rising
     with both bets off, or if it plateaus at the same level with them on — which would
     say the ceiling was never the binding constraint.
  The invariant every ticket on this ladder depends on: **a new observable or an optional
  substrate parameter must leave every existing run byte-identical.** §1.1 says a run is
  determined by `(params, seed)`, and three sweeps have now checked it rather than
  asserted it — the default arms of `radius`, `world-size` and `max-steps` reproduce the
  `mutation-rate` arms digit for digit. So a new observable reads the world and never
  writes to it or to the RNG stream, a new parameter defaults to the value that makes it
  invisible and draws nothing from the stream while it is off, and the determinism tests
  of §3 keep pinning the same `(params, seed) → hash` for every substrate. A parameter is
  data (§3): name, default and validated range in `Params`, exposed to Rails through
  `runner schema`.
  Vocabulary, locked, with what is built today marked: **lineage** (tapes descended by
  copying from one ancestor — not built); **lineage id** (FNV-1a hash of a tape's
  instruction skeleton; computed in `render.rs`, not recorded); **modal tape** (the most
  common tape; only its share, `top_share`, is recorded); **persistence** (epochs a run
  held a non-zero census and a qualifying sample by §1.2 — not built);
  **relapse** (a transitioned world returning to a random soup — observed, unnamed until
  now); **census peak** (the maximum of `replicator_count` and the first epoch reaching
  it — derived in Rails, not an engine observable); **copy cost** (interpreter steps per
  byte-exact copy — not built); **complexity of the dominant replicator** (instruction
  skeleton length of the modal tape — not built); **instruction cost** (optional
  per-instruction price, default 0 — not built); **environmental structure** (optional
  non-uniform world, default uniform — not built); **room to grow** (optional growable
  tapes, default fixed `tape_len` — not built). Findings and issues use these words and
  not synonyms.
