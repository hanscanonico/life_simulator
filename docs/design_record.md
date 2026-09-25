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
  measurable, and the sweep that can refute each one. The vocabulary each rung uses is
  defined once, in the glossary that closes this entry, with what is built today marked.
  **Intelligence is the direction of travel, not a deliverable**: nothing below is a claim
  that the soup will compute anything, only that each rung is the next thing that can be
  measured.
  1. **Persistence** — a colony that does not collapse. Already refutable with what the
     engine records: `replicator_count` over the samples after a transition, its **census
     peak**, and whether its samples keep qualifying by §1.2, so that an alphabet that
     coalesced never reads as a colony that held. A **relapse** is not hypothetical: the
     radius sweep entry's radius-2 run and the `mutation-rate-long` entry's 2^-12 seed 10
     (census peak 123 at 28 100, all 16 384 tapes distinct again by 60 000) both did it.
     The gap is that nothing measures how long a colony held: Rails derives the census
     peak from stored samples (`Findings::ShowPage`) and re-reads those samples by the
     engine's transition rule (`Runs::TransitionEpochService`), and that is all.
     **Persistence** as a per-run observable is not yet in the engine, and by §2 the
     engine has to be the one that measures it. Sweep: `persistence`, the transitioned
     parameter points (128², 2^-13) at 20 seeds and a budget several times 60 000.
     Hypothesis: **the hazard of relapse is constant per epoch** — a colony is never
     established, it is only lucky so far. Refuted if the relapse hazard falls with
     colony age.
  2. **Heredity with variation** — lineages that share ancestry and drift apart. The two
     observables it needs are the **lineage id** and the **modal tape**, and neither is a
     recorded value today: `skeleton_hue` in `render.rs` builds an FNV-1a digest over a
     tape's op bytes only as a local intermediate and folds it straight into a hue, so no
     lineage id exists as a value anywhere in the system, and `top_share` reports the
     modal tape's share without its identity outside a snapshot. Both are cheap to promote
     from a rendering detail to recorded observables, and a skeleton digest is an
     approximation of descent, not descent itself. Sweep: `lineage-diversity`, the
     diversity half of §1.3 item 3 that the radius sweep entry left open, re-run at the
     emergent rate with enough seeds to have transitions in every arm. Hypothesis: **after
     a transition a world stays polyphyletic, and the number of surviving lineage ids
     grows as a cell's reach shrinks** — locality keeps lineages apart. Refuted if every
     transitioned world collapses to one lineage id whatever the radius.
  3. **Adaptation** — later replicators outcompeting earlier ones. Observables: the
     turnover of the modal tape and of the dominant lineage id, `copy_rate` (already
     recorded, §1.2), and **copy cost**, which is new. The `max-steps` entry showed the
     budget is spent rather than merely bought (~12× the wall time from 2^8 to 2^16
     steps), so steps are the substrate's only currency and a cheaper copier is what
     "fitter" can mean here without smuggling in a fitness function. Sweep: `adaptation`,
     reading copy cost along the epochs after a transition — hypothesis: **copy cost of
     the dominant lineage falls over a run**, refuted if it is flat or rises. Proposed,
     not committed: **instruction cost**, the first substrate bet, and the sweep
     `instruction-cost` that prices it against the free substrate — hypothesis: **a
     positive instruction cost steepens that fall**, refuted if costed arms trace the same
     copy-cost curve as the free arm.
  4. **Open-ended evolution** — complexity that keeps rising instead of plateauing. The
     observable is the **complexity of the dominant replicator**, which is bounded above
     by `tape_len` and so cannot rise forever in today's substrate. That bound is the
     point, and it is what the baseline tests: hypothesis: **at a fixed tape length in a
     uniform world the complexity of the dominant replicator plateaus within a few
     thousand epochs of the transition**, refuted if complexity keeps rising with every
     substrate bet off. Proposed, not committed: two further substrate bets and a sweep
     for each. `environmental-structure` — hypothesis: **environmental structure raises
     the plateau**, refuted if a world whose regions differ plateaus where a uniform world
     does. `room-to-grow` — hypothesis: **room to grow raises the plateau**, refuted if
     tapes free to lengthen plateau where fixed-length tapes do. Either refutation says
     the ceiling was never the binding constraint.

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

  Vocabulary, locked, defined here and nowhere else, with what is built today marked:
  **lineage** (tapes descended by copying from one ancestor — not built); **lineage id**
  (FNV-1a digest of a tape's instruction skeleton, which `render.rs` already computes on
  the way to a hue and discards — not recorded, and no such value exists today); **modal
  tape** (the most common tape; only its share, `top_share`, is recorded); **persistence**
  (epochs a run held a non-zero census and a qualifying sample by §1.2 — not built);
  **relapse** (a transitioned world returning to a random soup; the radius sweep's
  radius-2 run and `mutation-rate-long`'s 2^-12 seed 10 are the two recorded cases — not
  measured); **census peak** (the maximum of `replicator_count` and the first epoch
  reaching it — derived in Rails, not an engine observable); **copy cost** (interpreter
  steps per byte-exact copy — not built); **complexity of the dominant replicator**
  (instruction skeleton length of the modal tape — not built); **instruction cost**
  (optional per-instruction price in interpreter steps, default 0 — not built);
  **environmental structure** (optional non-uniform world, default uniform — not
  built); **room to grow** (optional growable tapes, default fixed `tape_len` — not
  built). Findings and issues use these words and not synonyms.
- 2026-09-12 — **Leaving the transitioned state defined, Rails-side.** §1.2 fixes when a
  world enters the transitioned state; it says nothing about leaving one, and the engine's
  tracker — which only ever reports the first crossing — has no exit rule to borrow. The
  persistence summary (`Runs::PersistenceSummaryService`, stored on `runs.persistence`)
  defines one: the state ends at the first of **`hold_samples + 1` consecutive samples**
  `Lab::TransitionRule` rejects, and a run whose state never ends **persisted** to its last
  sample. The count mirrors the entry hold — three further qualifying samples confirm an
  entry, so three further rejecting samples confirm an exit, and the `+ 1` is the sample
  that starts the run of rejections, exactly as the crossing sample starts the hold. A
  single sample flickering back over the threshold is then no more a relapse than a single
  sample under it is a transition. **Consequence**: a run with fewer than `hold_samples + 1`
  samples after its transition cannot be flagged **relapsed** — it has no room for an exit
  to be confirmed in — and so reads as persisted, which is a limit of the record and not a
  reading of the world. This is a Rails-side definition over stored samples; the engine
  stays the single authority on entry.
- 2026-09-13 — **Lineage id is a tag carried by descent, not a digest of a tape.** The
  evolution programme entry defined the **lineage id** as the FNV-1a digest of a tape's
  instruction skeleton, and said in the same breath that such a digest is an approximation
  of descent and not descent itself: two lineages that converge on one skeleton read as
  one, and one lineage that drifts a single op reads as two. Rung 2 is heredity, so the
  observable has to be ancestry. §1.2 now defines the lineage id as a tag beside each cell's
  tape, unique per cell at init, which a cell takes from its partner when the tape it ends
  with is closer — **Hamming distance over the tape's bytes**, the plainest distance on a
  fixed-length tape and the same byte-by-byte reading `copy_rate` makes of an exact copy —
  to the partner's arriving tape than to its own, keeping its own on a tie. `distinct_lineages`
  and `top_lineage_share` are the two recorded observables. The skeleton digest keeps its
  one job, the hue in `render.rs`. **Consequences**: the invariant holds — a tag is never
  written into a tape and never drawn from the RNG stream, so every existing run is
  byte-identical and two pinned observable readings in `world.rs` say so; and a snapshot
  carries tapes only, so a **resumed run starts its lineage census over** from one id per
  cell, which is a limit of the record, not a reading of the world. A run whose lineage
  series is to be read end to end has to be one the runner did not resume.
- 2026-09-13 — **A snapshot carries the lineage tags (format version 3).** The entry above
  recorded, as a consequence of tagging by descent, that a resumed run starts its lineage
  census over and that a run whose lineage series is to be read end to end has to be one
  the runner did not resume. Rung 2 is measured over long runs, which the lab resumes, so
  that limit would have cost the programme its evidence. The snapshot format now carries
  the tags as a second zlib payload after the cells, with the cell payload's length in the
  header: a resumed run continues the census it was keeping, and a corpus rescore reads the
  ancestry the world actually had. Version 1 and version 2 blobs, which Postgres still
  holds, decode as before and restore with one lineage id per cell — for those runs the old
  limit stands, and only for them. **Consequences**: the determinism decision is honoured
  where it was not before — a run resumed from a version 3 snapshot reproduces the lineage
  series of an uninterrupted run digit for digit; and a snapshot grows by the compressed
  tags — for the largest world the programme runs (512×256) that is ~194 KiB at epoch 0,
  ~1.5 KiB once one lineage dominates, and under 400 KiB even for a scrambled world where
  every cell still holds a distinct id — against a snapshot cap of 64 MiB that does not
  move. **Deploy order**: the format is forward-only, so an engine that predates version 3
  rejects a version 3 blob outright (`UnsupportedVersion(3)`) rather than resuming it
  without tags. Deploy the engine before any run writes a version 3 snapshot, and treat
  reverting it after the first one as stranding every run whose latest snapshot is version
  3 — such a run resumes only from an older version 2 snapshot, if one survives the pruner,
  or not at all.
- 2026-09-13 — **Variation within a lineage is a pooled mean over the 8 largest lineages
  that hold more than one cell.** Descent alone says which cells are kin, not whether kin
  are clones, so §1.2 gains `lineage_variation`: the mean bytes by which a cell's tape
  differs from the **modal tape** of its lineage — Hamming distance, the same reading the
  lineage rule makes — over the members of the 8 largest lineages. Four choices are fixed
  here rather than left open. The **modal tape** is the tape most of a lineage's cells
  hold, the lowest of any that tie, so the reading is a function of the world alone and
  needs no centroid that no cell holds. The mean is **pooled over the cells** of those
  lineages rather than averaged per lineage, so a lineage counts for as many cells as it
  holds and a two-cell lineage cannot outweigh a colony. **Lineages of a single cell are
  excluded**: such a cell is a clone of itself at distance 0, and a soup carries one
  lineage per cell until a colony spreads, so pooling them would have read a drifting
  colony as near zero for as long as the crowd outnumbered it — a world holding no lineage
  of 2 reads 0 instead. The **8** is a constant of the engine, not a parameter: a sweep
  axis over that number would study the instrument instead of the world. **Consequences**:
  the reading is a pure read of tapes and tags at sample time — no tape byte moves, nothing
  is drawn from the RNG stream — so existing runs are unchanged, and the two pinned
  readings in `world.rs` now carry the lineage observables as well as the pre-lineage ones.
- 2026-09-13 — **Copy cost is the median over the passing trials, for the most populous
  tape that passes.** Rung 3 of the evolution programme fixed the vocabulary — copy cost is
  interpreter steps per byte-exact copy — and §1.2 now carries it as `copy_cost`. Three
  choices are fixed here. The **dominant replicator** is the most populous tape among the
  `top_k` tested that passes the replicator test, not the largest lineage: the census the
  observable sits beside is over tapes, and a lineage-wise cost needs a per-lineage assay
  that does not exist. The aggregate over the four trials is the **median of the passing
  ones**, lower of the two middles, so a tape whose cost depends on its partner reports a
  price some trial actually paid rather than a mean of costs and non-costs. A tape that does
  not replicate reports **null**, which reaches Rails as a JSON null and draws no point.
  **Consequences**: the cost is read off `Outcome.steps` of the trials the replicator test
  already runs, in the same order on the same stream — no trial is ever re-run to measure
  it — so a run's bytes and every existing observable are untouched, and the pinned
  determinism hashes and metric strings in `world.rs` do not move. No run recorded a copy
  cost before this change, so every series starts where the lab first ran the new engine.
- 2026-09-13 — **Complexity of the dominant replicator is compressed tape length and
  executed instruction count.** Rung 4 of the evolution programme needs a baseline for
  open-endedness, and §1.2 now carries one as `dominant_compressed_len` and
  `dominant_instruction_count`. Three choices are fixed here. The tape read is the **same
  dominant replicator `copy_cost` is priced on** — the most populous tape among the `top_k`
  tested that passes the replicator test — so a run's three replicator observables always
  describe one tape and can be read against each other. Compressed length is **zlib at the
  compressor `compress_ratio` already uses**, not a bespoke coder: it is already a dependency,
  it is deterministic, and it puts a tape and the world it sits in on one scale. The
  instruction count is counted against the **run's own op set**, so an ablation sweep counts
  only the bytes its interpreter would execute; with the default set it is the tape's
  `op_density` times its length. **Consequences**: both readings are pure functions of a tape
  the replicator test already selected — no trial is re-run, nothing is drawn from the RNG
  stream — so a run's bytes and every existing observable are untouched and the pinned
  determinism hashes and observable strings in `world.rs` do not move. A tape that does not
  replicate reports null, which reaches Rails as a JSON null and draws no point, and no run
  recorded either reading before this change.
- 2026-09-14 — **Instruction cost is an optional per-cell energy budget, off by default.**
  §1.1 said the substrate has no energy; it now has one that can be switched on, as
  `energy_per_epoch`, and §1.3 gains sweep 6 over it with the hypothesis that a cost
  pressure selects for efficient copiers and opens a second niche. Three choices are fixed
  here. The budget is **per cell and refilled in full at the start of every epoch**, not
  carried over: energy is then a function of the epoch alone, so a run resumed from a
  snapshot recharges exactly as the uninterrupted one did and no snapshot format moves. An
  interaction runs on **what the poorer of its two cells has left**, not on the sum:
  the two cells execute one concatenated program together, so neither can be made to pay
  past its own budget, and an interaction whose cells are spent executes nothing at all —
  it halts where the energy ran out, which is `copy_rate` reading a failed copy rather
  than a special case. The cost is **off at 0, which is the default**, so every run the
  lab has already made is the same run: with no budget nothing is allocated, nothing is
  counted, no draw leaves the RNG stream in a different place, and the pinned determinism
  hashes and observable strings in `world.rs` do not move — a test asserts the pinned
  readings again with the parameter named and set to 0. The replicator test is
  deliberately **not** priced: it is an assay run beside the world, not an interaction in
  it, so a tape's `copy_cost` stays comparable across the arms of the sweep.
- 2026-09-14 — **Environmental structure is an optional non-uniform mutation rate, off by
  default.** §1.1 gave the world one mutation rate everywhere; it can now be told to vary
  that rate with a cell's position, as `structure` and `structure_amplitude`, and §1.3
  gains sweep 7 over it. A cell is **dry** when its effective mutation rate is below
  `mutation_rate` and **wet** when it is above, the driest and wettest cells being the
  extremes the amplitude reaches; wherever the engine, the schema or this site describes a
  structured world, the words carry that meaning and no other. Its hypothesis is the one
  the evolution programme names: **environmental structure raises the plateau** the
  dominant replicator's complexity settles at, refuted if a world whose regions differ
  plateaus where a uniform world does; the secondary prediction, read off the same runs,
  is that a heterogeneous world keeps more lineages alive after emergence. Four choices
  are fixed here. The rate is the **target**, not the step budget: mutation is already the
  one per-cell probability the epoch applies byte by byte, so varying it changes the odds
  a byte faces and nothing else — no allocation, no count, no draw that was not already
  made — where a per-cell step budget would have to be spent against the energy ledger of
  sweep 6 and confound the two bets. The shapes are a **gradient** and a **patchwork**,
  `gradient` a triangle across the columns and `patchwork` four quadrants alternating dry
  and wet: a ramp would put the wettest column against the driest across the wrap, which
  on a torus is a wall and not a gradient, and two patches per axis is the fewest a torus
  carries without a patch meeting itself; an odd-sided world has no exact half, and its
  middle column or row falls with the first half of its axis. The amplitude is **relative
  to `mutation_rate`** — a cell runs between `1 - amplitude` and `1 + amplitude` times the
  run's rate, clamped to a probability — so a structured arm is comparable to the uniform
  arm it is swept against rather than to a different rate window; the sweep runs at
  amplitude 0.75, which keeps both the dry and the wet cells inside the window sweep 1
  mapped. The structure is **off at `uniform`, which is the default**, so every run the
  lab has already made is the same run: the same bytes are offered the same draws in the
  same order, and the pinned determinism hashes and observable strings in `world.rs` do
  not move — a test asserts the pinned readings again with the parameter named and the
  world uniform. `structure_amplitude` is read only while a structure is set, which is why
  an amplitude of 0 and a uniform world are the same run, and why its default of 0.5 is
  not a second off switch: it is the amplitude a structured run takes when the sweep names
  no other, and it is never read at all until a structure is named.
- 2026-09-14 — **Room to grow is an optional maximum tape length, off by default.** §1.1
  gave every cell a tape of exactly `tape_len` bytes for the whole of a run, so the
  complexity of the dominant replicator was bounded by construction; a run can now be told
  that a tape may lengthen up to `max_tape_len`, and §1.3 gains sweep 8 over it. A tape's
  **cap** is `max_tape_len` where one is set and `tape_len` where it is not; a tape is
  **grown** when it is longer than `tape_len`, and a world whose cap is its initial length
  is the fixed-tape world of every earlier sweep. Its hypothesis is the one the evolution
  programme names: **room to grow raises the plateau** the dominant replicator's complexity
  settles at, refuted if tapes free to lengthen plateau where fixed-length tapes do.
  Six choices are fixed here, one per part of the engine the change reaches.
  **The interpreter** grows the tape and nothing else does: a head that steps right off the
  last byte of the concatenation appends a zero byte and moves onto it instead of wrapping
  to the front, while the concatenation is shorter than the cap allows. Nothing else
  changes — the ops, the heads, the brackets and the halts are §1.1's — so growth is the
  programs' own work: a copy loop that walks past the end of its partner writes into new
  bytes rather than over its own start. At the cap the head wraps exactly as it always did,
  which is why a run whose cap is its initial length executes the identical instruction
  stream.
  **The pair** grows at its tail, so the tape that lengthens is the second of `A ++ B` —
  the one a copier writes into. The split back into the two cells stays at `A`'s length:
  the first cell keeps the length it arrived with and the second keeps the rest. A cell is
  the first of its own interaction once an epoch and the second of a partner's about as
  often, so no cell is barred from growing; and a tape never shrinks, because a length that
  could fall would let the world lose bytes no program wrote.
  **Storage** stays one flat array of cap-wide slots plus a live length per cell, rather
  than a vector per cell: a soup is millions of tapes and the slot a tape grows into must
  already be there. The bytes past a tape's length are zero and only ever become live by
  growing, so they can never go stale. A world that cannot grow keeps no lengths at all —
  the vector is empty, as the energy ledger and the life scratch buffer are when they are
  off — and `world_hash` stays the hash of the array alone; a world that can grow hashes
  its lengths after its bytes, since the same bytes under two different lengths are two
  different worlds.
  **The observables** read live bytes only, never the padding: `compress_ratio`, the byte
  histogram behind `op_density`, `entropy_bits` and `alphabet_size`, the tape ranking, and
  the replicator test all see the ragged concatenation. Two tapes of different lengths are
  different tapes, so the ranking separates a grown replicator from the shorter one it
  descends from. The replicator test of §1.2 is otherwise unchanged: a candidate is still
  paired with a random tape of its own length, and that pair never grows, so a tape is put
  to the same test in every arm of the sweep. Hamming distance — which both the lineage
  rule and `lineage_variation` read — counts a length difference as that many mismatches,
  so a tape that grew has moved away from its lineage's modal tape by exactly the bytes it
  gained. No observable is normalised by `tape_len`, so none of them had to be redefined
  for a mixed-length world. `copy_rate` is the one that needed a rule for a mixed-length
  pair: a half counts as copied when it ends holding a byte-exact image of the tape its
  partner arrived with, read from its first byte. Bytes past the image — the room a
  copier's last head step claimed — do not unmake the copy, and a half too short to hold
  the whole source is no copy of it. Read the other way round, an interaction that grew
  could never register a copy at all and the reading would be biased down in exactly the
  arms this sweep studies. The exclusion of pairs that arrive a copy already reads the
  same rule, not plain inequality: a frozen world of tapes beside the tapes one head step
  lengthened would otherwise report half its interactions as copies with nothing having
  run, the same bias pointing up. On a pair whose halves are the same length rule and
  exclusion are both the equality they always were, so no fixed-tape run moves.
  **The snapshot** carries the lengths, in a version 4 container: the cell payload is the
  ragged live bytes end to end, a third zlib payload holds one length per cell, and the
  header carries the cap they were written under, checked against the run's own like every
  other header field. Without it a blob written under one cap would silently resume under
  another whenever every length happened to fit the narrower slots, giving the world room
  it was never granted. A world that cannot grow writes the version 3 container it wrote
  before, byte for byte, and every version 1, 2 and 3 blob Postgres holds still restores.
  **Rendering** is unchanged in shape — one pixel per cell — and reads the cell's live
  tape, so a grown tape's hue and op density are read off the bytes it actually holds.
  The parameter is **off at `max_tape_len` 0, which is the default**, and a `max_tape_len`
  equal to `tape_len` is the same run as 0 rather than an error: the sweep's control arm
  names the fixed length it holds the other arms against. Below `tape_len` it is refused,
  because a cap under the length a run starts at is not a world the engine can build. With
  the cap at the initial length nothing is allocated, no head ever appends, no draw leaves
  the RNG stream anywhere new and no snapshot changes version — the pinned determinism
  hashes and observable strings in `world.rs` do not move, and a test asserts the pinned
  readings again with the parameter named and set both ways.
- 2026-09-15 — **A crossing is a candidate; a run emerged only when a witness confirms
  it.** The `max-tape-len` sweep's 512 arm made the case: all ten runs carry a
  `transition_epoch` between 600 and 670 with a peak `replicator_count` of 0, a peak
  `copy_rate` at or below 6.1e-05 and 16 384 of 16 384 distinct tapes at the last sample —
  the detector firing on the random fill settling into a compressible soup, not on
  replication. Of the sweep's 14 flagged runs only 4 (367, 371, 384, 389) ever held a
  replicator, and those same 4 are the only ones carrying a `dominant_compressed_len`
  reading. `transition_epoch` (DESIGN §1.2) is **unchanged**: it stays the detector's first
  qualifying, held crossing, and it stays the primary dependent variable of every sweep.
  What is added is a second, narrower reading beside it. A run **emerged** when that
  crossing is confirmed by the replicator census or the copy rate within
  `Runs::EmergenceEpochService::CONFIRM_WINDOW` samples of it — the window the transition
  report already reconciled the two observables over — and the confirmed epoch and its
  witness (`census` or `copy_rate`) are stored on the run as `emergence_epoch` /
  `emergence_witness`. The rule is spelled out in exactly one place,
  `Runs::EmergenceEpochService`, which `Experiments::TransitionReportService` reads, a
  finished run records through `Runs::FinishService`, and `lab:backfill_emergence[<slug>]`
  rewrites over stored samples. This is what the 2026 BFF paper reports as emergence
  (arXiv:2607.01483), so the programme's published claims now read the same way its prior
  art does.
  **Scope, deliberately narrow.** Only the two open-endedness findings change reader:
  `replicator-complexity-plateau` and `complexity-keeps-rising` read emerged runs and read
  their series at or after `emergence_epoch`, and where either printed one count it now
  prints both — how many runs the detector flagged, how many a replicator confirmed. The
  experiment pages print both counts too and mark a confirmed run distinctly from a bare
  flagged one. The other findings — the mutation-rate window, world size, radius,
  persistence and the bff-control positive control — keep reading `transition_epoch`: they
  are claims about how often and how fast the detector's crossing appears, the sweeps were
  read and published that way, and re-reading them on a narrower definition is a separate
  piece of work with its own evidence.
- 2026-09-15 — **An arm run to ten seeds with nothing emerged is evidence, not an untested
  arm.** The three substrate bets of §1.3 (sweeps 6, 7 and 8) are read on
  `complexity-keeps-rising` by counting each treated arm's emerged runs against its
  sweep's control arm, and the rule refused to refute a hypothesis while any treated arm
  carried fewer than two measured runs. That could not tell an arm nobody seeded from an
  arm run to its end in which nothing ever emerged, so the `max-tape-len` sweep's 512 arm —
  10 of 10 terminal, every one of its ten detector crossings a false positive with a peak
  `replicator_count` of 0 (entry above) — left room to grow unresolved forever, however
  many seeds were added. Sweep 6's three priced arms are heading the same way against a
  costless control that has emerged. **The rule adds a third arm state.** An arm is
  *measured* at two or more measured runs, unchanged; an arm is read as **never emerged**
  at **10 or more terminal runs** (finished or failed with at least one sample) with
  `emergence_epoch` null on every one; anything else — unseeded, still running, or one
  emerged run of ten — stays untestable. Ten is one seed-block: ten seeds per arm is the
  block §1.3 budgets a sweep, and where it budgets more it budgets whole blocks of ten
  (sweep 8 runs three, emergence at 128×128 being about 1 in 10), so an arm that drew a
  whole block blank has been seeded, not skipped. A hypothesis is refutable when the
  control arm is comparable, at least one treated arm is measured or never emerged, and no
  treated arm is untestable; an arm that never emerged holds no replicator whose complexity
  could stand above the control's, so it raises no plateau and a sweep whose treated arms
  all came up empty reads **not supported**. If the control arm itself never emerged the sweep is
  unresolved and the page says so: there is no default substrate to read anything against.
  `supported` is unchanged — some measured arm reads above the control in most of its runs.
- 2026-09-15 — **The dominant tape's complexity is read whether or not it replicates.**
  §1.2 defined `dominant_compressed_len` / `dominant_instruction_count` as readings of the
  dominant replicator, null when no tested tape passes the replicator test, and the engine
  emitted them only on a positive census. Since emergence is confirmed by the copy rate as
  well as by the census (entry above), that left a whole class of emerged run structurally
  unmeasurable: run 500 (`max-tape-len`, arm 128, seed 14) crossed at epoch 4 170 on
  `copy_rate`, reports 1 584 samples after its crossing, and carries `replicator_count` 0 —
  and therefore not one complexity reading — in every one of them, so the 128 arm reads
  "2 emerged, 1 measured" on `complexity-keeps-rising` and the plateau cannot be decided.
  **The two readings are now taken of the most populous tape when no tested tape passes**,
  with a new boolean observable `dominant_replicates` saying which of the two tapes was
  read. After a crossing the copy rate confirmed, the tape most cells hold is the thing
  that is copying, so its size is the reading the finding wants; and a sample that says
  false is not silently mixed with one that says true. Where a tested tape does pass, the
  numbers are read off it exactly as before — the most populous passing tape among the
  `top_k`, the tape `copy_cost` is priced on — so **every reading that existed is
  byte-identical**: a 20 000-epoch 128² run at the defaults (seed 14) reproduces its 2 001
  samples digit for digit outside the three dominant fields. Nothing else moves: no RNG
  stream is touched, no tape is read that the census did not already rank, and exactly one
  tape is compressed per sample, so the same run took 410.7 s before and 406.5 s after. The
  life substrate still reads null, having no tapes. **Runs already finished keep their
  nulls** — no backfill is possible, the tapes those samples described are gone — so an old
  run stays measurable only where its census was positive.
- 2026-09-15 — **Emergence is confirmed against every crossing a run holds, not only the
  detector's first.** The engine's tracker keeps one crossing per run — the first
  qualifying, held drop of `compress_ratio` — and confirmation read that one alone, so a
  false positive early in a run hid whatever came after it. Run 543 (`max-tape-len`, arm
  512, seed 17) is the case: `transition_epoch` 630 is the initial-condition crossing every
  512-arm run trips (entry above, #174), no witness stands within the confirmation window
  of it, and the run was recorded as never emerged — while from epoch ~12 700 it is alive.
  `replicator_count` is above zero in 66 samples between 12 700 and 19 990 (peak 53 at
  16 940), `copy_rate` is positive throughout, `compress_ratio` sits at 0.20–0.25 from
  14 000 to 20 000 against 0.96 for every other run of the arm, and distinct tapes fall
  from 16 384 to about 7 400. The 512 arm is 1 of 30 emerged, not 0 of 30. **The rule now
  reads every crossing**: `Runs::CrossingsService` derives them from the stored samples by
  the same predicate Rails already spells out (`Lab::TransitionRule` — a crossing is the
  first sample of a qualifying stretch that holds for `hold_samples` more, entered from a
  stretch that does not qualify), `Runs::EmergenceEpochService` reads the stored crossing
  first and then the later ones, and `emergence_epoch` / `emergence_witness` are the
  earliest crossing a witness backs. A world can leave the transitioned state and enter it
  again — the radius sweep recorded one that did (2026-09-11) — so which crossing carries
  the copier is an empirical matter, not the detector's to decide. **`transition_epoch` is
  untouched**: it stays the detector's first crossing and the primary dependent variable of
  every sweep (§1.2), and only the confirmation beside it moves. **Every epoch already
  confirmed is unchanged** — the stored crossing is still read first, and a crossing
  earlier than it is never considered — which the service and backfill specs pin on runs
  shaped like the confirmed ones. `lab:backfill_emergence[<slug>]` rewrites the whole
  corpus by the new rule and shouts when it would clear a stored emergence; the transition
  report gains a `crossings` column, so run 543 reads `crossings 2, transition_epoch 630,
  emergence_epoch 12 7xx`.
- 2026-09-16 — **Complexity is read off the instruction count, not the compressed length.**
  `dominant_compressed_len` saturates: zlib's envelope on an incompressible stream is 11
  bytes, so a tape of junk compresses to its own length plus 11, and that is exactly what
  92–99.8% of the post-crossing samples of every room-to-grow arm read — 75 / 139 / 267 /
  523 bytes at caps 64 / 128 / 256 / 512. "523 bytes" at cap 512 cannot be told apart from
  512 random bytes, so the reading measures the cap rather than the replicator, and a
  finding that decided the room-to-grow plateau on it would be reporting the parameter it
  swept. `dominant_instruction_count` is not capped that way: post-crossing it reads 9–17
  ops at cap 64, 20–26 at 128, 17–28 at 256 and 37–52 at 512, which is 14–26% of the tape
  at the smallest cap and 7–10% at the largest — quadrupling the byte budget does not
  quadruple the op content. **The pre-registered reading for "complexity keeps rising" is
  the instruction count** (and later a conserved core), never the compressed length alone:
  `Findings::OpenEndednessSurvey` now decides sweeps 7 and 8 on
  `dominant_instruction_count`, and the finding page states this caveat in the words above.
  The compressed length is kept as a length and nothing else. **Two per-sample observables
  are added so it can be read as one**: `dominant_raw_len`, the dominant tape's own length
  in bytes, and `dominant_tape_hash`, FNV-1a 64 of its bytes as sixteen lowercase hex
  digits — the engine's own `hash::fnv1a64`, a fixed function of the bytes on every
  platform and every build, never a platform hasher, and never compared for anything but
  equality. The run page reads compressed over raw off them (near 1 is junk, well under 1
  is a tape with structure) and counts how often the dominant tape's identity changes
  between consecutive samples; both are derived on the read side for display and neither is
  a new metric — the engine stays the authority. **Every reading that existed is unchanged**:
  the new fields are appended to `Metrics`, nothing draws from an RNG stream, no extra tape
  is compressed, and the engine's pinned observable digests are split so the fields that
  existed stay pinned to the digits they were pinned to. **Runs already finished keep nulls**
  on both new fields — the tapes those samples described are gone, so no backfill is
  possible — and every reader tolerates a null.
- 2026-09-16 — **The conserved core: two per-sample observables that read what a lineage
  holds still.** At the plateau one lineage holds 97–100% of the world while its members
  diverge across 83–93% of their bytes, and `lineage_variation` cannot say whether a
  working copy loop survives inside that cloud or whether the cloud is turnover at a flat
  tape size. `conserved_core_bytes` counts the byte positions the largest lineage holds
  invariant — the positions at least **nine of every ten** of its members give one and the
  same value — and `conserved_core_ops` counts how many of those hold a byte the run's own
  instruction set executes. The threshold is a ratio of two integers
  (`metrics::CONSERVED_CORE_SHARE_NUMERATOR` over `_DENOMINATOR`), so exactly nine members
  in ten is inside the core and eight is not, and the edge never depends on what a binary
  float rounds 0.9 to; it is a constant of the engine, not a parameter. The lineage read is
  the one `lineage_variation` already ranks by — the largest that holds at least two cells,
  ties by lowest id — and a member too short to reach a position agrees with nobody there,
  the reading `lineage_variation` already makes of a tape that grew. Both are null where no
  lineage holds two cells, on the life substrate, and on every sample recorded before they
  existed; runs already finished keep nulls, since the tapes are gone. **This is the
  pre-registered secondary reading of every substrate sweep that follows**, beside
  `dominant_instruction_count`. **Every reading that existed is unchanged**: the fields are
  appended to `Metrics`, the computation draws nothing from an RNG stream and only walks
  tapes the sample has already read, and the pinned digests of the earlier fields are left
  where they were — a 20 000-epoch 128² run at the defaults emits the same 2 001 samples,
  field for field, as the same run on the commit before. It costs one pass over the top
  lineage's tapes per sample (members × tape length): 0.6 ms of a 28 ms sample on 128².
- 2026-09-16 — **An energy stock that carries across epochs, off by default.** §1.1 gains
  `energy_influx` and `energy_stock_cap`: every cell holds a stock of instruction energy,
  one influx is added to it each epoch up to the cap, an interaction runs on the poorer of
  its two cells' stocks and debits both, and a cell whose stock is empty is passed over
  until a later influx recharges it. **This is not sweep 6 repeated.** `energy_per_epoch`
  refills every cell to the same allowance at the start of every epoch: nothing is
  accumulated, nothing is scarce across epochs, a cell that spends everything is whole
  again next epoch, and there is nothing any cell could take from another. A stock is
  conserved quantity — the world's total energy is bounded by cell count × cap, what one
  cell spends is gone until the influx pays it back, and a saved stock is a thing a
  future instruction can steal. The economy the evolution programme wants is that one; the
  per-epoch tax was measured and is kept as it stands. Three choices are fixed here. Every
  cell **starts the run full at the cap**, so a run opens at the world's energy ceiling
  rather than spending its first epochs filling up, and the cap alone bounds the world's
  energy at every epoch. A cap **below one epoch's influx is refused**: the surplus would
  be discarded on arrival and the economy would be the per-epoch allowance under another
  name. The stock is **state of the world, not a function of the epoch**: unlike the
  allowance it is hashed with the tapes and written into the snapshot, which is snapshot
  **version 5** — the version 4 container with the length payload's own length in the
  header and one stock reading per cell after it — so a lab run resumed on the mini-pc
  carries the energy its cells had instead of waking up full. The two economies are
  independent and compose: with both on an interaction is bounded by whichever is poorer,
  and both are debited. **Off at 0, which is the default**: with no influx nothing is
  allocated, no cell is gated, no draw leaves the RNG stream in a different place, the
  snapshot is version 3 or 4 byte for byte as before, and the pinned determinism hashes and
  observable strings in `world.rs` do not move — a test asserts the pinned readings again
  with both parameters named, influx 0 and a cap set, since a cap with no influx stocks
  nothing. No sweep is declared over the stock here: the substrate lands first, the steal
  op that makes the stock contestable follows, and the sweep is written over the substrate
  those two make.
- 2026-09-16 — **An asymmetric execution mode, off by default.** §1.1 gains `interaction`:
  at `concat` — the default and the substrate every run so far lived in — the whole
  concatenation is the program; at `host` the instruction pointer ranges over the first
  tape's bytes only and the partner is pure read/write substrate. **Why the substrate needs
  it.** In the symmetric pairing a tape's fate is decided by what the joint program does,
  and a tape has no interest in what it is made of: there is nothing another tape can do
  to it that its own bytes could resist, encourage or exploit, because its own bytes are
  running too. Asymmetry splits the two roles the parasitism literature needs apart — what
  a tape *does* is its own code, what *happens to* a tape is how the tapes that host it
  treat it as data — so a tape that is cheap to copy, or expensive to overwrite, or that
  hijacks a host's copy loop, is for the first time a distinguishable strategy. It is the
  precondition for the steal-and-defend arms race, not the arms race itself; no sweep is
  declared over it here. **Three edges are fixed.** The host's code is its **live** length,
  so a run with room to grow executes exactly the bytes the first cell holds and the bytes
  the pair claimed past them are data like the rest of the partner. **Both heads still
  range over the whole concatenation** and wrap around it — confining them too would make
  the partner unreachable and the mode pointless. And **bracket matching still scans the
  whole buffer**: a `[` whose match lies in the partner jumps the pointer out of the code,
  which ends the run exactly as stepping off the end does, rather than inventing a second
  matching rule for the same byte. **Off at `concat`, which is the default**: the
  interpreter gained one entry point taking an instruction-pointer bound and the existing
  ones pass the buffer's own cap, a bound the pointer can never reach, so the identical
  instruction stream runs — the pinned determinism hashes and observable strings in
  `world.rs` do not move, and a test asserts them again with `concat` named explicitly.
  The cost is one comparison in the interpreter's inner loop: criterion reads the change
  as under 2% on `bff/random_128` and inside the noise on a soup epoch.
- 2026-09-16 — **A steal op, off by default.** §1.1 gains `steal_amount` and `steal_loss`:
  the byte `$` becomes an instruction that moves `steal_amount` of instruction energy out of
  the partner cell's stock into the executing cell's, destroying the `steal_loss` share of
  it in transit, and §1.2 gains `steal_rate`, the share of a sampled epoch's interactions in
  which one executed. **Why the substrate needs it.** The stock of the entry above makes
  energy conserved and scarce; nothing yet makes it *contested*. Theft is the cheapest
  mechanism that does: it gives one tape something to gain from another tape's state beyond
  overwriting it, and gives the other something to defend, which is the arms race the
  literature ties to rising structural complexity in fitness-free soups (arXiv 2609.10817;
  Tierra's parasites and the hosts that learned to resist them). With the asymmetric
  `interaction` mode already landed, a tape's code and a tape's substrate are separable, so
  "steal from whoever hosts me" and "be expensive to steal from" are now distinguishable
  strategies rather than two readings of one joint program. **The byte is `$` (0x24)**,
  unassigned in BFF and the one character on the keyboard that says money; it is
  deliberately **not** an eleventh member of `OPS`, because those ten are the instruction set
  `op_density` measures and `ops` ablates, and folding a stock operation into them would move
  a tape statistic every earlier run is pinned on. **Off is `steal_amount = 0`**, the
  encoding `energy_influx`, `energy_per_epoch` and `max_tape_len` already use, rather than a
  separate boolean: the schema has no boolean kind, a steal that moves nothing is not an
  experiment, and `steal_loss` is read only once an amount is set the way
  `structure_amplitude` is read only once a `structure` is. An amount with **no influx
  behind it is refused** — there would be no stock to take from and the parameter would be
  silently inert. **Four edges are fixed.** The thief is the half of the pair the instruction
  pointer is in, which under `host` is always the host, matching how execution is already
  charged. A steal is settled **after** the interaction has paid for the instructions it ran,
  so theft comes out of what a cell has left and can never rob it of energy already spent —
  and the interaction's budget, fixed before it started, is untouched by what it steals.
  A partner poorer than the amount gives up everything it holds and an empty one gives up
  nothing; the thief's gain is capped at `energy_stock_cap` like any other, so the world's
  total energy still never passes cell count × cap. **The accounting is per op**: an
  interaction's steals settle one at a time, each taking `min(steal_amount, what the partner
  still holds)` and delivering `floor(moved * (1 - steal_loss))`, rather than the loss being
  taken on the interaction's summed movement. That is what the op means — one op, one
  transfer — and it has a rounding consequence worth stating: three steals of `1` at a loss
  of `0.5` deliver `0`, not `1`, so a small amount is pure destruction and a sweep must pick
  an amount and a loss with a non-zero per-op yield. **Off at 0, which is the default**: the byte
  is absent from the table the interpreter's inner loop reads, so it is the plain no-op every
  other non-instruction byte is, the identical instruction stream runs, and the pinned
  determinism hashes and observable strings in `world.rs` do not move — a test asserts them
  again with `steal_amount` named off and a `steal_loss` set, and another shows a soup of
  nothing but `$` running the epoch a soup of any other inert byte runs, energy included,
  with the stock on and with it off. No sweep is declared over theft here: the substrate
  lands, and the sweep is written over the substrate the stock and this op make together.
- 2026-09-18 — **A rescore is comparable only with the live sample at the same epoch.**
  Issue #184 read a corpus rescore as a decode regression — every confirmed-emerged run of
  the `max-tape-len` sweep rescoring to `replicator_count` 0 while its samples had held a
  census, `--top-k` moving no column — and concluded that **every negative rescore in the
  record is void**. That conclusion is **retracted**. A read-only re-measurement of the
  stored corpus finds no decode failure: at every epoch where a snapshot and a live sample
  coincide, the rescored count equals the stored one exactly — run 367 @5000 538/538/538
  against 538, run 737 @5900 43/43/49 against 43, run 197 @5000 538 against 538, run 186
  @9900 316 against 316, run 185 @16000 112 against 112, and the runs whose latest world is
  read (367 @20000, 186 @50000, the three `mutation-rate` nulls @20000) read 0 where the
  live sample also reads 0. Two things made it look otherwise. **The wrong epoch**:
  `rescore-corpus --epochs latest`, the default, reads each run's final world, and in every
  confirmed run the census is 0 at the final epoch on the live sample too — census-positive
  epochs are transient and mid-run. **A per-epoch draw**: `World::replicator_census` seeds
  its assay with `rng::seeded(seed, STREAM_REPLICATOR, epoch)`, so the result flickers
  sample to sample — run 384 reads 0 at 15000, 51 at 15020, 0 at 15030, 68 at 15040, 0 at
  15050 — and the issue compared a snapshot at 15000 (live 0, rescore 0, agreement) with a
  sample at 15020. A negative rescore of a final world is therefore a valid reading of that
  final world and nothing more; `rescore-corpus --epochs latest` is not the instrument for
  confirming emergence, and any rescore offered as evidence about a census peak must name
  the epoch of the peak. **`top_k` stays at 16**, where DESIGN §1.2 locks it: widening is
  not a no-op — run 737 @5900 gives 43 at 16 and 49 at 256 — but across the twelve worlds
  re-read only that one moved, and the issue's `--top-k 1,16,4096` probe cannot be run at
  all (values above 256 are refused). The check is bounded by snapshot cadence: only 5 of
  16 confirmed runs hold a snapshot at an epoch whose census was positive, because a
  snapshot is written every 500 to 2 000 epochs depending on the sweep while outside a
  sustained peak the census reads positive at scattered single samples — run 384 at 23 of
  the samples between 15 020 and 18 230, run 186 at 11 between 9 650 and 27 700. Closing
  that gap is follow-up work — a `census` snapshot reason that forces a world where the
  count is positive, and a census read as a pass rate over repeated draws rather than one
  seeded draw — neither decided here.
- 2026-09-18 — **The replicator census is read over 8 draws, not one.** The assay is four
  Bernoulli trials against random partners with a 3-of-4 threshold, seeded
  `(seed, STREAM_REPLICATOR, epoch)`, so a tape at the edge of the test passes or fails at
  random between adjacent samples: run 384 reads 0 at 15 000, 51 at 15 020, 0 at 15 030,
  68 at 15 040 and 0 at 15 050 (entry above). `World::replicator_census` now runs the
  ranked loop `CENSUS_DRAWS = 8` times and reports two new observables beside the count —
  **`replicator_pass_rate`**, the share of draws in which some tape passed, and
  **`replicator_count_mean`**, the mean of what they counted. A count of 0 beside a
  positive pass rate is a draw that missed; a count of 0 beside a pass rate of 0 is a world
  with nothing in it, and only that second reading is a negative result. **The census is an
  observable**: it reads the world and writes nothing back — no cell, no lineage, no
  simulation stream — so repeating it cannot change what the run does next, and the extra
  draws use a distinct seeded stream (`STREAM_REPLICATOR_DRAW | draw`) that the simulation
  never touches. Draw 0 keeps `STREAM_REPLICATOR` unchanged, which is why the pinned
  `(params, seed) → hash` of both substrates and every pinned observable string in
  `world.rs` are unmoved and every field a sample already carried prints the same digits;
  the two new fields are pinned apart from them, as #192's and #193's were.
  **`replicator_count` stays draw 0** rather than becoming the mean: every finding in the
  record reads it, a mean would silently redefine a series that has thousands of samples
  behind it and no backfill is possible, and the count is the reading a rescore of a stored
  world reproduces exactly. The mean is the better estimator and it is offered as its own
  field, to be read forward. **Draws are 8 and not a parameter**: this is how an observable
  is read, not something a sweep varies, so it is a module constant with no schema, wasm or
  sweep-grid consequence. The measured cost, `runner run` at 128×128 for 300 epochs with
  `sample_every = 10`, `--release`, three runs each: **7.61 s → 7.82 s, +2.7 %**, inside the
  3 % the change was allowed — a census is 30 of the 300 epochs' work, and eight draws of a
  16-tape assay are cheap beside the epochs between them. `runner rescore` prints a
  `pass_rate` column and carries it in its report JSON; no `rescores` column and no
  migration, and samples carry the two fields in the `values` jsonb they already use, so an
  old runner and a new one coexist.
- 2026-09-18 — **A `census` snapshot reason, so a census-positive epoch has a world.** The
  entry above closes on the gap it found: outside a sustained peak the census reads
  positive at scattered single samples, cadence is 500 to 2 000 epochs, and only 5 of 16
  confirmed runs hold a snapshot at an epoch whose census was positive. The run loop now
  takes a snapshot when, on a sampling epoch, `replicator_count_mean` **rises off zero** —
  the mean rather than draw 0's count, so an epoch whose first draw misses but whose others
  pass still counts as positive — and it fires on every later rise after a return to zero,
  not only the first. **Rate limit: at most one census snapshot per `snapshot_every`
  epochs**, reusing the cadence parameter rather than adding a Params field; a rise inside
  that window is counted and skipped. Worst case a world whose census flickers on and off
  doubles its snapshot volume, which is what the limit buys. **Census is chosen only when
  no other reason fires** — a cadence, age or transition snapshot at that epoch already
  stores the world, and the rise still spends the limiter's budget so the limit is honest.
  A census snapshot gets **no retention privilege**: the 2026-09-10 retention rules apply to
  it unchanged. The watch is a loop local, so a resumed run reads its first positive sample
  as a rise and may store one snapshot the uninterrupted run would not. **No simulation byte
  moves**: the reason is chosen from an observable the loop already samples, the snapshot
  format is unchanged (no version bump), and `Snapshot::REASONS` gains `"census"` with no
  migration — Rails must accept the reason before a runner posts it, and the mini-pc deploys
  the app before the runner.
- 2026-09-19 — **A `crossing` snapshot reason, so the transition epoch itself has a world.**
  `transition_epoch` names the **first** qualifying sample, and the tracker only settles it
  `TRANSITION_HOLD_SAMPLES` = 3 samples later, so the 2026-09-11 `transition` snapshot is
  always stored 3 samples past the epoch a rescore is asked about — 150 epochs at the
  sweeps' `sample_every` of 50. `Experiments::SnapshotAuditService` counts a transition
  covered only within **one** sample, so a run whose nearest world is the settled snapshot
  is reported uncovered by construction; issue #185 read that as a ~350-epoch miss on the
  `max-tape-len` 512 arm. The run loop now takes a snapshot on the first sampling epoch
  whose metrics are a `transition_candidate` while no transition has settled, under the
  reason `crossing`, so the crossing epoch is stored when it happens rather than once it is
  known to hold. **Rate limit and coverage follow the `census` rule verbatim** (2026-09-18):
  at most one per `snapshot_every` epochs, skipped when another reason already stored that
  epoch's world, the rise spending the budget either way — worst case a world whose
  `compress_ratio` flickers around 0.6 costs one extra snapshot per cadence. **The settled
  `transition` snapshot stays**: it is the world behind the observable the sweeps report,
  and the two epochs are different worlds. Crossing is chosen **last**, after census, so an
  epoch a replicator census also names keeps the narrower reading. `PruneSnapshotsService`
  needs no change: it keeps the snapshot nearest the transition epoch, and a crossing
  snapshot sits on it. **No simulation byte moves**: the reason is read off the metrics the
  loop already samples through `Metrics::transition_candidate`, the snapshot format is
  unchanged and `Snapshot::REASONS` gains `"crossing"` with no migration — Rails accepts the
  reason before a runner posts it, and the mini-pc deploys the app before the runner. Runs
  already stored keep the gap they have; only runs started after this ships are auditable at
  their crossing epoch.
- 2026-09-19 — **Complexity is read per dominant lineage as well as per dominant tape.**
  `dominant_compressed_len` / `dominant_instruction_count` are read off whichever tape is
  most populous at each sample, and that tape is a rotating representative rather than a
  persistent sequence: on `complexity-keeps-rising` both "still rising" columns read 0 for
  every arm, because a lineage that keeps getting more complicated while its modal tape
  turns over reads flat through a per-tape series. Two observables are added beside them:
  **`lineage_compressed_len`** and **`lineage_instruction_count`**, the very same two
  readings — zlib under the compressor `compress_ratio` uses, and the bytes the run's own
  instruction set executes — taken of a tape chosen by descent. **The representative rule**:
  the lineage is the one `conserved_core` and `lineage_variation` already rank each sample,
  the largest that holds at least two cells with ties by lowest lineage id, and the tape is
  that lineage's **modal tape**, ties broken by the lowest tape value — the rule
  `lineage_variation` already reads a lineage's modal tape by, and a function of the world
  alone rather than of the order the cells arrive in, so a run resumed from a snapshot reads
  the tape the run that wrote it read (`world.rs`, `a_resumed_world_reads_the_same_lineage_complexity`).
  The cell index is deliberately not the tie-breaker: the modal rule was already in the
  engine, and reusing it keeps one definition of "the tape of a lineage" rather than two.
  **The per-tape series stays** exactly as it is — every finding in the record reads it, the
  tapes behind the stored samples are gone so no backfill is possible, and a redefinition
  would silently move thousands of samples. The two series are read side by side instead.
  **`lineage_compressed_len_median` over the lineage's members is not added**: the members
  are enumerated, but the median would compress every one of them — 97–100 % of the cells at
  the plateau, against exactly one tape today — which is nowhere near the 3 % budget.
  **These are observables**: no simulation byte moves, nothing is drawn from an RNG stream,
  and the reading walks tapes the sample already holds, so the pinned `(params, seed) → hash`
  of both substrates and every pinned observable string in `world.rs` are unmoved; the two
  new fields are pinned apart from them, as #192's, #193's and #211's were. A 300-epoch
  128² run at the defaults emits the same 31 samples, field for field, as the same run on
  the commit before — only the two new keys are added and only the wall clock differs.
  The measured cost, `runner run` at 128×128 for 300 epochs with `sample_every = 10`,
  `--release`, three runs each: **8.87 s → 8.76 s of user time** (before 8.65 / 8.90 / 9.05,
  after 8.72 / 8.79 / 8.76), a difference inside the noise of a loaded laptop and well
  inside the 3 % budget — one more tape compressed on 30 of 300 epochs. Samples carry the
  two fields in the `values` jsonb they already use, so there is no migration and an old
  runner and a new one coexist; the run page charts them, the samples CSV carries them, and
  the sweep page draws them per arm beside the dominant pair.
- 2026-09-19 — **A relative transition reading beside the constant one;
  `transition_epoch` stays locked.** Measured with `lab:detector_baseline` (GitHub #174):
  a fresh soup's `compress_ratio` depends on `max_tape_len`, and the dependence straddles
  the 0.6 threshold the detector is defined by.

  | `max_tape_len` | mean over the first 500 epochs | min |
  |---|---|---|
  | 64 | 0.984 | 0.973 |
  | 128 | 0.853 | 0.796 |
  | 256 | 0.788 | 0.677 |
  | 512 | 0.754 | 0.618 |

  At cap 512 a run starts within a hair of the line and every seed "crosses" by epoch 1000
  with nothing replicating, and the host–parasite cap-128/256 arms inherit the same offset,
  so a cross-cap comparison of flag rates is confounded by the initial condition rather than
  by anything that happened in the world. **`transition_epoch` does not move**: it is the
  locked observable of §1.2 and every finding in this record is stated in it. What is added
  is a second, independent reading beside it, **`transition_epoch_relative`**: the first
  sampled epoch at which `compress_ratio <= 0.61 x baseline`, held the same 3 further
  samples and guarded by the same alphabet-collapse rule, where `baseline` is the mean
  `compress_ratio` of the samples with epoch <= 500. **The fraction is the constant
  expressed against the arms it was chosen on**: 0.6 / 0.984 = 0.61 at cap 64, so those arms
  read the crossings they always did while a wide-tape arm has to fall as far, in its own
  terms, as a cap-64 arm does. A run with no sample inside the baseline window, and one that
  never samples past it, read no relative epoch at all — the engine's tracker and the Rails
  re-derivation agree on that, deliberately.

  **It is an observable, not a rule**: no simulation byte moves, nothing is drawn from an
  RNG stream, and the pinned `(params, seed) -> hash` of both substrates and every pinned
  observable string are unmoved — the reading is the tracker's, not a `Metrics` field, and
  it is tested apart from them (`metrics.rs`). The tracker carries the baseline as a sum and
  a count plus the samples inside the window that cannot be judged until it closes, and
  **the snapshot carries all of it**, so a resumed run reads the epoch the uninterrupted run
  reads; snapshot versions 6, 7 and 8 are versions 3, 4 and 5 with that block written after
  every payload, and every older blob still restores as it did.

  **The corpus is rescored from the stored samples**, not re-run:
  `lab:backfill_relative_transitions[slug]` fills the new `runs.transition_epoch_relative`
  column from a run's samples through `Runs::RelativeTransitionEpochService`, and
  `lab:transition_report` prints `relative` and `both_rules` per arm so the two rules can be
  compared arm by arm. **Whether to relock the detector on the relative rule is not decided
  here**: that waits for the rescore, and until then every finding keeps reading
  `transition_epoch`.
- 2026-09-21 — **A run whose conserved core is zero is read as measured; the conserved-core
  clause of §1.3 sweeps 9 and 10 becomes absolute.** **This is a post-hoc amendment made
  after the sweep's data were seen.** The reason: under the pre-registered rule a run is
  measured only where the first-decile median of *both* `dominant_instruction_count` and
  `conserved_core_bytes` is nonzero, because the rule is stated as ratios — and in the
  finished host–parasite sweep the conserved core reads 0 in the first decile (and nearly
  always in the last) of **25 of the 26 confirmed emerged runs**, so 25 runs drop out as
  unmeasured, no arm reaches two measured runs, and every non-barren arm reads "unread". The
  core is zero for a real reason: the dominant lineage's members diverge across most of their
  bytes, so no byte is conserved. That is a reading, not a missing reading. **The amended
  rule**: a run is **measured** when its `dominant_instruction_count` first-decile median is
  nonzero over the post-crossing span, and the conserved-core clause is an **absolute**
  comparison — the core "does not fall" when the last-decile median is not below the
  first-decile median in bytes, so 0 → 0 satisfies it. A run carrying no `conserved_core_bytes`
  sample at all over the span stays unmeasured: there the clause cannot be read at all.
  Everything else is unchanged — rising (+20 % instructions with the core not falling),
  plateau (±10 %), mixed, neither, barren, the two-measured-run threshold and the theft
  readings. **Every finding that uses the amended rule must state what the pre-registered
  rule read**, which was: unmeasured. So each arm row carries the count of its measured runs
  the pre-registered rule would have dropped, in the sweep page's table and in the transition
  report CSV (`pre_registered_unmeasured`), beside the amended reading it is never printed
  without. Nothing about the engine, the samples or any locked observable moves: this is a
  rule for reading stored samples, applied in `Experiments::ComplexityArmsService`.
- 2026-09-21 — **`transition_epoch` relocks on the relative rule; the constant threshold
  becomes the companion reading.** This closes the decision the 2026-09-19 entry deferred
  (GitHub #174, #229). The primary dependent variable of every sweep is now the first
  sampled epoch at which `compress_ratio <= 0.61 x baseline` and the next 3 samples do too,
  under the same two collapse guards, where `baseline` is the mean `compress_ratio` of the
  run's samples at epoch `<= 500`. The constant `compress_ratio < 0.6` reading is kept and
  reported beside it as **`transition_epoch_constant`**.

  **The evidence** — measured, not re-measured here, with `lab:detector_baseline` and the
  `lab:backfill_relative_transitions` rescore of 1 729 terminal runs (2026-09-19):

  | `max_tape_len` | mean over the first 500 epochs | min | n terminal | constant | relative | both |
  |---|---|---|---|---|---|---|
  | 64 | 0.984 | 0.973 | 30 | 3 | 3 | 3 |
  | 128 | 0.853 | 0.796 | 90 | 5 | 5 | 5 |
  | 256 | 0.788 | 0.677 | 90 | 4 | 4 | 4 |
  | 512 | 0.754 | 0.618 | 30 | 30 | 1 | 1 |

  Two distinct claims rest on that rescore, and they do not cover the same experiments:

  | claim | what it covers |
  |---|---|
  | the two rules read the same crossings, arm by arm, in all 35 arms tabulated on 2026-09-19 | `energy-per-epoch`, `environmental-structure`, `mutation-rate`, `world-size`, `bff-control`, `host-parasite` |
  | over the whole rescored corpus of 1 729 terminal runs the cap-512 arm is the only place the two rules part, and there is no crossing the relative rule finds and the constant one misses (#224) | everything, `max-tape-len`, `radius`, `max-steps` and `mutation-rate-long` included |

  The corpus-wide sentence is the one the `radius`, `max-steps` and `mutation-rate-long`
  finding pages cite, because the arm-by-arm tabulation never reached them. Beyond those
  two claims: a surviving relative crossing lands on its constant counterpart's epoch or
  0–30 epochs after it, never before; and at cap 512 the one crossing the relative rule
  keeps is the one the replicator census confirms. **So every finding stated at cap
  `<= 256` stands unchanged**, and the only reading that moves is the cap-512 arm of
  `max-tape-len`, from 30 of 30 flagged to 1 of 30.

  **Why relock rather than keep the constant rule with a permanent footnote.** The
  confound is on `max_tape_len`, which is the axis the room-to-grow sweep varies: a primary
  dependent variable that reads the initial condition rather than the world is not a
  dependent variable, and a footnote does not stop a future sweep from reading it. The
  relative rule asks every run to fall as far, in its own terms, as a cap-64 run had to
  fall under the constant threshold, which is what `0.6 / 0.984 = 0.61` is derived to do.

  **Its structural limits, stated so they are never rediscovered as a surprise.** (1) It
  **cannot fire before its baseline window closes at epoch 500**: a run has no reading
  until then, where the constant rule reads from the first sample. (2) A crossing **inside
  the window contaminates its own baseline** — the samples inside it are held back and
  judged once the window closes, against a mean their own fall pulled down. (3) A run with
  **no sample inside the window, or none past it, has no reading at all**; runs shorter
  than 500 epochs are unmeasurable by it. (4) **Cross-cap comparisons remain the census's
  job**: the relative rule removes the starting bias, it does not make a crossing a
  replicator.

  **The option not taken** was to keep the constant rule primary and report the relative
  reading beside it forever. Its consequences would have been: no hash and no stored value
  moves; every finding's transition table carries both rules permanently; and DESIGN §1.2
  says the primary observable is known to be cap-confounded above `max_tape_len` 256 — a
  known-broken instrument kept for continuity, which the record would have had to repeat at
  every future sweep that varies the cap. It was rejected on that.

  **What moves.** The engine's `TransitionTracker::epoch` is the relative reading and
  `constant_epoch` the companion; `World::transition_epoch` follows, and the runner posts
  both under the rule that made each (`transition_epoch_relative`, `transition_epoch_constant`)
  rather than under a role name, so the app — which deploys before the runners — reads an
  older runner's `transition_epoch` correctly as its constant reading. The `crossing`
  snapshot reason follows the primary rule, and what it names has shifted with it: it is now
  the first sample the tracker can *judge* as qualifying — the epoch `transition_epoch`
  names when the fall happens past the baseline window, and the first qualifying sample
  after the window closes when the fall began inside it, since nothing inside the window can
  be judged until the baseline is known. So a run whose transition falls inside its own
  window stores its `crossing` world later than the epoch the observable names, on top of
  the cadence gap GitHub #185 already records. DESIGN §2's snapshot list says this.
  In Rails the two columns **swap names, not contents** — `runs.transition_epoch` becomes
  `transition_epoch_constant` and `runs.transition_epoch_relative` becomes
  `transition_epoch`, each column keeping the numbers its rule made, which is what keeps
  the migration reversible and the corpus readable at every point of it.
  `lab:backfill_transitions[slug]` now recomputes **both** readings from the stored samples
  (`Runs::TransitionEpochService`, `Runs::ConstantTransitionEpochService`) and refreshes the
  persistence summary; `lab:backfill_relative_transitions` is gone into it.

  **What keeps the constant rule, and the gate that leaves open.** The crossing *series* —
  `Runs::CrossingsService`, and `emergence_epoch` through it — stays on the constant
  threshold. The reason is limit (2) above: the relative rule judges no crossing inside its
  own window, and a second crossing would be judged against a baseline the first one
  contaminated, so a series of crossings can only be read by the rule that needs no
  baseline. What makes an emergence is the witness, not the threshold, so the candidate list
  stays as wide as it was and every stored emergence in the corpus is unchanged. The price
  is stated plainly: **the gate on emergence therefore remains the cap-confounded rule**. A
  future run that transitions on the relocked rule while never falling below 0.6 holds no
  crossing `Runs::CrossingsService` can put a witness against, and cannot be confirmed as
  emerged until that gate is revisited. No run in the corpus is in that position today; the
  first one that is, is the trigger for the next entry.

  **The persistence summary relocks with the transition — the decision to approve or
  overturn.** The column swap left `Runs::PersistenceSummaryService` a hybrid: it anchors on
  `runs.transition_epoch`, which is the relative reading from now on, while its
  sample-by-sample predicate was still the constant one. That misreads twice. On one series
  whose constant crossing is 510 and whose relative crossing is 560, the hybrid counts
  `epochs_persisted` 340 where the stored summary says 390 — and `lab:backfill_transitions`
  did not correct it, because the swap leaves both stored epochs equal to what a recompute
  finds, so the run was never revisited. Worse, a run whose baseline is 1.0 and whose series
  holds at 0.605 — transitioned under the relocked rule, never under the constant one —
  reads `epochs_persisted` 0 and `relapsed` true for a world that held the state for 390
  epochs, which is precisely the regime the relock exists to make measurable. **Decided:
  the summary is anchored on the relocked `transition_epoch` and qualifies each sample by
  the relative predicate**, `compress_ratio <= 0.61 x baseline` under the same two collapse
  guards. Every sample at or after a relocked transition lies outside the baseline window by
  construction, so the predicate is well defined over the whole span the summary reads, and
  "in the transitioned state" means one rule everywhere a run is read after its transition.
  A run whose samples hold no baseline has no summary, as it has no transition.
  **The corpus's stored persistence summaries therefore do move**, and
  `lab:backfill_transitions` now refreshes the summary of *every* run it visits rather than
  only the ones whose epochs changed.

  **Deploying it.** The app deploys before the runners, so there is a window in which a
  pre-relock runner posts to a relocked app. Nothing is mis-stored — the wire keys are
  rule-named and an older runner's `transition_epoch` is mapped to the constant column — but
  an in-flight run under a pre-relock runner **reads as untransitioned on the primary
  column** until `lab:backfill_transitions` rescores it. Post-deploy, in this order:
  `lab:backfill_transitions` (both readings, and the persistence summary of every run it
  visits), then `lab:backfill_emergence`, since a crossing that moved is a different
  candidate. `lab:backfill_persistence` is the standalone for a run that needs the summary
  alone rescored.

  **Pinned hashes.** No simulation byte moves: no RNG stream is drawn from, no `Metrics`
  field changes, the snapshot format is untouched (the relative block versions 6–8 already
  carry the baseline), and the pinned `(params, seed) -> hash` of both substrates and every
  pinned observable string in `world.rs` are **unmoved**. What moves is the *observable*
  `transition_epoch` itself, for the cap-512 arm and for any future run whose fall is small
  against its own start: a pinned reading of that observable is the one thing a reader must
  re-read, and the backfill is what re-reads the stored corpus.

  **The findings that only change their footing.** `complexity-keeps-rising` already reads
  both rules side by side (#224); its table now names the relocked reading as the primary
  one and the constant one as the companion, and no verdict on it moves — its peaks are read
  from emerged runs, and emergence is unchanged. Five sweep pages — `mutation-rate`,
  `mutation-rate-long`, `radius`, `world-size`, `max-steps` — state a verdict reached under
  the constant threshold while their tables and phase diagrams read `runs.transition_epoch`
  live, which is the relocked column. Each now says exactly that, and cites the claim above
  that covers it. No verdict on those five moves either.

  **The two findings whose population moves.** `emergence-can-be-left` and
  `copy-cost-adaptation` are surveys of `Run.transitioned`, which is `transition_epoch` not
  null — the relocked reading from now on — and they join samples at or after
  `runs.transition_epoch`. So **29 rows leave both** (the cap-512 arm, 30 flagged by the
  constant threshold, 1 kept by the relative rule), and none enters, since the corpus holds
  no crossing the relative rule finds and the constant one misses. Both pages count from the
  database at render time, so the headline counts fall by those 29; every surviving row
  re-anchors on a crossing 0 to 30 epochs later, so its epochs persisted and its first
  post-transition copy cost are read from there, and the persistence rule above moves the
  spans again. The **relapse verdict of `emergence-can-be-left` does not turn on the
  departing runs**: the two relapses the record names — the radius-2 run of 2026-09-11 and
  `mutation-rate-long` 2^-12 seed 10 — are 64-byte-tape runs in arms where the two rules
  read the same crossings, so "a transitioned world is not safe" survives the change of
  population. The exact split after the backfill is what the page prints; it is not asserted
  here. Both method paragraphs now name the rule they read by and say that the population
  moved.
- 2026-09-24 — **The host–parasite finding states its claim: one priced arm keeps rising, on
  one of its two measured runs, and the controls read neither.** Sweep 9 finished on 2026-09-20,
  1 260 runs, every one terminal, 90 per arm. Read under the amended measured-run rule of
  2026-09-21 (`FORMAT=csv lab:transition_report[host-parasite]`, 2026-09-24):

  | arm | emerged / 90 | measured | pre-registered unmeasured | rising | plateau | reading | theft |
  |---|---|---|---|---|---|---|---|
  | `0 128` (control) | 5 | 5 | 5 | 1 | 2 | neither | — |
  | `0 256` (control) | 4 | 4 | 4 | 1 | 1 | neither | — |
  | `0×8192 128` | 2 | 2 | 2 | 0 | 0 | neither | — |
  | `0×8192 256` | 2 | 2 | 2 | 0 | 1 | plateau | — |
  | `1024×8192 128` | 4 | 4 | 4 | 0 | 1 | neither | evolved, peak 0.93 |
  | `1024×8192 256` | 1 | 1 | 1 | 1 | 0 | unread | evolved, peak 0.85 |
  | `0×2048 128` | 2 | 2 | 2 | 0 | 1 | plateau | — |
  | `0×2048 256` | 1 | 1 | 1 | 1 | 0 | unread | — |
  | `1024×2048 128` | 2 | 2 | 2 | 1 | 0 | keeps rising | evolved, peak 0.32 |
  | `1024×2048 256` | 3 | 3 | 2 | 0 | 0 | neither | evolved, peak 0.94 |
  | `0×512 128` | 0 | 0 | 0 | 0 | 0 | barren | — |
  | `0×512 256` | 0 | 0 | 0 | 0 | 0 | barren | — |
  | `1024×512 128` | 0 | 0 | 0 | 0 | 0 | barren | evolved, peak 0.32 |
  | `1024×512 256` | 0 | 0 | 0 | 0 | 0 | barren | evolved, peak 0.32 |

  **The claim**: complexity kept rising in 1 of the 12 priced arms — `1024×2048 128`, on 1
  of its 2 measured runs, the smallest arm the rule reads, while its own control `0 128`
  holds a rising run too (1 of 5). Two priced arms plateau, three read neither, two are
  unread on one measured run, and the four 512-influx arms are barren: the poorest economy
  holds no replicator to read. Both controls read **neither**. No priced arm emerged more
  often than the control at its cap (none of the Fisher tests reaches p < 0.05), and theft
  evolved in all six steal arms (peak `steal_rate` 0.32–0.94), so no arm reads the
  theft-never-evolved null. **Pooled over runs**, the priced arms' measured runs rise no more
  often than the controls' — 3 of 17 against 2 of 9 — which is descriptive, not part of
  the pre-registered reading, and printed only so the one rising arm can be weighed. The
  refutation condition as worded — the priced arms plateau where their controls plateau — is
  not met, because neither control plateaus. **Under the pre-registered measured rule**,
  25 of the 26 emerged runs are unmeasured and no arm reads; the page states that beside the
  amended reading, as the 2026-09-21 entry requires.

  **Registry status `partial`**: the sweep has finished, but the one supporting arm stands on
  the fewest measured runs the rule reads, beside a control that holds a rising run too, so the
  reading cannot be taken as final; more seeds on `1024×2048 128` and `0 128` would decide
  it. The page renders every count above from the stored runs at render time through
  `Findings::ComplexityArmsReading`, which composes `Experiments::ComplexityArmsService`'s
  arms and pairs each treated arm with the control at its `max_tape_len`, so it is built to
  serve sweep 10 with its own control predicate. Nothing about the engine, the rules or any
  observable moves.
- 2026-09-24 — **The asymmetric-execution finding states its claim: every host arm is
  barren, so the refutation condition cannot be evaluated.** Sweep 10 finished on
  2026-09-20, 360 runs, every one terminal, 90 per arm. Read under the amended measured-run
  rule of 2026-09-21 (`FORMAT=csv lab:transition_report[asymmetric-execution]`, 2026-09-24):

  | arm | emerged / 90 | measured | pre-registered unmeasured | rising | plateau | reading |
  |---|---|---|---|---|---|---|
  | `concat 128` (control) | 5 | 5 | 5 | 1 | 2 | neither |
  | `concat 256` (control) | 4 | 4 | 4 | 1 | 1 | neither |
  | `host 128` | 0 | 0 | 0 | 0 | 0 | barren |
  | `host 256` | 0 | 0 | 0 | 0 | 0 | barren |

  **The claim**: nothing emerged under `host` — 0 of 90 at each cap against 5 and 4 of 90 in
  the `concat` controls at the same caps (two-sided Fisher exact p = 0.059 at 128 and 0.12 at
  256; pooled over both caps, descriptive only, 0 of 180 against 9 of 180, p = 0.0035).
  Under the 2026-09-15 rule a blank block of ten reads as an arm holding no replicator; here
  the blank block is every run of both arms. Running only the first tape's code did not lower
  the plateau, it kept replication from arising at all, which is the mode's own null the
  finding named in advance ("halving a pair's code stops abiogenesis"). So the
  **pre-registered refutation** — the `host` arms plateau where their `concat` controls
  plateau — **cannot be evaluated**: it needs a `host` plateau to set beside a control's, and
  a control read alone says nothing about asymmetry. The **secondary reading** on
  `distinct_lineages` is unreadable for the same reason: no host arm has a measured run and
  so no lineage span. The controls read **neither** under the amended rule (last-decile
  `distinct_lineages` medians 2 and 1, against 37 and 77 at the start), and **under the
  pre-registered measured rule** every one of the 9 emerged control runs is unmeasured, for a
  conserved core at zero, and no arm reads; the page prints both as reference readings of the
  same worlds. Those worlds are, seed for seed, sweep 9's economy-off control (`host-parasite`
  arms `0 128` and `0 256`): the same nine seeds emerged at the same epochs, because both
  sweeps ran the default substrate as their control and the engine is deterministic in
  `(params, seed)`. They are separate runs in the database, but the two findings' controls are
  one control read twice, not independent evidence.

  **Registry status `negative`**: the sweep finished and the effect was not there — the
  asymmetric mode produced no replicator to carry any effect, in 180 seeds. The page renders
  every count from the stored runs through `Findings::ComplexityArmsReading` with a `concat`
  control predicate (a run carrying no `interaction` reads the engine schema's default,
  `concat`), and gains an every-treated-arm-barren branch in its headline, verdict and
  refutation sentence. What the barren asymmetry bet means for the programme is not decided
  here; a later entry weighs it (#233). Nothing about the engine, the rules or any
  observable moves.
- 2026-09-24 — **Where the programme stands after sweeps 9 and 10: every pre-registered
  sweep has run, five substrate bets have been read, and the next substrate is an open
  decision.** This entry is a reading of the record, not a plan: it seeds no sweep, adds no
  §1.3 entry and changes no rule, sweep definition or observable. All ten sweeps of §1.3 are
  terminal (2 516 finished runs lab-wide, none pending), and the mini-pc run queue has been
  empty since 2026-09-20; it stays empty until the decision this entry ends on is taken.

  **The five bets on rung 4** ("does complexity keep rising"), each read by the finding that
  carries it. Emergence is the confirmed-crossing count (2026-09-15) against the arm's own
  control; complexity is read on `dominant_instruction_count`, never on compressed length
  (2026-09-16).

  | bet | sweep | emergence against its control | complexity reading | secondary | finding |
  |---|---|---|---|---|---|
  | Instruction cost | 6, `energy-per-epoch` | every priced arm lower (2, 2, 0 of 30 against 3 of 30); `2048` barren | decided on lineages as DESIGN states it: **not supported**; instructions printed without a verdict | — | `complexity-keeps-rising`, hypothesis 1 |
  | Environmental structure | 7, `environmental-structure` | both shapes lower (6 and 2 of 90 against 3 of 30) | **unresolved**: `gradient`'s median peak equals the control's (16 ops), `patchwork` untestable on one measured run | lineages **supported** (8 715 and 8 971 against 8 424) | `complexity-keeps-rising`, hypothesis 2 |
  | Room to grow | 8, `max-tape-len` | 5 and 4 of 90 at caps 128 and 256, 1 of 30 at 512, against 3 of 30 at 64 | **supported as a level**: median peak 26 and 33 ops at caps 128 and 256 against 10 at 64; `512` untestable | compressed length is the cap plus 11 bytes and decides nothing | `complexity-keeps-rising`, hypothesis 3 |
  | Contested energy | 9, `host-parasite` | every priced arm below the control at its cap, none at p < 0.05; the four 512-influx arms barren | 1 of 12 priced arms **keeps rising**, on 1 of 2 measured runs; 2 plateau, 3 neither, 2 unread; both controls **neither**; the pre-registered rule reads 25 of 26 emerged runs unmeasured and no arm | theft evolved in all six steal arms (peak `steal_rate` 0.32–0.94) | `complexity-under-contest` (`partial`) |
  | Asymmetric execution | 10, `asymmetric-execution` | both `host` arms **barren**, 0 of 90 each, against 5 and 4 of 90 (pooled, descriptive: 0 of 180 against 9 of 180, p = 0.0035) | **not evaluable**: no replicator arose to read | lineages unreadable for the same reason | `complexity-under-asymmetry` (`negative`) |

  **What the corpus says about "does complexity keep rising".** Across every substrate
  tested, nothing makes complexity keep climbing in a way the record can stand on. Room to
  grow raised the **height** of the plateau — the dominant tape of an emerged world reaches
  more ops when it has more bytes — but the within-run reading of sweeps 9 and 10, applied
  to the **very same worlds** (below), reads the cap-128 and cap-256 controls as neither: 1
  rising run of 5 and 1 of 4. The one priced arm that clears the rising bar (under the
  2026-09-21 amended rule) does so at the smallest n the rule reads, beside a control that
  holds a rising run too, and pooled over runs the priced arms rise no more often than the
  controls (3 of 17 against 2 of 9, descriptive). Every treated arm of the five bets emerged
  less often than its own control, as a point estimate: no arm's Fisher test reaches
  p < 0.05, only sweep 10's pooled, descriptive comparison does, and three treatments
  emerged in none of their seeds (the `2048` cost on 30, the 512 influx and the
  host mode on 90 an arm); since the complexity reading is taken on emerged runs only, each
  arm's reading rests on 0 to 6 runs, and in sweep 9 the post-crossing span those runs are
  read over has a median of 9 460 epochs (80 to 16 660) inside a 20 000-epoch budget. The
  mechanism the 2026-09-16 investigation proposed — a drift–selection balance in which a
  byte off the copy path costs nothing — is not contradicted by anything sweeps 9 and 10
  read.

  **The same 180 worlds, read three times.** Sweep 8's cap-128 and cap-256 arms, sweep 9's
  economy-off arms and sweep 10's `concat` arms are the default substrate at the same caps,
  rate, size and seeds 1–90, so the engine's determinism makes them the same runs computed
  three times — the same nine seeds emerge at the same epochs in all three (cap 128: 8, 14,
  31, 55, 71; cap 256: 3, 61, 63, 77). Sweep 8 reads them as treated arms against its cap-64
  control, sweeps 9 and 10 as their controls: the two later findings share one control, not
  two independent ones. Only sweep 10's control is a pure duplicate: sweep 8's runs predate
  `conserved_core_bytes` (2026-09-17) and carry no sample of it, so under sweep 9's reading
  they are unmeasured and sweep 9 needed its own control; sweep 10's, defined the same day
  as sweep 9's (2026-09-18), is the 180 runs that recompute it.

  **The literature #191 weighed, against what sweeps 9 and 10 actually showed.** #191 took
  the energy-stock-plus-steal result on a Z80 soup (arXiv 2609.10817) and Tierra's parasite
  arms race as the best fitness-free evidence that a contested quantity drives structure.
  Sweep 9 put that mechanism on BFF: theft evolved wherever it was offered, but the rise in
  structure #191 cited it for is read in one steal arm, on one of two measured runs, beside
  a control that holds a rising run too — not a rise the record can stand on. Sweep 10's
  host mode is the Tierra-shaped asymmetry, and it never produced a replicator at all;
  Tierra's parasites evolve from a hand-written ancestor, so Tierra never asked the
  host–parasite mechanism to also produce the first replicator, which is what this
  programme's design couples it to. The BFF group's 2026 paper (arXiv 2607.01483), which
  makes a plateau the expected outcome of the pairing dynamic, stands; the task-modulated
  pairing result (arXiv 2607.09211) remains the only one cited with a rising capability
  ladder, and it imports an objective.

  **The open decision.** Which substrate, or which question, the next sweep takes. The
  options, with the evidence for and against each; costs are from sweeps 9 and 10's measured
  `compute_seconds` (about 21 minutes a run at cap 128, 30 at cap 256, 12 runs at a time).

  1. **Decide the one rising arm.** More seeds on `1024×2048 128` and its control `0 128`.
     *For*: it is the only arm in the corpus that clears the rising bar, and the machinery
     exists. *Against*: it stands on 1 rising run of 2, and its control holds 1 of 5 — two
     rates that few runs cannot tell apart; at the rates the two arms showed (2 and 5 of
     90), 180 more seeds each add roughly four emerged runs to the priced arm and ten to the
     control. About nine hours of the mini-pc for 360 runs (the 2 048-influx arms at cap 128
     averaged 13 minutes a run, the control 21).
  2. **A longer horizon on the worlds that emerged.** *For*: the post-crossing spans are
     short (median 9 460 epochs in sweep 9, one run read over 80) and `mutation-rate-long`
     confirmed five of its eight emergences after epoch 20 000, so a slow climb could be
     hiding under the budget. *Against*: nothing in the stored series shows one, and the
     drift–selection mechanism does not depend on the horizon. A longer budget replays the
     first 20 000 epochs deterministically, so each run costs its whole length unless a run
     can be resumed past its original budget.
  3. **Start the treatments from an emerged world.** Take the post-crossing snapshots of the
     nine emerged control worlds and turn the economy or the host mode on from there. *For*:
     every treated arm emerged less often than its control and host mode not at all, so
     sweeps 9 and 10 read the complexity question on 0 to 5 runs an arm and asymmetry is
     unreadable rather than refuted; Tierra starts from an ancestor. *Against*: it is a new
     start condition that changes what a run's `(params, seed)` identity means (a parent
     snapshot becomes an input), needs engine support and a record entry, and answers a
     narrower question — does an existing replicator keep complicating under X — than
     spontaneous emergence.
  4. **A second, labelled substrate with an exogenous task** (arXiv 2607.09211). *For*: the
     only cited line of work with a rising capability ladder. *Against*: it imports an
     objective the programme has so far kept out, so it has to be a second substrate beside
     Soup, not a change to it.
  5. **A richer instruction set.** *For*: the energy-and-theft result is on a Z80 soup and
     sweep 9 did not reproduce its rise in structure on BFF, so what a tape can express may
     be the binding difference. *Against*: a new substrate's engineering cost, and no
     measurement here isolates the instruction set as the constraint — sweep 5 only removed
     ops.
  6. **Close rung 4 on Soup and spend compute below it.** The evolution programme entry
     (2026-09-11) defined the `persistence`, `lineage-diversity` and `adaptation` sweeps for
     rungs 1–3, and none has been seeded: what the site says about those rungs is read off
     surveys of runs assembled by having transitioned. *For*: five bets have run on rung 4
     and a mechanism for the plateau has been proposed that nothing since contradicts, while
     the rungs below it have never had their own designed sweep. *Against*: it leaves the
     programme's headline question answered only in the negative, and only for this
     substrate.

  Independently of which is chosen: the pending relock of `transition_epoch` (#229, #237)
  moves no emergence count above — emergence here is census- or copy-confirmed, and the
  relative rule flags exactly the runs the constant one does in every arm at cap ≤ 256: the
  2026-09-19 rescore for the corpus it covered, the 2026-09-24 transition reports for sweeps
  9 and 10, where it reads each crossing 10 to 30 epochs later. And any future sweep whose
  control is the default substrate at caps 128/256 on seeds 1–90 can read sweep 9's 180
  stored worlds, for any observable they record, rather than run them a fourth time.
