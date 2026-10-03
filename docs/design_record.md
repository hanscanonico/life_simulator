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
- 2026-09-25 — **The next step after sweeps 9 and 10: decide the one rising arm now, and
  build runs that start from an emerged world.** The open decision the previous entry ends
  on, an experimental choice made by the orchestrator after the user's instruction of
  2026-09-25: "continue the experimentation of this project to create life — You are free to
  do whatever you think is best, look at issues, run things on the mini pc, other things
  etc". It is a choice of which experiment runs next, not a change to any rule or locked
  decision of the programme. Two of the six options are chosen, in order: option 1 now, on
  compute alone, and option 3 next, as engineering. Options 2, 4, 5 and 6 are not taken;
  option 2 and rung 1's persistence sweep ride on option 3's machinery (below), and options
  4 and 5 wait on what option 3 reads. The relock of `transition_epoch` (#229, #237) remains
  pending the user's approval, as the previous entry states, and nothing here depends on it.

  **What the emerged worlds hold after their crossing** (two read-only lab queries,
  2026-09-25, SELECTs only). Sweep 9's economy-off arms emerged in nine worlds — cap 128:
  runs 944, 950, 967, 991, 1007 (seeds 8, 14, 31, 55, 71); cap 256: runs 1029, 1087, 1089,
  1103 (seeds 3, 61, 63, 77) — and sweep 8's cap-128 and cap-256 arms and sweep 10's
  `concat` arms emerged on exactly the same seeds, so these are the only emerged
  default-substrate worlds at these caps lab-wide. None is a colony that held and then died:
  in each, the replicator census is intermittent from the crossing on, positive in 23 of
  1 050, 139 of 959, 8 of 1 412, 2 of 313, 3 of 1 184, 7 of 1 239 and 152 of 1 232
  post-emergence samples of runs 944, 967, 1007, 1029, 1087, 1089 and 1103, and never
  positive in 950 and 991, which `copy_rate` alone confirmed. `dominant_replicates` is true
  only on those samples, while copying goes on between them: a run's median post-crossing
  `copy_rate` is 10^-4 to 2·10^-3, against a median of 0 before its crossing. What does
  change steadily after the crossing is the lineage structure: over the last decile of the
  post-crossing samples `distinct_lineages` is 1 or 2 and `top_lineage_share` 0.55–1.0 in
  eight of the nine worlds (run 991, which crossed at epoch 17 200, is at 18 and 0.24). An
  emerged world is a near-monoculture that keeps copying and mostly fails the replicator
  test, with `dominant_raw_len` at the cap before and after the crossing. Cap 64 is no
  better (sweep 8's runs 367 and 371: one census burst peaking at 867 and gone within about
  600 epochs, then intermittent bursts until 15 430), and lab-wide, of the 70 finished runs
  with a confirmed emergence and any census above zero — `mutation-rate-long`'s 60 000-epoch
  runs and `bff-control` included — one (run 1357, `host-parasite` cap 128, seed 61) still
  has a census above zero at its final sample. **So the complexity spans sweeps 9 and 10
  read were read over near-monocultures whose census is mostly zero**, and rung 1's question
  — does a colony persist — comes before rung 4's.

  **Now: sweep 9 is amended so three arms run seeds 1–270 instead of 1–90.** The arms are
  `1024×2048 128` (`energy_influx` 2^11, `steal_amount` 2^10, `max_tape_len` 128), its
  control `0 128` (the economy off, cap 128) and the other control `0 256` (the economy off,
  cap 256). The first two are option 1 as the previous entry states it: `1024×2048 128` is
  the only priced arm in the corpus that reads keeps rising, on 1 of its 2 measured runs,
  beside a control holding 1 rising run of 5, and the host–parasite entry of 2026-09-24
  names more seeds on these two arms as what decides it. At the rates they showed (2 and 5
  emerged of 90), 180 more seeds add roughly 4 emerged runs to the arm and 10 to its
  control. `0 256` is in for option 3: the economy-off controls are the emerged
  default-substrate worlds option 3 starts from, and at 4 of 90 the cap-256 control adds
  roughly 8, so the pool of parent worlds grows by about 18 beside today's 9 — roughly three
  times as many. Cost, from sweep 9's measured `compute_seconds` at 12 runs at a time: a
  mean of about 13 minutes a run for the 2 048-influx arm, 21 at `0 128` and 30 at `0 256`,
  as the previous entry states them — 540 runs and about 16 hours of the mini-pc.

  The amendment adds seeds to arms sweep 9 already defines. It changes no rule, no
  observable, no arm and no stored run: the new seeds are new `(params, seed)` points, so
  nothing stored moves, and seeding is idempotent on canonical params and seed, so
  re-running `lab:sweep[host_parasite]` queues exactly the 540 new runs. Seeds 91–270 are
  not in sweep 8 or sweep 10, so the "same 180 worlds, read three times" of the previous
  entry stays true of seeds 1–90 only; sweep 10's control keeps its 90 seeds and its reading
  does not move. An arm here is an economy bundle and a cap together, so `seeds_by_arm`
  gains a form that names an arm by several parameters at once; the one-parameter form
  sweeps 7 and 8 stored still reads.

  **How `complexity-under-contest` is re-read once the new seeds are terminal.** The same
  rule — the 2026-09-21 amended measured-run rule, with the pre-registered rule's reading
  printed beside it — and the same pairing, each treated arm against the economy-off control
  at its `max_tape_len`. At cap 128 the question becomes `1024×2048 128` at n = 270 against
  `0 128` at n = 270; every other priced arm keeps n = 90 and is compared, by Fisher's exact
  test on emergence as before, against a control that now has 270. Until then the page
  counts terminal runs only, so a pending seed is neither an emerged run nor an unemerged
  one. The extension was chosen after the 90-seed reading was seen, and the re-read says so.
  The finding stays `partial`, and its claim is rewritten in its own entry when the runs
  finish.

  **Next: option 3, runs that start from an emerged world ("descendant runs").** A run whose
  start is a stored post-emergence snapshot of a parent run, with params that may switch a
  treatment on (the economy, host mode) and a fresh continuation seed. Chosen over options
  2, 4, 5 and 6 because every treated arm of the five bets emerged less often than its
  control, as a point estimate, and host mode never: sweeps 9 and 10 read the complexity
  question on 0 to 5 runs an arm, and asymmetry is unreadable rather than refuted. Starting
  from an emerged world decouples "does X keep complexity rising" from "does X let a
  replicator arise", which is Tierra's framing — a hand-written ancestor, never a
  spontaneous one. The same machinery carries option 2 (a descendant with its parent's own
  params is a longer horizon without replaying the first 20 000 epochs) and rung 1's
  persistence hypothesis (2026-09-11: the relapse hazard against colony age needs many
  emerged colonies watched for a long time, and a handful of spontaneous emergences cannot
  give that). Given the near-monocultures above, **the first question descendant runs answer
  is rung 1's: under what continuation does the census hold?** The candidate arms are the
  parent's own params; a lowered mutation rate, on an error-threshold estimate (at 2^-13 a
  128-byte tape takes 1/64 of a mutation an epoch, against at most about 0.002 copies a cell
  an epoch at the copy rates above, so about eight mutations a copy or more); the economy;
  and host mode. Rung 4's question is read on the same children only where a census holds.
  Options 4 and 5 wait on what option 3 reads: if an existing replicator does not keep
  complicating under the economy or host mode either, the instruction set becomes the
  leading suspect and option 5 the next bet; if it does, the BFF substrate was never the
  binding constraint, emergence was.

  Option 3 changes what a run's identity means — a parent snapshot becomes an input — so it
  is pre-registered in its own entry, with its sweep as §1.3 item 11, once the machinery
  exists. That entry must lock: **the child's identity** (the parent snapshot's digest, the
  child's params and its continuation seed, and nothing else); **the parent snapshot**, the
  world a child starts from — an emerged run's terminal snapshot, at epoch 20 000, which all
  nine worlds above have stored and thinning never removes, is the one this entry expects,
  and the exact rule is that entry's to lock; **which params may differ** from the parent's,
  and which may not (world size, tape length, anything the snapshot's shape fixes); **epoch
  numbering**, whether a child counts on from its parent's epoch or from zero, which decides
  what "the last decile" and a colony's age mean; and **the readings**: the relapse hazard
  against colony age for rung 1, and the complexity rule of sweeps 9 and 10 over the child's
  span, since a child starts post-emergence. This entry takes the decision and names those
  questions; it designs none of them.
- 2026-09-25 — **The replicator census is blind to replicators that copy in reverse.** The
  worlds the programme reads as near-monocultures that mostly fail the replicator test
  (previous entry) are, by a pilot's reading, worlds of working replicators the test cannot
  count. This entry records the pilot, adds orientation-aware companion observables beside
  the census, and relocks nothing: `replicator_count`, `copy_rate`, the emergence rule and
  every finding stand as they are until the user decides what follows.

  **The pilot** (2026-09-25; every number below is a pilot's, from read-only lab data). The
  terminal snapshots of the nine emerged sweep-9 worlds — cap 128: runs 944, 950, 967, 991,
  1007; cap 256: runs 1029, 1087, 1089, 1103 — and of three `bff-control` runs (182 at
  mutation 0, 184 and 185 at 2^-12; fixed 64-byte tapes) were restored and stepped with the
  engine's own code by a scratch crate, the repository untouched and the mini-pc read with
  SELECTs only. The pipeline reproduces the lab: run 1007's epoch-19 000 snapshot stepped
  forward reproduces its stored samples 19 010–19 100 exactly, and run 967 replayed from
  13 000 to 13 890 reproduces the stored census of 246 and its dominant tape hash.

  | world | cap | census | cells ≥ 0.99 reversed (aligned) | cells ≥ 0.9 reversed (best rotation) | in-situ forward copy | in-situ reverse copy |
  |---|---|---|---|---|---|---|
  | 944 | 128 | 0 | 0.82 | 0.93 | 0.0007 | 0.64 |
  | 950 | 128 | 0 | 0.91 | 0.93 | 0.0001 | 0.71 |
  | 967 | 128 | 0 | 0.89 | 0.96 | 0.0013 | 0.71 |
  | 991 | 128 | 0 | 0.51 | 0.74 | 0.0010 | 0.39 |
  | 1007 | 128 | 0 | 0.97 | 0.98 | 0.0008 | 0.71 |
  | 1029 | 256 | 0 | 0.90 | 0.97 | 0.0012 | 0.69 |
  | 1087 | 256 | 0 | 0.01 | 0.95 | 0.0007 | 0.005 |
  | 1089 | 256 | 0 | 0.65 | 0.99 | 0.0002 | 0.52 |
  | 1103 | 256 | 0 | 0.89 | 0.98 | 0.0002 | 0.71 |
  | BFF 184 (2^-12) | 64 fixed | 0 | 0.78 | 0.83 | 0.0000 | 0.91 |
  | BFF 185 (2^-12) | 64 fixed | 0 | 0.97 | 0.97 | 0.0000 | 0.95 |
  | BFF 182 (0) | 64 fixed | 0 | 0.25 | 0.32 | 0.0014 | 0.23 |

  A cell's "reversed" fidelity is the share of its partner half that holds its tape
  reversed after one interaction, over 500 random cells × 50 world partners (rotation: 300
  cells × 20 partners); the in-situ rates are 16 384 neighbour pairs under the engine's own
  pairing and copy rule. Before the interaction the reversed fidelity is 0.07–0.18. The
  in-situ forward rate of run 1007, 0.00079, is its stored `copy_rate` at epoch 20 000. Every
  top-10 tape of every world passes the engine's own test 0 times in 4 on all 8 draws, and
  writes its exact reverse 64 times in 64 in all but run 1087's (reversed with a rotation of
  2) and one of run 1103's ten.

  **The mechanism.** Run 1007's commonest tape, skeleton `{[.<>>{]>]{>.><[{`: `{` moves
  head1 from 0 to the pair's last byte, and the loop `[.<>>{]` copies head0 onto head1 with
  head0 moving right and head1 left, so the partner half becomes `reverse(T)` byte-exact
  whatever it held. The tape holds no zero byte, so the loop never exits, runs out the 8 192
  steps and leaves its own half as it was. The tail mirrors the loop, so `reverse(T)` runs the
  same program and writes `T` back: the population is `X` and `reverse(X)`, a two-generation
  replicator (in 1007, 15 163 of 16 384 cells have their exact reverse elsewhere in the
  world). The replicator test asks for `T` itself in the partner (`replicator.rs`,
  `&buf[len..] == tape`), and `copy_rate` for a same-orientation image, so neither can
  count it. **The census positives on record are exact palindromes** (`T == reverse(T)`):
  at run 967's epoch 13 890, census 246, the tapes that passed are palindromes among the top
  16, and all 16 tested tapes there pass the reversed and two-generation tests.

  **The error-threshold reading of this morning is contradicted.** The previous entry named
  a lowered mutation rate as a candidate continuation, on an estimate of about eight
  mutations a copy. Measured, the worlds make about 0.7 new exact reversed copies per cell
  per epoch against 1/64 (1/32 at cap 256) mutation hits per tape per epoch: copying
  outpaces mutation 20–45×. Continued from their own terminal worlds at mutation 0, runs
  1007, 1029 and 1103 go clonal — distinct tapes fall from 4 018, 7 143 and 5 742 to 22, 265
  and 47, and run 1007 ends 5 000 epochs later with every sampled cell a perfect reverse
  copier — while the census never reads above 0; in run 967 lowering mutation *reduced* the share of samples
  with a positive census, from 0.40 to 0.004–0.014, because the palindromic variants were
  lost.

  **The same class elsewhere.** The 2024 BFF paper's canonical replicator
  (`[[{.>]-] ]-]>.{[[`) is a palindrome copied in reverse. cubff also starts both heads at 0
  and wraps modulo the pair, so `{` from 0 lands on the partner's last byte there too; in
  short seeded cubff runs, 36–37% of tapes pass cubff's own detector at the transition and
  every one writes `reverse(parent)` (preliminary; stopped early). The 2026 paper's detector
  (arXiv 2607.01483, Algorithm 1; cubff's `CheckSelfRep`) sees them because it runs an odd
  chain of five runs against noise and compares the final first half with the original:
  over nine chains it counts the positions that hold the original byte in at least three
  of them (cubff: more than three of thirteen), scores the second halves' agreement with
  one another the same way, keeps the smaller score and passes at 48 of 64 bytes.

  **Decision: add orientation-aware companions, relocking nothing.** DESIGN §1.2 gains the
  orientation-aware detector (`replicator::self_replicates`: the paper's chain of 5, 5
  trials, a strict majority of them per position — stricter than the paper's three of
  nine — 3/4 of positions, the carried first half alone, and a separate rotated verdict)
  and four sampled observables: `replicator_share` and `replicator_share_rotated`, the share
  of 256 cells drawn uniformly with replacement whose tape passes aligned and under rotation;
  `dominant_self_replicates`; and `reverse_copy_rate`, `copy_rate` with the image reversed.
  They draw only from streams of their own and write nothing back: every pinned hash and
  every pinned observable string of the engine passes unmodified, and `replicator_count`,
  `copy_rate` and every other observable read what they read before. The per-sample cost is
  about 4% (3.7–4.1%) of the ten epochs a sample reads, measured on the terminal worlds of
  runs 1007, 1029 and 1087, the worst case (every interaction runs out the step budget). On
  run 1007's world the new readings give `replicator_share` 0.96 and `reverse_copy_rate`
  0.73 where the census reads 0. Run 1087's copy reflects about an axis one byte off the
  pair's centre (the pilot's rotation of 2, `B[(254 − i) mod 256] = A[i]`), so its
  `reverse_copy_rate` stays near 0; but the next copy reflects about the same axis and
  undoes the offset, so the five-run chain passes it aligned, `replicator_share` 0.91 and
  rotated 0.94. Random tapes, a fresh soup a few hundred epochs in, and the dominant
  tapes of runs 1007, 967 and 1087 with their `.` removed or their bytes shuffled all fail.

  **For the user to decide.** Whether `replicator_count`, the emergence confirmation
  (2026-09-15, #172/#189) and the persistence and relapse readings relock on the
  orientation-aware detector. That decision comes after the stored corpus is rescored with
  the detector (the next slice) and the findings that rest on the census can be read both
  ways. Exposed until then:
  - census-confirmed emergence in every sweep, where a crossing was confirmed by the census
    rather than by `copy_rate`;
  - `emergence-can-be-left`: its relapses are census zeros, which in these worlds read
    reverse copiers as absent;
  - the persistence summaries, read off the same census;
  - the dominant-replicator readings — `dominant_replicates` and `copy_cost`, and with them
    `copy-cost-adaptation` — which price only same-orientation copiers and palindromes;
  - the lineage observables: `inherits_partner`, `lineage_variation` and
    `conserved_core_bytes` compare aligned bytes, so a population of `X` and `reverse(X)`
    reads as two drifting halves (run 1007 continued at mutation 0 ends at a
    `lineage_variation` of 100.6 bytes and a conserved core of 0 over 22 near-clones). A
    stated limitation; nothing here fixes it;
  - the census's `top_k` = 16 window, whose tapes cover 2–4% of the cells of these worlds,
    so even an orientation-aware top-16 census would count a few percent of a world of
    replicators. The companions draw from the whole world instead.
- 2026-09-25 — **Runs that start from an emerged world: the from-emerged sweep,
  pre-registered.** Option 3 of the entry of 2026-09-24, chosen by the next-step entry
  above ("The next step after sweeps 9 and 10"), which named what this one must lock. It
  is §1.3 item 11, experiment `from-emerged` (sweep key `from_emerged` in `Lab::SWEEPS`).
  One finding changed the question after the next-step entry was written, and the entry
  starts from it.

  **What an emerged world is made of** (#245, a pilot on the nine worlds the previous
  entry lists, all numbers pilot). They are not relapsed monocultures. In 74–99% of their
  cells the tape is a working copier that writes a byte-exact **reversed** copy of itself
  into its partner on nearly every interaction; its reverse runs the same program, so the
  population is X and reverse(X). The locked replicator census and `copy_rate` compare in
  the same orientation only, so they read about zero in worlds that are about 95%
  replicators, and copying outpaces mutation 20 to 45 times. So the next-step entry's framing
  — rung 1 first, under what continuation does the census hold, with a lowered mutation rate
  as an error-threshold arm — is contradicted: the colonies held, the instrument did not see
  them. Descendant runs are therefore for **rung 4**: does an existing replicator keep
  complicating under a treatment? They also re-test rung 1's persistence, with an instrument
  that sees the replicators: the orientation-aware census (#247), sampled live as
  `replicator_share`, `replicator_share_rotated`, `dominant_self_replicates` and
  `reverse_copy_rate`, and read from stored worlds into `snapshot_readings` under instrument
  `oriented_census/1` (#246). The lowered-mutation arm is dropped: its premise was the error
  threshold.

  **Identity.** A descendant run is determined by **(its parent run's stored world at
  `parent_epoch`, its params, its seed)**, and nothing else; this amends DESIGN §1.1's
  "(params, seed)" for descendants only. Its epoch count continues its parent's: it starts
  at `parent_epoch` and `epochs` is the absolute epoch it stops at, so its own span is
  `epochs − parent_epoch` and its own samples are those at epochs above `parent_epoch`. A
  child with its parent's params and seed is the exact continuation of the parent, byte for
  byte (the engine's `World::descend` test, #243). Inside the experiment a child is
  identified by (canonical params, seed, parent run, parent epoch), so re-seeding the sweep
  never duplicates a child.

  **The parent rule.** A parent is a finished run of experiment `host-parasite` in one of
  sweep 9's two economy-off controls, `{energy_influx 0, steal_amount 0, max_tape_len 128}`
  and the same at `max_tape_len 256`, seeds 1–270 as the next-step entry extended them. The
  world a child starts from is the parent's **last stored world**, its terminal snapshot at
  `epochs`: every finished run stores it and thinning never removes it, so the rule names
  the same world for every parent and needs no choice of a post-crossing epoch. A parent
  **qualifies** when the `snapshot_readings` row under `oriented_census/1` at that epoch reads
  `replicator_share ≥ 0.5` — at least half of the world's cells are orientation-aware
  replicators. Emergence as this record defines it (census- or copy-confirmed, 2026-09-15)
  is not the gate, because that census is blind to the reverse copiers that fill these
  worlds; a child still carries its parent's emergence epoch where it has one, which is
  what `colony_age_at` counts from. A parent that has no such reading yet does not qualify
  **yet**: the builder skips it and says so, by reason (not finished, no stored world at the
  last epoch, no reading of the last world, share below the minimum), and re-seeding once
  the readings pass reaches it adds its children. What may differ from the parent is the
  **dynamics** only; what may not is the world's shape, `Lab::CanonicalParams::
  STRUCTURAL_KEYS` (`substrate`, `width`, `height`, `tape_len`, `max_tape_len`, `ops`),
  which Rails and the engine both refuse to change. **Stock minting** is a treatment
  choice, named as one: the parents hold no energy, so in the priced arms every cell starts
  full at the child's `energy_stock_cap`, as a fresh run does, and the economy is switched
  on over a world that has never been priced.

  **The sweep.** Every qualifying parent × four treatments × three seeds, each treatment a
  bundle merged over the parent's params:
  1. `{}` — the **continuation**, the parent's own dynamics: the control;
  2. `{energy_influx 2^11, steal_amount 2^10, energy_stock_cap 4·2^13, steal_loss 0.5}` —
     sweep 9's one arm that read keeps rising;
  3. `{energy_influx 2^13, steal_amount 2^10, energy_stock_cap 4·2^13, steal_loss 0.5}` —
     the rich economy;
  4. `{interaction host}` — sweep 10's asymmetry.

  Seeds 1001, 1002 and 1003, the same under every treatment and none a parent's own, so the
  design is **paired**: each (parent, seed) is observed under all four, and a treated child
  is read against the continuation child of the same (parent, seed). Budget 20 000 epochs
  past the parent, so a child of a 20 000-epoch parent runs 20 000 → 40 000. Priority 50,
  ahead of sweep 9's extension (seed-major, 0 − seed). That is **12 children per qualifying
  parent**. The expected pool today is the nine emerged controls the next-step entry lists.
  #247 read four of their terminal worlds with the detector the gate reads, at epoch
  20 000: `replicator_share` 0.96 for 1007, 0.91 for 1087, 0.95 for 967 and 0.71 for 991,
  each with a self-replicating dominant tape. 1087 passes aligned although its copy
  reflects about an axis one byte off centre, because the offset cancels over the
  detector's five-run chain. The other five are expected to qualify but have no reading
  yet, and the pilot's single-generation measures are not the shares the gate reads; any
  that reads below 0.5 is skipped and reported, not re-gated. The extension to seeds
  91–270 adds about 18 more emerged worlds. So about 108 children now and about 320 once the
  extension is terminal. **Cost**, from sweep 9's measured `compute_seconds` at 12 runs at a
  time (the next-step entry's figures): about 21 minutes a 20 000-epoch run at cap 128 and 30
  at cap 256 for the economy off, 13 for the 2 048-influx arm. An emerged world is dearer
  than those means, which average over worlds that mostly never emerged: its copier loops
  never exit and spend the whole step budget of every interaction. Taking 30 minutes a child
  as the planning figure, 108 children are about 54 run-hours, about 4½ hours of the
  mini-pc, and 320 about 13 hours; the first finished children's `compute_seconds` replace
  the estimate.

  **The readings, per child, over its own samples** (epochs above `parent_epoch`; the
  numbers live in `Lab::DescendantReading`, which the reading reads):
  - **Persistence (rung 1).** A child **held** its replicators when the median
    `replicator_share` of its last decile of samples is at least **0.5** and the share never
    sat below **0.1** for **3** consecutive samples; it **relapsed** otherwise. The
    2026-09-11 rung-1 hypothesis, **the hazard of relapse is constant per epoch**, is read on
    the continuation children against `colony_age_at`, the age counted from the parent's
    emergence; a child whose parent has no emergence epoch has no colony age and is left out
    of it. A relapsed child's **relapse epoch** is the first sample of its first run of 3
    samples below 0.1; a child that relapsed on its last decile alone is listed without
    one. This reading is descriptive: each relapse is listed with its colony age beside the
    colony ages every continuation child was watched over, and no test of the hazard's
    shape is pre-registered here, since the pilot expects few relapses or none. If no
    continuation child relapses, the record says the colonies persisted over the budget and
    that the constant-hazard hypothesis had no relapse to be read on.
  - **Complexity (rung 4).** `dominant_instruction_count` over the samples whose
    `dominant_self_replicates` is true. A child **rises** when its last-decile median is at
    least **1.2 ×** its first-decile median, **plateaus** when the last-decile median is
    within **±10%** of the first, and reads **mixed** otherwise. A child is **unmeasured**
    when fewer than **10** samples in either decile have a self-replicating dominant tape.
    The conserved-core clause of the sweeps 9 and 10 rule (2026-09-21) is **dropped** for
    this sweep: `conserved_core_bytes` compares aligned bytes and reads 0 in a population of
    X and reverse(X) (#245), so in these worlds it measures orientation, not conservation.

  **Hypotheses and what refutes them.**
  - **H-economy.** A priced arm's children rise more often than their paired continuation
    children. Read with a one-sided sign test over the (parent, seed) pairs where the two
    children's rise verdicts differ, at p < 0.05, only on pairs where both children are
    measured. Refuted if the priced arm rises no more often than the continuation; an arm
    that rises more often short of p < 0.05 reads **not shown**, neither held nor refuted.
    Each priced arm (2 and 3 above) is read on its own.
  - **H-host.** The same for the host arm against the continuation.
  - **H-persistence.** The continuation children hold. Refuted by any continuation child
    that relapses; how many did is reported.
  - A treated arm whose children relapse more often than the continuation's is reported as
    such: that is the treatment killing replicators, not a complexity reading, and its
    complexity verdicts are printed but not read as H-economy or H-host.
  - Secondary and descriptive only: `steal_rate` in the priced arms, the `replicator_share`
    trajectories, `distinct_tapes`.

  **When it is read.** When sweep 9's extension is terminal, the readings pass has read its
  terminal worlds, and every child of every parent that then qualifies has finished. A
  reading printed before that is labelled **interim**. The children need a runner that
  samples the orientation-aware keys, and the parents need the reading of their terminal
  worlds, so the sweep is seeded only once #247 is deployed and the readings pass has read
  `host-parasite`'s latest worlds; a child that sampled none of those keys is unmeasured
  by construction.

  **What is not claimed.** This asks whether an **existing** replicator keeps complicating
  under a treatment. It is not spontaneous emergence, and says nothing about whether the
  treatment lets a replicator arise. Every child of one parent shares that parent's world,
  so the children are not independent: the reading reports, beside the pooled sign tests,
  per-parent agreement — for each parent and each treated arm, how many of its three pairs
  favour the treatment, favour the continuation or tie — and a sign test that falls to
  p ≥ 0.05 once the pairs of some one or two parents are left out is stated as carried by
  those parents.
- 2026-09-25 — **The from-emerged reading: six clarifications made before any child was
  read.** The entry above left six places a reading could go two ways. They were closed on
  the day the sweep was seeded, while every one of its children was still running and before
  any reading of them, interim or otherwise, had been printed or consulted. The rules now
  read, in `Experiments::FromEmergedReadingService` and `Lab::DescendantReading`:
  1. **Deciles.** A child's first and last deciles are the first and last `ceil(n / 10)` of
     all `n` of its own samples in epoch order, as sweeps 9 and 10 cut them over a run's
     samples; the complexity rule then reads, inside each decile, the samples whose
     `dominant_self_replicates` is true. The samples are not filtered before the deciles are
     cut: the rule compares the dominant replicator early against late, and a filtered
     series would take a child whose replicator lapsed at its "last decile" from mid-span,
     while "fewer than 10 samples in either decile have a self-replicating dominant tape"
     would reduce to a count of the whole series. A median is the lower middle
     (`Findings::Median`), and a value the engine did not report as a number drops out of
     its decile.
  2. **No measured pair.** A treated arm with no (parent, seed) pair measured on both sides
     reads **no measured pairs**: neither held, not shown nor refuted. An arm with measured
     pairs but none discordant rises no more often than the continuation and is refuted.
  3. **Relapsing more often** is a strictly larger share of relapsed children among the
     children read for persistence, the treated arm's against the continuation's, untested.
     In the final reading the arms are the same size and this is a count; in an interim one
     it compares only the children read so far.
  4. **Per-parent agreement** counts ties among the pairs measured on both sides; a pair not
     measured on both sides is counted in a column of its own, not as a tie.
  5. **Leaving parents out** is read on a test that holds (p < 0.05) only. Every set of one
     or two parents whose pairs, left out, bring p to 0.05 or above — or leave no discordant
     pair — is listed as carrying the test, except a set containing a smaller one already
     listed.
  6. **Finished** means finished: a failed child keeps the reading interim until it is
     re-run and finishes, since its samples stop short of its budget. The parents' pool is
     settled when every candidate is terminal and every finished one that kept its world
     has been read.
- 2026-09-25 — **Oriented companions for heredity and adaptation: the lineage readings
  read the way round, and `copy_latency` beside `copy_cost`.** The pilot recorded in the
  entry "The replicator census is blind to replicators that copy in reverse" found that an
  emerged world is a population of tapes `X` and `reverse(X)`, byte-exact reverse copiers
  whose loop never exits and runs the full `max_steps`. Two more families of observables
  cannot read such a population, and this entry adds a companion beside each. It relocks
  nothing: every existing observable, every pinned hash and every run stays as it was to the
  bit, and the new fields are appended at the end of `Metrics`.

  **Heredity, rung 2.** `lineage_variation` and `conserved_core_bytes` / `_ops` compare
  aligned bytes, so a lineage of near-clones copied two ways round reads most of a tape of
  variation and a core of only the positions `X` and its reverse happen to share. The
  entry "The replicator census is blind to replicators that copy in reverse" gave the
  pilot's run 1007 continued at mutation 0 as the instance — `lineage_variation` 100.6 over
  "22 near-clones" — and that description is corrected below.
  `lineage_variation_oriented` and `conserved_core_bytes_oriented` /
  `conserved_core_ops_oriented` put each member of a lineage the way round — its live bytes
  as they are, or last to first — that is Hamming-closer to its lineage's modal tape, a tie
  keeping it as it is, and then read exactly as the aligned definitions do. A tape that grew
  is reversed over its own live length. They draw nothing.

  **Adaptation, rung 3.** `copy_cost` stays as locked: interpreter steps per byte-exact
  copy, the median over the passing trials of the replicator test. It is undefined for a
  copier that never halts, which is every dominant copier of the emerged corpus, so the
  rung-3 question — do later replicators copy more cheaply — had no reading there.
  `copy_latency` is that reading: the step at which the partner half first holds a complete
  byte-exact image of the dominant tape in either orientation, whether or not the program
  ever halts. It uses the orientation-aware detector's setup — the fixed `2·len` buffer, a
  fresh noise partner, `max_steps` — one generation per trial over `SELF_REP_TRIALS` trials;
  the reading is the median trial, null where fewer than half complete an image, and
  `copy_latency_orientation` says whether that trial's image lies `forward`, `reverse` or
  `both` (a palindrome). Its noise comes from a stream of its own
  (`STREAM_COPY_LATENCY`, `0x4c41_5445_0000_0000`), apart from every stream the run, the
  census and the detector draw on. The watch for a complete image runs in a replica of the
  interpreter kept for this reading alone, pinned step for step against `bff::run_with`;
  the interpreter the soup runs gains no per-step check.

  **What they cost and what they read.** On run 1007's stored world at epoch 20 000 with
  its own params (`sample_every` 10), the three companions add about 10 ms to a sample:
  5.3 ms for the oriented variation, 4.7 ms for the oriented core and 0.04 ms for the
  latency, whose five trials stop at the first complete image. A sample period there —
  ten epochs and one sample — takes about 2 s, so they add about 0.5% to a run. There they
  read `lineage_variation` 120.8 against 115.8 oriented, a core of 0 bytes both ways,
  `copy_cost` null and `copy_latency` 4 845 steps, `reverse`. The same world continued at
  mutation 0 to epoch 25 000 (the pilot's arm iii, seed 71) reproduces the pilot's 22
  distinct tapes and `lineage_variation` 100.6; oriented it reads 74.7, and a core of 1 byte
  against 0, with `copy_latency` 5 099, `reverse`. The oriented reading does what it is for
  — 4 018 cells sit at distance 0 from the modal tape oriented, 2 030 aligned — and shows
  what the pilot's summary missed: the 22 tapes are **eleven** tapes and their reverses,
  eleven different programs, not near-clones. Put the way round, they sit 20 to 127 bytes
  from the modal tape, and even under the best rotation 20 to 116 from it and 20 to 120 from
  one another, all under one lineage tag. The variation that remains is the tag's, not the
  orientation's (below).

  **The readings pass.** The new keys are not added to `oriented_census/1`: rows are
  already stored under it without them, its resume skip treats a world read under `/1` as
  read, and `OrientedSummary`, `OrientedArmsService` and `Lab::DescendantReading` read it.
  Widening `/1` would leave it meaning two things. `oriented_census/2` reads everything `/1`
  reads and the five new keys, each beside the aligned reading it accompanies
  (`lineage_variation`, `conserved_core_bytes` / `_ops`, `copy_cost`) as a control against
  the live sample. `runner readings-corpus --instrument` selects it; `/1` stays the default,
  so a `/1` pass reads exactly what it read. A `/2` pass is the lab's to run when asked.

  **What this does not change.** The from-emerged pre-registration's readings: they read
  `replicator_share`, `dominant_self_replicates`, `dominant_instruction_count`, the
  secondary `steal_rate` and `distinct_tapes`, and the `/1` readings, none of which moves,
  and none of these keys. The lineage **tags** are not
  touched either: a cell still takes its partner's tag when its new tape is Hamming-closer,
  aligned, to its partner's arriving tape. That rule is world state stored in every
  snapshot, and changing it would change existing runs. So after a takeover a cell
  overwritten by `reverse(A)` can keep its own tag, tags stop tracking descent, and one
  lineage can hold unrelated tapes; the oriented readings correct the orientation of the
  members they are given, not which members a lineage holds. That limitation stands until a
  record entry changes the rule.
- 2026-09-25 — **The interpreter skips what it can prove, and nothing else moves.** A
  performance change. No rule, parameter or observable changes, and every run, snapshot,
  sample and pinned hash stays identical to the bit. The pilot behind the entry "The
  replicator census is blind to replicators that copy in reverse" found that an emerged
  world is mostly reverse copiers whose loop never exits. Nearly every interaction runs all
  of `max_steps`, which is why from-emerged descendants took ~2.5 h per 20 000 epochs.

  `bff::run_stealing`, through which the soup, the census and the replicator test all run,
  now skips two kinds of steps whose outcome is already determined (DESIGN §1.1). The first
  is a whole cycle: the full state recurs at a jump back with the buffer unchanged, so whole
  periods of steps and steals are added at once. The second is a repeated lap: a loop that
  closes on the same bracket again is replayed from its acting steps at the shifted heads.
  Replay stops before any bracket that would read the other way and before any write to the
  lap's own code, and runs only on a buffer at its cap. The cycle case alone does nothing
  for emerged worlds: their loops span tens of bytes, so the heads never come round within
  8192 steps. The lap case is what speeds them up. Steps and steals come out exactly as a run
  of every step produces them, so the energy debit, the stock cap and the steal settlement
  all read what they read before. `bff::first_image`, the `copy_latency` interpreter, still
  steps one at a time.

  Equivalence tests hold the skipping interpreter to one that runs every step: 400 000
  random pairs, handwritten reverse copiers at 64, 128 and 256 bytes with ragged partners
  and room to grow, a forward copier that steals every lap, laps whose inner loop changes
  course, and a synthetic emerged world stepped 50 epochs with and without the skips, joined
  and hosted with the stock and steal on. The pilot's stored worlds 1007, 1029, 1087, 1089
  and 1103 stepped 50 epochs give the same hash every epoch, the same snapshot bytes and the
  same full sample. Single-thread epochs per second, before and after:
  run 1007 (cap 128) 5.6 → 29.6 (5.3×); run 1029 (cap 256) 5.6 → 20.5 (3.6×); the emerged
  BFF control 184 (512×256, 64 fixed) 0.82 → 2.1 (2.6×); a fresh random 128² soup at epoch
  100, 68 → 129 (1.9×).
- 2026-09-25 — **The lineage rule becomes a parameter: `lineage_rule`, `aligned` by default,
  `oriented` for tags that follow descent through reverse copies.** The entry "Oriented
  companions for heredity and adaptation" found that on run 1007's world continued at
  mutation 0 the 22 distinct tapes are eleven programs and their reverses, 20 to 127 bytes
  from the modal tape, **all under one lineage tag**. The tag is inherited by the rule of the 2026-09-13
  entry: a cell takes its partner's tag when its tape ends Hamming-closer, aligned, to the
  partner's arriving tape than to its own. A cell overwritten by `reverse(A)` is aligned-far
  from `A`, so it keeps its own tag while its bytes descend from `A`. After a takeover by a
  reverse copier the tags stop tracking descent. The oriented readings put members the right
  way round but read the aligned tags, so they cannot fix which members a lineage holds.
  That entry left the limitation standing "until a record entry changes the rule". This is
  that entry. It changes the rule by adding a second one beside it, not by replacing it.

  **The rule.** `lineage_rule ∈ {aligned, oriented}`, default `aligned` (DESIGN §1.2). At
  `aligned` the engine runs exactly the code it ran before. At `oriented` both distances are
  oriented: the distance from the cell's final tape to an arriving tape is the smaller of the
  Hamming distance to that tape and to its reverse. The reverse is taken over the arriving
  tape's live bytes and read from the cell's first byte, the image `reverse_copy_rate` reads
  a reverse copy as, so a grown tape's extra bytes count against both. The cell takes its
  partner's tag when
  `min(d(final, partner), d(final, reverse(partner))) < min(d(final, own), d(final, reverse(own)))`.
  The own side is oriented too because a comparison that allowed the partner a reversal and
  denied it to the cell would tilt every close call toward the partner. It would also move a
  cell whose own bytes came back to it reversed to another lineage, although nothing of
  anyone else's reached it. The tie still keeps the cell's own tag, and a palindrome's copy
  inherits under both rules. It follows that the oriented rule reads a tape and its reverse
  as one tape: a cell holding `X` overwritten by an exact forward copy of a partner holding
  `reverse(X)` is a tie and keeps its own tag, where the aligned rule hands it the
  partner's.

  **What it moves.** Nothing but tags. The rule reads the pair each interaction already keeps,
  draws nothing and writes no byte, so a world's bytes and every RNG stream are the same
  under both rules. Every pinned hash and observable digest stays as it was. New pins lock
  the oriented rule from the start. The 32×32 soup at seed 42, stepped 50 epochs, has the
  bytes `PINNED_SOUP_HASH` under `oriented` and the same tags as under `aligned`
  (`0x4d38_1366_823a_e560`): no interaction there leaves a tape nearer an arrival reversed.
  That is this world's reading, not a property of random soups: a 64×64 soup at seed 7 or
  seed 1 parts on 3 or 4 cells by epoch 50.
  A 16×16 world half seeded with the handwritten reverse replicator at the default mutation
  rate, seed 5, 50 epochs, has one set of bytes (`0x752c_1e85_b477_d74e`) and two sets of
  tags. It reads 39 distinct lineages aligned and 15 oriented. A reverse copier whose
  reverse agrees with it at no byte, invading a random half-world without mutation, keeps
  its 128 tags at home under `aligned`, while 12 cells hold its copy under their victims'
  tags. Under `oriented` its tags reach 140 cells and no copy wears a foreign tag. The
  snapshot stores no params, so its format does not change. The rule is dynamics, not
  structure: a descendant may switch it, and `Lab::CanonicalParams::STRUCTURAL_KEYS` does
  not name it.

  **Which runs use which.** Every existing run and the running `from-emerged` sweep use
  `aligned`. A run stored before the parameter existed carries no `lineage_rule` key, and
  `Lab::CanonicalParams` fills in the engine default, `aligned`, on both sides of every
  identity comparison. Stored runs keep their identity and are not rebuilt by a sweep that
  now writes the key. The rung-2 `lineage-diversity` sweep of the evolution-programme
  entry (2026-09-11), when it is pre-registered, will run at `lineage_rule = oriented`. Its
  hypothesis is about lineages sharing ancestry and drifting apart, and the aligned tag
  is the one reading that cannot follow ancestry through the reverse copies that dominate
  emerged worlds. Nothing is relocked.
- 2026-09-25 — **Lineage diversity after a transition: rung 2's `lineage-diversity` sweep,
  pre-registered, with a lineage census that can see it.** The evolution-programme entry
  (2026-09-11) locked rung 2's sweep and its hypothesis: **after a transition a world stays
  polyphyletic, and the number of surviving lineage ids grows as a cell's reach shrinks** —
  locality keeps lineages apart — refuted if every transitioned world collapses to one
  lineage id whatever the radius. It is the diversity half of §1.3 item 3 that the radius
  sweep entry left open. It was never seeded, because the instrument could not see it: the
  census is blind to the reverse copiers emerged worlds are made of (#245), and the lineage
  tags stopped following descent at a reverse copy. `replicator_share` (#247) now says
  whether a world holds replicators, and `lineage_rule = oriented` (entry above) makes the
  tags follow descent through reverse copies. This entry adds the last piece, a reading of
  "polyphyletic", and locks the sweep. It is §1.3 item 12, experiment `lineage-diversity`
  (sweep key `lineage_diversity`), and its numbers live in `Lab::LineageDiversityReading`.

  **The observables.** `distinct_lineages` is a poor reading of "polyphyletic". It counts
  every tag any cell holds, and every cell starts with a tag of its own, so the relics of
  cells no copy ever reached inflate it: a colony holding 99% of a world beside 100 relic
  singletons reads 101. `top_lineage_share` reads the largest lineage and nothing about the
  rest. DESIGN §1.2 gains two engine observables, appended at the end of `Metrics`:
  - `lineage_effective_count`, the **inverse Simpson index** of the lineage shares,
    `1 / Σ pᵢ²` over the tags the cells hold, computed as `N² / Σ nᵢ²` in integers. It reads
    1 for a monophyletic world and k for k equal lineages; the colony above reads 1.02;
  - `lineages_over_one_percent`, the number of tags each holding at least 1% of the cells.

  Both read the tags alone, draw nothing and write nothing, so every existing observable,
  run and pinned hash is unchanged; new pins lock them on the pinned worlds. The 32×32 soup
  at seed 42, epoch 50, reads 1 020.0 effective lineages of 1 022, and 0 over 1%. The
  mutating reverse colony of the entry above reads 17.7 and 23 aligned, 9.5 and 12 oriented.
  They are **live-only**: `oriented_census/2` does not read them, because rows may already be
  stored under it and an instrument version never changes what it reads once they are. This
  sweep samples them as it runs.

  **The sweep.** The radius sweep's arms, radius **{1, 2, 4, 0 = well-mixed}**, at 128²,
  with `mutation_rate` 2^-13 (`Lab::EMERGENT_MUTATION_RATE`, where the later sweeps hold
  it), `tape_len` = `max_tape_len` = 64 so every tape keeps its length and the lineage
  comparisons are the plain whole-tape case, and **`lineage_rule = oriented`**. `oriented`
  is the point of the sweep: under `aligned` a reverse copy passes no tag on, so after a
  takeover by a reverse copier the tags count the survivors of the takeover rather than
  descent from it. **Seeds 1–90 in every arm**, 20 000 epochs, 360 runs, priority 20: after
  the from-emerged children (50), ahead of sweep 9's extension (0 − seed). Why 90: the radius
  sweep saw 6 transitions in 40 runs, one or two an arm, and the reading needs at least two
  measured emerged runs in every arm. At 2^-13 on this world `mutation-rate-long` confirmed
  2 emergences of 10 inside 20 000 epochs. At a rate of 1 in 10 an arm of 90 expects about
  9 emerged runs, and the chance of fewer than 2 is below 0.1%.

  **Emergence, for this sweep.** A run is **emerged** when it has the record's confirmed
  `emergence_epoch` (2026-09-15: the detector's crossing confirmed by the census or
  `copy_rate`) **and** reads `replicator_share ≥ 0.5` at some sample at or after that epoch.
  The share is a live companion the engine records at every sample of a soup run, so every
  run of this sweep carries it from its crossing on; a sample without it is no reading, never
  a share of 0, and a run with no such sample at or after its crossing is not emerged.
  The confirmed rule found the right worlds on sweep 9: the nine economy-off worlds it
  confirmed are, read by #245's pilot, 74–99% working reverse copiers. The share clause is
  needed because the census that confirms a crossing is blind to reverse copiers (#245):
  its positives on record are palindromes, which can be transient in a world that is not
  mostly replicators. The share sees the reverse copiers and asks that the world, at some
  point after its crossing, was one.

  **The reading, per emerged run**, over its own samples from `emergence_epoch` to the end.
  Its last decile is the last `ceil(n / 10)` of those `n` samples in epoch order, and a
  median is the lower middle (`Findings::Median`), as the from-emerged reading cuts them.
  - **Polyphyletic**: the last-decile median of `lineage_effective_count` is **≥ 2**.
  - **Monophyletic**: it is **< 1.5**.
  - **Between** otherwise.
  - A run with fewer than **10** samples in its last decile is **unmeasured**. At the
    default `sample_every` of 10, that is a run that emerged after epoch 19 100.

  The samples read are those that carry `lineage_effective_count` as a number, which every
  sample of this sweep does; a sample without it is skipped, never read as 0.

  **Per arm**, the counts of emerged, measured, polyphyletic, between and monophyletic runs,
  and the median last-decile `lineage_effective_count` over the measured runs. An arm with
  fewer than **2** measured emerged runs is **unread**, as sweeps 9 and 10 require.

  **The hypothesis and its test.** The locked hypothesis has two halves: a transitioned
  world stays polyphyletic, and the number of surviving lineages grows as reach shrinks.
  - **The trend** is a **one-sided Jonckheere–Terpstra test** of the runs' last-decile
    `lineage_effective_count` across the arms in the order well-mixed < 4 < 2 < 1,
    predicting higher values toward radius 1. It runs over the measured emerged runs of the
    read arms, and needs at least **two** read arms. The statistic counts, over every pair of
    runs in two different arms, the pairs where the run of shorter reach reads higher, a tie
    counting one half. Its p is a **permutation** p, not the normal approximation: the pooled
    values are dealt at random into arms of the observed sizes **100 000** times, from a
    generator seeded with `PERMUTATION_SEED` so the reading reproduces, and p = (1 + b) /
    (1 + 100 000), where b dealings reach a statistic at least the observed one. At the arm
    sizes this sweep expects the normal approximation is anti-conservative exactly where the
    decision falls: at three runs in each of three arms the statistic 21 reads p = 0.048
    against an exact 0.061, and at three runs in each of four arms 39 reads 0.044 against
    0.052. Monophyletic worlds can read exactly 1.0, so ties are expected, and dealing the
    observed values handles them with no correction. A complete enumeration is out of reach
    past a few runs an arm (4.7 × 10^21 dealings at ten each), and the estimate
    (1 + b) / (1 + 100 000) never rejects more often than its level.
  - **Shown** when both halves hold: the trend at p < 0.05, **and** the read arm of shortest
    reach has a median last-decile `lineage_effective_count` of at least 2, polyphyletic. A
    significant trend among worlds that all read monophyletic is reported as a trend, not as
    the hypothesis.
  - **Refuted**, per the locked wording, when at least two arms are read and every measured
    emerged run of the sweep, in read and unread arms alike, reads monophyletic. An arm that
    never transitions holds no transitioned world to refute on, so refutation does not wait
    for all four arms; the unread arms are named.
  - **Neither shown nor refuted** otherwise, with the per-arm counts and the trend's p
    printed. An unread arm is named as unread; it is not counted as a monophyletic one.
    Shown and refuted cannot both hold: a polyphyletic median is a polyphyletic run.

  **Secondary and descriptive only.** `lineages_over_one_percent` over the same last decile;
  the oriented core and variation (#255: `lineage_variation_oriented`,
  `conserved_core_bytes_oriented`, `conserved_core_ops_oriented`); `copy_latency` over the
  run, a rung-3 look at whether the dominant copier gets faster; and the emergence count per
  arm against the radius sweep's. That last comparison is not a replication: the rate, the
  seeds and the lineage rule all differ.

  **Cost.** Most runs are random soup to the end. Measured on this machine, single thread
  under a load of about 6, the sweep's radius-1 params at seed 1 ran the first 2 000 epochs
  at 107 epochs/s, samples and snapshots included. #256 measured a fresh 128² soup at 129.
  So a run that never emerges costs about 3 CPU-minutes. An emerged world spends every
  interaction's step budget and is several times dearer: #256's emerged BFF control ran at
  2.1 epochs/s over 2^17 cells, about 17 at this sweep's 2^14. Taking about 10 minutes for
  the emerged part of a run, 360 runs are about 25 CPU-hours. On the mini-pc, sweep 9's
  measured 21 minutes a cap-128 run at 12 at a time, halved by #256, gives a planning
  figure of about 10 minutes a run: 60 run-hours, about 5 hours of the mini-pc. The first
  finished runs' `compute_seconds` replace the estimate.

  **When it is read.** When all 360 runs are terminal; a reading printed before that is
  labelled **interim**. The reading service is a later slice. It reads the constants in
  `Lab::LineageDiversityReading` and nothing else.

  **What is not claimed.** Lineage tags approximate descent: a cell takes its partner's tag
  when its final tape is closer to what the partner brought than to what it brought itself.
  They are not a phylogeny. Two lineages that converge on one tape stay two, and a copy
  overwritten by a stranger's partial write may keep or lose its tag on a byte count. The
  sweep reads how the tags split a world, not a tree. It also says nothing about why a world
  stays split: a spatial world can hold several colonies that never meet, and "locality
  keeps lineages apart" is that reading, not a mechanism.
- 2026-09-25 — **The lineage-diversity reading: five clarifications made before any run was
  read.** The entry above left five places its reading could go two ways. They were closed
  on the day the reading service landed, while the sweep's 360 runs were seeded and none
  had yet been claimed, so no run of it had been read, interim or otherwise. The rules now
  read, in `Experiments::LineageDiversityReadingService` and `Lab::LineageDiversityReading`:
  1. **Finished** means finished, where the entry said terminal: the reading is final when
     every run of the sweep has finished, and a failed run keeps it interim until it is
     re-run and finishes, since its samples stop short of its budget — as the from-emerged
     reading's sixth clarification reads its children. An interim reading reads the finished
     runs only; a pending, running or failed run is counted in its arm and not read, its
     last decile not yet its last.
  2. **Deciles** are cut first, as the from-emerged reading's first clarification cuts them:
     a run's first and last deciles are the first and last `ceil(n / 10)` of all `n` of its
     samples from `emergence_epoch` on, in epoch order. Inside a decile a value the engine
     did not report as a number drops out, and a run is unmeasured when fewer than 10 of its
     last decile's samples carry `lineage_effective_count` as a number. Every sample of this
     sweep carries it, so the two readings coincide in practice.
  3. **Unmeasured** is a class of emerged runs only. A run that did not emerge has no class
     and counts in none of the class columns.
  4. **The permutation dealing**, so that anyone can reproduce p. The groups are the read
     arms in the order well-mixed, 4, 2, 1, an unread arm left out, each holding its measured
     emerged runs' last-decile medians. The pooled values are sorted ascending, and beside
     them lies a list of group labels, each read arm's label repeated once per value it
     holds, in that arm order. One generator, CRuby's `Random.new(PERMUTATION_SEED)`
     (MT19937), serves the whole reading: each of the 100 000 dealings in turn is
     `labels.shuffle(random: generator)`, CRuby's Fisher–Yates, and the i-th label deals the
     i-th value. Every distinct dealing into the observed arm sizes is equally likely, and
     tied values are interchangeable under a statistic that counts a tie one half, so their
     order among themselves does not move p. b counts the dealings whose statistic is at
     least the observed one, and p = (1 + b) / (1 + 100 000) is compared with 0.05 as an
     exact fraction. The same generator deals the same labels on CRuby 3.3 and 4.0.
  5. **The descriptive spans.** Per run, `lineages_over_one_percent` and the oriented core
     and variation are last-decile medians, and `copy_latency` "over the run" is its
     first-decile median set against its last, both over the samples from the crossing on;
     per arm each is the median over the measured emerged runs. The radius sweep's count
     is its finished founding runs per radius with a confirmed `emergence_epoch`: that sweep
     sampled no `replicator_share`, so its count carries no share clause, where this sweep's
     does.
- 2026-09-25 — **The corpus read by the orientation-aware detector: what the census and the
  emergence gate got right and wrong.** The census entry above deferred its relock question
  — do `replicator_count`, the emergence confirmation and the persistence readings relock on
  the orientation-aware detector? — until the stored corpus had been read both ways. The
  readings pass (#248) has now read every kept world of every finished founding run, and
  this entry records what that reading shows and puts the question to the user. **It
  relocks nothing.**

  **The reading** (lab visit 2026-09-25 about 21:25Z, read-only). Instrument
  `oriented_census/1` (#246), static readings only (`epoch = source_epoch`), taken at the
  worlds pruning keeps, about one every 1 000 epochs; a run is measured once every kept
  world is read. `flagged` is `transition_epoch` present; `emerged` is `emergence_epoch`
  present, the 2026-09-15 rule (a crossing confirmed by the census or `copy_rate`);
  `replicator worlds` are measured runs whose peak `replicator_share` is at least 0.5;
  `held to end`, a last reading at least 0.5. `lab:oriented_report[all]` (#250):

  | experiment | runs | measured | flagged | emerged | replicator worlds | held to end | replicators, not emerged | emerged, no replicators | median first replicator epoch (coarse) |
  |---|---|---|---|---|---|---|---|---|---|
  | `mutation-rate` | 100 | 100 | 5 | 4 | 4 | 4 | 1 | 1 | 15 000 |
  | `world-size` | 40 | 40 | 4 | 4 | 3 | 3 | 0 | 1 | 17 000 |
  | `radius` | 40 | 40 | 6 | 5 | 5 | 3 | 1 | 1 | 13 000 |
  | `bff-control` | 6 | 5 | 6 | 6 | 2 | 2 | 0 | 3 | 5 550 |
  | `mutation-rate-long` | 40 | 40 | 8 | 8 | 4 | 4 | 0 | 4 | 20 000 |
  | `max-steps` | 40 | 40 | 2 | 2 | 1 | 1 | 0 | 1 | 8 000 |
  | `ops` | 60 | 60 | 4 | 3 | 1 | 1 | 0 | 2 | 8 000 |
  | `max-tape-len` | 240 | 240 | 42 | 13 | 12 | 12 | 0 | 1 | 8 000 |
  | `energy-per-epoch` | 120 | 120 | 8 | 7 | 5 | 5 | 0 | 2 | 9 000 |
  | `environmental-structure` | 210 | 210 | 11 | 11 | 7 | 6 | 0 | 4 | 8 000 |
  | `host-parasite` | 1 329 | 1 323 | 27 | 27 | 25 | 24 | 0 | 2 | 11 000 |
  | `asymmetric-execution` | 360 | 360 | 9 | 9 | 9 | 9 | 0 | 0 | 9 000 |
  | `from-emerged` | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | — |
  | `lineage-diversity` | 44 | 0 | 2 | 2 | 0 | 0 | 0 | 0 | — |
  | all (founding, finished) | 2 629 | 2 578 | 134 | 101 | 78 | 74 | 2 | 22 | 10 000 |

  `from-emerged` reads zero throughout because its runs are descendants, which the table
  excludes; `lineage-diversity` was still running, its first 44 runs just finished and none
  yet measured. Direct SELECTs over the measured runs, taken as the pass finished
  (2 582–2 584 measured at query time, 131 of them flagged):
  - **(a) Flagged, never at a share of 0.5: 53 of 131.** `max-tape-len` 30, all but one in
    the cap-512 arm — the cap confound of 2026-09-19, an arm that is always flagged and
    almost never confirmed; `mutation-rate-long` 4, `environmental-structure` 4,
    `bff-control` 3 (runs 182, 183 and 186, all confirmed emerged), `energy-per-epoch` 3,
    `ops` 3, `host-parasite` 2, and one each in `max-steps`, `mutation-rate`, `radius` and
    `world-size`. About 22 of the 53 are confirmed emerged, the table's 22.
  - **(b) Never flagged, ever at 0.5: 0.** No run the detector passed over holds a kept
    world that is half replicators.
  - **(c) Of 98 measured emerged runs, 76 ever reach 0.5**, the first reading at 0.5 a
    median of +790 epochs after `emergence_epoch` (range +20 to +7 180), never before it.
  - **(d) 67 of those 76 (88%) stay at 0.5 or more at every later reading**; over all 98
    emerged runs, 68% both reach and hold.
  - **(e) Replicators at a run's end.** The census (`replicator_count` > 0 at the final
    sample) sees them in 1 run of 2 584; the share (at least 0.5 at the last reading) in 74.

  **What it shows.**
  - *Which worlds hold replicators, the detector found.* Every world that ever held a
    half-replicator population was flagged (b), and all but 2 of them were confirmed. Both
    misses are the confirmation window's, not the census's orientation: the `mutation-rate`
    run at 2^-12 (run 59) carries no `copy_rate` before epoch 18 400, since its sweep
    predates the observable, and the same world (seed 9, same parameters) is confirmed by
    `copy_rate` in `world-size`, `radius` and `mutation-rate-long`; the `radius` run at
    radius 4 (run 170) crosses at 5 910 and first lifts `copy_rate` at 6 120, 21 samples
    later, outside the 10-sample window, its census at 8 680.
  - *What happens after emergence, the census got wrong.* It reads 1 world holding
    replicators at the end where the share reads 74, and colonies hold: 88% of the worlds
    that reach 0.5 never fall below it at a later reading. The persistence and relapse
    readings stated in the census describe the instrument, not the worlds.
  - *The emergence confirmation admits worlds that never become half replicators.* 22 of
    98 confirmed emergences never reach 0.5. Not all are empty: `bff-control`'s
    zero-mutation runs are among them, and #245's pilot read run 182 at about 25% reverse
    copiers (X and reverse(X) holding 26.5%) — replicators present, a minority. The 22 are
    runs below the 0.5 bar, and the bar is a choice. Nor are they 22 worlds: seven are
    one, the 2^-13 seed-1 world that seven sweeps replay (census-confirmed at 5 030, a census
    peak of 867 cells on `interaction-budget`, a share peak of 0.31–0.32), so the 22 are 16
    distinct worlds.
  - *The detector's false alarms are dominated by the cap confound*: 29 of the 53 flagged
    runs that never reach 0.5 are cap-512 `max-tape-len` runs.
  - The lag in (c) is mostly the reading's own resolution, a kept world every ~1 000
    epochs, plus the time a replicator takes to fill half the world.

  **For the user to decide.** Four options, none taken. The findings named under each are
  the ones whose headline numbers would move, read from the finding bodies and the
  instrument notes of #252 (`Findings::InstrumentNotes`).
  1. **Relock the census, `replicator_count`, onto the orientation-aware detector** —
     `replicator_share` over 256 sampled cells, the chain test — in place of the top-16
     same-orientation test. The census numbers move on: `mutation-rate-window` (the census
     agreeing with the detector, and fading after its peak); `mutation-rate-long-horizon`
     (6 of 40 census-confirmed, the two runs flagged with an empty census, the census peaks
     and with them the lower cutoff); `world-size-scaling` (the census counts 0, 0, 0 and 3,
     and the 128² flagged run read as a collapse); `interaction-budget` (the census peaks
     and "the detector and the census agree everywhere"); `bff-control` (its census
     readings, and the reasoning that with no mutation nothing that replicates emerges);
     `emergence-can-be-left` (its census split and census peaks). The emergence gate reads
     the census as a witness, so this option either carries option 2 with it or keeps the
     old test as the gate's witness under another name. The dominant-replicator readings
     (`dominant_replicates`, `copy_cost`, and through them `copy-cost-adaptation`,
     `replicator-complexity-plateau` and the complexity findings' dominant series) are a
     separate same-orientation test and do not move under this option alone.
  2. **Relock the emergence confirmation (2026-09-15, #172/#189) onto "a detector crossing
     confirmed by `replicator_share` ≥ θ within the run".** θ is open: 0.5, or lower to
     admit minority populations like run 182's. At θ = 0.5, from the table, 22 runs leave
     and 2 enter: `mutation-rate` 4 → 4 (one out, one in), `world-size` 4 → 3, `radius` 5 → 5
     (one out, one in), `bff-control` 6 → 3 (run 181, not yet fully measured, already reads
     1.0),
     `mutation-rate-long` 8 → 4, `max-steps` 2 → 1, `ops` 3 → 1, `max-tape-len` 13 → 12,
     `energy-per-epoch` 7 → 5, `environmental-structure` 11 → 7, `host-parasite` 27 → 25,
     `asymmetric-execution` 9 → 9. Emerged counts move on: `complexity-under-contest`
     (`host-parasite`, 27 → 25, and the arm readings built on them); `complexity-keeps-rising`
     (`energy-per-epoch`, `environmental-structure`, `max-tape-len`, as above, and each
     arm's verdict against its control); `replicator-complexity-plateau` (its population is
     every emerged run); `mutation-rate-long-horizon` (the gate's eight, the page's six
     census-confirmed, four at θ = 0.5);
     `bff-control` (its confirmed zero-mutation runs). `complexity-under-asymmetry` does not
     move (9 → 9), nor the detector counts of `mutation-rate-window`, `radius-locality`,
     `world-size-scaling` and `interaction-budget`; the experiment pages' emerged columns and
     survival curves move with the column. The two rung-2 readings (from-emerged,
     lineage-diversity) already carry a share clause at 0.5 and do not move, except the
     lineage-diversity reading's `radius` reference counts: radius 2 loses its one emerged
     run (160, share peak 0.06) and radius 4 gains run 170.
  3. **Relock the persistence and relapse readings onto the share**: a world is in the state
     while its `replicator_share` holds, rather than while `compress_ratio` does. Moves
     `emergence-can-be-left` (its persisted/relapsed split, its census split and peaks, and
     the reading of a zero-census relapse as a soup that stopped compressing),
     `mutation-rate-long-horizon` (the confirmed run that fell back to a soup's
     `compress_ratio`) and `radius-locality` (the transition that "did not hold"). The
     from-emerged reading already reads relapse on the share.
  4. **Leave everything locked and read the companions beside it, as now.** No number moves;
     the #252 instrument notes stay as each page's caveat, and the pages that read the census
     at a run's end keep a reading that sees replicators in 1 run where the share sees 74.

  **The pending `transition_epoch` relock (#229, #237) is separate and still awaits the
  user.** It moves the flag, not the gate: at cap 512 the constant rule flags 30 of 30 runs
  and the relative rule keeps only run 543, the one confirmed emerged. It would drop 29 of
  the 53 flagged runs that never reach 0.5, every cap-512 one (the 30th `max-tape-len` run,
  367 at cap 64, crosses at 5 030 under both rules), while `emergence_epoch` stays on the
  constant crossing series and no emergence count above moves. Option 3 and #237 touch the same
  persistence summary — #237 re-anchors it on the relative crossing, option 3 changes what
  it qualifies a sample by — so whichever lands second is written against the first.

  **Not claimed.** The 0.5 bar and the 256-cell draw are choices, not properties of the
  worlds: a lower bar reads more of the 22 as replicator worlds. The readings are ~1 000
  epochs coarse, so (b) says no kept world of an unflagged run reads 0.5, not that none
  ever held it between two kept worlds, and first-reach epochs are bounded by the spacing.
  The lineage tags of every existing run remain `aligned` (#257), so nothing here reads
  lineages oriented. Every count is of runs, not independent worlds: the sweeps share
  reference arms, so one world is counted once per sweep that replays it.
- 2026-09-25 — **The from-emerged economy arms, confirmed on held-out parents: a
  confirmatory reading, pre-registered after looking.** A second reading of the same sweep,
  `from-emerged`, on a subset of its children that does not exist yet. The entry "Runs that
  start from an emerged world" and its six clarifications stand untouched, and their reading
  stays the sweep's pre-registered one. This entry adds rules that were written **after**
  seeing that reading's interim numbers and an exploratory look at the same children, which
  is exactly why they are tested only on children none of whose samples had been seen.

  **What was seen.** The interim reading of all 120 children of the first ten parents (runs
  944, 950, 967, 991, 1007, 1029, 1087, 1089, 1103 and 2568), every one finished, under the
  locked rules:

  | treatment | held | relapsed | rises | plateau | mixed |
  |---|---|---|---|---|---|
  | continuation | 29 | 1 | 2 | 17 | 11 |
  | economy 2048 | 22 | 8 | 7 | 6 | 17 |
  | economy 8192 | 27 | 3 | 10 | 8 | 11 |
  | host mode | 30 | 0 | 0 | 15 | 15 |

  H-economy for economy 8192 went 10 pairs against 1, p = 0.0059, but reads **not read:
  relapses more than the continuation**, and the result is carried by pairs of parents.
  H-host is refuted. Then an **exploratory** look, not pre-registered, by SELECTs on the same
  120 children:
  1. The economy lowered `copy_latency` (#255: the step at which the partner first holds a
     complete image of the dominant tape, in either orientation). The median over children
     of their first-decile and last-decile medians went 4 780 → 1 930 in economy 8192, with
     23 of 30 children falling, and 1 864 → 1 280 in economy 2048, with 22 of 25 falling. In
     the continuation and in host mode 14 of 30 fell in each.
  2. 8 of the 9 relapses in economy 2048 are a transient crash within about 500 epochs of the
     switch at 20 000, recovered by 20 050–20 670. One child of the whole sweep (economy 8192,
     seed 1003) went extinct for good, as its `steal_rate` rose to about 0.9.
  3. No halting copier appeared: `copy_cost` equals `max_steps` in 16 385 of 16 400 non-null
     samples.

  Those observations suggested the rules below, so they cannot be tested on the children
  they came from.

  **The held-out set.** The children whose parent is a founding `host-parasite` run with
  **seed > 90** — sweep 9's extension, seeds 91–270, in the economy-off arms at caps 128 and
  256, qualifying by the sweep's existing parent rule — **and is not one of the ten parents
  above**. Run 2568 is an extension parent (seed 102, cap 128) that qualified early; its
  twelve children are among the 120 seen, so the seed alone does not hold them out, and it
  is excluded by name. At the time of writing (2026-09-25 21:43 UTC, a SELECT on the lab
  database) the sweep holds 120 children, all of the ten parents above, and **no held-out
  child exists**. The extension adds about 18 parents; their worlds finish after
  2026-09-26. The constants live in `Lab::FromEmergedHeldout`
  (`LAST_SEEN_SEED`, `SEEN_PARENT_IDS`), and the reading is in
  `Experiments::FromEmergedReadingService` beside the original one.

  **The readings, per child, over its own samples** (epochs above `parent_epoch`):
  - **Settled relapse.** A child relapses only where its `replicator_share` sits below
    **0.1** for **3** consecutive samples, counting only samples at epochs above
    `parent_epoch` + **1 000** (`SETTLING_WINDOW`): the exploratory look found switching
    shocks that recover, and this window leaves them out. A child is **extinct** where its
    last-decile median share, the original entry's last decile, is below **0.1**
    (`EXTINCT_SHARE`). A child that never sampled a share is read by neither rule.
  - **H3-latency (rung 3).** For each child that is not extinct, the latency ratio **R** is
    its last-decile median `copy_latency` divided by its first-decile median. The deciles
    are the first and last `ceil(n / 10)` of the `n` samples at epochs above `parent_epoch`
    + 1 000 that carry `copy_latency` as a number; a median is `Findings::Median`'s lower
    middle. A child with fewer than **10** such samples in either decile
    (`MIN_DECILE_SAMPLES`), or whose first-decile median is 0, is **unmeasured**. Each pair
    is an economy child and the continuation child of the same parent and seed, both
    measured; it favours the treatment where the treatment's R is lower than the
    continuation's, the continuation where it is higher, and equal ratios tie and are
    dropped. The test is the original one-sided sign test at p < **0.05**, per economy arm
    (2048 and 8192 on their own). **Shown** at p < 0.05; **refuted** where the pairs
    favouring the continuation are at least as many as those favouring the treatment;
    **not shown** otherwise; **no measured pairs** where no pair is measured on both sides.
  - **H4-survivors (rung 4).** The original complexity rule — rises, plateau, mixed,
    unmeasured, from `dominant_instruction_count` over self-replicating samples — read only
    on pairs where **neither** child had a settled relapse and **neither** is extinct, and,
    as the original test requires, both are measured. A pair favours the treatment where the
    treatment child rises and the continuation child does not, and the continuation in the
    reverse case. The same sign test, per economy arm, with the same shown, refuted, not
    shown and no-measured-pairs outcomes. There is no "relapses more" clause here: the
    settled-relapse and extinction counts per treatment are reported beside the tests,
    descriptively, and that is where "the economy kills replicators" shows.
  - **Host mode** is not re-tested: it was refuted. Its held-out children are counted in the
    per-treatment table like the others.
  - **Robustness.** Each shown result carries the original entry's per-parent agreement and
    its leave-one-or-two-parents-out rule (clarification 5): every set of one or two parents
    whose pairs, left out, bring p to 0.05 or above is listed as carrying it.

  **When it is read.** The reading is **final** when every held-out child of every parent
  qualifying from the extension has finished, which is the original reading's own final
  (clarification 6: the parent pool settled, every child of every qualifying parent
  finished). Before that it is labelled **interim**, and before any held-out child exists
  it says so.

  **What is not claimed.** A held-out confirmation on about 18 parents is still one
  substrate, one budget and correlated children per parent: it guards against reading
  noise the look found into rules the look wrote, not against those limits. `copy_latency`
  is measured on the dominant tape against noise, not in situ, so a lower ratio says the
  dominant copier copies faster in isolation, not that the colony replicates faster. Both
  tests condition on surviving the treatment: H3-latency leaves out extinct children and
  H4-survivors every pair with a settled relapse or an extinct child. A treatment that
  kills the colonies that would not have sped up or complicated leaves survivors that did,
  so a shown result is read on the survivors, with the settled-relapse and extinction
  counts beside it, not as the treatment's effect on every colony it touched.
- 2026-09-27 — **The lineage-diversity finding states its claim: after emergence one
  lineage takes the world at every reach.** Sweep 12 finished on 2026-09-26, 360 runs, every
  one finished, 90 per arm. Read under the pre-registered rule and its five clarifications of
  2026-09-25 (`lab:lineage_diversity_report` on the lab, 2026-09-27, "final reading"):

  | arm | runs | emerged | measured | polyphyletic | between | monophyletic | median effective count |
  |---|---|---|---|---|---|---|---|
  | well-mixed | 90 | 3 | 3 | 0 | 0 | 3 | 1 |
  | radius 4 | 90 | 16 | 16 | 0 | 2 | 14 | 1 |
  | radius 2 | 90 | 9 | 9 | 0 | 2 | 7 | 1 |
  | radius 1 | 90 | 4 | 4 | 0 | 1 | 3 | 1 |

  Every arm is read. The trend over well-mixed < 4 < 2 < 1 reads JT = 193.5, permutation
  p = 0.07930: **the hypothesis is neither shown nor refuted**. Not shown, because the trend
  misses 0.05 and radius 1 is not polyphyletic; not refuted, because five runs read between
  rather than monophyletic — radius 4 seeds 23 (1.88) and 66 (1.61), radius 2 seeds 39
  (1.73) and 65 (1.99), radius 1 seed 51 (1.88), last-decile effective counts; a SELECT
  re-deriving the class from the samples finds the same five. Descriptively, every arm's
  median `lineages_over_one_percent` is 1, its oriented conserved core 0 bytes and 0 ops,
  its `lineage_variation_oriented` 34.7, 40.1, 51.1 and 45.2, and its `copy_latency` first →
  last decile 1087 → 908, 955 → 1013, 712 → 736 and 469 → 663.

  **The claim**: none of the 32 emerged worlds stayed polyphyletic. 27 read monophyletic and
  5 between, none reaching 2, and the median effective number of lineages is 1 in every arm.
  After emergence one lineage takes the world whatever the reach. The locked hypothesis's
  first half, that a transitioned world stays polyphyletic, is not supported; its second
  half, more lineages at shorter reach, is not shown, and at p = 0.079 over 32 worlds a small
  trend among near-monophyletic worlds is not excluded either.

  **Registry status `negative`**, finding `lineages-after-emergence`: every run finished and
  the reading is final, so `partial` ("cannot yet be read as final") does not apply, and the
  hypothesis is not shown, so `published` does not either. `negative` ("the sweep finished
  and the effect was not there") is the registry's convention for a finished sweep whose
  effect did not appear even where it was not formally refuted — as the radius-locality
  finding reads the speed half of sweep 3. The effect the sweep was built to see, worlds
  holding several lineages after a transition, was not there in any arm. The page renders
  the per-arm reading at render time from `Experiments::LineageDiversityReadingService`, the
  report the sweep page draws, and carries no census note: it is built on
  `replicator_share` and the `oriented` lineage tags, the orientation-aware instrument.

  **What it means for rung 2**: on this substrate diversity does not survive a transition.
  A reach of 1 on a 128² torus does not keep lineages apart for 20 000 epochs; the winner of
  the takeover holds the world. Lineage tags approximate descent and are read `oriented`,
  and the result is one world size and one budget.

  **Emergence by reach, descriptively.** The sweep was not designed to test emergence
  against radius, and this is not a pre-registered test. Its arms emerged 3, 16, 9 and 4 of 90,
  well-mixed then radius 4, 2 and 1; a Freeman–Halton exact test on the 4×2 table reads
  p = 0.0031 (Pearson χ² = 14.5, 3 df, p = 0.0023). A further 17 runs had a confirmed
  crossing but never read `replicator_share` ≥ 0.5 after it and are not emerged (well-mixed
  4, radius 4 9, radius 2 3, radius 1 1; a SELECT on the lab agrees). The radius sweep, at
  the default rate 2^-12, ten seeds an arm and no share clause, saw 2, 1, 1 and 1 of 10. A
  peak at an intermediate reach is a candidate for a future sweep that pre-registers
  emergence against radius; it is not a result.
- 2026-09-27 — **Does emergence peak at an intermediate reach? The `locality-emergence`
  sweep, pre-registered on fresh worlds.** Sweep 12 (`lineage-diversity`, entry of
  2026-09-25) was designed for rung 2 and asked nothing about how often a world crosses. Its
  counts of emerged runs, read by that entry's own emergence rule over its 360 finished runs,
  came out far from flat and not monotone in reach (a SELECT on the lab database,
  2026-09-27):

  | arm | emerged / finished |
  |---|---|
  | radius 1 | 4 / 90 |
  | radius 2 | 9 / 90 |
  | radius 4 | 16 / 90 |
  | well-mixed | 3 / 90 |

  That is an **exploratory** observation: emergence against radius was not sweep 12's
  pre-registered question, and the pattern was seen before any rule below was written. The
  radius sweep (entry of 2026-09-11) read locality as not speeding emergence on 10 seeds an
  arm, 1–2 transitions an arm, at 2^-12 and on the detector's crossing; it ruled out a large
  effect, not this one. Whether conditions make abiogenesis likely is rung 0's central
  question, so the pattern is put to fresh worlds under rules fixed first. This is §1.3 item
  13, experiment `locality-emergence` (sweep key `locality_emergence`), and its numbers live
  in `Lab::LocalityEmergenceReading`.

  **The sweep.** Sweep 12's world to the byte — 128², `tape_len` = `max_tape_len` = 64,
  `mutation_rate` 2^-13 (`Lab::EMERGENT_MUTATION_RATE`), `lineage_rule = oriented` — at radius
  **{1, 2, 3, 4, 6, 8, 0 = well-mixed}**. Radius 8 is inside the engine's range (0–64, and a
  positive radius must satisfy 2r + 1 ≤ 128). **Seeds 91–180** in every arm: `lineage_rule`
  changes no byte of a world, so seeds 1–90 at radius 1, 2, 4 and 0 would replay sweep 12's
  worlds, the exploratory counts included. No run on the lab reads these worlds already (a
  SELECT, 2026-09-27): the only runs at seeds 91–180 are the host-parasite sweep's, at radius
  1 with `max_tape_len` 128 and 256, energy stock on in most of their arms — variable-length
  worlds, not these. 20 000 epochs, **630 runs**, priority **30**: after the from-emerged
  children (50), ahead of sweep 9's extension.

  **Emergence** is sweep 12's, unchanged: a run is **emerged** when it has the record's
  confirmed `emergence_epoch` **and** reads `replicator_share ≥ 0.5` at some sample at or
  after that epoch. A sample without the share, or with anything but a number in it, is no
  reading. The constants are `Lab::LineageDiversityReading`'s (`SHARE_KEY`, `MIN_SHARE`),
  named again in `Lab::LocalityEmergenceReading`. Per arm the reading is **emerged over
  finished**; a run pending, under way or failed is listed and not counted.

  **H-peak (confirmatory: the exploratory pattern).** Radius 4 emerges more often than
  radius 1, **and** more often than the well-mixed world.
  - Two **one-sided Fisher exact tests** on the 2×2 tables of emerged and not emerged among
    finished runs, radius 4 against each rival, each p the hypergeometric upper tail
    P(X ≥ radius 4's emerged count) (R's `alternative = "greater"`), taken in exact
    rationals.
  - **Holm-corrected** at family α = **0.05**: the smaller p is multiplied by 2, the larger
    by 1, and an adjusted p never falls below the one before it.
  - **Shown** where both adjusted p are below 0.05.
  - An arm with no emerged run is tested as it stands: the tables are exact at zero, and
    radius 4 at 0 emerged against a rival at 0 has p = 1.
  - **Refuted** where radius 4's rate is at most radius 1's **and** at most well-mixed's —
    radius 4 at 0 emerged is refuted.
  - **Not shown** otherwise, radius 4 ahead of one rival and not the other included.
  - **Not yet tested** until each of the three arms has a finished run.

  At sweep 12's rates (0.178, 0.044, 0.033) the family has a power of about **0.82**; if
  radius 4's true rate is 0.12, as regression from an exploratory high would make likely,
  about **0.38** (2 000 simulated sweeps, 2026-09-27). A not-shown result is read with that
  in mind, not as evidence of no effect.

  **H-shape (descriptive, with one pre-registered test).** Across the six finite radii,
  emergence peaks at an intermediate reach.
  - A **binomial logistic regression** of emergence on radius and radius², logit p = b₀ +
    b₁r + b₂r², over the finished runs of radius 1, 2, 3, 4, 6 and 8, radius in cells,
    uncentred. It is fitted by maximum likelihood with Newton–Raphson from all coefficients
    at zero, stopping when every coefficient moves by less than 10⁻¹⁰, within 100 steps
    (`Stats::QuadraticLogistic`). A fit that does not settle, or whose information matrix
    cannot be inverted, is **no fit**: that is what a separated table does.
  - **Shown** where b₂ is negative, its **two-sided Wald p** (b₂ over its standard error from
    the inverse information at the maximum, against the normal) is below **0.05**, and the
    **fitted peak** −b₁ / (2b₂) lies strictly between radius 2 and radius 6, so that two of
    the radii read lie on each side of it. A concave curve that only rises or only falls
    across the radii puts its vertex outside them or just inside an end — rates of 1, 2, 5,
    9, 20 and 22 of 90 fit a significant b₂ < 0 with the vertex at 7.5 — and that is a
    curve, not an intermediate peak.
  - **Not shown** otherwise, no fit included (it is labelled "no fit"). The fitted peak
    radius and b₂ with its p are reported whichever way it reads.
  - **Not yet tested** with fewer than three finite radii holding a finished run, or with no
    emerged or no not-emerged run among them.
  - **Well-mixed is left out of the fit** — radius 0 is not a distance — and its count is
    reported beside it.

  **When it is read.** Final when every run of the sweep has finished; before that the page
  and `lab:locality_emergence_report` label it **interim** and count only the finished runs.
  A failed run keeps the reading interim until it is re-run and finishes, as the
  lineage-diversity reading's first clarification reads its failed runs. Radius 2, 3, 6 and
  8 enter H-shape only; well-mixed enters H-peak only.
  The reading is `Experiments::LocalityEmergenceReadingService`.

  **What is not claimed.** One world size (128²), one mutation rate (2^-13), one tape length
  (64 bytes, fixed), one 20 000-epoch budget, one lineage rule. A peak here says where
  emergence is likeliest inside that budget on that world; a larger world or a longer budget
  can move it, and a rate difference inside 20 000 epochs can be a speed difference that a
  longer budget would erase. The radius sweep's reading of the speed half of item 3 stands
  where it was measured (2^-12, detector crossings, 10 seeds).

  **Cost.** Sweep 12's 360 runs took **76.2 compute-hours** (runs' `compute_seconds`: mean
  606 s at radius 1, 811 s at 2, 914 s at 4, 716 s well-mixed) and **7 hours of wall time**
  on the lab, 2026-09-25 20:24 to 2026-09-26 03:27 UTC. At the same per-run cost, taking the
  new radii at radius 4's, 630 runs are about **145 compute-hours**, about **13–14 hours** of
  wall time at sweep 12's parallelism with the lab to themselves.
- 2026-09-27 — **The host–parasite finding re-read at 270 seeds on the rising arm and its
  controls: the one rising arm reads neither, and the finding stays `partial`.** The
  next-step entry of 2026-09-25 extended three arms of sweep 9 to seeds 1–270 —
  `1024×2048 128`, its control `0 128` and the control `0 256` — and said the finding would
  be re-read with the same rule and the same pairing once they were terminal. They are: 1 800
  of 1 800 `host-parasite` runs finished at 2026-09-26 13:30Z. The extension was chosen after
  the 90-seed reading was seen, so this re-read decides that reading rather than testing a
  fresh one. Read under the amended measured-run rule of 2026-09-21
  (`FORMAT=csv lab:transition_report[host-parasite]`, 2026-09-27):

  | arm | emerged | measured | pre-registered unmeasured | rising | plateau | reading | theft |
  |---|---|---|---|---|---|---|---|
  | `0 128` (control) | 11 / 270 | 11 | 10 | 1 | 3 | neither | — |
  | `0 256` (control) | 7 / 270 | 7 | 7 | 1 | 1 | neither | — |
  | `0×8192 128` | 2 / 90 | 2 | 2 | 0 | 0 | neither | — |
  | `0×8192 256` | 2 / 90 | 2 | 2 | 0 | 1 | plateau | — |
  | `1024×8192 128` | 4 / 90 | 4 | 4 | 0 | 1 | neither | evolved, peak 0.93 |
  | `1024×8192 256` | 1 / 90 | 1 | 1 | 1 | 0 | unread | evolved, peak 0.85 |
  | `0×2048 128` | 2 / 90 | 2 | 2 | 0 | 1 | plateau | — |
  | `0×2048 256` | 1 / 90 | 1 | 1 | 1 | 0 | unread | — |
  | `1024×2048 128` | 8 / 270 | 8 | 8 | 1 | 3 | neither | evolved, peak 0.35 |
  | `1024×2048 256` | 3 / 90 | 3 | 2 | 0 | 0 | neither | evolved, peak 0.94 |
  | `0×512 128` | 0 / 90 | 0 | 0 | 0 | 0 | barren | — |
  | `0×512 256` | 0 / 90 | 0 | 0 | 0 | 0 | barren | — |
  | `1024×512 128` | 0 / 90 | 0 | 0 | 0 | 0 | barren | evolved, peak 0.32 |
  | `1024×512 256` | 0 / 90 | 0 | 0 | 0 | 0 | barren | evolved, peak 0.32 |

  **Emergence**, two-sided Fisher exact against the economy-off control at the same cap, as
  the finding tests it: `1024×2048 128` 8 of 270 against 11 of 270, p = 0.64; at cap 128
  `0×8192` p = 0.53, `1024×8192` p = 1, `0×2048` p = 0.53, `0×512` and `1024×512` p = 0.072;
  at cap 256, against 7 of 270, `0×8192` p = 1, `1024×8192` p = 0.69, `0×2048` p = 0.69,
  `1024×2048` p = 0.72, `0×512` and `1024×512` p = 0.20. None reaches p < 0.05.
  `1024×8192 128` (4 of 90) and `1024×2048 256` (3 of 90) sit above their control as point
  estimates and every other priced arm at or below. Pooled over both caps, descriptive only,
  the priced arms emerged in 23 of 1 170 runs against 18 of 540 for the controls, p = 0.091.
  In the extension's seeds 91–270 alone, `1024×2048 128` and `0 128` emerged in 6 of 180
  each and `0 256` in 3 of 180.

  **The claim**: complexity keeps rising in none of the 12 priced arms. `1024×2048 128`,
  which read keeps rising at 90 seeds on 1 of its 2 measured runs, reads **neither** at 270:
  1 rising and 3 plateauing of 8 measured runs, and the rising run is still the seeds-1–90
  one (run 1733, `dominant_instruction_count` 17 → 21); the 6 runs of seeds 91–270 hold none
  rising and 3 plateauing. Its control `0 128` reads **neither**, 1 rising and 3 plateauing
  of 11 (the rising run, 967, is from seeds 1–90 too), and `0 256` reads **neither**, 1
  rising and 1 plateauing of 7 (the rising run, 1029, likewise). Two priced arms plateau
  (`0×8192 256`, `0×2048 128`), four read neither, two are unread on one measured run each
  (`1024×8192 256` and `0×2048 256`, which were not extended, and whose single runs both
  rise), and the four 512-influx arms are barren. Theft evolved in all six steal arms (peak
  `steal_rate` 0.32–0.94), so no arm reads the theft-never-evolved null. **Pooled over
  runs**, descriptive and not part of the pre-registered reading, the priced arms' measured
  runs rise 3 of 23 against the controls' 2 of 18 (Fisher p = 1), and at cap 128 the pair
  the extension was for reads 1 of 8 against 1 of 11 (p = 1). The refutation condition as
  worded — the priced arms plateau where their controls plateau — is still not met, because
  neither control plateaus.

  **Under the pre-registered measured rule**, 39 of the 41 emerged runs are unmeasured and
  no arm reads. The two it measures are run 2700 (`0 128`, seed 234, core 52 → 0 bytes) and
  run 1770 (`1024×2048 256`, seed 24, core 143 → 0), one in each of two arms, and neither
  rises. Every reading above stands on the amended rule of 2026-09-21, and the page states
  the pre-registered one beside it.

  **The aligned-core confound.** Both rules read `conserved_core_bytes`, which compares
  aligned bytes; the 2026-09-25 entries (#245, the census; #255, the oriented lineage) found
  that a population of X and reverse(X) reads zero there. The amended core clause counts a
  core at zero at both ends as not falling, so under it the core clause passes nearly every
  run, and the arm readings rest on `dominant_instruction_count`, which the instrument note
  of 2026-09-25 marks as exposed in its own right (it is read off the commonest tape that
  passes the same-orientation replicator test where one does, and off the world's commonest
  tape where none does). The extension's runs finished after #255's deploy
  and carry `conserved_core_bytes_oriented`; seeds 1–90 do not. **Descriptive only**, read
  by a read-only `bin/rails runner` of SELECTs on the lab database (2026-09-27), with the
  same deciles and lower-middle medians as `Experiments::ComplexityArmsService`: of the 15
  emerged runs of seeds 91–270 in the three extended arms, 14 carry the oriented core (run
  2568, `0 128` seed 102, finished before the deploy and does not). It reads zero at both
  ends of the post-crossing span in 13 of them; run 2700 reads 55 → 1. None of the 14 raises
  `dominant_instruction_count` by 20% (the largest rise is run 3035's 18 → 21, 17%), so none
  rises with the oriented core in the clause either, and a pre-registered-style rule on the
  oriented core would measure run 2700 alone and read no arm. So on these runs the aligned
  core's confound does not change the reading: the oriented core is at zero too, and no run
  rose on instructions for a core clause to stop.

  **Registry status stays `partial`.** The 2026-09-24 entry's criterion is met for what it
  named: the one supporting arm stood on the fewest measured runs the rule reads, beside a
  control holding a rising run too, and "more seeds on `1024×2048 128` and `0 128` would
  decide it". They did: at three times the seeds the arm holds four times the measured runs,
  none of the new ones rises, and it reads neither beside a control that reads neither. That
  decides the arm, not the sweep. `1024×8192 256` and `0×2048 256`, never extended, hold one
  measured run each, and both runs rise; the rule reads an arm on two, so both are unread,
  and the verdict `Findings::ComplexityArmsReading` was built with for this finding (#238,
  before the extension was chosen) reads a sweep with no rising arm and any unread one as
  unresolved, not as no arm rising. `negative` — the sweep finished and the effect was not
  there — would say of those two arms what their one run each cannot, and would set the
  registry against the page's own verdict badge, so the registry follows the verdict:
  `partial`, a reading stated that cannot yet be read as final. The pooled count (3 rising of
  23 priced measured runs against 2 of 18 in the controls) is consistent with the two single
  runs sitting at the controls' background rate, but it is descriptive and moves no status.
  With one rising run already, a second measured run can only make either arm read keeps
  rising or mixed; it takes two more that do not rise for it to read anything else, which at
  1 emerged run in 90 is roughly another 180 seeds an arm, and the programme does not extend
  them here. It is not `refuted` either: the refutation condition needs a control plateau to
  match and neither control plateaus. The finding keeps its instrument note: the
  reading stands on `dominant_instruction_count` as the census reads it, and a re-read with
  the orientation-aware dominant tape would be a new reading, not this one. The page renders
  every count above from the stored runs at render time; the registry summary, the body's
  Method and Result prose, the instrument note and DESIGN §1.3 item 9 carry the new claim.
  The asymmetric-execution finding's "seed for seed" control is now scoped to sweep 9's
  seeds 1–90, as the 2026-09-25 entry said it would be. Nothing about the engine, the rules
  or any observable moves.
- 2026-09-28 — **The from-emerged findings state their claims: copying gets faster under an
  energy economy, rung 3's first confirmed adaptation, and the economy does not keep
  complexity rising from an emerged start.** Sweep 11 (`from-emerged`) is final: all 216
  children of its 18 qualifying parents finished by 2026-09-28 00:50Z. Both of its readings
  are read here as registered, on the lab (`lab:from_emerged_report` and
  `lab:from_emerged_heldout_report`, 2026-10-01, "final reading" and "held-out reading,
  final").

  **The original reading** (2026-09-25, "Runs that start from an emerged world", and its six
  clarifications), every parent:

  | treatment | children | held | relapsed | rises | plateau | mixed | unmeasured |
  |---|---|---|---|---|---|---|---|
  | continuation | 54 | 52 | 2 | 3 | 20 | 31 | 0 |
  | economy 2048 | 54 | 40 | 14 | 7 | 11 | 36 | 0 |
  | economy 8192 | 54 | 46 | 8 | 13 | 11 | 29 | 1 |
  | host mode | 54 | 54 | 0 | 2 | 17 | 35 | 0 |

  H-economy at 2048: 7 pairs favour the treatment, 3 the continuation, 44 tie, p = 0.172, not
  shown — and not read, since the arm relapses more than the continuation. H-economy at 8192:
  12 against 1 over 53 measured pairs, p = 0.00171, so the sign test holds, but it is **not
  read**: the arm relapses more than the continuation, and the result is carried by parents
  1029 and 1103 together. H-host: 1 against 2, p = 0.875, **refuted**. H-persistence:
  **refuted**, 2 of 54 continuation children relapsed (run 3171, parent 1087, at epoch
  21 520, and run 3601, parent 2654, on its last decile).

  **The held-out confirmatory reading** (2026-09-25, "The from-emerged economy arms, confirmed
  on held-out parents", #263), written after the first ten parents had been seen and read
  only on the eight that qualified afterwards — 2577, 2590, 2654, 2676, 2700 (cap 128) and
  2771, 2802, 2862 (cap 256), 96 children:

  | treatment | children | settled relapses | extinct | latency measured | survivors |
  |---|---|---|---|---|---|
  | continuation | 24 | 0 | 0 | 24 | 24 |
  | economy 2048 | 24 | 3 | 0 | 24 | 21 |
  | economy 8192 | 24 | 5 | 0 | 24 | 19 |
  | host mode | 24 | 0 | 0 | 24 | 24 |

  | hypothesis | arm | pairs | favour treatment | favour continuation | ties | p | outcome |
  |---|---|---|---|---|---|---|---|
  | H3-latency | economy 2048 | 24 | 20 | 4 | 0 | 0.000772 | shown |
  | H3-latency | economy 8192 | 24 | 21 | 3 | 0 | 0.000139 | shown |
  | H4-survivors | economy 2048 | 21 | 0 | 1 | 20 | 1 | refuted |
  | H4-survivors | economy 8192 | 19 | 1 | 0 | 18 | 0.5 | not shown |

  No one or two parents carry either H3-latency result. Per parent, the treatment wins the
  majority of the pairs in 7 of 8 parents at economy 2048 (parent 2771 goes 1 to 2) and in
  all 8 at economy 8192.

  **The size of the effect**, medians over the 24 held-out children of each treatment (all
  latency-measured), lower middle as `Findings::Median` takes it, read off the per-child rows
  and re-derived from the samples by a read-only `bin/rails runner` on the lab:

  | treatment | first-decile `copy_latency` | last-decile | median R | R below 1 |
  |---|---|---|---|---|
  | continuation | 1 449 | 3 073 | 1.11 | 6 of 24 |
  | economy 2048 | 1 409 | 1 023 | 0.821 | 21 of 24 |
  | economy 8192 | 1 429 | 1 070 | 0.749 | 16 of 24 |
  | host mode | 1 437 | 2 065 | 1.00 | 9 of 24 |

  Left alone, the median dominant copier slows by about a tenth over 20 000 epochs; under
  either economy it speeds up by a fifth to a quarter. Descriptively, at cap 256 the economy
  children's first-decile latency already sits far below the continuation's (medians 1 806
  at 2048 and 5 126 at 8192 against 6 761), so part of the speed-up happens inside the
  1 000-epoch settling window the ratio does not read: R understates the change there rather
  than overstating it. On the held-out children `copy_cost` is non-null in 7 654 samples and
  equals `max_steps` (8 192) in every one: no halting copier appeared.

  **The rung-3 claim**, finding `copying-gets-faster-under-an-economy`, **registry status
  `published`**: under an energy economy, the dominant replicator's `copy_latency` falls
  relative to the paired continuation. That is selection for faster copying, and it is the
  programme's first confirmed adaptation result: a hypothesis written down before the data
  it is tested on, shown on held-out parents at both economies, at p below 0.001, not resting
  on one or two parents. `published` ("every run finished and the claim stands on them") is
  the registry's status for exactly that. What it does not claim: `copy_latency` is measured
  on the dominant tape against a noise partner, not in situ, so it says the dominant copier
  copies faster in isolation, not that the colony replicates faster; H3 conditions on not
  going extinct, leaving extinct children out (none of the held-out ones was), while the 3
  and 5 economy children with a settled relapse stay in its 24 pairs — descriptively, not
  as a registered test, leaving them out too reads 19 to 2 and 17 to 2; it is one substrate,
  20 000 epochs and three correlated children per parent; the mechanism — why copies get
  faster — is not identified; and the copiers still loop rather than halt, which is the
  exploratory `copy_cost` observation above, not part of the reading.

  **The rung-4 claim**, finding `complexity-from-an-emerged-start`, **registry status
  `negative`**: from an emerged start, an energy economy does not keep complexity rising.
  Neither economy arm can be read under the original rule, because both kill replicators
  more often than the continuation, and the rich economy's 12-to-1 rests on two parents. The
  held-out H4-survivors reading asked the same question of colonies that survived, on parents
  nobody had seen, and the seen economy-8192 complexity signal did not replicate: refuted at
  2048, not shown at 8192, with almost every surviving pair tied. The sweep finished and the
  effect was not there, which is the registry's `negative`. Host mode is refuted, and the
  colonies are robust — 52 of 54 continuations held their replicators for another 20 000
  epochs — with only the strict no-relapse rule refuted. So the complexity question stands
  where the 2026-09-24 entry ("Where the programme stands after sweeps 9 and 10") left it:
  no substrate tested keeps complexity rising, now including an economy switched on in a
  world that already holds replicators, and the next substrate is still the open decision
  that entry named.

  Neither finding rests on the orientation-blind census, so neither carries an instrument
  note: the readings use `replicator_share`, `copy_latency` and `dominant_instruction_count`
  over `dominant_self_replicates` samples, the parents qualify on the orientation-aware
  census, and `copy_latency` reads an image in either orientation. Both pages render every
  count from `Experiments::FromEmergedReadingService` at render time, the report the sweep
  page draws; the registry summaries and DESIGN §1.3 item 11 carry the claims. Nothing about
  the engine, the rules or any observable moves.
- 2026-10-01 — **The locality-emergence finding states its claim: emergence peaks at an
  intermediate reach.** Sweep 13 (`locality-emergence`, entry of 2026-09-27) finished on
  2026-09-28, 630 of 630 runs, 90 per arm, seeds 91–180. Read under the pre-registered rule
  (`lab:locality_emergence_report` on the lab, 2026-10-01, "final reading"), with crossings
  and emergence re-counted by an independent SELECT on the lab database (crossed: a confirmed
  `emergence_epoch`; emerged: crossed and `replicator_share` ≥ 0.5 at a sample at or after
  it), which agrees arm for arm:

  | arm | radius 1 | radius 2 | radius 3 | radius 4 | radius 6 | radius 8 | well-mixed |
  |---|---|---|---|---|---|---|---|
  | crossed / 90 | 5 | 10 | 11 | 20 | 11 | 5 | 8 |
  | emerged / 90 | 4 | 9 | 7 | 16 | 6 | 3 | 3 |

  **H-peak shown**: radius 4 16/90 against radius 1 4/90, one-sided Fisher p = 0.00385, Holm
  0.00385; against well-mixed 3/90, p = 0.00135, Holm 0.00269. Both adjusted p are below
  0.05. **H-shape shown**: over the six finite radii the radius² coefficient is −0.11379,
  two-sided Wald p = 0.00407, and the fitted peak is at radius 4.10, strictly between 2 and
  6; well-mixed, not fitted, 3/90.

  **The claim**: on this world (128², fixed 64-byte tapes, 2^-13, 20 000 epochs) a replicator
  arises most often at an intermediate reach.
  Radius 4 emerged four times as often as radius 1 and five times as often as the well-mixed
  world, on worlds no earlier reading had seen, and the curve over the finite radii rises from
  radius 1, peaks near 4 and falls by radius 8. It is the exploratory pattern of sweep 12,
  confirmed under rules fixed before any run was read.

  **Registry status `published`**, finding `emergence-peaks-at-intermediate-reach`: every
  run finished, the reading is final and both pre-registered hypotheses are shown, which is
  what "every run finished and the claim stands on them" asks. It is the registry's first
  `published` finding. The page renders the curve, the two hypotheses and sweep 12's arms
  beside them at render time from `Experiments::LocalityEmergenceReadingService`, the report
  the sweep page draws, applied to both sweeps. It carries no census note: emergence is read
  on `replicator_share`, the orientation-aware clause (#245, #252). The radius-locality page
  gains a line pointing to it.

  **A coincidence of totals, stated so no reader suspects a copy.** At radius 1, 2, 4 and
  well-mixed this sweep emerged 4, 9, 16 and 3 of 90, exactly sweep 12's exploratory counts.
  They are different worlds: this sweep's seeds are 91–180 and sweep 12's 1–90; its runs are
  ids 3673–4302 and sweep 12's 3217–3576, none shared; the confirmed crossings count 5, 10,
  20 and 8 here against 5, 12, 25 and 7 in sweep 12; and at radius 1, where both count five,
  the crossing seeds and epochs are different ones (seeds 96, 113, 119, 123 and 143 at epochs
  17 990, 10 480, 13 000, 10 520 and 5 470, against seeds 1, 5, 20, 51 and 82 at 5 030, 7 000,
  6 210, 17 250 and 9 330). The share clause then leaves the same totals by chance. The
  confirmatory weight is on the three new arms as much as the four repeated ones: radius 3, 6
  and 8 are what make H-shape a peak rather than a rise.

  **What it means for rung 0**: the conditions under which a replicator arises include how
  far a cell reaches, and not monotonically. The radius sweep (2026-09-11) read locality as
  not speeding emergence on ten seeds an arm and could rule out only an enormous effect; at
  nine times the seeds and the emergent rate the effect is there, as a best reach in the
  middle rather than a benefit of locality as such — the tightest reach is among the worst.
  With the lineage-diversity finding it divides the work: reach changes how often a
  replicator arises, while after emergence one lineage held the world at every reach sweep 12
  read. Not claimed: other world sizes, rates, growing tapes or budgets than 128²,
  2^-13, 64 bytes and 20 000 epochs; detector crossings that the share clause does not keep;
  any mechanism for why a reach near 4 is best; well-mixed as a point on the radius scale.
  Nothing about the engine, the rules or any observable moves.
- 2026-10-01 — **Does the reach effect carry to growable tapes? The `reach-cap128` sweep,
  pre-registered, and a pool of parents with room to grow.** This is §1.3 item 14,
  experiment `reach-cap128` (sweep key `reach_cap128`), and its numbers live in
  `Lab::ReachCap128Reading`.

  **What was seen.** Sweep 13 (`locality-emergence`, entry of 2026-09-27) finished on
  2026-09-28, 630 of 630 runs. Read by its own rule over the live samples (a SELECT on the lab
  database, 2026-10-01), emergence is 4 / 90 at radius 1, 9 at 2, 7 at 3, **16 at 4**, 6 at
  6, 3 at 8 and 3 / 90 well-mixed. Its pre-registered tests read off those counts: H-peak
  shown (radius 4 against radius 1, one-sided Fisher p = 0.0039; against well-mixed p =
  0.0013, Holm 0.0027) and H-shape shown (radius² coefficient −0.114, Wald p = 0.0041,
  fitted peak at radius 4.1). That curve is on **fixed 64-byte tapes**. Every rung-4
  experiment runs on growable ones — `tape_len` 64 under `max_tape_len` 128 — and starts from
  emerged worlds of that kind (#243/#244, the `from-emerged` sweep). Today the only pool of
  such parents is sweep 9's economy-off control at cap 128, radius 1: **11 of 270** runs
  carry the record's confirmed `emergence_epoch` (definition a). Under the replicator-world
  definition (b) — confirmed, and `replicator_share ≥ 0.5` at some reading at or after the
  crossing — it is **11 of 270** too, every confirmed run qualifying, but that count stands
  on a different instrument per run: 6 of the 11 finished before #247 and carry no live
  `replicator_share` sample at all, so for them (b) can only be read off the
  `oriented_census/1` readings of their stored worlds. Those are one world about every 1 000
  epochs — the first, the last, every tenth snapshot at `snapshot_every` 100, and the one
  nearest the transition, 21 a run on average — against a live sample every 10 epochs. A
  live count would give a post-#247 run a hundred chances at a passing sample for every one
  a pre-#247 run gets. All 270 control runs carry the stored-world readings, every kept
  world read (a SELECT, 2026-10-01). The readings of the 11: terminal share 0.71–0.98, the
  peak after the crossing 0.74–0.99; their dominant tape at the last live sample is 128 bytes
  long in all 11, with 10–95 instructions (median 20).

  **Emergence, locked.** One definition, applied identically to both arms: a finished run
  is **emerged** when it has the confirmed `emergence_epoch` **and** some
  `oriented_census/1` reading of a world it kept — a static reading, `epoch =
  source_epoch`, at or before the run's last epoch, at or after the crossing, of a world
  the run still stores — reads `replicator_share ≥ 0.5`. A reading without the share as a
  number is no reading. Live samples do not enter it, and nor does a reading of a world
  pruned since it was read. A run counts only once the readings pass has read **every**
  world it kept (`Runs::OrientedSummary#measured?`); until then it is listed and not
  counted. Both arms keep their worlds under the same pruning, so the resolution is the
  same in both. The one difference is a world a descendant run starts from, which pruning
  also keeps: each of the control's 11 confirmed runs keeps one, and none of the 11 needs
  it — each reads the share on a world every run keeps, a multiple of 1 000 or its last
  (a SELECT, 2026-10-01). A run read before the prune job thinned it would carry about 200
  readings where the control carries 21, hence the stored-world clause. **The snapshots
  are thinned, `lab:prune_snapshots`, and then a readings pass, `readings-corpus
  --experiment reach-cap128 --epochs all`, precedes the reading**; the reading is final
  only when every run of both arms has finished and been read in full. The constants are `INSTRUMENT`, `SHARE_KEY` and
  `MIN_SHARE` (0.5) in `Lab::ReachCap128Reading`.

  **The sweep.** Every parameter of sweep 9's economy-off cap-128 control, read off
  `Lab::SWEEPS["host_parasite"]` and copied, the inert economy keys included
  (`energy_influx` 0, `steal_amount` 0, `energy_stock_cap` 32 768, `steal_loss` 0.5): 128²,
  `tape_len` 64, `max_tape_len` 128, `mutation_rate` 2^-13, the engine's defaults
  otherwise — at **radius 4**, with `lineage_rule = oriented`, which changes no byte of a
  world (entry of 2026-09-25). A run's canonical params differ from the control's in
  `radius` and `lineage_rule` alone. **Seeds 1–270**, the control's, 20 000 epochs, **270
  runs**, priority **30**. Radius changes the world, so these are new worlds: no run on the
  lab at any seed has radius 4 with `max_tape_len` 128 (a SELECT, 2026-10-01; the radius-4
  runs stored are `radius`, `lineage-diversity` and `locality-emergence`'s, all at a fixed
  64 bytes).

  **H-reach128 (confirmatory).** Radius 4 at cap 128 emerges more often than sweep 9's
  cap-128 control at radius 1. One **one-sided Fisher exact test** of emerged over counted,
  radius 4 above the control (`Stats::FisherExact.greater`). **Shown** where p < **0.05**;
  **refuted** where radius 4's rate is at most the control's; **not shown** otherwise;
  **not yet tested** until each arm has a counted run. With the control fixed at its 11 of
  270, all 270 runs counted, it is shown at **21** emerged runs or more. The power against
  that fixed control is about 0.59 if radius 4's true rate is 0.08, 0.91 at 0.10 and 0.99 at
  0.12 (exact binomial sums, 2026-10-01); sweep 13's ratio, four times radius 1's rate, would
  put radius 4's rate near 0.16, where the power is all but 1. The control was run 2026-09-18 to 2026-09-26 and its count was seen
  before this entry; it is a historical arm, not a concurrent one, and the engine's
  determinism is what makes it comparable: its worlds would be the same runs today.

  **Secondary, descriptive.** Per arm, over the emerged runs: the median `emergence_epoch`;
  the median terminal `replicator_share` of the stored world at the last epoch; and the
  dominant tape's `dominant_raw_len` and `dominant_instruction_count` at the run's last live
  sample, with whether the terminal stored world's dominant tape self-replicates
  (`dominant_self_replicates`) — do the tapes use the room? Lower-middle medians
  (`Findings::Median`). None of it decides anything.

  **The parent pool.** An emerged world whose terminal stored-world `replicator_share` is at
  least **0.5** (`PARENT_SHARE`) is an **eligible parent** for later descendant sweeps; the
  reading counts them per arm. No later sweep's parent rule is locked here: a sweep that
  starts from these worlds states its own.

  **When it is read.** `lab:reach_cap128_report` and the sweep's page read it, labelled
  **interim** until every run of both arms has finished and the readings pass has measured
  every one of them. A failed run keeps it interim until it is re-run and finishes. The
  reading is `Experiments::ReachCap128ReadingService`.

  **What is not claimed.** One world size, one rate, one cap (128), one budget, one reach
  against one. A difference inside 20 000 epochs can be a speed difference. The control is
  the economy-off arm of a sweep run under the `aligned` lineage rule, which moves no byte,
  and before #256, which moved run time and nothing else. Sweep 13's curve is not re-read on
  stored worlds here; its counts above are its own rule's.

  **Cost.** Measured from the runs' `compute_seconds` (2026-10-01): sweep 9's cap-128
  control averaged **1 261 s** a run on seeds 1–90, before #256, and **823 s** on seeds
  91–270, mostly after it. Sweep 13, all after #256, put radius 4 at 877 s against radius 1's
  485 s, **1.8×**, with more emerged and so dearer worlds in it. At 823 s × 1.8 ≈ 1 490 s a
  run, 270 runs are about **112 compute-hours**; at the pre-#256 1 261 s, about 170. Sweep 13
  ran 124 compute-hours in 11 hours of wall time (about 11 runs at once), so this is about
  **10 hours** of wall time with the lab to itself, 15 at the high end.
- 2026-10-01 — **Who pays for an interaction becomes a parameter: `energy_payer`, `pair` by
  default, `initiator` so that income can buy copies.** The user's instruction was
  "continue, don't stop until life exists". Of the six options of the 2026-09-24
  entry the orchestrator chose option 4, a second, labelled substrate with an exogenous
  task, as the next rung-4 bet. In the record and on the site it will be called
  "Metabolism": computing earns the energy to copy. In the engine it is Soup plus opt-in
  parameters. This entry is its first slice and changes the economy alone. The task assay,
  the reward and the observables come in later slices, and the `metabolism` sweep is
  pre-registered in its own entry before any of its runs is seeded.

  **Why `pair` cannot carry a reward.** Under the stock economy of §1.1 an interaction runs
  `min(stock_a, stock_b)` steps and debits both cells, and every cell initiates every epoch.
  A copy from a rich cell into a poorer one, and a copy back, are both bounded by the poorer
  stock, so extra income is neutral at the frontier where composition changes. It enriches
  only interactions between rich cells. A rich cell is also never starved, so it loses the
  protection an empty stock gives against being overwritten. A pilot on a throwaway copy of
  the engine (a design study's, not a finding) planted task-solving copiers into run 2577's
  world and paid each solving cell a second income. Under `pair` every planted solver died
  out within 500 epochs, in 17 of 17 runs, and in the five matched runs its sham, the same
  tape with the task's output op disabled, outlasted it. Under the initiator rule below
  every planted solver held 69 to 97% of the world 1 500 epochs after planting, in 11 of
  11 runs.

  **The rule.** `energy_payer ∈ {pair, initiator}`, default `pair` (DESIGN §1.1). At `pair`
  the engine runs exactly the code it ran before. At `initiator`:
  - a cell initiates only if its stock is at least `max_steps`, the price of one
    interaction, and is otherwise passed over as initiator. Its partner is drawn
    regardless, so the shuffle and every partner draw are the ones `pair` makes and no RNG
    stream moves;
  - the interaction's budget is `max_steps`;
  - the initiator alone is debited the full price, whatever ran. Debiting the steps run
    instead would favour copiers that halt early, which already initiate once per epoch
    and could buy nothing with a reward;
  - the partner is never gated and never debited, and steals settle after the price as
    they settle after a pair's debit.

  A cell's income is then the rate at which it initiates. The rule is refused without an
  `energy_influx` (there is no stock to pay from), with an `energy_stock_cap` below
  `max_steps` (no stock could ever pay), and beside an `energy_per_epoch` (the allowance
  bounds an interaction by both cells' purses, which is the pair rule again). The study
  weighed one other variant: the initiator's stock as the budget, with no fixed price. It
  was rejected because a copier that never halts would then copy if and only if its influx
  covered its copy latency, a knife edge rather than a rate.

  **What it moves.** Nothing at the default. Every pinned hash and observable digest stays
  as it was. A new pin, taken on the code before the parameter existed, holds a stocked
  soup with theft (32×32, seed 42, influx 2 048, cap 8 192, steal 1 024, 50 epochs) at
  `0xff36_fede_bb44_6d42` with `pair` named. The initiator rule has its own pin: 32×32,
  seed 42, influx 1 024, cap 65 536 (eight prices), 50 epochs, `0x6009_9358_301f_03ac`. A
  test records the partner sequence and finds the two rules draw the same one. The
  parameter is dynamics, not structure: a descendant may switch it,
  `Lab::CanonicalParams::STRUCTURAL_KEYS` does not name it, and `World::descend` from an
  unstocked parent mints full stocks under it as under `pair`. A run stored before the
  parameter existed carries no `energy_payer` key, and `Lab::CanonicalParams` fills in the
  engine default, `pair`, so stored runs keep their identity. Nothing is relocked.
- 2026-10-01 — **The task assay, the emit op `!` and the task reward: `tasks`, `task_every`
  and `task_reward`, off by default.** This is slice 2 of the "Metabolism" substrate, option
  4 of the 2026-09-24 entry, whose first slice was `energy_payer` above. It adds the task a
  cell can earn energy by and the reward that pays it. The observables come in the next
  slice; the `metabolism` sweep, the substrate's label on the site and its pre-registration
  come in a later one, in their own entry, before any of its runs is seeded.

  **The assay** (DESIGN §1.1, "Tasks and the emit op"). A cell's tape runs alone, on a
  buffer of its live bytes T (length L) followed by L zeros: a fixed 2L that never grows,
  both heads wrapping over all of it. The inputs sit on the last two bytes, `B[2L−1] = x`
  and `B[2L−2] = y`, where head0 reaches them with `<` and `<<` and head1 with `{`, the
  move every emerged copier already makes. The run executes the run's own `ops`, with the
  steal byte a no-op and the byte `!` (0x21) as an emit op: it appends the byte under head0
  to an output list, as `.` writes it to head1. The run stops at the end of the buffer, on
  an unmatched bracket, after `TASK_STEPS` = 4 096 steps (the budget MUL's minimal program
  needs) or at the `TASK_MAX_OUTPUTS` = 4th emit. There are `TASK_CASES` = 3 cases, x and y
  uniform in 0..15, drawn once per assay epoch on a new stream, `STREAM_TASK`, at
  (seed, epoch), and shared by every cell. Task t is credited when some output slot j < 4
  holds t's value in all three cases. A tape holding no `!` byte is credited nothing and is
  never run, and a case that emits nothing ends the assay. The second is exact; the first
  is a rule, not a shortcut, because a tape can increment a byte to `!` where its pointer
  will reach it, and the emit a tape is paid for must be one it carries. The verdict is a
  pure function of (tape, seed, epoch), so each distinct tape is assayed once per assay
  epoch and cell order cannot matter.

  **The separating rule.** The cases are redrawn until five things hold. Within each task
  the three expected outputs are pairwise distinct, so no constant can pass. No two tasks
  expect the same three outputs, so one output slot matches at most one task. The three x
  values are pairwise distinct, and so are the three y values. No task's outputs sit a
  constant offset from x, or from y, unless the task is that offset of that input
  everywhere, as ECHO, INC and DEC are of x. And no input is 0. The rule exists because the
  input domain is small: in the design study's pilot, without its first two clauses, tapes
  that only echo x were credited ADD and SUB on draws whose y was 0 in all three cases, and
  MUL on draws whose y was 1, five false credits in run 1007's world alone; with them there
  were none outside genuine computation in six emerged worlds of 16 384 cells.

  The last three clauses were added in review, before any run used the assay. The study's
  two clauses rule out only one ladder task passing for another, not a cheap function
  outside the ladder passing for a task. Review found `<+++!`, which emits x+3, credited
  ADD on any draw whose y is 3 in all three cases, about one draw in 2 500; distinct inputs
  close it, since no input can then be held constant for another task to absorb. A search
  of every program of up to 5 bytes, and 120 000 sampled programs of 6 and 7, against
  thousands of draws then found two cheap classes the distinct inputs leave open. The
  first is an input plus a constant matching a task through a relation between the inputs:
  `<<+!`, which emits y+1, was credited DOUBLE wherever y = 2x−1, and y±1 credited SUB
  wherever x−2y was constant. The offset clause closes it: an input plus a constant, the
  cheapest thing a tape can emit, earns only the task it is. The second is a zero test,
  BFF's only branch, telling one case apart: `[<]>!` scans left to the first zero byte and
  emits x where y is 0 and y elsewhere, credited SUB wherever x = 2y in the other two
  cases. Refusing an input of 0 closes it. With all five clauses the same search found no
  credit to a slot that does not compute its task on at least half of the 256 inputs. A
  zero test can still split cases on another value after decrements (`-[`), but that
  costs a byte per unit tested, and none surfaced up to 7 bytes.

  About 68% of draws are redrawn (5 434 392 of the 16^6 triples separate); the draw is
  bounded at `TASK_CASE_DRAWS` = 1 024 and then falls back to a fixed separating set,
  (3, 5), (7, 2), (12, 9), so it is total and deterministic. Tests hold every clause over
  10^5 draws, and hold `<+++!`, the other x±c and y±c, and the scan `[<]>!` to the credit
  they compute over 10^5 draws. The rewarded run's pin below did not move with the tighter
  rule: its solvers echo x, which every separating draw credits alike.

  **The ladder.** ECHO x, INC x+1, DEC x−1, ADD x+y, SUB x−y, NOT 255−x, DOUBLE 2x and MUL
  x·y, mod 256, worth 1, 2, 2, 4, 4, 8, 8 and 16 units, doubling with difficulty as Avida's
  merits do; 45 units in all. Arithmetic rather than bitwise, because BFF's only data ops
  are ±1, copies and a zero test, and bit extraction would need programs of a hundred ops.
  Each minimal program of the study (`<!>`, `<+!>`, … the 32-op MUL) computes its task on
  its first output slot for all 256 inputs, through the assay itself, and is credited with
  its own task alone on separating cases; pure copiers, copiers with a junk emit, constant
  emitters and sprayers such as `[!+]` are credited nothing.

  **The reward.** At every epoch that is a multiple of `task_every` (≥ 1, default 8), before
  that epoch's influx, every cell is paid `task_reward × Σ units` over its credited tasks
  into its stock, capped at `energy_stock_cap`. A lump per assay rather than an income per
  epoch needs no new world state. The assay draws only from `STREAM_TASK` and writes only
  stocks, so the stocks are the one place a reward can act, through the economy. A reward
  needs `tasks = arith` (a reward with nothing to earn it by would be silently inert) and
  an `energy_influx` (there is no stock to pay into without one); `tasks` is refused on
  life. The reward does **not** require `energy_payer = initiator`: the study found a
  reward useless under `pair`, but a `pair` reward arm is a legitimate control for that
  very finding, and refusing it would make the claim untestable.

  **The emit op in the interpreter.** Emit lives inside `bff::execute`, behind a
  compile-time switch that every soup interaction leaves off, so the byte is not in the
  table the soup's loop reads. An emit is an acting step to both skips of 2026-09-25: it
  marks the buffer changed, so no cycle is skipped across it, and a lap that reaches one is
  not replayed, so every emit the plain loop makes is made. Copy loops that hold no emit
  are still skipped inside the assay. The equivalence tests hold an emitting run, skipping
  or not, to a stepper written by the book on random assay buffers dense in emits and
  loops, and hold it to the soup's own interpreter on pairs that carry no `!`.

  **What it costs.** On restored emerged worlds (128×128) one full assay epoch took 1.5 to
  22 ms memoised with the skips, 3.6 to 42 ms without the memo, 9.5 to 108 ms with the memo
  and every step run, and 43 to 272 ms with neither, against a soup epoch of 11 to 15 ms
  under the metabolism economy. At an assay every 8 epochs the control arm pays nothing,
  and a rewarded arm pays 0.2 to 2.8 ms an epoch for the assay: about 1% of a soup epoch
  in the world with the fewest emitting tapes and about 20% in the one with the most,
  before the reward's own effect on the dynamics.

  **The invariant.** Nothing moves at the defaults, `tasks = off` and `task_reward = 0`,
  and every pinned hash and observable digest stays as it was. `!` is never an instruction
  in the soup. A reward of 0 runs no assay at all, so a run with `tasks = arith` and
  `task_reward = 0` is byte for byte, stock for stock, the run with `tasks = off`, and the
  control arm can carry the next slice's readings. The rewarded run has its own pin: 32×32,
  seed 42, `initiator` at influx 1 024 and cap 65 536, `tasks = arith` every 8 epochs at a
  reward of 2 048, a quarter of the cells given `<!>` at the front of their tape, 50 epochs,
  `0xace9_3173_c4dd_563f`. No snapshot version is needed, since the reward lives in the
  existing stock. The parameters are dynamics, not structure: a descendant may set them,
  and `Lab::CanonicalParams::STRUCTURAL_KEYS` does not name them. A run stored before they
  existed carries none of the keys, and `Lab::CanonicalParams` fills in the engine defaults,
  `off`, 8 and 0, so stored runs keep their identity. `runner schema` exports the assay's
  constants and the ladder under `tasks`, beside `self_replication`.

  **Descent validates.** `World::descend` never called `Params::validate`, so a descendant
  could carry a combination validation refuses (a reward with no influx, or the initiator
  with no stock, which #273 made inert rather than a panic). A descendant is a new run, so
  it is now refused such params at descent, and the runner fails it cleanly as it fails
  any descent error. `World::from_snapshot` still does not validate: it resumes a run
  already under way, which must keep resuming however validation has tightened since.
  Nothing is relocked.
- 2026-10-01 — **The task observables: twelve live-only readings of what the soup
  computes (Metabolism, slice 3).** The task assay of the entry above pays; these read. They
  are appended to `Metrics` with these exact keys, which the `metabolism` pre-registration
  codes against: `task_share_echo`, `task_share_inc`, `task_share_dec`, `task_share_add`,
  `task_share_sub`, `task_share_not`, `task_share_double`, `task_share_mul`,
  `task_capability`, `task_capability_loop`, `dominant_tasks` and `dominant_task_count`.

  **What they read.** A share is the fraction of 256 cells, drawn uniformly with
  replacement, credited with its task, on cases drawn first and then cells drawn on
  `STREAM_TASK | 1` at `(seed, epoch)`, as `replicator_share` draws on its own stream; each
  distinct tape in the sample is assayed once. A task is a capability when its share is at
  least 1/10, compared in integers (`10 × count ≥ 256`, so 26 of 256); the loop count is
  over ADD, SUB, NOT, DOUBLE and MUL. `dominant_tasks` is the census's dominant tape's
  credit as a `u32` bitmask in `task::TASKS` order, assayed on cases drawn on
  `STREAM_TASK | 2`, and `dominant_task_count` is its popcount; it reads 0, not null, where
  that tape solves nothing.

  **When.** Whenever `tasks != off`, rewarded or not, so the reward-0 control arm carries
  the readings its treatment does. Null wherever `tasks = off`, on life (including a life
  run resumed with `tasks` set, which `from_snapshot` does not refuse), and on every sample
  recorded before them. Rails stores them in `Sample::OBSERVABLES`; `dominant_tasks` is a
  flag, not a series, and the run page names its tasks from the ladder `runner schema`
  exports. A missing key draws no point and is never read as 0.

  **The invariant, pinned.** The readings draw on streams nothing else draws on and write
  nothing. A test steps `tasks = arith, task_reward = 0` beside `tasks = off` under both
  payers, sampling every 5 epochs, and holds them to the same world hash, stocks, snapshot
  and every pre-existing observable, sample for sample. Every earlier hash and digest is
  unmoved; the task readings have their own digest, split from the others as #247 and #255
  split theirs: the reward-0 control of the rewarded pin (seed 42, 50 epochs) reads an ECHO
  share of 0.06640625 and nothing else, and a planted still world reads three capabilities,
  one loop capability and a dominant bitmask of 9.

  **Cost.** On the eight restored emerged worlds (128×128, 2 800 to 11 300 cells holding a
  `!` byte), a sample with the readings cost within about 1% of a sample interval of 10
  epochs more than one without, inside the noise of a shared machine.

  **Live-only.** They are not added to `oriented_census/1` or `/2`, since an instrument
  version never changes once readings exist under it. Nothing is relocked.
- 2026-10-01 — **Metabolism: a second, labelled substrate that imports an objective. The
  `metabolism` sweep, pre-registered.** This is §1.3 item 15 and it opens DESIGN §1.4. The
  experiment is `metabolism` (sweep key `metabolism`), and its numbers live in
  `Lab::MetabolismReading`. It is the fourth slice of the substrate whose economy and assay
  the energy-payer and task-assay entries added; the observables it reads (`task_share_echo` …
  `task_share_mul`, `task_capability`, `task_capability_loop`, `dominant_tasks`,
  `dominant_task_count`) come in their own slice, and **the sweep is seeded only once the
  runner that records them is deployed**: a child sampled by a runner without them is
  unmeasured on every task reading, by construction.

  **The choice.** It is the orchestrator's: option 4 of the 2026-09-24 entry ("Where the
  programme stands after sweeps 9 and 10"), a second, labelled substrate with an exogenous
  task, taken after the user's instruction "continue, don't stop until life exists". It
  tests the record's 2026-09-16 explanation of the plateau, a drift–selection balance in
  which "a byte off the copy path costs nothing and buys nothing". Here a byte off the copy
  path can buy something: the energy to copy. If complexity rises when computation is paid,
  and does not in the unpaid twin under the same economy, the plateau was "nothing pays",
  not "BFF cannot express more". If nothing rises, the instruction set or the mutation
  operator binds first.

  **The label.** In the engine the substrate stays `soup`: a descendant may not change
  `substrate`, which is structural, and the world's shape is Soup's. The label lives in the
  record, the sweep and the registry, and it is locked here:
  - every run with `task_reward > 0` is a **Metabolism** run (`Lab::MetabolismReading.
    metabolism_run?`);
  - its runs are **never pooled** with fitness-free arms. The no-reward arm below is
    fitness-free — at a reward of 0 nothing pays a task and its world runs byte for byte as
    with `tasks` off; only its samples assay the soup, on streams of their own, to measure
    it — and is not a Metabolism run; it enters this reading only as the paired twin, which
    is a comparison, not a pool;
  - **rung 4 on Soup stays "not shown"** whatever this sweep reads. A shown result here is
    a result about a substrate that imports an objective;
  - its findings carry an **"imports an objective"** badge. The badge is built in the
    finding slice, once a reading is final; this entry only locks that it is carried.

  **What was seen before writing**, all of it the design study's pilot, on a throwaway copy
  of the engine with the assay and the payer rule added — not the merged engine, and not
  findings:
  - *Chance credit.* The assay run once on every cell of six stored worlds (16 384 cells
    each) found genuine ECHO, INC and DEC solvers, unrewarded, in up to 8% of cells, and no
    credit above DEC; without the separating rule it found five false credits in run 1007's
    world.
  - *Planted solvers.* Under `pair` every planted solver died out within 500 epochs (17 of
    17 runs) and its sham outlasted it in all 5 matched runs; under `initiator` every
    planted solver held 69–97% of the world 1 500 epochs after planting (11 of 11).
  - *De novo.* Descendants under `initiator` at influx 1 024, the assay every 8 epochs, with
    the reward on or off: the one-substitution rungs climbed in **9 of 9** rewarded pilot
    worlds, ECHO first, then INC, DEC or both; the four read to 20 000 epochs ended solving
    all three, and every unrewarded twin ended at zero tasks above 10%. The reward world
    ended above its twin in 8 of 8 pilot pairs. **No loop rung** (ADD, SUB, NOT, DOUBLE,
    MUL) appeared in any pilot world: at most 3 cells, ever. In the four worlds with
    crude early and late medians, the reward children's dominant tape rose by 28–47% in 3
    and both arms fell in the fourth (2862).
  - The pilot's worlds are **four of this sweep's parents**: the mini-sweep ran 1007, 2577,
    1029 and 2862 at seed 1, and the first runs 1007 and 2577 again, with 3151, a
    from-emerged child. Its seeds were not 2001–2003 and its reward scales were ⅛ and
    ½ of an influx per unit, not this sweep's ¼, so no child of this sweep has been run;
    but the reading is **not held out** from those four parents. Its per-parent agreement
    shows how much of any result they carry, and every test is re-read without them (the
    sensitivity reading below).

  **The sweep.** A descendant sweep under the from-emerged sweep's own parent rule, shared
  as data (`Lab::FROM_EMERGED_PARENTS`, read by `Experiments::DescendantParentsService`),
  not a list of ids: sweep 9's economy-off controls at caps 128 and 256 whose terminal
  `oriented_census/1` reading holds `replicator_share ≥ 0.5`. Sweep 9 is terminal and every
  terminal world has been read, so the rule qualifies the same **18 parents** the
  from-emerged sweep read: 944, 950, 967, 991, 1007, 2568, 2577, 2590, 2654, 2676 and 2700
  at cap 128, and 1029, 1087, 1089, 1103, 2771, 2802 and 2862 at cap 256 (a SELECT on the
  lab database, 2026-10-01). Each child starts from its parent's last stored world, epoch
  20 000. Two bundles, each merged over the parent's params:
  - **reward**: `{energy_payer: initiator, energy_influx: 1024, energy_stock_cap: 65536,
    steal_amount: 0, tasks: arith, task_every: 8, task_reward: 2048}`;
  - **no reward**: the same with `task_reward: 0`.

  The influx is `max_steps`/8, the cap 8 prices, theft off, and a reward of 2 048 makes one
  unit a quarter of an influx per epoch (`influx · task_every / 4`, design study §3.2). Both
  bundles pass `Params::validate` merged over a parent's params: `initiator` has an influx,
  a cap of at least `max_steps` and no `energy_per_epoch`; the reward has `tasks` on and an
  influx; and `tasks = arith` at a reward of 0 is accepted, since the task-assay entry
  refuses a reward with tasks off, not tasks without a reward. Descent now validates
  (task-assay entry), so a bundle that failed would fail its children cleanly at descent.
  The parents carry `energy_stock_cap` 32 768 and `steal_loss` 0.5; the bundle overrides
  the cap, and the loss is inert with theft off. Seeds **2001, 2002 and 2003**, none a
  parent's own (1–270) nor a from-emerged child's (1001–1003); **40 000 epochs** past the
  parent, so a child runs 20 000 → 60 000; priority **40**, after the from-emerged
  children (50) and ahead of the reach sweeps (30), so it runs ahead of whatever of
  `reach-cap128` is still pending. 18 × 2 × 3 = **108 children**. Stocks are minted full at
  descent, as for every priced descendant, so the first few epochs burst; both arms share
  it and the readings skip it.

  **The assay the children run** is the task-assay entry's, under its separating rule as
  that entry states it when this sweep is seeded: the study's two clauses (each task's
  three expected outputs pairwise distinct, no two tasks expecting the same three) and the
  clauses #274's review added before any run used the assay, which keep a cheap function
  outside the ladder from passing for a task — distinct x and distinct y across the three
  cases, so `<+++!` (x + 3) is not credited ADD on a draw whose y is 3 throughout, no task
  a constant offset from an input unless it is that offset, and no input of 0. That entry,
  not this one, is the rule's record. The pilot's chance-credit counts above were taken
  under the study's two clauses alone.

  **The readings, per child**, over its own samples at epochs above `parent_epoch` +
  **1 000**, #263's settling window (`SETTLING_WINDOW`):
  - **Deciles** are cut as clarification 1 of the from-emerged reading cuts them, over
    these settled samples: the first and last `ceil(n / 10)` of all `n` settled samples in
    epoch order, unfiltered, and inside a decile the samples that carry the key as a number.
    A median is `Findings::Median`'s lower middle. Every decile of this reading is cut from
    the settled samples, extinction's and the complexity rule's included: #263 cut
    extinction's last decile from all own samples, which for a 40 000-epoch child differs
    by the last decile's first ten samples, and the from-emerged complexity rule cut both
    deciles from all own samples, which here would read the descent burst as the "first"
    replicator.
  - **Extinct** where the last-decile median `replicator_share` is below **0.1**; a
    **settled relapse** where the share sits below **0.1** for **3** consecutive settled
    samples (#263, `Lab::FromEmergedHeldout::Child`). A child that never sampled a share is
    read by neither rule and is measured on nothing.
  - **Capability**: the last-decile median of `task_capability`, and of
    `task_capability_loop`. A child with fewer than **10** numbers in its last decile
    (`MIN_DECILE_SAMPLES`) is unmeasured on that key. Both are integers and compared as
    such.
  - **Complexity**: the from-emerged rule, unchanged but for the deciles above —
    `dominant_instruction_count` over the samples whose `dominant_self_replicates` is true,
    **rises** at a last-decile median at least **1.2 ×** the first, unmeasured with fewer
    than 10 such samples in either decile (`Lab::DescendantReading::Child`).

  **Pairs and the tests.** A pair is the reward child and the no-reward child of the same
  (parent, seed). A pair where either child is extinct, or unread, is excluded from every
  test. Each test is a **one-sided sign test** over the discordant pairs
  (`Stats::SignTest`): **shown** at p < **0.05**; **refuted** where the pairs favouring the
  no-reward twin are at least as many as those favouring the reward, which includes a test
  with measured pairs that all tie; **not shown** otherwise; **no measured pairs** where no
  pair is measured on both sides. Every test carries the from-emerged reading's per-parent
  agreement (clarification 4: ties counted among measured pairs, unmeasured pairs in their
  own column) and its leave-one-or-two-parents-out rule (clarification 5: read on a shown
  test only; every minimal set of one or two parents whose pairs, left out, bring p to 0.05
  or above, or leave no discordant pair, is listed as carrying it). There is no "relapses
  more" clause: as in #263, the settled-relapse and extinction counts per arm are reported
  beside the tests, descriptively, and that is where "the reward kills replicators" shows.
  - **H-capability.** A pair favours the reward when the reward child's last-decile median
    `task_capability` exceeds its twin's, the twin when the reverse holds; equal medians
    tie. Relapsed children stay in, as #263's H3-latency kept them. The pilot predicts it
    shown, carried by the one-substitution rungs; ECHO is nearly free (it drifted to 14% in
    one pilot control), so the rung-4 claim does not ride on it.
  - **H-ladder**, the rung-4 question: the same test on `task_capability_loop`, the count of
    ADD, SUB, NOT, DOUBLE and MUL at a share of at least a tenth.
    - *If refuted*: when computation pays, BFF copiers take the one-substitution rungs and
      stop. The drift–selection plateau then holds for every feature that needs several
      coordinated mutations, and the suspects become option 5 of the 2026-09-24 entry, the
      instruction set, and the substitution-only mutation operator. Pairs that all tie,
      no loop rung at a tenth in either arm, read the same way, as strongly as the power
      below allows.
    - *If shown*: paid computation climbs past one-substitution rungs.
    - *If not shown*: neither; the rate of loop climbing is below what 54 pairs resolve.
    - *Power*, from the study: the pilot saw 0 loop rungs in 9 rewarded worlds over 10 000–
      20 000 epochs, a two-sided 95% upper bound of 0.34 on the rate per child. With the
      twins at zero, the test needs **5** discordant pairs (p = 1/32); over 54 measured
      pairs its power is **0.64** at a rate of 0.1 per child and **0.92** at 0.15.
  - **H-complexity**: the from-emerged complexity rule, read only on pairs where both
    children are measured and **neither relapsed** past the window (nor is extinct). A pair
    favours the reward when its child rises and its twin does not, the twin in the reverse
    case. Mirroring and stacked one-substitution rungs add 6–14 ops, so this can be shown
    without H-ladder; it then reads **"paid complexity rises"**, not "open-ended".

  **The piloted parents, a sensitivity reading.** Each of the three tests is also read, by
  the same rules, over the pairs of the 14 parents no pilot ran — all but 1007, 2577, 1029
  and 2862 (`PILOT_PARENTS`) — and printed beside the tests. It decides no outcome. A
  finding reports it beside each test, and a test shown over the 18 parents but not over
  the 14 is reported as resting in part on the piloted parents.

  **Descriptive only**, printed per child and per arm, tested nowhere:
  - the **first own epoch** at which each task's share reaches **0.1** (`task_share_<task>
    ≥ 0.1`, which over 256 draws is `task_capability`'s line of 26 cells), read over every
    own sample, the settling window included, and so the **ladder order**;
  - **Lenski's stepping stones**: whether a child whose world reached a loop rung had INC
    or DEC at 0.1 at or before the first sample at which a loop rung did. The samples read
    world shares, not lineages, so "a lineage holding INC or DEC" is read as the world
    holding it first;
  - `dominant_tasks` (the commonest mask of the last decile, the smaller on a tie; 0, a
    dominant tape that solves nothing, is a mask like any other),
    `dominant_task_count`, `copy_latency` and `replicator_share` (last-decile medians).
    `copy_latency` is descriptive only now: the fixed price removes the latency selection
    #263 read;
  - the **share of income from tasks**, estimated from the last-decile median shares as
    `task_reward · Σ units · share / task_every` against `energy_influx`, with each task's
    units from `runner schema`'s ladder. It ignores the stock cap a lump can hit, so it is
    an estimate, not a measurement.

  **When it is read.** The reading is **final** when every child of every qualifying parent
  has finished (`Experiments::DescendantSweepSettledService`, clarification 6: a failed
  child keeps it interim until re-run). Before that, `lab:metabolism_report` labels it
  **interim**, and nothing is claimed from it. **Cost**: about 10 hours of the mini-pc,
  115 run-hours (design study §3.7: about 2 700 and 4 200 s a no-reward and a reward child
  at cap 128, 3 500 and 5 400 s at cap 256); the first finished children's
  `compute_seconds` replace the estimate.

  **What is not claimed.** The substrate **imports an objective**: whatever rises here was
  paid for by a task the programme chose, and says nothing about fitness-free emergence or
  about Soup's rung 4. The **input domain is small** (x and y in 0..15, three cases), which
  keeps loops bounded and is why the separating rule is load-bearing. The ladder is
  **arithmetic** because BFF has no bitwise ops: AND, OR, XOR and EQU would need programs
  of about a hundred ops, so "complexity" here is a ladder of arithmetic, not of logic. It
  is **one substrate**, one budget, three correlated children per parent, and four of its
  parents were piloted. The design study numbered this item 14 and DESIGN §1.3 gave 14 to
  the reach-cap128 sweep first, so it is item 15.

- 2026-10-01 — **The Metabolism label, implemented.** The entry above locks that a run with
  `task_reward > 0` is a Metabolism run, that its runs are never pooled with fitness-free
  arms and that its findings carry an "imports an objective" badge; this is how the site
  keeps it. Nothing is relocked.
  - **One predicate.** `Run.metabolism` and `Run.fitness_free` read `task_reward` off a run's
    params, a missing or null key as 0, so a run stored before the parameter is fitness-free.
    The engine reads the reward only as a JSON number, so any other value pays nothing and is
    read as 0, never cast. `Lab::MetabolismReading.metabolism_run?` is the same rule on a
    params hash.
  - **The badge** is a boolean on the finding's registry entry, `imports_objective`, not a
    reading of its sweep's runs: the findings index would otherwise query runs for it, and a
    finding is content written against its runs anyway. The registry spec holds every
    finding resting on the `metabolism` sweep to it. The badge sits beside a finding's
    status wherever that renders (the findings index and page, the home page, a sweep's and
    a run's citations), and links to an "imports an objective" entry in the how-it-works
    glossary that names §1.4. A sweep holding a paid run carries it beside its substrate.
  - **Never pooled.** Every site-wide or cross-sweep reading takes the fitness-free runs
    alone: the status strip's largest census and seeds transitioned, the surveys of every
    transitioned or emerged run (persistence, copy cost, complexity) and the findings
    index's denominator for them, the detector baseline read across the lab and
    `lab:oriented_report[all]`. The open-endedness survey pools only the fitness-free bets it
    names, so it needs no filter. The strip's counts of work done (sweeps queued, runs
    finished, epochs simulated) and the lab status page are throughput, not readings, and
    keep every run. A sweep's own page and its own reports keep its paid runs.
  - **The reading on the page.** The `metabolism` sweep's page prints the reading of the
    entry above, interim until final as `lab:metabolism_report` labels it: the arms, the
    three tests with their per-parent agreement and their re-reading without the piloted
    parents, the pairs, and the descriptive ladder. It is one pass over the children's
    samples, held under the page's cache key as the from-emerged reading is.

- 2026-10-01 — **The logic assay, the NAND op `~` and `task_floor` (Logic, slice 1).**
  "Logic" is a variant of the Metabolism substrate. It keeps Metabolism's economy, assay
  and reward, and swaps the arithmetic ladder for a logic one. It imports an objective
  **and a primitive**, and it carries Metabolism's label and pooling rule. This is its first
  slice: the op, the ladder, the parameters and the reward. The observables come next, in
  their own slice, and deploy with this one as a single runner restart, after the
  Metabolism sweep is final. The sweep and its pre-registration come after the Metabolism
  sweep reads, in their own entry, before any of its runs is seeded. Nothing is relocked.

  **Why a primitive.** A design study of the Metabolism ladder (2026-10-01, a scratch study
  outside the repository; its numbers are *pilot* numbers, from a throwaway copy of the
  engine and the stored worlds of six rewarded `metabolism` children, not findings) asked
  what holds that ladder at its one-substitution rungs. Its answer is the instruction set,
  not the variation operator:
  - BFF has no two-input data op, so every two-input task needs a counted loop, and the
    only loop a copier owns is its copy loop;
  - no loop solver that still copies lies within 3 substitutions of any evolved solver
    measured: one loop solver, which no longer copies, among 143 million mutants within two
    edits of every kind on 12 focal tapes, and among 20–37 million triple substitutions in
    the code window of each of four of them, 94 loop solvers, all of which spend the copy
    loop on the count and none of which copies;
  - the nearest loop solver that still copies is **5–7 coordinated substitutions** away
    by construction, and no partial kernel on the way computes anything new;
  - **indels do not shorten it**: 6–9 insertions under a length-keeping indel operator, no
    loop solver among 127 million one- and two-edit mutants involving an insertion,
    deletion or duplication, and 0 loop rungs in 4 of 4 pilot worlds with half of all
    mutations indels.

  NAND is the one primitive whose ladder has a known compositional depth and a stepping-
  stone result to test against (Lenski et al. 2003): every logic task is a composition of
  NANDs. *Pilot*: 2 of 4 cap-128 worlds climbed NOT/NAND → ORN → OR/ANDN → NOR within 20 000
  epochs, and with the rungs below OR unpaid the same two worlds climbed nothing, like the
  no-reward twin. XOR and EQU were reached by no single or double substitution of any
  evolved solver measured, nor by any triple substitution in the code window: they are the
  deep rungs.

  **The NAND op** (DESIGN §1.1, "The logic assay and the NAND op"). The byte `~` (0x7E)
  writes `¬(B[head0] ∧ B[head1])`, bitwise, under head0. It is an instruction **only in the
  logic assay**. `bff::run_emitting` takes an `AssayOps`, `Emit` for the arithmetic assay
  and `EmitNand` for the logic one, and `bff::execute` gains a third compile-time switch,
  `NAND_ON`, beside `EMIT_ON`, so the soup's table never holds `~` and the arithmetic
  assay's never does either: Metabolism's runs, live on the lab, run the code they ran. A
  NAND marks the buffer changed when it changes a byte, so the cycle skip stays exact, and
  a lap that reaches one is not replayed, as one that reaches an emit is not, since a lap's
  beats record no NAND. The equivalence tests hold an emit-and-NAND run, skipping or not,
  to a stepper written by the book over random assay buffers dense in `~`, `!` and loops,
  with whole-byte inputs; hold either assay's interpreter to the soup's own on pairs that
  carry neither byte, except where an increment manufactured one and the pointer reached it;
  and hold the arithmetic assay's stepper test to `~` as a no-op.

  **The ladder.** ECHO 1, NOT 1, NAND 1, AND 2, ORN 2, OR 4, ANDN 4, NOR 8, XOR 8, EQU 16:
  47 units, the study's 46 and an ECHO rung. NOT, ORN and ANDN credit either operand order,
  as Avida's do, and ECHO either input. Minimal NANDs are 0, 1, 1, 2, 2, 3, 3, 4, 4 and 5;
  `logic::FIRST_DEEP_TASK` is XOR's index.
  - **ECHO** is new to the study's ladder. Its §5.6 risk was that NOT needs `~` and `!`
    placed together, where Metabolism's entry rung needed only `!`, and 2 of 4 pilot worlds
    climbed nothing. ECHO restores the one-byte entry rung. It is a capability rung, like
    NOT through NOR. It adds no instruction and no form to any other task, so XOR and EQU
    keep their depth, and since its forms are the inputs, the study's "no form and an input
    expect the same three" is the same clause as "no two forms of different tasks".
  - **The solvers.** The study's hand-written NOT `<{~!`, NAND `<<{~!`, AND `<<{~{~!`, OR
    `<{~<{~}~!`, XOR `<<<{,{~>>{~<~}}~!` and EQU `<<<{,{~>>{~<~}}~{~!`, with ECHO `<!`, ORN
    `<{~<~!`, ANDN `<<{{~>~}~!` and NOR `<{~<{~}~{~!` written the same way, each compute
    their task over 4 096 random byte inputs and are credited with it alone over 10^5
    separating draws. Copiers, constant emitters, `[!+]` sprayers, `~!~!~!` and an input
    plus a constant are credited nothing over 10^5 draws, and tapes that echo an input
    ECHO alone.

  **The separating rule**, the study's, read with ECHO on the ladder. x and y are uniform
  bytes, drawn x then y for each case on `STREAM_TASK` at (seed, epoch): a run has one
  ladder, so the logic draw needs no stream of its own and moves nothing the arithmetic one
  draws. A set is redrawn until:
  - the x values are pairwise distinct, and so are the y values;
  - every form of every task expects three distinct outputs;
  - no two forms of different tasks expect the same three, which with ECHO on the ladder
    includes the study's "no form and an input";
  - no form is an input plus a constant, except ECHO's own form of that input; ECHO's x is
    refused where it is y plus a constant, so `<<-!` cannot pass for ECHO where y = x+1.

  About 73% of draws separate. The draw is bounded at `LOGIC_CASE_DRAWS` = 1 024 and then
  falls back to a fixed set, (0x5a, 0x33), (0xc6, 0x9f), (0x21, 0xe8), which a test holds to
  the rule. A test reads every clause off the inputs and the ladder directly over 10^5
  draws. Two clauses the arithmetic rule carries were measured and **not** adopted. A search
  of every program of up to 5 bytes over the ten ops, `!` and `~` (5 307 distinct output
  behaviours), against 20 000 separating draws, found credits to slots that compute their
  task on fewer than half of 512 random inputs, at most 1.4% of draws for one tape. They are
  NANDs with a byte of the tape itself: `<}~!` emits ¬(x ∧ 0x7D), which is NOT on six of x's
  eight bits, and is credited NOT wherever bits 1 and 7 of x are clear in all three cases,
  1 draw in 64. Refusing an input of 0 removed 4% of those credits, and refusing any two
  forms a constant apart 0.01%. Neither closes a cheap class. The rest is partial bitwise
  computation, which three cases of whole bytes cannot tell from the whole and which is a
  part of the task rather than something outside it, at a fraction of the task's pay.

  **No cheap tape is credited a deep rung** (measured at review, on this engine):
  - no program of up to 6 bytes over the ten ops, `!` and `~`, in front of a zero tail or
    either of two random tails (20 003, 25 375 and 20 207 distinct behaviours), is
    credited XOR or EQU on any of 4 000 separating draws;
  - among every single and double substitution, over those 12 bytes and 0x00, 0x01, 0x55
    and 0xFF, in the code of the hand-written AND, ORN, OR, ANDN and NOR solvers, none is
    ever credited XOR, and two are credited EQU on 1 draw in 4 000 (they compute it on
    6.6% of inputs);
  - in the pilot's seven logic end worlds, about 95 000 distinct tapes over 1 000 draws
    each, three tapes, each one cell of 944's rewarded world, are credited XOR, on at most
    7.2% of draws. The commonest two are masked XOR circuits: exact on five bits and OR on
    three, so 42.5% of inputs. No draw put XOR or EQU at a share of 1/10 in any world.

  A tape that computes a task on a share p of inputs is credited on about p³ of the
  draws, so it needs p above 0.79 to be credited on more than half of a decile's samples.
  For a masked circuit, that means at most one masked bit. So the last-decile median that
  H-deep reads cannot be lifted by partial solvers. A single sample can be, so readings
  taken off one sample need a persistence rule. That applies to the first epoch at which
  a rung reaches 1/10, and to the stepping-stone order read from it. The observables must
  draw fresh cases at each sample.

  **`task_floor`** (default `echo`) names the lowest rung paid, under either ladder. Rungs
  below it are still assayed, since the observables read them, and pay nothing. It must
  name a rung of the chosen ladder, `echo` … `mul` under `arith` and `echo` … `equ` under
  `logic`; with `tasks = off` only the default is accepted. ECHO is the first rung of both
  ladders, so the default pays every rung and moves nothing. `runner schema` lists the union
  of both ladders' names as its values, and validation holds a run to its own. The study's
  deep-only arm is `task_floor: xor`, Lenski's control, separating "deep features are built
  on paid parts" from "deep features are directly reachable".

  **The reward.** `pay_tasks` dispatches on `tasks`. Under `logic` each cell is paid
  `task_reward × Σ units` over its credited rungs at or above the floor, into its stock,
  capped at `energy_stock_cap`, exactly as under `arith`, and each distinct tape is assayed
  once per assay epoch. It draws only from `STREAM_TASK` and writes only stocks.

  **What it costs.** Memoised per distinct tape, one full logic assay epoch against the
  arithmetic one on the same restored 128×128 worlds (24 draws each, a loaded Mac): 1.4 to
  21.2 ms against 1.4 to 21.0 ms on the eight stored Metabolism-study worlds (at most 12%
  slower), and 8.5 to 19.6 ms against 8.4 to 18.7 ms on the pilot's eight end worlds, where
  nearly every tape emits, at most 30% slower (944's logic world, 19.6 against 15.1). At an
  assay every 8 epochs that is 0.6–5% of a soup epoch on the first and 9–50% on the second,
  whose epochs under the initiator economy run 5–14 ms.

  **The invariant.** Nothing moves at the defaults, and every pinned hash and observable
  digest stays as it was, the arithmetic reward's pin and observables included. `~` is never
  an instruction in the soup or the arithmetic assay. A reward of 0 runs no assay, so
  `tasks = logic` at `task_reward = 0` is byte for byte, stock for stock, the run with
  `tasks = off`, which a test holds under both payers. The logic reward has its own pin:
  the arithmetic reward pin's params at `tasks = logic`, an eighth of the cells given the
  NOT solver at the front of their tape and an eighth the XOR solver, seed 42, 50 epochs,
  `0xc0af_53f9_71a4_d7b4`. The task observables of the entry above read the arithmetic
  ladder alone and are null under `logic` until its own observables land. `tasks` and
  `task_floor` are dynamics, not structure: a descendant may set them. A run stored before
  `task_floor` existed carries no key, and `Lab::CanonicalParams` fills in `echo`, the
  floor it ran at, so stored runs keep their identity. `runner schema` exports the logic
  ladder (names, units, minimal NANDs), the NAND byte and the first deep rung under
  `tasks.logic`, beside the arithmetic ladder Rails already reads.

- 2026-10-01 — **The logic observables: fourteen live-only readings of the logic ladder
  (Logic, slice 2).** The logic assay of the entry above pays; these read, as the task
  observables read the arithmetic ladder, and with their shape. They are appended to
  `Metrics` with these exact keys, which the Logic pre-registration codes against:
  `logic_share_echo`, `logic_share_not`, `logic_share_nand`, `logic_share_and`,
  `logic_share_orn`, `logic_share_or`, `logic_share_andn`, `logic_share_nor`,
  `logic_share_xor`, `logic_share_equ`, `logic_capability`, `logic_capability_deep`,
  `dominant_logic_tasks` and `dominant_logic_task_count`. The `logic_` prefix keeps them
  apart from the arithmetic keys, since bitwise NOT of a byte is the arithmetic NOT.

  **What they read.** A share is the fraction of 256 cells, drawn uniformly with
  replacement, credited with its rung, on cases drawn first and then cells drawn on
  `STREAM_TASK | 3` at `(seed, epoch)`; each distinct tape in the sample is assayed once
  (`logic::Memo`). The cases are drawn fresh at every sample, keyed by `(seed, epoch)`,
  as slice 1's deep-rung check asks, so a partial solver's chance credit does not repeat
  from one sample to the next. A rung is a capability at a share of at least 1/10,
  compared in integers (26 of 256), and `logic_capability_deep` counts XOR and EQU only
  (`logic::FIRST_DEEP_TASK..`), the count H-deep reads. `dominant_logic_tasks` is the
  census's dominant tape's credit as a `u32` bitmask in `logic::LOGIC_TASKS` order, on
  cases drawn on `STREAM_TASK | 4`, 0 rather than null where that tape solves nothing.

  **When.** Whenever `tasks = logic`, rewarded or not, so the none arm carries the readings
  the full and deep-only arms do. Null with tasks `off` or `arith`, on life (including a
  life run resumed with `tasks = logic`), and on every sample recorded before them. The
  arithmetic readings stay null under `logic`, as slice 1 left them. Live-only: neither
  `oriented_census/1` nor `/2` reads them. Rails stores them in `Sample::OBSERVABLES`,
  `dominant_logic_tasks` as a flag the run page names from the logic ladder `runner schema`
  exports; a missing key draws no point and is never read as 0. The run page draws a
  ladder's charts, arithmetic or logic, only for a run with a reading of that ladder, so a
  run on neither carries no block of empty charts.

  **The invariant, pinned.** Nothing else draws on the two streams, and the readings write
  nothing. A test steps `tasks = logic, task_reward = 0` beside `tasks = off` under both
  payers, sampling every 5 epochs, and holds them to the same world hash, stocks, snapshot
  and every other observable, the arithmetic ones included, sample for sample. Every
  earlier hash and digest is unmoved; the logic readings have their own digest, split from
  the others as the task readings' is. The reward-0 control of the logic reward pin (seed
  42, 50 epochs) reads a NOT share of 0.10546875 and an XOR share of 0.07421875, one
  capability and no deep one, and a planted still world (half XOR, a quarter OR, a row of
  EQU) reads two capabilities, one deep, and a dominant tape of XOR alone (256).

  **What it costs.** Measured beside the sample on the logic pilot's seven end worlds and
  the eight stored Metabolism-study worlds (128×128, 3 300 to 16 400 cells holding a `!`,
  a loaded Mac): 0.08 to 0.73 ms a sample, one reading of 3.5 ms, which is 0.02% to 0.3% of
  a sample interval at `sample_every` 10. Relocks nothing.

- 2026-10-01 — **Logic: does a soup assemble features beyond its one-step rungs when the
  parts are paid? The `logic` sweep, pre-registered.** This is §1.3 item 16 and it adds a
  paragraph to DESIGN §1.4. The experiment is `logic` (sweep key `logic`), and its numbers
  live in `Lab::LogicReading`. It is the third slice of Logic: the assay, the NAND byte and
  `task_floor` (slice 1) and the logic observables (slice 2) are the two entries above, and
  the three deploy together, as one runner restart, once the Metabolism sweep is final.

  **The choice.** It is the orchestrator's, following the next-substrate design study of
  2026-10-01 (§3.6 of the Metabolism study: if the ladder stalls, the instruction set or the
  variation operator binds first) and the user's instruction "continue, don't stop until
  life exists". The study's diagnosis is that **the instruction set binds, not the variation
  operator**: BFF has no data op that takes two inputs, so every two-input task needs a
  counted loop, and the only loop a copier owns is its copy loop. Its landscape numbers, on
  twelve focal tapes of six rewarded Metabolism children (*measurements*, on stored worlds,
  with the real assay and detector):
  - no loop solver that still copies within **2 edits of any kind** (substitution,
    insertion, deletion, tandem duplication and their pairs: **143 M** mutants);
  - nor within **3 substitutions** in the executed code window (**112 M** mutants; the 94
    loop solvers there all spend the copy loop and none copies);
  - the nearest loop solver that copies is **5–7 substitutions** away, and **6–9** under
    length-keeping insertions, with no intermediate that computes anything new;
  - *pilot A*: indels at half of all mutation events on the Metabolism ladder gave **0 loop
    rungs in 4 of 4 worlds** over 20 000 epochs.

  Logic therefore changes the instruction set, minimally: one assay-only NAND byte and a
  ladder whose every rung is a composition of it, so the lower rungs are parts of the higher
  ones and stepping stones exist by construction (Lenski et al. 2003).

  **Metabolism's reading, final** (`lab:metabolism_report`, 2026-10-01 22:05Z: all 108
  children finished, none extinct, no settled relapse, all 54 pairs measured).
  - **H-capability: shown.** 54 pairs favour the reward, 0 the control, 0 ties
    (p = 5.6 × 10⁻¹⁷). Every one of the 18 parents splits 3–0.
  - **H-ladder: refuted.** 0 favour the reward and 0 the control, so all 54 pairs tie at zero,
    which the Metabolism entry reads as refuted. Across all 432 000 samples of the 108
    children, `task_capability_loop` never leaves 0. The only nonzero loop-task share is one
    `task_share_double` sample at 1/256.
  - **H-complexity: shown.** 18 pairs favour the reward and 1 the control, with 35 ties
    (p = 3.8 × 10⁻⁵). 10 parents lean to the reward, none to the control.
  - **Unpiloted parents.** The re-reading without them gives the same three outcomes: 42–0,
    0–0 with 42 ties, and 11–1 (p = 0.003).

  Paid computation climbed ECHO, INC and DEC in nearly every rewarded child (54, 52 and 50
  of 54). Tasks gave about half the income (0.35–0.55). Nothing climbed past the
  one-substitution rungs: exactly the stall the landscape measurements predict.

  **Two rules on seeding, locked here.**
  - The Logic sweep is **seeded only after the Metabolism reading is final**
    (`lab:metabolism_report` reads "final"), and after the runner carrying slices 1 and 2 is
    deployed: a child sampled without the logic observables is unmeasured on every test.
  - **If Metabolism's H-ladder reads shown or not shown rather than refuted**, loop rungs
    were reached despite the 5–7-substitution gap the study measured. Logic is then **not
    seeded until those loop-rung children have been read with the study's landscape tools**:
    the depth each crossed, and whether through a neutral path (study §5.3, last paragraph).
    Only then is Logic built on, or its premise revised in an entry of its own. The diagnosis
    predicts refuted, or every pair tied at zero, which the Metabolism entry reads as refuted.

  **The label.** Logic **imports an objective and a primitive**: the tasks are the
  programme's, and so is the NAND byte, which no Soup world holds as an instruction. It
  carries Metabolism's label and pooling rule unchanged: every run with `task_reward > 0` is a
  Metabolism run (`Run.metabolism`, `Lab::MetabolismReading.metabolism_run?`), so the full
  and deep-only arms are, and the none arm is fitness-free and enters this reading only as
  the paired twin. Its runs are never pooled with fitness-free arms, the sweep's page carries
  the "imports an objective" badge, and any finding resting on it carries the badge too (the
  registry spec holds both sweeps to it). **Rung 4 on Soup stays "not shown"** whatever this
  sweep reads.

  **The sweep.** A descendant sweep under the from-emerged parent rule
  (`Lab::FROM_EMERGED_PARENTS`), the rule Metabolism uses, so the same **18 parents**. Three
  bundles, each merged over the parent's params:
  - **full**: `{energy_payer: initiator, energy_influx: 1024, energy_stock_cap: 65536,
    steal_amount: 0, tasks: logic, task_every: 8, task_reward: 2048}`, Metabolism's reward
    bundle with `tasks: logic`;
  - **deep-only**: the same with `task_floor: xor`, Lenski's control: every rung below XOR is
    assayed and pays nothing;
  - **none**: the same with `task_reward: 0`.

  Seeds **2001, 2002 and 2003**, **40 000 epochs** past the parent, priority **40**:
  18 × 3 × 3 = **162 children**. Every bundle passes the engine's `Params::validate` over a
  cap-128 and a cap-256 parent. **The none arm repeats Metabolism's no-reward arm**: its
  params differ from that bundle in `tasks` alone, a reward of 0 runs no assay, and the
  engine holds `tasks = logic` at reward 0 to the run with tasks off, so for each (parent,
  seed) its world is that sweep's no-reward child's, byte for byte. It is run anyway, as the
  study planned: it is simpler than a readings pass over stored worlds, it carries the logic
  observables on every sample, and it checks the identity.

  **The readings, per child**, are Metabolism's, over its own samples at epochs above
  `parent_epoch` + **1 000**: deciles over the settled samples, lower-middle medians,
  **extinct** where the last-decile median `replicator_share` is below **0.1**, a **settled
  relapse** where it sits below 0.1 for 3 consecutive settled samples, and a key unmeasured
  with fewer than **10** numbers in its last decile. `Lab::FromEmergedHeldout` and
  `Lab::DescendantReading` are reused exactly as the Metabolism reading uses them.

  **Pairs and the tests.** A pair is a full child and a control child of the same (parent,
  seed). A pair with an extinct or unread child is excluded. Each test is a **one-sided sign
  test** over the discordant pairs: **shown** at p < **0.05**; **refuted** where the pairs
  favouring the control are at least as many as those favouring the full arm, ties
  included; **not shown** otherwise; **no measured pairs** where none is measured on both
  sides. Each carries the per-parent agreement and the leave-one-or-two-parents-out rule, as
  Metabolism's tests do, and the per-arm extinction and settled-relapse counts are printed
  beside them.
  - **H-capability-L** (full against none): the last-decile median `logic_capability`, the
    rungs, ECHO to EQU, at a share of at least 1/10. Relapsed children stay in, as in
    Metabolism's H-capability. ECHO is nearly free, so the rung-4 claim does not ride on it.
  - **H-deep**, the rung-4 question (full against none): the same test on
    `logic_capability_deep`, the count of XOR and EQU at a share of at least 1/10. With the
    none arm at zero the test needs **5** discordant pairs (p = 1/32); over 54 measured pairs
    its power is **0.64** at a rate of 0.1 per child and **0.92** at 0.15, Metabolism's
    H-ladder arithmetic. *Pilot*: 0 of 4 full worlds reached XOR or EQU in 20 000 epochs, an
    upper rate bound of 0.6, so the power at the true rate is unknown.
  - **H-stones**, Lenski's (full against deep-only): the same key. It separates "deep
    features are built on paid parts" from "deep features are directly reachable".
  - **H-complexity** (full against none): the from-emerged rise rule on
    `dominant_instruction_count`, as Metabolism reads it: pairs where both children are
    measured and neither relapsed past the window nor is extinct. It reads **"paid
    complexity rises"**, never "open-ended".

  **What each outcome means** (study §5.3):
  - **H-deep shown and H-stones shown.** A BFF soup assembles features several coordinated
    substitutions beyond any solver it holds (at least 4 in the measured window), and only
    when the parts are paid: Lenski's mechanism, in a soup. Read beside a refuted Metabolism
    H-ladder, the arithmetic plateau was the missing stepping stones of BFF's instruction
    set, not an inability to accumulate.
  - **H-deep shown, H-stones refuted.** The deep rungs are directly reachable, so the depth
    the study measured overstates the barrier. Complexity rises when paid, with or without
    parts.
  - **H-deep shown, H-stones not shown.** A soup assembles the deep rungs when the ladder is
    paid; whether it needs the paid parts is below what the pairs resolve, and nothing is
    claimed about stepping stones.
  - **H-deep refuted.** With a composable primitive and every lower rung paid, the soup
    still stops short of a feature four or more substitutions deep. The binding constraint
    is then the copier and its population, not the instruction set: the code must run before
    a copy loop that never exits, the reverse copier's mirror halves selection on a new
    feature, and a specific byte arrives at 4.8 × 10⁻⁷ per epoch. The next suspects are
    mutational supply (a rate arm) and a code region apart from the copied tape; the
    "ladder of compositions" route is closed.
  - **H-deep not shown.** The rate of deep climbing is below what 54 pairs resolve, and
    Metabolism's power arithmetic applies.

  **Two sensitivity readings**, printed beside each test, deciding no outcome:
  - **Extinct kept** (study §5.6, partial copiers read as extinct): *pilot*, 944's full
    world ended with 81% of its cells credited and its commonest solvers passing the
    detector, yet only 9% of 400 sampled cells passed, because most of its interactions are
    short in-register overwrites of kin. The extinction rule would drop such a pair. Each
    test is also read by the same rules with the replicator-share rules dropped: extinct
    children are kept, and for H-complexity relapsed children too, since a settled relapse
    is the same 0.1 line read over three samples and would drop the same pair. **The
    pre-registered reading is the one with them excluded.**
  - **Unpiloted parents**: each test re-read without the pairs of the four parents the
    study's pilots ran, **1007, 944, 2577 and 2700** (`PILOT_PARENTS`), as Metabolism re-reads
    its own. A test shown over the 18 parents and not over the 14 is reported as resting in
    part on the piloted parents.

  **Descriptive only**, printed per child and per arm, tested nowhere:
  - **the first own epoch each rung reaches 1/10**, and so the ladder order, read over every
    own sample, the settling window included, under a **persistence rule**: a rung reaches
    1/10 at the first sample of a run of **k = 5** consecutive own samples at a share of at
    least 1/10 (`PERSISTENCE_RUN`); a sample that does not carry the share breaks the run.
    *Why 5.* #283's review showed that a tape computing a rung on a share p of inputs is
    credited on about p³ of the draws, and the logic observables draw fresh cases at every
    sample, so samples trip independently. The commonest masked XOR circuit it found
    (p = 0.425, so p³ ≈ 0.077; 7.2% of draws measured) trips a sample with q ≈ 0.077
    wherever it holds a tenth of the world, since every cell of a sample is read on that
    sample's one case set. A child has about 4 000 own samples (40 000 epochs at the
    default `sample_every` of 10), so the expected number of chance runs of k samples is
    about n·qᵏ: **1.8** at k = 3, **0.14** at k = 4, **0.011** at k = 5. k = 3 would make a
    false "reach" likely in any world dominated by such a circuit; 5 brings it to about 1 in
    90 such worlds. A genuine rung is still dated at the first sample of its run; the rule
    misses only one that never holds 1/10 over five samples running (40 epochs), where the
    pilot's rungs arrived 500 epochs or more apart.
    The last-decile medians the tests read need no such rule: a rung credited on more than
    half of a decile's samples needs p above 0.79, at most one masked bit;
  - **Lenski's stepping stones**: whether a child whose world reached a deep rung had OR,
    ANDN or NOR at 1/10, under the same persistence rule, at or before the first sample at
    which a deep rung did; per arm, the deep children and those through a stepping stone, so
    "only in worlds already holding OR, ANDN or NOR" reads as the two counts being equal;
  - `dominant_logic_tasks` (the commonest mask of the last decile, the smaller on a tie),
    `dominant_logic_task_count`, `replicator_share` and `copy_latency` (last-decile medians);
  - **the share of income from tasks**, estimated as Metabolism estimates it, over the paid
    rungs alone, those at or above the child's `task_floor`, with each rung's units from
    `runner schema`'s logic ladder; an estimate, since it ignores the stock cap;
  - **per child, the substitution distance** from its parent's commonest copier to its
    deepest solver, measured later with the study's landscape tool on the stored end worlds.
    It is descriptive and not part of the reading's code.

  **What was seen before writing**, all of it the design study's *pilot* on a throwaway copy
  of the engine (`c0cb7ba` with the NAND byte and the logic ladder added; seed 1, 20 000
  epochs from each parent's epoch-20 000 world, the Metabolism economy) — not the merged
  engine, and not findings:
  - *Pilot B's climbs.* **1007** reached NOT and NAND (2 000 epochs), then ORN (7 500), OR
    (8 500) and NOR (9 500); **944** reached NOT (3 000), ORN (14 500), NAND (15 000), AND
    (15 500) and ANDN (16 500); **2577 and 2700 climbed nothing** (at most 2 and 9 cells).
    The credits are genuine: each world's commonest credited tape computes its rung on
    98.8–100% of 4 000 random inputs and is credited on 194–200 of 200 fresh case sets.
  - **XOR and EQU appeared in 0 of 4 worlds.**
  - *The controls.* The deep-only arm (floor at OR in the pilot) on 1007 and 944 and the
    no-reward arm on 1007 **climbed nothing**: at most 241 cells credited NOT and 38 NAND in
    1007's deep-only world, 8 and 1 in 944's, 248 and 51 in 1007's no-reward world, and 2 or
    fewer with anything else.
  - *The depth of each rung* (study §5.1, exhaustive over the 13 values plus `~`, 6 case
    sets, the detector for "replicating"): from evolved ORN solvers OR, NOR and ANDN are one
    substitution away (10–14 replicating single mutants), and from an evolved NAND solver AND
    is (58); XOR and EQU are reached by **no** single or double substitution of any evolved
    solver measured (≈ 6 M double mutants) and by no triple in the first 56 bytes (71.2 M
    mutants of 1007's NOR solver, 48 credited on one case set and 0 on all six; 72.3 M of
    944's ANDN solver, 0). Within that window XOR and EQU are at least four substitutions
    beyond the solvers measured, which is why the deep rungs are XOR and EQU alone and NOT
    through NOR are capability.
  - *#283's false-credit check* (on the merged assay): no program of up to 6 bytes is
    credited XOR or EQU on any of 4 000 separating draws; no single or double substitution of
    the hand-written AND to NOR solvers is ever credited XOR, and two are credited EQU on 1
    draw in 4 000; in the pilot's seven end worlds three tapes, each one cell, are credited
    XOR on at most 7.2% of draws, masked circuits exact on five bits. Partial bitwise
    computation is credited at a fraction of the task's pay and cannot lift a last-decile
    median; the persistence rule above is what keeps it from lifting a first epoch.
  - The pilot's worlds are **four of this sweep's parents**, so the reading is not held out
    from them; hence the unpiloted re-reading.

  **When it is read.** The reading is **final** when every child of every qualifying parent
  has finished (`Experiments::DescendantSweepSettledService`); before that,
  `lab:logic_report` and the sweep's page label it **interim**, and nothing is claimed from
  it. **Cost** (study §5.5), from Metabolism's finished children at cap 128: about 2 000 s a
  full child (1 650–2 520) and 1 420 s a none child (1 230–1 740), about 1 660 s a deep-only
  child (1.17 × none, the assay without the pay), and 1.3 × each at cap 256: 3 × (11 × 5 080 + 7 × 6 600) ≈ 306 000 run-seconds, about 85 run-hours or **about
  7 hours** of the mini-pc's 12 slots. It is interim until the first finished children's
  `compute_seconds` replace it.

  **What is not claimed.** The substrate **imports an objective and a primitive**: whatever
  rises was paid for by tasks the programme chose, computed with a byte the programme added,
  and says nothing about fitness-free emergence or about Soup's rung 4. The **ladder is
  finite**: EQU is its top, so "complexity" here is at most five NANDs deep. It is **one
  substrate**, one budget, three correlated children per parent, and four of its parents
  were piloted. A shown result is **a mechanism** — paid parts let a soup assemble a deeper
  feature — **not open-endedness**. The design study's §5.4 numbered this sweep's slices; it
  is item 16 of DESIGN §1.3, after Metabolism's 15.

- 2026-10-02 — **The Metabolism finding states its claim: paid to compute, replicators take
  the one-step tasks and stop there.** Sweep 15 (`metabolism`, entry of 2026-10-01,
  "Metabolism: a second, labelled substrate that imports an objective") is final: all 108
  children of its 18 parents finished. It is read here as registered, on the lab
  (`lab:metabolism_report`, 2026-10-01 22:05Z, "metabolism reading, final (Metabolism:
  imports an objective)").

  | arm | children | finished | settled relapses | extinct | capability measured | reached a loop task | stepping stone | complexity survivors | rises |
  |---|---|---|---|---|---|---|---|---|---|
  | reward | 54 | 54 | 0 | 0 | 54 | 0 | 0 | 54 | 18 |
  | no reward | 54 | 54 | 0 | 0 | 54 | 0 | 0 | 54 | 1 |

  | hypothesis | pairs | favour reward | favour twin | ties | p | outcome | without the piloted parents |
  |---|---|---|---|---|---|---|---|
  | H-capability | 54 | 54 | 0 | 0 | 5.55e-17 | shown | 42 to 0, p = 2.27e-13, shown |
  | H-ladder | 54 | 0 | 0 | 54 | — | refuted | 0 to 0, 42 ties, refuted |
  | H-complexity | 54 | 18 | 1 | 35 | 3.81e-05 | shown | 11 to 1, 30 ties, p = 0.00317, shown |

  No pair was excluded: no child is extinct and none relapsed. The reading on the piloted
  parents decides nothing, and it changes no outcome.

  **Per parent.** H-capability: all 18 parents go 3 to 0. H-ladder: all 18 tie 3 times.
  H-complexity: 10 parents lean to the reward (944 at 2 to 1, 2577 at 3 to 0, the rest 2 or
  1 to 0 with ties), 8 tie throughout, and none leans to the twin. The one pair favouring the
  twin is parent 944's at seed 2003: the twin, run 4578, rises, and its reward child reads
  mixed.

  **The leave-out.** The entry above takes the from-emerged reading's
  leave-one-or-two-parents-out rule (clarification 5): on a shown test, list every minimal
  set of one or two parents whose pairs, left out, bring p to 0.05 or above. The reading
  service already applies it — `Lab::DescendantReading::Comparison#carried_by`, the report's
  `carried_by` column, the sweep page's "Carried by parents" line — and prints "—" for both
  shown tests: no set carries either. So no row was missing and the service is unchanged.
  Re-derived from the per-parent table for the record: H-capability left without any two
  parents reads 48 to 0; H-complexity's hardest single leave-out is parent 2577, 15 to 1
  (p = 0.00026), and its hardest pair is 2577 with any 2-to-0 parent (950, 1007, 1029, 1089
  or 2771), 13 to 1 (p = 0.00092); 2577 with 2590 reads 14 to 1 (p = 0.00049).

  **Descriptive**, from the report's per-child rows. A task's line is a share of 0.1 at any
  own sample, the settling window included; epochs are the children's own (a child runs
  20 000 → 60 000):

  | task | reward: children | median first epoch | no reward: children | median first epoch |
  |---|---|---|---|---|
  | ECHO | 54 | 20 750 | 27 | 24 910 |
  | INC | 52 | 22 060 | 1 | 44 120 |
  | DEC | 50 | 22 550 | 0 | — |
  | ADD, SUB, NOT, DOUBLE, MUL | 0 | — | 0 | — |

  The median paid world took ECHO about 750 epochs after descent, and INC and DEC about
  1 300 and 1 800 epochs after that. At the end of the run (last-decile medians) every reward
  child holds 2 or 3 tasks at a tenth of its world (40 at 3, 14 at 2) and every twin 0, but
  for run 4679 at 1. The reward children's dominant tapes are credited 3 tasks in 34, 2 in
  19 and 1 in 1, the twins' none. No child reached a loop task, so no stepping stone was
  read in either arm. The estimated share of a reward cell's income from tasks averages
  0.498 (0.350 to 0.550). A read-only count over the stored samples on the lab found
  `task_capability_loop` at 0 in all 432 000 samples of the 108 children, and a nonzero
  loop-task share in one sample only: `task_share_double` at 1/256.

  **The claim**, finding `paid-computation-stops-at-one-step-tasks`, "Paid to compute,
  replicators take the one-step tasks and stop there": when computation pays, BFF copiers
  take ECHO, INC and DEC, the tasks one substitution of a copier computes, and go no further.
  H-ladder is refuted on ties throughout, which the entry above reads "as strongly as the
  power below allows". The test needed 5 discordant pairs; 0 loop children in 54 reward
  children puts a two-sided 95% upper bound of 0.066 on the rate per child over this budget,
  against the pilot's 0.34. H-complexity is shown and reads, as registered, "paid complexity
  rises", never "open-ended": mirroring a solver and stacking one-step tasks adds executed
  instructions without a loop.

  **Registry status `negative`.** The sweep was registered to answer one rung-4 question,
  H-ladder, and the sweep finished without the effect, which is the registry's `negative`.
  This follows `complexity-from-an-emerged-start` and `lineages-after-emergence`: in both,
  the headline was not there, and the tests that held beside it are stated on the page
  without lifting the status. The from-emerged sweep split its shown rung-3 test into a
  `published` finding of its own because that test answered a rung's question. Neither shown
  test here does. H-capability is the pilot's predicted manipulation check, that pay buys the
  cheap tasks. H-complexity is registered to read only "paid complexity rises" inside an
  imported objective. So they stay in this finding, named in its title's first half. It
  carries `imports_objective: true`, and with it the badge and the note that rung 4 on Soup
  is unaffected.

  **What the refutation points at.** The entry above names two suspects if H-ladder is
  refuted: the instruction set and the substitution-only mutation operator. The design
  study's landscape measurement, recorded in "The logic assay, the NAND op `~` and
  `task_floor`" (2026-10-01) and restated in the Logic pre-registration, separates them. BFF has no two-input data op. The nearest loop
  solver that still copies is 5–7 coordinated substitutions from any evolved solver
  measured, and no partial kernel on the way computes anything rewardable. Indels do not
  shorten the path. So the instruction set holds the ladder at one substitution, and Logic
  (DESIGN §1.3 item 16), which imports the NAND primitive with an objective, is the next
  question. Rung 4 on Soup stays "not shown".

  **The page** renders the tests, their parent leanings, the leave-out, the re-reading
  without the piloted parents and the descriptive ladder at render time, through
  `Findings::Metabolism` over `Experiments::MetabolismReadingService`'s report, the reading
  the sweep page draws, and includes that page's section. The numbers the page hand-types
  are the registry summary's, which match the report, the lab's sample count above and the
  bound derived from it.
  DESIGN §1.3 item 15 gains a result line. Nothing about the engine, the rules or any
  observable moves.
- 2026-10-02 — **The stack NAND: `logic_nand`, `in_place` or `stack` (Meta-stack, slice A).**
  "Meta-stack" is the next bet after Logic: the metabolism tape of the next-substrate design
  study, read by the logic assay with a NAND that keeps its operands. This is its first
  engine slice, the NAND alone. The metabolism tape is a sibling slice, and the observables
  follow. Nothing here deploys until the Logic sweep reads and the sibling slices land. The
  sweep and its pre-registration come after the Logic reading, in their own entry, before
  any of its runs is seeded. Nothing is relocked.

  **What is imported, named honestly.** Logic imports an objective and a primitive. This
  slice adds a **choice of the primitive's semantics, made because it lets the deep rungs
  come in the pilot**. `~` is assay-only and was new in Logic, so what it writes was ours to
  choose. A follow-up to the design study (2026-10-02, §7, a scratch study outside the
  repository) tried seven semantics on a throwaway copy of the engine. Every number below is
  *pilot*, from that copy and the stored worlds of 1007's pilot, not a finding:
  - five semantics (into h0+1, into h1, an accumulator, a fixed scratch cell, into h0−1)
    left XOR and EQU where they were. No program of ≤ 11 bytes (≤ 10 for the accumulator)
    computes either under any of them, they stay ≥ 4 substitutions from every minimal and
    evolved lower-rung solver (0 deep among 2.5–3.2 million mutants per start, as under the
    stack NAND from the same starts), and no pilot of "into h0−1" made a deep rung;
  - the stack NAND, "into h0−1, and head0 follows", brings the shortest known XOR from 17
    bytes to 13. On a 32-byte metabolism tape seeded from each cell's own first 32 tape bytes,
    at the instruction-set mutation rate × 32, over 20 000 epochs, **2 of 3 seeds** held XOR
    and/or EQU at a tenth of the world: seed 2001 both from epoch 4 000, at up to 8 078
    deep cells; seed 2003 EQU from 14 500, at up to 8 434;
  - the same start under today's in-place NAND made no deep rung, nor did any of 8
    metabolism-tape arms with it; with the rungs below XOR unpaid (`task_floor: xor`) the
    stack climbed nothing past ECHO; and on the woven tape, with no metabolism tape, it
    re-climbed to NOR and made no deep rung.

  The stack NAND meets the study's ask by moving the depth, not by keeping it. From the
  forms the soup holds before a deep rung, XOR and EQU are still ≥ 3–4 substitutions away,
  through credit losses. The soup then evolves loop-shaped ORN, ANDN and OR solvers, each
  **one** substitution below XOR or EQU, and takes that step: the deep rungs are assembled
  from paid parts, Lenski's mechanism. A deep rung under `stack` is therefore not by itself
  a multi-step crossing, and the Meta-stack pre-registration must read it with the
  per-child substitution distance and the deep-only control, as the study's §7.6 lays out.

  **The semantics** (DESIGN §1.1, "The stack NAND"). At `stack`, `~` in the logic assay
  computes `¬(B[head0] ∧ B[head1])`, writes it to `B[head0 − 1]` (wrapping from byte 0 to
  the last byte of the assay buffer, as `<` does), and moves head0 onto it. Both operands
  are kept, and a chain of NANDs stacks its results leftward into the zero half of the
  buffer, which is what lets a later NAND read an earlier one's result without a copy.
  `in_place`, the default, is the NAND of the logic assay entry, so every earlier run and
  every pin is unchanged.
  - **Only `tasks = logic` accepts `stack`** (`ParamError::LogicNandWithoutLogic`):
    elsewhere `~` is never an instruction, and a parameter must never be silently inert.
    The default is accepted everywhere. An unpaid logic run may set it, since its
    observables read the ladder.
  - **It is dynamics, not structure**: it moves no byte of a world, so a descendant may
    set it. A run stored before it existed carries no key, and `Lab::CanonicalParams` fills
    in `in_place`, the NAND it ran, so stored runs keep their identity.
  - **The soup and the arithmetic assay are untouched.** `~` stays a no-op there.
  - **The observables read the run's own NAND.** `pay_tasks`, the logic shares and the
    dominant tape's logic credit all assay with `logic_nand`, through `logic::assay_on` and
    `logic::Memo`, so a stack run's readings are read on the machine it was paid on.

  **The dispatch: a mode on `AssayOps`, compiled in.** `AssayOps` gains `EmitStackNand`
  beside `Emit` and `EmitNand`, and `LogicNand::assay_ops` maps the parameter onto it.
  `bff::execute`'s third compile-time switch widens from the bool `NAND_ON` to a `u8`
  `NAND_MODE`: off, in place or stack. A `u8`, because a const generic cannot yet be an
  enum. `AssayOps` is already what `run_emitting` takes to choose the assay's machine, so
  the mode rides it and no caller's signature grows. A compile-time switch, not a runtime
  flag, so the soup's and the arithmetic assay's loops compile without any test of it, as
  they did; the stack's only cost is one head move inside the NAND arm.
  - **The cycle skip stays exact.** The write marks the buffer changed only where it
    changes a byte. The head move changes none, and needs no mark: the recurrence compares
    the heads at every jump back.
  - **A lap holding `~` is never replayed**, under either NAND: a lap's beats record no
    NAND, so `Laps::note` stops at one, as it stops at an emit.

  **The ladder, re-proved under `stack`.** An exhaustive search of every program of up to
  9 bytes over `<>{},~!`, on 6 separating draws, gives the shortest program of each rung
  below XOR: NOT `<{~!` (4 bytes), NAND `<<{~!` (5), AND `{{<~~!` (6), ORN `<<{~~!` (6), OR
  `{,~<~~!` (7), ANDN `{,~{~~!` (7) and NOR `{,~{~>~~!` (9). The same lengths as the study's
  search, which padded to 16 bytes. No XOR or EQU program is that short. XOR is the
  study's 13-byte `<<{~~{{>>~{~!`, the four-NAND circuit, and EQU the same with one more
  NAND, `<<{~~{{>>~{~~!`. With ECHO `<!`, each computes its task over 4 096 random byte
  inputs and is credited with it alone over 10^5 separating draws (`STACK_SOLVERS`).
  - **One solver computes three rungs.** The pilot's evolved deep solver,
    `{<<[~><~{~{!]`, is a loop that stacks three NANDs a lap while head1 trails onto what
    earlier laps wrote, and emits ¬y, XOR, ¬y and EQU on all but 5 of the 65 536 inputs, all
    five with x the emit byte 0x21 or its complement. It is credited NOT, XOR and EQU and
    nothing else on every one of 10^5 draws, and with all three on 97% of them. A lap that
    leaves a zero under head0 ends the loop early (y = 0x00, y = 0xff or x = y), so it does
    not reach all three on every draw. That is the fan-out the stack buys: intermediates kept
    on the stack and read again on a later lap.
  - **No cheap tape is credited a deep rung**, #283's search re-run under `stack`:
    - every program of up to 6 bytes over the ten ops, `!` and `~`, in front of a zero
      tail and two random tails of 24 bytes (18 078, 20 914 and 18 273 distinct behaviours),
      is credited XOR or EQU on none of 4 000 separating draws;
    - every single and double substitution, over those 12 bytes and 0x00, 0x01, 0x55 and
      0xFF, in the code of the stack NOT, NAND, AND, ORN, OR, ANDN and NOR solvers and the
      3 bytes after it (4 830–15 030 distinct mutants each), is credited XOR or EQU on none
      of 4 000 draws.

  **The invariant.** Nothing moves at the default. Every pinned hash and observable digest
  stays as it was, the logic reward's pin included. The stack has its own pin: the logic
  reward pin's params at `logic_nand = stack`, its layout planted with the stack NOT and XOR
  solvers, seed 42, 50 epochs, `0x5fe2_0698_d6b1_b3af`. The same tapes under the in-place
  NAND end elsewhere, at a reward of 0 the stack run is the run with tasks off, and a run
  under the stack reward is deterministic under both payers. Each
  NAND pays its own XOR solver 8 units at `task_floor: xor` and the other's nothing. The
  interpreter's equivalence tests hold the stack run, skipping or not, to a stepper written
  by the book over 10^5 random assay buffers dense in `~`, `!` and loops, with
  whole-byte inputs, beside the in-place run's own. Pairs that carry neither byte still run
  as the soup's interpreter runs them under all three assay machines.
- 2026-10-02 — **The metabolism tape (Meta-stack, slice B).** "Meta-stack" is a variant of
  Logic. It keeps Logic's economy, assay, ladder and reward, and moves what the assay reads
  off the replicating tape onto a second tape the soup never executes. This is the slice
  that builds that tape: its parameters, its state, its inheritance, its mutation, its pay
  and its snapshot section. A sibling slice adds the stack-like NAND as a `logic_nand`
  parameter, the observables slice points the logic readings at this tape, and the sweep
  and its pre-registration follow in their own entry, before any of its runs is seeded.
  Nothing is relocked.

  **Why a second tape.** A design study (2026-10-02, a scratch study outside the
  repository; its numbers are *pilot* numbers, from a throwaway copy of the engine at
  `dba2c96` and the stored end worlds of two Logic pilot continuations, not findings) asked
  what holds Logic's soups below XOR and EQU. In both pilot worlds the evolved circuit is
  the copy loop: every byte the assay executes is also executed by a copy loop in one
  orientation or the other, so no byte is free. The one deep rung the landscape offered,
  EQU three substitutions from a NOR solver, passes through intermediates that all stop
  copying and copies with a one-byte rotation, and four planted blocks of it were gone
  within 500 epochs. The metabolism tape takes the copier out of every such path, and lets
  the computing region take a rate the replicating tape cannot: × 16 on the soup melted the
  copiers.
  - *Pilot*, 32 bytes, instruction-set draws at × 32, today's in-place NAND, seeded with
    zeros, from 1007's end world: ECHO at a tenth by 500 epochs, NOT and ORN by 1 500, OR
    and NOR by 2 000, ANDN by 2 500, then no XOR or EQU, not even on one case set, in the
    17 500 epochs that followed. Seven other metabolism-tape arms under today's NAND stalled
    in the same place.
  - *Pilot*, the same seeded from each cell's own first 32 tape bytes under the stack-like
    NAND: XOR and EQU at a tenth in 2 of 3 seeds within 20 000 epochs (up to 8 434 cells),
    and nothing past ECHO with every rung below XOR unpaid.
  - *Pilot*: under uniform draws the replicating tape's detector share ended at 0.53–0.66,
    from 0.92. Paid on another tape, the copier is no longer tied to the pay.

  **The parameters** (DESIGN §1.1, "The metabolism tape"). `meta_len` (0–1 024 bytes, `0`
  = off, the default; the sweep's 32), `meta_rate` (per byte per epoch; default 32/8192,
  the study's × 32 on the Logic sweep's 1/8192), `meta_draw` (`uniform`, the default, or
  `isa`) and `meta_seed` (`zeros`, the default, or `own_tape`). They are dynamics, so a
  descendant may set them. A length needs `tasks = logic`, paid or not, since the logic
  assay is its only reader; any other `meta_*` value away from its default with no length
  is refused as silently inert. The defaults of the three settings are judgement calls: the
  study's rate, so a length alone gives its design rate; the plainest draw, the one the
  soup's own mutation makes; and the empty seed of the study's §5 design. The sweep names
  all four explicitly.

  **The state.** Each cell's tape sits in one flat array beside the cells, `meta_len` bytes
  per cell. It is hashed after the stocks (a world without it hashes as it always did),
  never rendered and never executed.
  - **Inheritance**, the pilot's rule exactly (its `STATS` tally of near copies): after
    every interaction, if the partner's tape changed and at least 9 in 10 of the positions
    it shares with the tape the initiator arrived with hold the initiator's byte, read
    forward from byte zero or with the initiator's tape reversed, the initiator's metabolism
    tape is copied whole onto the partner's. The positions shared are the shorter tape's
    length. Only the partner inherits: it is the tape a copier writes into, as the copy
    rates read it. The comparison draws nothing.
  - **Mutation**, after the soup's own, on `STREAM_META` (`0x4d45_5441_0000_0000`, "META",
    keyed by seed and epoch like every stream): each byte in cell order is offered one
    `chance` at `meta_rate`, and a hit is redrawn by `meta_draw`. `isa` picks one of 14 at
    1/14: the ten ops, `!`, `~`, 0, or the 243 other bytes, drawn uniformly by rejection.
    The structure parameters do not lean this rate.
  - **Pay.** `pay_tasks` reads each cell's metabolism tape in place of its tape. The
    observables still read the replicating tape until their slice moves them; the engine's
    one switch for "the tape the logic assay reads" is `World::assayed_tape`.
  - **Switching on.** At epoch 0 of a founding run, after the initial bytes are drawn, or
    at descent from a parent without tapes: zeros, or each cell's first `meta_len` live
    bytes, zero padded past a shorter tape. A parent whose tapes have the child's length
    hands them on, so a child under its parent's params and seed is the parent continued;
    a child of another length switches its own on; a child without them drops them.

  **Reward 0.** A reward of 0 runs no assay, so the tape is never read; it still mutates
  and is still inherited, on a stream and a rule that touch nothing else. Pinned: over 30
  epochs, under either draw, every byte, stock and lineage of a reward-0 metabolism-tape
  world equals the tape-off logic world's and the tasks-off world's, its hash with the
  tapes left out equals theirs, and the tapes moved. So the Logic sweep's none child of a
  (parent, seed) is a metabolism-tape none child's twin byte for byte, which is why the
  sweep needs no none arm of its own. A reward-0 run that sets the tape is still a distinct
  arm by canonical params, and its world hash includes the tapes.

  **The snapshot.** Versions 9, 10 and 11 are 6, 7 and 8 with a metabolism section: two
  header fields after the relative block's length (the compressed payload's length and the
  tape length per cell) and the payload between the last older payload and the relative
  block. Stripping them gives the older container byte for byte, a world without tapes
  writes 6–8 as before, and a blob of an older version reads as a world without tapes. A
  resume holds the tapes to the params, as it holds the stocks: a blob without them under
  params with them, the reverse, or another length is refused. The runner's bound on a
  snapshot answer now counts `meta_len` per cell; the app's 64 MiB cap is far above a
  128×128 world with 32-byte tapes.

  **Cost**, measured on the restored Logic pilot end worlds of 1007 and 944 (cap 128,
  seed 2001, 400 epochs, the four arms run side by side on a loaded Mac): at a reward of 0,
  which isolates the bookkeeping, the tape adds 10–17% per epoch (1007: 13.5 → 15.8 and
  10.0 → 11.1 s per 1 000 epochs over two readings; 944: 9.2 → 10.0 and 7.5 → 8.5). With
  the reward on, the metabolism-tape world ran at 0.6 and 0.9 times the Logic full world's
  time (1007: 23.5 → 14.2; 944: 12.7 → 11.4), since a restored world's solvers stop being
  paid and its cells initiate less until a tape climbs.

  **The import.** The world, not the program, copies the metabolism tape: on a near copy
  of the replicating tape, the engine moves the tape whole. Meta-stack therefore imports an
  objective, a primitive **and a hereditary channel**. It carries Metabolism's label and
  pooling rule, and rung 4 on Soup stays "not shown" whatever it reads.

  **Tests.** Every existing pin and digest is unmoved at `meta_len` 0, where nothing is
  allocated and the snapshot keeps its old version. New: the reward-0 identity above; a
  pin of the rewarded bundle and of its reward-0 arm; the assay paying the metabolism tape
  and not the tape; inheritance on exact, near (9 in 10) and partial (8 in 10) copies,
  forward and reversed, on ragged pairs, and through a live copier colony; the mutation
  rate and the `isa` draw's fourteenths; determinism with a mid-run resume under both
  draws and seeds; the snapshot round trip in every payload shape, the stripping property,
  the refusals; and descent under `own_tape`, `zeros`, a carried parent and a dropped one.
- 2026-10-02 — **The logic observables read the metabolism tape (Meta-stack, slice C).** The
  observables slice of Meta-stack. Slice B left the logic readings on the replicating tape
  while the assay paid the metabolism tape; this slice points them at the tape that is paid,
  and adds three readings of the tape itself. Nothing is relocked, and every reading of a run
  without the tape is what it was.

  **What moves.** Where a run carries a metabolism tape, `logic_share_*`,
  `logic_capability` and `logic_capability_deep` assay each sampled cell's metabolism tape
  through `World::assayed_tape`, the one switch the payment reads, on the same stream and
  draws (`STREAM_TASK | 3`). `dominant_logic_tasks` and its count read the most common
  metabolism tape, not the census's dominant replicating tape: counted over the `meta_len`
  chunks with `metrics::ranked_tapes`, so a tie goes to the lower tape in byte order, the
  rule the census already breaks ties by, on cases of `STREAM_TASK | 4` as before. A
  descriptive reading of the replicating tape's logic would otherwise sit under the key the
  pre-registration reads, beside a payment that never looks at it.

  **Three new keys, live-only.**
  - `meta_inherit_rate`: inherit events over interactions, counted at the `inherit_meta`
    call in the pass that counts `copy_rate`, so over the same interactions of the epoch
    before the sample. The study's §5.3 lists it as descriptive. Null, not 0, where that
    epoch ran no interaction or none has run since a resume, unlike `copy_rate`, which
    reads 0 there: a share of nothing is no reading, and on an energy-starved world it is
    common. On the restored 1007, 944 and m6 worlds at the study's bundle, in the 300
    epochs after descent, 70 of 90 sampled epochs ran no interaction and the rest ran 1 to
    60 of 16 384 cells, where the rate read up to 1.0 beside a `copy_rate` of 0. No floor
    on the count is set: any floor is arbitrary, and a small count is a true, noisy share,
    so the reading is meant over a window. The near copy that passes a tape on is looser
    than `copy_rate`'s exact copy and blind to orientation, so the rate can sit far above
    the copy rates.
  - `meta_diversity`: how many distinct metabolism tapes the whole world holds, not the 256
    sampled cells the brief allowed. A judgement call: the whole-world count comes free with
    the ranking that names the dominant tape, draws nothing, and is `distinct_tapes`' own
    definition on the other tape, where a 256-cell count saturates at 256 on a world as
    diverse as the restored pilot worlds (13 000–16 300 distinct tapes of 16 384).
  - `logic_capability_replicating`: `logic_capability` read on the replicating tapes, on
    cells and cases of `STREAM_TASK | 5`, so the reading can see whether the woven copier
    still computes once it is no longer paid. One more 256-cell tally per sample.
  Null wherever the run carries no tape. None writes anything; the first two draw nothing,
  and the third draws on a stream nothing else draws on.

  **Cost**, on the restored Logic pilot end worlds of 1007 and 944 and the m6 woven world
  (128×128, descended to a 32-byte `own_tape` tape at `isa` × 32 under the stack NAND, 210
  epochs on, on a loaded Mac): a metabolism-tape world's sample took 1.2–4.6 ms more than the
  tape-off world's 45–55 ms, at most 4% of a 10-epoch sample interval.

  **Tests.** The three keys null without the tape on every substrate and ladder, and every
  earlier pin and digest unmoved. On hand-built worlds under both NANDs, with each NAND's
  own solvers planted on the metabolism tapes and NOT on the replicating ones: the shares,
  the capabilities and the dominant bitmask read the metabolism tapes, the replicating
  capability reads NOT, and the diversity counts the planted tapes; the stack XOR is deep
  under `stack` and nothing under `in_place`. The dominant reading names the most common
  metabolism tape and breaks a tie by byte order whichever rows hold which. The inherit rate
  through a live copier colony. A new digest pin, split from the logic one, of the
  rewarded bundle and its reward-0 arm (equal but for the inherit rate, since neither passes
  a tape on in 50 epochs and the reward-0 arm cannot afford to interact before the sample),
  and of a copying colony under the stack NAND, paid and unpaid, whose readings differ. The
  pay under the metabolism tape and the stack NAND together: the stack XOR solver on a
  metabolism tape is paid XOR under `stack` alone. Sampling every epoch moves no byte, stock or lineage; a sample reads the same
  twice and after a resume, but for the inherit rate, which needs an epoch.

  **Rails.** `Sample::OBSERVABLES` gains the three keys; the run page charts them only for
  a run that has a reading of them, as it gates each ladder; a sample without them draws no
  point; the glossary defines them. They are live-only: no `oriented_census` version reads
  them.
- 2026-10-02 — **Meta-stack: does a soup assemble the deep rungs from paid parts on a
  metabolism tape read with a stack NAND? The `meta_stack` sweep, pre-registered.** This is
  §1.3 item 17 and it adds a paragraph to DESIGN §1.4. The experiment is `meta-stack` (sweep
  key `meta_stack`), and its numbers live in `Lab::MetaStackReading`. It is the last slice of
  Meta-stack: the stack NAND (slice A), the metabolism tape (slice B) and the observables that
  read the tape (slice C) are the entries above, and the four deploy together, as one runner
  restart, after the Logic sweep reads. Nothing is relocked.

  **The choice.** It is the orchestrator's, under the user's instruction "continue, don't stop
  until life exists", following a design study of 2026-10-02 (a scratch study outside the
  repository; every number below is *pilot* or a measurement on stored pilot worlds, from a
  throwaway copy of the engine at `dba2c96`, not a finding). Its diagnosis:
  - **The valley binds, not supply.** A specific substitution lands somewhere in a 16 384-cell
    world about once every **128 epochs** (u = 4.8 × 10⁻⁷ per cell per epoch), and the one-step
    rungs came on schedule, 500–1 000 epochs apart once the rung below was common. XOR and EQU
    are the only rungs that read an input twice, and they sit behind **≥ 3–4 coordinated
    substitutions** through intermediates that stop copying or lose credit. On Weissman et
    al.'s (2009) valley arithmetic the expected wait for K = 4 with intermediates costing a
    quarter of a cell's income is **3 × 10¹⁴ epochs** or more, and **3.4 × 10⁵** even on a
    neutral plateau with ten paths a step, 8–15 times the horizon. Bringing it to 40 000
    epochs needs the rate × 2.8–3.7 on a neutral plateau and × 500 or more on a valley, and
    the copier's error threshold sits between × 8 and × 16.
  - **The landscape** (exhaustive, with the real assay and detector): in both pilot worlds
    no byte is free, **0 of 128**: every byte the assay executes is a copy loop's byte too.
    EQU is **3 substitutions** from 1007's NOR solver (94 triples credited on 6 case sets of
    886 M screened, 20 of them replicating), but every one of their singles and doubles stops
    copying, and the deep form copies with a one-byte rotation: four planted blocks were gone
    within 500 epochs. Coordinated pairs that gain a rung pass through a neutral order in
    0–53% of cases, and a free region removes the copier but not the depth: no XOR or EQU
    within 3 substitutions of any short solver, nor within 4 of the hand-written OR (303 M
    mutants).
  - **So the binding constraint is fan-out in a two-head machine whose NAND writes in
    place**: using a value twice needs a stored copy and re-aligned heads, which in the woven
    tapes only the copy loop supplies.
  - **The pilots.** *Rate arms*: × 4 and × 8 from 1007's end world made no deep rung in
    20 000 epochs, and × 16 melted the copiers (detector share 0.05 by 2 000 epochs).
    *Metabolism-tape arms* under today's NAND: the free tape climbed every read-once rung
    (seeded with zeros at × 32 instruction-set draws, ECHO by 500 epochs and NOR by 2 000) and
    no deep rung, **0 of 8** arms. *The stack NAND* on a 32-byte tape seeded from each cell's
    own tape, at × 32 instruction-set draws: XOR and/or EQU at a tenth in **2 of 3 seeds**
    within 20 000 epochs (seed 2001 from epoch 4 000, up to 8 078 cells; seed 2003 EQU from
    14 500, up to 8 434). *Deep-only*, the same with every rung below XOR unpaid: **climbed
    nothing** past ECHO. *Today's NAND on the same tape and start*: no deep rung.

  So Meta-stack tests the study's revised recommendation (its §7.6): the metabolism tape with
  the stack NAND, its deep-only control, and the tape with today's NAND as the semantics
  control, against the Logic sweep's own children.

  **Logic's reading.**
  Final (`lab:logic_report`, 2026-10-02 07:10Z). All 162 children finished. One full child is
  extinct (4755) and six full children settled into relapse; the other arms have neither.
  - **H-capability-L: shown.** 53 pairs favour the full arm, 0 the none arm (p = 1.1 × 10⁻¹⁶).
    Every parent leans to the full arm.
  - **H-deep: refuted.** All 53 pairs tie at zero. `logic_capability_deep` is 0 in every
    sample of every child.
    - XOR's largest share in any sample is 5/256 (run 4817, epoch 46 470).
    - EQU's is 1/256.
  - **H-stones: refuted.** All 53 pairs tie at zero, because no arm built a deep rung.
  - **H-complexity: not shown.** 2 pairs favour the full arm and 1 the none arm, with 45 ties
    (p = 0.5).
  - **Sensitivity readings.** The extinct-kept reading and the unpiloted re-reading give the
    same four outcomes.

  **The full arm's ladder** (children reaching each rung at 1/10 under the k = 5 rule, of 54):

  | rung | ECHO | NOT | NAND | ORN | ANDN | OR | AND | NOR | XOR | EQU |
  |---|---|---|---|---|---|---|---|---|---|---|
  | children | 54 | 52 | 37 | 44 | 32 | 23 | 14 | 19 | 0 | 0 |

  The deep-only and none arms reach ECHO in 19 children each and nothing above it. Tasks gave
  the full arm 0.59 of its income on average.

  This is the stall the deep study predicted: every read-once rung up to NOR climbs, and
  neither rung that needs an input twice comes.

  **Two rules on seeding, locked here.**
  - **(a)** Meta-stack is **seeded only after the Logic reading is final** (`lab:logic_report`
    reads "final") **and the runner carrying slices A, B and C is deployed**: a child sampled
    without the tape-reading observables is unmeasured on every test.
  - **(b)** **If Logic's H-deep reads shown**, Meta-stack is **not seeded as designed**. Deep
    rungs came on the woven tape with today's NAND, so the question moves: the study's §5.7
    path takes over — whether the deep solvers are heritable (planted back into their own
    worlds), then H-stones, then a ladder with no near top (3-input logic, read with the rise
    rule on the deepest rung held) — in an entry of its own.

  **The label.** A rewarded Meta-stack run is a Metabolism run. It imports **an objective**
  (the tasks), **a primitive** (the NAND byte), **a hereditary channel** (the world, not the
  program, copies the metabolism tape on a near copy of the replicating tape), **and a choice
  of the primitive's semantics made because it lets the deep rungs come** (study §7.6): the
  stack NAND was chosen among seven semantics because it was the one under which the pilot's
  deep rungs came. It carries Metabolism's badge and pooling rule, and rung 4 on Soup stays
  "not shown" whatever it reads.

  **The sweep.** A descendant sweep from the from-emerged sweep's 18 parents under the same
  rule (`Lab::FROM_EMERGED_PARENTS`), seeds **2001–2003**, **40 000** epochs past the parent,
  priority **40**. Three bundles, each merged over the parent's params, on top of the Logic
  full bundle (`energy_payer: initiator, energy_influx: 1024, energy_stock_cap: 65536,
  steal_amount: 0, tasks: logic, task_every: 8, task_reward: 2048`) and one tape
  (`meta_len: 32, meta_rate: 0.00390625, meta_draw: isa, meta_seed: own_tape`, all four named):
  - **meta-stack**: `logic_nand: stack`;
  - **meta-stack-deep-only**: `logic_nand: stack, task_floor: xor`, Lenski's control;
  - **meta-inplace**: `logic_nand: in_place`, the study's §5 design kept as the semantics
    control.

  **18 × 3 × 3 = 162 children.** Each bundle was run through the merged engine (`runner run`)
  over a cap-128 and a cap-256 control's params and accepted. The builder is idempotent, adds
  nothing to the Metabolism or Logic sweeps, and no child shares its canonical params with
  another child of the same (parent, seed) in any of the three sweeps.

  **Pairing, across two sweeps.** A pair is two children of the same (parent, seed). The
  twins come from the Logic sweep's own children, so no new arm is run for them: **Logic's
  none child** (reward 0, no tape) is the **no-reward twin**, since at a reward of 0 the tape
  is never read and slice B pins the world of a reward-0 tape run to the tape-off run byte for
  byte; **Logic's full child** (reward on, the woven tape assayed) is the **woven twin**.
  Logic's deep-only children are in no arm here. The arms are keyed on each child's params, its
  reward, `meta_len`, `logic_nand` and `task_floor` (`Lab::MetaStackReading.treatment_key`), not
  on the sweep it sits in.

  **The readings** are Logic's exactly, per child, over its own samples: the **settling
  window** (epochs above `parent_epoch` + 1 000), **deciles** over the settled samples and
  **lower-middle medians**; **extinct** where the last-decile median `replicator_share` — the
  detector's share, which reads the **replicating** tape — is below **0.1**, and a **settled
  relapse** where it sits below 0.1 for 3 consecutive settled samples; a key unmeasured with
  fewer than 10 numbers in its last decile. Each test is a **one-sided sign test** over the
  discordant pairs, measured where both children carry the key's last-decile median and
  neither is extinct: **shown** at p < **0.05**; **refuted** where the pairs favouring the
  control are at least as many as those favouring the treated arm, ties included; **not
  shown** otherwise; **no measured pairs** where none is measured on both sides. Each carries
  the **per-parent agreement** and the **leave-one-or-two-parents-out** rule, and two
  sensitivity readings that decide no outcome: **extinct kept** (study §5.6, partial copiers)
  and **unpiloted**, re-read without the pairs of the four parents the pilots ran, **1007,
  944, 2577 and 2700**. First epochs are read under the **persistence rule, k = 5** consecutive
  own samples at a share of at least 1/10. With slice C the logic readings of a tape run read
  its metabolism tape.

  **The tests.** All on last-decile medians.
  - **H-deep-Ms**, the rung-4 question (meta-stack against Logic none):
    `logic_capability_deep`, the count of XOR and EQU held by a tenth of the world. With the
    none arm at zero it needs **5** discordant pairs (p = 1/32). Over 54 measured pairs its
    power is **0.64** at a rate of 0.1 deep children per child, **0.92** at 0.15 and **0.99**
    at 0.2. The pilot's 2 of 3 seeds, on one world, would give a power of about 1, but one
    world bounds nothing about 18.
  - **H-stones-Ms** (meta-stack against meta-stack-deep-only): the same key, Lenski's
    control. *Pilot*: deep-only climbed nothing, 1 seed.
  - **H-stack** (meta-stack against meta-inplace): the same key. Does the NAND's semantics
    decide it? *Pilot*: 2 of 3 seeds against 0 of 1 on the same start.
  - **H-deep-M** (meta-inplace against Logic none): the same key, the study's §5 question.
    *Pilot*: 0 of 8 metabolism-tape arms with today's NAND.
  - **H-decouple** (meta-inplace against Logic full): the same key. **Kept**: §5.3 asked
    whether deep rungs come more often off the copy loop than on it, and meta-inplace is still
    the one arm that holds the NAND fixed and moves only the code region — off the copier, at
    the tape's rate and draw — so this is the only test of the tape itself against the paid
    woven twin. It reads the tape and its rate together, never the copy loop alone.
  - **H-capability-M** (meta-stack against Logic none): `logic_capability`, ECHO to EQU at a
    tenth. Relapsed children stay in, as in Logic.

  Logic's H-complexity is not a test here: its rise rule reads the dominant replicator's
  instruction count, on the replicating tape, which this sweep no longer pays; the per-arm
  complexity survivors and rises are printed descriptively.

  **What each outcome means** (study §5.4 and §7.6, adapted to the stack arms). A deep rung
  shown here is **"assembled from paid parts"** only with H-stones-Ms; no outcome is worded
  "crossed a valley".
  - **H-deep-Ms shown and H-stones-Ms shown.** On a metabolism tape read with the stack NAND,
    a soup **assembles XOR and EQU from paid parts**: Lenski's mechanism, in a soup, under
    the four imports named. It is a multi-step crossing only for the deep children whose
    substitution distance (below) is at least 2. H-stack then says whether the semantics
    decides it: shown, the result is the stack NAND's; refuted, the tape alone would have done.
  - **H-deep-Ms shown, H-stones-Ms refuted.** The deep rungs come as often when only they are
    paid: on this machine they are directly reachable, the paid parts are not needed, and the
    depth the semantics moved is no barrier.
  - **H-deep-Ms shown, H-stones-Ms not shown.** The soup assembles the deep rungs when the
    ladder is paid; whether it needs the parts is below what the pairs resolve.
  - **H-deep-Ms refuted.** The pilot's 2 of 3 does not carry to 18 worlds: even with the
    copier out of the path, Avida's per-site rate and a NAND that keeps its operands, the soup
    builds no deep rung in 40 000 epochs. Rung 4 by composition then needs a machine with
    non-destructive storage — registers, a new-substrate decision for the user — or a question
    this machine can answer: a ladder of read-once compositions without a top.
  - **H-deep-Ms not shown.** The rate of deep climbing is below what 54 pairs resolve.
  - **H-deep-M refuted** (the pilot's prediction), with H-deep-Ms shown: today's NAND climbs
    every read-once rung and none that reads twice, even off the copier at Avida's rate, so
    the binding constraint was **fan-out in a two-head machine whose NAND writes in place**,
    as a finding rather than a pilot. **H-deep-M shown**: copying and supply together were the
    constraint, and the stack NAND was not needed (H-stack then reads refuted or not shown).
  - **H-decouple shown**: deep rungs come more often on the tape, at its rate, than on the
    woven tape under the same NAND. **Refuted** with H-deep-M shown: the woven children reach
    them as often, so the tape is not needed and Logic's own reading is the result.
  - **H-capability-M shown**: the tape re-climbs the read-once ladder from its own-tape seed
    under the stack NAND. **Refuted**: the restart failed, and the deep tests read a tape that
    never climbed.

  **Reported with each deep child, locked now and measured after the sweep** with the study's
  landscape tools on the stored worlds (offline, not this reading's code). **The 6 fixed case
  sets** are the study's landscape draw, six `logic::Cases::draw` in turn off
  `rng::seeded(0xdee9, 1, 0)`, frozen as constants; a tape is credited a rung "on all 6 sets"
  where the logic assay, under the child's own instruction set and NAND, credits it on each.
  - **the substitution distance** from the child's dominant metabolism tape at the epoch the
    last lower rung to reach the line did so (its first epoch at 1/10 under k = 5, read on the
    stored world nearest at or before it) to the first deep solver (the commonest metabolism
    tape credited XOR or EQU on all 6 fixed case sets in the first stored world after the deep
    rung's first epoch). **A deep rung counts as a multi-step crossing only if that distance is
    ≥ 2**;
  - **heritability**, by planting that deep solver (its cell's replicating and metabolism
    tapes) as a 4×4 block in the centre of its own end world, with every other cell whose
    metabolism tape is credited that rung on any one of the 6 sets given the world's commonest
    metabolism tape credited it on none, under the child's params, seeds 2001–2003, 2 000
    epochs, beside an **unplanted control**: the same world with the block's metabolism tapes
    given that commonest tape too and its replicating tapes planted as before, so the two
    differ only in the block's metabolism tapes, under the same seeds. Both resume the end
    world as stored (`World::from_snapshot`). **Heritable** where, in at least **2 of the 3
    seeds**, the planted world has at least **a tenth of the world** (1 639 cells) credited
    the rung on all 6 sets at 2 000 epochs while its control, same seed, has 16 cells or
    fewer. Where any seed's control reaches the tenth, the rung re-arose from the reseeded
    tape (the stepping stones sit one substitution below the deep solvers, §7.4 of the study,
    and at `meta_rate` 1/256 with 1/14 draws a given substitution at a given site comes about
    every 3 600 cell-epochs), so heritability is reported **unresolved**, not heritable,
    whatever the other seeds read. A paid rung that is kept should get there: once
    established, a rung held a tenth within about 120 epochs in the study's arithmetic (§1.3),
    and the pilot's deep rungs went from their first cells to a tenth in 1 000–1 500 epochs;
  - **the circuit behind it**, by the study's traced stepper on x = 0x5a, y = 0x33 and the 6
    fixed case sets, **printed descriptively and tested nowhere**: the NANDs behind the
    credited output, and which values (x, y or an intermediate) two of them read. It is no
    test of depth. XOR and EQU are not read-once functions, so every NAND circuit computing
    either reads some input or intermediate in two NANDs; a read-once rung can be built by a
    circuit that does too (the stack ORN `<<{~~!` is NAND(NAND(y, x), x)); and no per-input
    rule separates them, since an XOR may fan out NOT x instead of x. What makes a deep child
    deep is its credit.

  **Descriptive only**, printed per child and per arm, tested nowhere: the first own epoch
  each rung reaches 1/10 and so the ladder order, and the stepping-stone counts, as Logic
  reads them; `meta_inherit_rate`, `meta_diversity` and `logic_capability_replicating`
  (last-decile medians); the replicating tape's `replicator_share` beside its Logic twins'
  (*pilot*: under uniform draws it ended at 0.53–0.66, from 0.92); and the share of income
  from tasks, Logic's estimate over the paid rungs, read on the metabolism tape.

  **When it is read.** Final when every child of every qualifying parent has finished, **in
  this sweep and in the Logic sweep** (`Experiments::DescendantSweepSettledService` on both);
  until then `lab:meta_stack_report` and the sweep's page label it **interim**. **Cost**
  (study §7.6): 162 children at the 47–77 s per 1 000 epochs upper bound, the pilot's tape
  children running faster than woven ones, about **5–9 hours** of the mini-pc's 12 slots;
  interim until every child has finished and its `compute_seconds` replace it.

  **What is not claimed.** The substrate imports **an objective, a primitive, a hereditary
  channel and a choice of the primitive's semantics made because it lets the deep rungs
  come**; whatever rises says nothing about fitness-free emergence or Soup's rung 4. The
  **ladder is finite**: EQU is its top. It is **one substrate**, one budget, three correlated
  children per parent, and four of its parents were piloted. A shown result is **a mechanism**
  — paid parts let a soup assemble a deeper feature on an imported tape — **not
  open-endedness**. Every constant above lives in `Lab::MetaStackReading`.

- 2026-10-02 — **The three design studies are kept in the repository, in `docs/studies/`.**
  The record cited them by summary while they lived in a session scratchpad. They are dated
  research notes, kept as written but for their scratchpad paths; every number in them is
  pilot unless an entry above says otherwise. Nothing is relocked.
  - The Metabolism entry (2026-10-01) follows `docs/studies/metabolism.md`.
  - The Logic entry (2026-10-01) follows `docs/studies/logic.md`.
  - The Meta-stack entry (2026-10-02) follows `docs/studies/meta-stack.md`; its offline
    readings (the substitution distance, heritability by planting, the circuit behind a deep
    solver) run on `research/landscape/`, the study's tools ported to the merged engine.

- 2026-10-02 — **The Logic finding states its claim: given a NAND, paid replicators climb
  every logic task that reads its inputs once, and none that needs one twice.** Sweep 16
  (`logic`, entry of 2026-10-01, "Logic: does a soup assemble features beyond its one-step
  rungs when the parts are paid?") is final: all 162 children of its 18 parents finished. It
  is read here as registered, on the lab (`lab:logic_report`, 2026-10-02 07:10Z, "logic
  reading, final (Logic: imports an objective and a primitive)"). The Meta-stack entry above
  summarises the same reading; this entry states the claim.

  | arm | children | finished | settled relapses | extinct | capability measured | reached a deep rung | stepping stone | complexity survivors | rises |
  |---|---|---|---|---|---|---|---|---|---|
  | full | 54 | 54 | 6 | 1 | 53 | 0 | 0 | 48 | 2 |
  | deep-only | 54 | 54 | 0 | 0 | 54 | 0 | 0 | 54 | 1 |
  | none | 54 | 54 | 0 | 0 | 54 | 0 | 0 | 54 | 1 |

  | hypothesis | pairs | favour full | favour control | ties | p | outcome | extinct kept | without the piloted parents |
  |---|---|---|---|---|---|---|---|---|
  | H-capability-L (against none) | 53 | 53 | 0 | 0 | 1.11e-16 | shown | 54 to 0, p = 5.55e-17, shown | 41 to 0, p = 4.55e-13, shown |
  | H-deep (against none) | 53 | 0 | 0 | 53 | — | refuted | 54 ties, refuted | 41 ties, refuted |
  | H-stones (against deep-only) | 53 | 0 | 0 | 53 | — | refuted | 54 ties, refuted | 41 ties, refuted |
  | H-complexity (against none) | 48 | 2 | 1 | 45 | 0.5 | not shown | 2 to 1, 51 ties, not shown | 2 to 0, 35 ties, p = 0.25, not shown |

  The one extinct child is run 4755 (parent 1103, seed 2003), which leaves its pairs out of
  every test; the six settled relapses (4700, 4755, 4807, 4825, 4826 and 4827) leave theirs out
  of H-complexity. **Per parent**: H-capability-L goes 3 to 0 at every parent but 1103, 2 to 0
  with its extinct pair unmeasured. H-deep and H-stones tie throughout at every parent.
  H-complexity's two favouring pairs are both parent 1029's and its one pair against is
  944's. **The leave-out**: the report's `carried_by` is "—" for the one shown test, so no one
  or two parents carry it.

  **Descriptive**, the report's per-child first epochs under the k = 5 persistence rule,
  counted by the reading service's own ladder (`Lab::LogicReading::Arm#ladder`):

  | arm | ECHO | NOT | NAND | AND | ORN | OR | ANDN | NOR | XOR | EQU |
  |---|---|---|---|---|---|---|---|---|---|---|
  | full | 54 | 52 | 37 | 14 | 44 | 23 | 32 | 19 | 0 | 0 |
  | deep-only | 19 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
  | none | 19 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

  It matches the table in the Meta-stack entry above, which lists the rungs in another order.
  Read-only SELECTs over every stored sample of the 162 children found
  `logic_capability_deep` at 0 throughout, XOR's largest share 5/256 (run 4817, epoch
  46 470) and EQU's 1/256, against the 26 cells of 256 a tenth needs. Child for child, the
  deep-only children read exactly as the none children in every column of the report: no
  XOR or EQU was ever credited, so their pay was never collected. The estimated share of a
  full cell's income from tasks averages 0.589 (0.177 to 0.781).

  **The claim**, finding `paid-logic-climbs-only-read-once-tasks`, "Given a NAND, paid
  replicators climb every logic task that reads its inputs once, and none that needs one
  twice": paid for every rung of Avida's logic ladder with an assay-only NAND byte, BFF
  copiers reach every read-once rung, NOT to NOR, and neither XOR nor EQU, the two rungs no
  NAND circuit computes without reading an input or an intermediate twice. H-deep needed 5
  discordant pairs; 0 deep children in 54 full children puts a two-sided 95% upper bound of
  0.066 on the rate per child over this budget.

  **Registry status `negative`**, as for the Metabolism finding: the sweep was registered to
  answer one rung-4 question, H-deep, and it finished without the effect. H-capability-L,
  the shown test, is the manipulation check that pay buys the read-once rungs, and stays in
  this finding, named in its title's first half. It carries `imports_objective: true`, with
  the badge and the note that rung 4 on Soup is unaffected; the page adds that Logic imports
  a primitive besides.

  **What the refutation points at.** The pre-registration read H-deep refuted as the copier
  and its population binding rather than the instruction set, with mutational supply and a
  code region apart from the copied tape as the next suspects. The design study
  `docs/studies/meta-stack.md`, summarised in the Meta-stack entry above and written before
  this reading, had already separated them in pilots: supply does not bind (a specific
  substitution every 128 epochs, rate arms at × 4 and × 8 with no deep rung, × 16 melting the
  copiers), and a free metabolism tape under the in-place NAND climbs the read-once rungs and
  stalls in the same place. Its reading is that
  the binding constraint is **fan-out in a two-head machine whose NAND writes in place**, not
  mutational supply. That is the study's pilot reading, which this sweep agrees with and does
  not itself test; Meta-stack (DESIGN §1.3 item 17), seeded right after this reading, does.
  Rung 4 on Soup stays "not shown".

  **The page** renders the tests, their parent leanings, both sensitivity readings, the
  leave-out, the arms' losses and the descriptive ladder at render time, through
  `Findings::Logic` over `Experiments::LogicReadingService`'s report, the reading the sweep
  page draws and caches, and includes that page's section. The numbers the page hand-types
  are the lab's sample maxima above and the bound derived from the report. It links both
  studies it cites, `docs/studies/logic.md` and `docs/studies/meta-stack.md`, and links the
  Meta-stack sweep once that experiment is in the database. DESIGN §1.3 item 16 gains a
  result line. Nothing about the engine, the rules or any observable moves.

- 2026-10-02 — **The minimal-NAND tables for the topless ladder (preparation only).**
  The topless study (`docs/studies/topless.md`, now kept beside the other three) proposes
  the next rung-4 question if Meta-stack's H-deep-Ms reads shown: on a nested 2 → 3 →
  4-input logic ladder, does the deepest rung held keep rising late in long runs (H-rise,
  study §3)? A rung's depth is the exact minimal NAND count of its function, and the study
  makes the sweep pre-registrable only on a four-input table exact past 10 gates, where it
  left 19 045 of the 65 536 functions open. `research/minnand/` computes the tables; it
  does not close the four-input one.
  - **The cost** is the study's: the fewest two-input NAND gates of a circuit computing f
    from its inputs, fan-out free, NOT a = NAND(a, a) one gate as `logic::LOGIC_TASKS`
    counts it. Inputs are free. The tables count from the inputs alone, so 1 costs 2 and 0
    costs 3, as in the study's table. The machine pays nothing for a constant: the assay
    buffer is the tape followed by zeros, and a tape may hold any byte. So those two entries
    are not machine costs and are never read as a depth. No slot credits a constant, and
    free constants change no other entry, so every non-constant cost is the machine's. Cost
    is invariant under input permutation, so the tables are per P-class (80 on three inputs,
    3 984 on four).
  - **The tables**, committed as data: `data/minnand3.bin` (256 bytes) and
    `data/minnand4.bin` (65 536 bytes), one cost byte a function, with their SHA-256 in the
    crate's README, a witness circuit per class and a proof log. Three inputs: costs 0–10,
    the top "exactly one of three" at 10. Four inputs, functions by cost 0–13: 4, 10, 31,
    98, 293, 807, 2 067, 4 351, 8 941, 13 085, 16 804, 12 210, 5 464 and 767 (XOR4 12,
    XNOR4 13); **604 functions (75 classes) are left at "13 or more"**, a lower-bound byte
    0x8D, among them "exactly one of four". So the four-input table is exact past 10 gates
    for all but those 604, and its maximum is at least 13 and not known. The exhaustion to 13
    gates, which would decide them, was stopped at 4 CPU-hours unfinished (the slice's
    budget); the README gives what remains and its cost.
  - **The method**: exhaustive canonical enumeration (the study's method 1, cut by the
    number of unread gates a minimal circuit can still absorb and by input-permutation
    symmetry) to 12 gates, 18 CPU-minutes; above it, every exact class's witness extended by
    one or two gates gives circuits at 13 for 78 of the 153 classes left. Lower bounds are by
    exhaustion; SAT (varisat, a dependency of the crate only) re-proves the three-input ones
    and samples the four-input ones in the tests, and can carry the open classes on. Every
    claimed cost has a witness that re-evaluates.
  - **Checked**: the three-input table equals the study's checked table on all 256
    functions, is re-derived by exhaustion, and its every lower bound is re-proven by
    UNSAT; every four-input cost to 10 equals the study's `minnand4` output; the four-input
    table extends the three-input one; every witness re-evaluates; the known costs hold
    (XOR 4, EQU 5, XOR3 8, MAJ3 6, the full adder 9 together, NAND3 3, AND3 4, OR3 6, NOR3
    7, XOR4 12). `make minnand` runs the checks; it is outside `make verify`.
  - **Preparation only.** No sweep is seeded, nothing is relocked, and neither the engine
    nor any observable moves. H-rise still needs Meta-stack's H-deep-Ms to read shown, the
    study's engine slices (three-input ladder, four-input ladder, the depth observables) and
    its own pre-registration entry, which would lock the table as a constant. As the study
    rules, that entry needs the four-input table exact to its maximum, so the 604 open
    functions are closed first.
  - **The study's pilot numbers, labelled pilot** (one start world, Meta-stack child 4845's
    at epoch 31 900, on a throwaway engine copy; study §4): on the three-input ladder depth
    jumped from 5 (EQU) to 9 by jumps of 3–4 NANDs, held at a tenth from 3 500 epochs in
    seed 2001 and from 4 500 in seed 2002, and stayed at 9 to the end of both runs (40 000
    and 10 000 epochs) without reaching the top, 10; on the four-input ladder the same world
    re-climbed 4 → 8 → 9 and held 9 from 10 000 to 20 000 epochs. Depth jumped 5 → 9 and
    plateaued at 9 on both ladders. Pilot numbers, not findings.

- 2026-10-02 — **The Meta-stack finding states its claim: with a stack NAND on a metabolism
  tape, paid parts assemble the logic rungs that need an input twice, in a sixth of the
  worlds.** Sweep 17 (`meta-stack`, entry of 2026-10-02 above, "Meta-stack: does a soup
  assemble the deep rungs from paid parts on a metabolism tape read with a stack NAND?") is
  final: every child of its 18 parents finished, here and in the Logic sweep whose children
  are its twins. It is read here as registered, on the lab (`lab:meta_stack_report`,
  2026-10-02 18:25Z, "meta-stack reading, final").

  | arm | children | finished | settled relapses | extinct | capability measured | reached a deep rung | stepping stone | complexity survivors | rises |
  |---|---|---|---|---|---|---|---|---|---|
  | meta-stack | 54 | 54 | 0 | 0 | 54 | 9 | 9 | 54 | 3 |
  | meta-stack-deep-only | 54 | 54 | 0 | 0 | 54 | 0 | 0 | 54 | 2 |
  | meta-inplace | 54 | 54 | 0 | 0 | 54 | 0 | 0 | 54 | 3 |
  | logic-none | 54 | 54 | 0 | 0 | 54 | 0 | 0 | 54 | 1 |
  | logic-full | 54 | 54 | 6 | 1 | 53 | 0 | 0 | 48 | 2 |

  | hypothesis | pairs | favour treated | favour control | ties | p | outcome | extinct kept | without the piloted parents |
  |---|---|---|---|---|---|---|---|---|
  | H-deep-Ms (meta-stack against logic-none) | 54 | 9 | 0 | 45 | 0.00195 | shown | the same | 8 to 0, 34 ties, p = 0.00391, shown, carried by 967 + 2771 |
  | H-stones-Ms (against meta-stack-deep-only) | 54 | 9 | 0 | 45 | 0.00195 | shown | the same | 8 to 0, 34 ties, p = 0.00391, shown, carried by 967 + 2771 |
  | H-stack (against meta-inplace) | 54 | 9 | 0 | 45 | 0.00195 | shown | the same | 8 to 0, 34 ties, p = 0.00391, shown, carried by 967 + 2771 |
  | H-deep-M (meta-inplace against logic-none) | 54 | 0 | 0 | 54 | — | refuted | the same | 42 ties, refuted |
  | H-decouple (meta-inplace against logic-full) | 53 | 0 | 0 | 53 | — | refuted | 54 ties, refuted | 41 ties, refuted |
  | H-capability-M (meta-stack against logic-none) | 54 | 54 | 0 | 0 | 5.55e-17 | shown | the same | 42 to 0, p = 2.27e-13, shown |

  **Per parent**: the 9 deep children are 4845, 4862, 4863, 4871, 4890, 4952, 4961, 4979 and
  4980, from 7 parents: 967 and 2771 gave two each, and 944, 991, 1029, 2654 and 2676 one.
  H-capability-M goes 3 to 0 at every parent. **The leave-out**: the report's `carried_by` is
  "—" for every shown test, so no one or two of the 18 parents carry one; leaving out 967 and
  2771 together leaves 5 to 0, p = 0.03125. **Without the piloted parents** (944's child 4845
  goes), the three deep tests read 8 to 0 and that re-reading is carried by 967 + 2771:
  without both, 4 to 0, p = 0.0625. By the entry, the re-readings decide no outcome; the page
  states this one plainly.

  **Descriptive**, from the report's per-child columns: the meta-stack arm reached ECHO, NOT,
  NAND, AND, ORN, OR, ANDN and NOR in 54, 54, 43, 17, 54, 51, 49 and 51 children, XOR in 7 and
  EQU in 9; 4979 and 4980 hold EQU alone. Meta-inplace reached every read-once rung but AND
  and no deep one; the deep-only arm reached ECHO alone. The deep children's last-decile
  median XOR and EQU shares, read from the samples, are 0.46 to 0.57 for the six at
  `max_tape_len` 128; at 256, 4890 reads 0.28 and 0.41, 4980 EQU 0.47 and 4979 EQU 0.15.

  **The locked offline readings** ("Reported with each deep child"), made on 2026-10-02 with
  `research/landscape/` at `3cd9abb` on the stored worlds, read through SELECTs. Their summary
  is kept in `docs/readings/meta-stack/` (`summary.txt`, and `summary.csv`, one row per
  planting), with the scripts as run and the descriptive helper's source in `method/`; the
  14 MB of worlds are not.
  - **Substitution distance**: 9 of 9 read d ≥ 2 (17 to 31), so "multi-step" by the locked
    rule, which is **uninformative here**. Each world holds 9 634 to 14 375 distinct
    metabolism tapes and its dominant tape sits on 9 to 21 cells; drift puts it a median 22
    to 30 of 32 bytes from a cell of its own world, so the d ≥ 2 test can only fail where the
    dominant tape is the deep solver itself. Descriptive, not locked, every mutant within 3
    substitutions of the dominant tape: no credited path in any child; the nearest deep
    mutant at 2 (4845, 4871), at 3 (4863, 4952, 4980), none within 3 (4862, 4961); in 4890
    and 4979 the dominant tape was already an EQU solver at the pre-deep line.
  - **Heritability**: 0 heritable, 8 unresolved, 1 not heritable (4979). In 14 of the 15
    locked plantings every seed's unplanted control re-grew the rung to a tenth by e + 500
    (5 889 to 10 043 cells), level with the planted world; in 4979 neither reached a tenth.
    In 10 of 16 plantings (a labelled extension for 4890's XOR included) the filler is one
    substitution from the rung. Read plainly: in these worlds the deep rung is a property of
    the population, re-derived within hundreds of epochs, often from abundant lower-rung tapes
    one substitution below it, not a single lineage's invention — the study's §7.6, "The soup
    then evolves loop-shaped ORN/ANDN/OR solvers that sit one substitution below XOR/EQU, and
    takes that step."
  - **Circuits**: every deep solver is a loop that stacks NANDs leftward and reads earlier
    laps' results, credited on 18 of 18 traced cases, and each fans out an input. XOR takes
    4 to 6 NANDs, but 12 in 4863, a chain ending in a double negation; EQU 5 to 12.

  **The claim**, finding `paid-parts-assemble-deep-logic-on-a-stack-nand`, "With a stack
  NAND on a metabolism tape, paid parts assemble the logic rungs that need an input twice, in
  a sixth of the worlds": H-deep-Ms and H-stones-Ms shown, which the entry reads as "assembles
  XOR and EQU from paid parts", Lenski's mechanism in a soup under the four imports named.
  H-stack shown and H-deep-M refuted make the semantics decide it: the binding constraint
  under the in-place NAND was fan-out in a two-head machine whose NAND writes in place, now
  as a finding rather than a pilot. H-decouple ties throughout because neither of its arms
  built a deep rung: under the in-place NAND, moving the computing off the copier was not
  enough. No crossing is called multi-step on the distance.

  **Registry status `published`.** The registry reads `published` as "every run finished and
  the claim stands on them" and `partial` as "a reading is stated, but it cannot yet be read
  as final". The reading is final, and the claim is the pre-registered one, made on the two
  tests that ground it, both shown on the primary reading with no one or two parents carrying
  either. `partial` was used where the supporting reading itself stood on too few runs to be
  final (`complexity-under-contest`, 2026-09-24), which is not the case here. The two
  weaknesses are stated, not hidden: the unpiloted re-reading is carried by two parents, and
  the entry locks that re-readings decide no outcome; heritability is unresolved, which
  bounds what the claim says (a population property, not a lineage's invention) and is not a
  test of it. The title keeps the claim's size, a sixth of the worlds. It carries
  `imports_objective: true`, and the page names the four imports.

  **What it does not say.** Not open-endedness: the ladder tops out at EQU. Rung 4 on Soup
  stays "not shown". The depth is what the loop's later laps compute (the topless study,
  `docs/studies/topless.md` §2.3–2.4), not a count of accumulated steps. The next question,
  whether depth keeps rising on a ladder without a near top, is the topless study's; its
  engine slice is in review, and it needs a pre-registration of its own.

  **The page** renders the six tests, their parent leanings, both re-readings with the
  parents that carry them, the leave-out, the deep children and the arms' losses at render
  time, through `Findings::MetaStack` over `Experiments::MetaStackReadingService`'s report,
  the reading the sweep page draws and caches, and includes that page's section. The offline
  readings are hand-typed from `docs/readings/meta-stack/summary.csv`, which it links, and
  checked against it. DESIGN §1.3 item 17 gains a result line. Nothing about the engine, the
  rules or any observable moves.

- 2026-10-02 — **The topless ladder, engine slice: `tasks = logic3 | logic4`, depth-scaled
  pay and `task_depth_cap`, and the depth readings.** Slices 1–3 of the topless study's
  §1.5 (`docs/studies/topless.md`), built together because a sweep needs all three. No sweep
  is seeded and nothing is relocked; H-rise and its pre-registration come after the
  Meta-stack offline readings, and still need the 604 open four-input functions closed.
  - **Inputs.** `logic3` puts z on `B[2L−3]`, `logic4` also w on `B[2L−4]`
    (`task::run_case_with`; a buffer shorter than the inputs holds none, as before). Buffer,
    emit, `TASK_MAX_OUTPUTS`, both `logic_nand` modes and the metabolism tape are the logic
    ladder's. `logic3` runs the logic ladder's three cases; `logic4` runs six
    (`topless::Inputs::cases`), the only departure from `TASK_CASES`.
  - **Case draws**, designed, on `STREAM_TASK` at (seed, epoch), at most
    `DEPTH_CASE_DRAWS` = 1 024, then a fixed set a test holds to the rule. Every row
    (combination of the inputs) is read `READS_PER_ROW` = 3 times, each at a different bit
    position: three times over, a Fisher–Yates shuffle puts each row on exactly one bit
    column of that read's cases (one case on three inputs, two on four), reshuffled (at most
    1 024 times) until no row lands on a bit position an earlier read gave it. The draw is
    redrawn until each input's values are pairwise distinct and, on three inputs only, no
    non-constant function expects equal outputs or sits a constant offset from an input it
    is not the projection of. About 94% of three-input draws and 82% of four-input ones
    pass. Each rule is read off the inputs directly over 10^5 draws.
    - **Why three reads apart.** The study's draws (three-input: random bytes covering the
      8 rows; four-input: a bijection of the 16 rows onto cases 0 and 1, case 2 random) read
      many rows at one bit position only. A NAND masked by a code byte computes a
      different function at different bit positions (`~<~~!` outputs x on the mask's bits
      and 1 elsewhere), and a row read once at one position passes that mix as a single,
      deep function. On the study's draws the false-credit search below found `[<~!]`
      credited depth ≥ 5 on 26% of four-input draws and ≥ 7 on 16%, `~<~~!` ≥ 9 on 4.1%,
      and on three inputs `~<~~!` ≥ 5 on 1.4%; and the reward paid it — in the
      `with_logic_solvers` world at reward 1 024 over 50 epochs, 383 of 45 982 four-input
      credits (11 of 45 745 three-input) were functions of depth ≥ 5 the tape does not
      compute, mostly on mutants holding `{~!` or `<~!` behind one junk byte. A row read
      at three distinct positions contradicts itself unless the mask agrees at all three,
      so the mix is refused. Two reads per row (four cases on four inputs) still left
      `[{~!]` at ≥ 5 on 1.1%; three leave nothing above 0.05% (below).
  - **Credit.** One pass per slot over every bit column gives its truth table (bit k is the
    row whose input values are k's bits, x then y then z, w the top bit on four, as
    `research/minnand` numbers them). A slot credits nothing where two columns disagree on
    a row (not a bitwise function, or not the same one at every bit position), the
    function is constant, its output bytes are all equal, or they are an input plus one
    constant and the function is not that input. On three inputs the draw already refuses
    the last two; on four they are refused at the slot, whatever function matches (study
    §1.2), which six cases spring on fewer than 10 of 400 000 random functions. Otherwise
    the slot credits its function's input-permutation class, the least truth table among
    its permutations (a 64 K table built once per process). **Rungs** are those classes:
    78 on three inputs (ECHO = the projections, then Avida's 77), 3 982 on four; input
    copies and constants are no rungs but ECHO. A tape is credited at most four, each once.
  - **Depth** is the exact minimal NAND count, `include_bytes!` of copies of
    `research/minnand/data/minnand{3,4}.bin` under `engine/crates/life-engine/data/`, held by
    a test to the SHA-256 in that README (the engine computes the hash itself; no dependency
    on the research crate). The 604 four-input "13 or more" functions are credited at 13
    (`topless::DEPTH_FLOOR`), **a lower bound**: any reading whose depth reaches 13 must be
    reported as "13 or more", and a child reaching it named.
  - **Pay**, per cell per assay: `task_reward × Σ DEPTH_UNITS[min(d, cap)]` over the
    **distinct rungs** the tape is credited (the study's "summed over the distinct classes"),
    saturating, never past `energy_stock_cap`. `DEPTH_UNITS[d]` = √(2^d) rounded to the
    nearest integer, computed exactly as n = ⌊√(2^d)⌋ plus one where 2^d > n² + n: 1, 1, 2,
    3, 4, 6, 8, 11, 16, 23, 32, 45, 64, 91 for d = 0–13. Both ladders use ×√2; the study's
    ×1.25 for four inputs is not adopted, so the reward that spreads the ×8 economy over the
    four-input ladder is the pre-registration's to choose (at 1 024 a lone depth-12 rung
    already saturates at `task_every` 8).
  - **`task_depth_cap`** (integer 0–13, default 0 = none): a rung deeper than the cap is paid
    as a rung of the cap's depth, the study's capped-control arm (§3, cap 5). Refused unless
    `tasks` is `logic3` or `logic4`.
  - **`task_floor`** accepts only `echo` on these ladders: a floor by rung name does not map
    onto 78 or 3 982 classes, and no H-rise arm needs one. A depth floor, if a design ever
    needs it, is a new parameter.
  - **The depth readings**, `logic_depth_max` (an integer, −1 where nothing is held) and
    `logic_depth_classes`, on `STREAM_TASK | 6`: 256 cells drawn with replacement on fresh
    cases, each distinct assayed tape once; a rung is held at 26 of 256. Under `logic3` and
    `logic4` the Logic keys (`logic_share_*`, `logic_capability`, `logic_capability_deep`,
    `dominant_logic_tasks`, `logic_capability_replicating`) keep their keys, streams and
    meaning — the share of cells credited each two-input rung — read as the class of that
    rung's two-input form, so AND is x∧y, x∧z or y∧z alike. Under `logic` they are
    unchanged. The depth readings are null on every other ladder, on life, and on every
    earlier sample; live-only; pinned in a digest split from the others.
  - **Invariants.** Every existing pin and digest is unmoved. Either ladder at a reward of
    0 is the run with tasks off, byte for byte and stock for stock, under both payers and
    `task_every` 1 and 8, and its readings leave every shared reading the same sample for
    sample. Reward pins: `with_logic_solvers` at reward 1 024, seed 42, 50 epochs,
    `0x2561_20e8_9636_e281` (`logic3`) and `0x7eb5_a1ec_92c0_2518` (`logic4`).
  - **Solvers.** Straight-line tapes compiled from `research/minnand`'s witness circuits —
    XOR3 (8), MAJ3 (6), NOR3 (7), the three-input top 0x16 (10), the four-input NOR (10),
    XOR4 (12), a 13-gate class 0x0168 and a 7-gate four-input one — compute their function
    on 4 096 random input sets and are credited exactly their rung on 20 000 draws each
    under both NANDs (on four inputs, nothing on a draw that refuses the function at the
    slot, and only there). Copiers, junk emitters, sprayers and inputs plus a constant are
    credited nothing, echoers ECHO alone.
  - **False deep credit** (`the_false_deep_credit_search`, on demand): every program of up
    to 5 bytes over the ten ops, `!` and `~` in front of a zero tail, on 400 draws, the six
    nearest at each depth re-read on 20 000 fresh draws (and once on a 2 000-draw screen).
    The most draws any program is credited depth ≥ 5 on: 0.04% on three inputs (`.<~~!`,
    `}-<~!`, under either NAND), 0 on four inputs in place and 0.04% under the stack NAND
    (`[{!~]`); ≥ 7 at most 0.02% (`<~~!+`, three inputs), nothing ≥ 8 on either ladder. A
    test holds every program of up to 4 bytes to at most one of 200 draws at depth ≥ 5. In
    the `with_logic_solvers` world above (a one-off check against a reference reading of
    every row at every bit position), no credit was a deep function the tape does not
    compute on either ladder; 10 of 45 698 three-input credits were shallow ones.
  - **Cost** (`the_topless_assay_cost`, on demand): on a Meta-stack-like 128×128 world,
    32-byte stack metabolism tapes all mutants of the evolved loop (16 366 distinct), one
    assay epoch costs 10.4–11.0 ms under `logic`, 11.6–11.7 ms under `logic3` (the first
    including the one-time 64 K class table) and 22.2 ms under `logic4`, whose six cases
    double the runs; a sample's logic and depth readings 0.2 ms under `logic` and 0.4–0.6
    ms under the topless ladders. The study's own draws cost 12.0 and 15.6 ms on the same
    machine.
  - `tasks`, `task_depth_cap` are dynamics: a descendant may set them. A run stored before
    `task_depth_cap` existed carries no key, and `Lab::CanonicalParams` fills in 0, the
    uncapped run it was. `runner schema` exports the ladder's units, floor and draw bound
    under `tasks.topless`, with the reads per row and each ladder's case count.

- 2026-10-02 — **Topless rise: does the deepest rung held keep rising when depth is paid?
  The `topless_rise` sweep, pre-registered.** This is §1.3 item 18 and it adds a paragraph to
  DESIGN §1.4. The experiment is `topless-rise` (sweep key `topless_rise`), and its numbers
  live in `Lab::ToplessRiseReading`. It is the topless study's question 3
  (`docs/studies/topless.md` §3), turned into an entry with the adjustments below, on the
  engine slice above (`tasks = logic4`, `task_depth_cap`, `logic_depth_max`). Nothing is
  relocked.

  **What was seen.**
  - **Meta-stack, final** (`lab:meta_stack_report`): **H-deep-Ms shown, 9 pairs to 0**, on 9
    deep children over 7 parents: runs **4845, 4862, 4863, 4871, 4890, 4952, 4961, 4979 and
    4980**. Each holds XOR, EQU or both by a tenth of the world, every one through a loop that
    stacks NANDs leftward and reads an earlier lap's result.
  - **Meta-stack's locked offline readings** (2026-10-02, `research/landscape` at `3cd9abb`;
    `docs/readings/meta-stack/`):
    multi-step crossings by the locked rule d ≥ 2 in **9 of 9** (d = 17–31); heritability by
    planting **0 heritable, 8 unresolved, 1 not heritable** (4979); no credited order in any
    child, a neutral-or-better one in 3. Two of those rules taught what this entry must not
    repeat:
    - **a distance from the dominant tape is uninformative here.** Each world holds 9 634 to
      14 375 distinct metabolism tapes of 16 384, its dominant tape sits on 9 to 21 cells and
      is a median 22–30 bytes from a cell of its own world, and at `meta_rate` 1/256 any two
      stored worlds 1 000 epochs apart differ by far more than 2 substitutions. The d ≥ 2 cut
      could only come out "no" where the dominant tape was the deep solver itself;
    - **a planting test is unresolved when the control re-derives the rung inside the
      window.** In every unresolved planting each seed's control was back at a tenth by
      e + 500, level with the planted world: the filler sat one substitution below the rung
      in 10 of 16 plantings.
  - **The topless study's pilots, labelled pilot** (one start world family, a throwaway engine
    copy; study §4): from Meta-stack child 4845's world at epoch 31 900, **depth jumped 5 → 9
    by co-opting bytes into a loop** (+4 NANDs in one substitution, load-bearing bytes 14 → 20)
    and **plateaued at 9 on both ladders**: no 10 on three inputs in 36 000 epochs, and on four
    inputs the same world re-climbed 4 → 8 → 9 and held 9 from 10 000 to 20 000 epochs.
    Switching to ×√2 pay at 1 024 cut every deep start's deep share within 500 epochs before
    the re-climb. Pilot numbers, not findings.
  - **The engine slice's false-credit measurements** (the entry above): on the study's draws a
    masked NAND passed as a deep function — `[<~!]` credited depth ≥ 5 on 26.4% of four-input
    draws and ≥ 7 on 15.6%, `~<~~!` ≥ 9 on 4.1%, and 383 of 45 982 paid four-input credits in
    the `with_logic_solvers` world were functions the tape does not compute. With every row
    read at three bit positions the worst is **0.04% at ≥ 5 and nothing at ≥ 7** on four
    inputs, and none of the paid credits is false.

  **The question.** On the nested four-input ladder, does the deepest rung held keep rising in
  the second half of a long run when depth is paid, and not otherwise? "Keeps rising" is the
  study's §2.4: a late, persistent increase of `logic_depth_max`, on a ladder whose top is not
  within one reorganisation of the start, read beside load-bearing bytes so a rise by
  co-option is told apart from one by new code.

  **The sweep.**
  - **Parents.** H-deep-Ms is shown on 9 children over 7 parents, fewer than about 10, so the
    study's rule applies: **all 54 meta-stack-arm children** of the meta-stack sweep (the
    stack NAND paid from ECHO up, no `task_floor` or the default one), each from its last
    stored world at epoch 60 000 (SELECT, 2026-10-02: all 54 finished at 60 000; a terminal
    world is the one snapshot pruning always keeps). The rule is data (`Lab::ToplessRiseReading::PARENTS`): the
    children of `meta-stack` in that arm, finished, that kept a world at their last epoch,
    with no reading of that world required. `Experiments::DescendantParentsService` reads a
    rule with `"descendants" => true` over the source sweep's descendant runs, and a rule with
    no instrument as qualifying on the terminal world alone; the from-emerged rule and every
    sweep built on it read as before. No id is hard-coded in the rule. **The 9 deep children
    are a declared subgroup** (`DEEP_PARENTS`).
  - **Arms**, merged over each parent's params, so each keeps its 32-byte metabolism tape and
    the stack NAND:
    - **rise**: `tasks: logic4, task_reward: 512`;
    - **capped**: the same with `task_depth_cap: 5`, every rung deeper than 5 paid as a
      depth-5 rung: is the rise paid for, or does depth drift up by hitchhiking?
    - **none**: `tasks: logic4, task_reward: 0`, the drift baseline. A reward of 0 runs no
      assay, and the depth readings still read every sample (the slice pins this).
  - **The reward, 512**, redone with the engine's `DEPTH_UNITS` (1, 1, 2, 3, 4, 6, 8, 11, 16,
    23, 32, 45, 64, 91 for d = 0–13). Under the initiator payer a cell's income is
    1 024 + reward × units / 8, worth nothing past 8 192, so a cell saturates at
    57 344 / reward units: 56 at 1 024, 112 at 512. Beside ECHO, NOT and XOR in the other
    slots (6 units), the gain of one more NAND in the deepest slot is:

    | reward | saturates at | 5→6 | 7→8 | 9→10 | 10→11 | 11→12 | 12→13 |
    |---|---|---|---|---|---|---|---|
    | 1 024 | 56 units | 0.10 | 0.20 | 0.24 | 0.28 | 0.09 | **0** |
    | 768 | 75 units | 0.09 | 0.18 | 0.23 | 0.27 | 0.31 | 0.06 |
    | **512** | **112 units** | **0.07** | **0.15** | **0.20** | **0.24** | **0.28** | **0.31** |
    | 256 | 224 units | 0.05 | 0.10 | 0.15 | 0.19 | 0.23 | 0.27 |

    At 1 024 a lone depth-12 rung saturates the cell, so the gradient stops where the
    four-input ladder starts to be topless. At 512 no single rung up to the 13 floor
    saturates it (13 beside the three: 7 232 of 8 192), every NAND from 5 up pays 7–31% more
    income, and only two rungs of 12 and 13 together saturate. The price: a depth-9 cell
    earns about 2.5 times a shallow ECHO + NOT cell, against 3.7 at 1 024, so the switch from
    Meta-stack's pay (about 5 : 1) dilutes deep shares more than the pilots did. 512 is
    unpiloted.
  - **Seed 4001**, one per parent. A descendant's identity is (canonical params, seed, parent
    run, parent epoch); no stored run descends from a meta-stack child and none carries seed
    4001 (SELECT, 2026-10-02), and no other sweep names it. It is not 2001–2003, so it replays
    none of the meta-stack streams from a new start. **100 000 epochs** past the parent (each
    child ends at epoch 160 000), **priority 40**. **54 × 3 = 162 children.**
  - **Cost.** The meta-stack sweep's finished children ran at 68.2 s per 1 000 epochs (cap
    128, 99 runs) and 64.9 (cap 256, 63 runs) on the mini-pc (SELECT, 2026-10-02). `logic4`
    adds about 11.5 ms an assay epoch over `logic` (22.2 against 10.4–11.0 ms), every 8
    epochs, so about 1.5 s per 1 000 epochs: rise and capped about **70**. The none arm runs
    no assay: Logic's none rate, 42, plus 10–17% for the tape, about **47**. 54 × 100 × (70 +
    70 + 47) s ≈ 1.0 M run-seconds ≈ **23 h of the 12 slots**; without the capped arm ≈ 14 h.
    Interim until every child's `compute_seconds` replace it.
  - **Validation.** Each bundle, merged over a cap-128 and a cap-256 meta-stack child's params
    (4845 and 4890, read with SELECTs), was accepted by `runner run` from this branch; and
    each was descended from that child's own stored world at epoch 60 000 by
    `World::descend` and run 1 000 epochs, seed 4001, reading `logic_depth_max` at every
    sample. *Pilot-level, one seed, labelled*: both worlds read depth 5 under four inputs at
    the switch and lost it within 200 epochs in every arm (the reward switch of the study's
    §1.3); 4845's rise child was back at 7 by 1 000 and its capped child at 0; the none
    children fell to ECHO or nothing held. `replicator_share` fell from 0.85 and 0.78 to
    0.38–0.56 by 1 000 epochs in all three arms, none included. On the Mac the rise and
    capped arms stepped 1 000 epochs in 12.8–16.1 s and the none arm in 8.7–12.1 s, a ratio
    of 1.3–1.5 against the 1.5 the cost above assumes.
  - The builder is idempotent, adds nothing to the meta-stack sweep or any earlier one, and
    adds a parent's three children once it qualifies.

  **The readings, per child**, over its own samples. Logic's: the **settling window**
  (epochs above `parent_epoch` + 1 000), **extinct** where the last-decile median
  `replicator_share` (the detector on the replicating tape) is below **0.1**, a **settled
  relapse** where it sits below 0.1 for 3 consecutive settled samples, **lower-middle
  medians**, and a decile unread with fewer than **10** numbers in it.
  - **Deciles** are cut by index over all `n` settled samples, unfiltered: decile k is the
    samples from ⌊(k − 1)·n/10⌋ to before ⌊k·n/10⌋, so the tenth is Logic's last ⌈n/10⌉ and
    the fifth ends the first half. Inside a decile the samples carrying `logic_depth_max` as a
    number count.
  - **−1**, nothing held at a tenth, **enters a median and the bar below as the number −1**,
    one below ECHO's 0 and below every depth. A decile of −1 and 0 in equal numbers reads −1
    (the lower middle).
  - **The bar** is the deepest the child's lineage reached before the second half: the
    largest of (a) its **fifth-decile median**, (b) its **depth at descent**, the
    `logic_depth_max` of its first own sample, the parent's world read on the four-input
    ladder one sample interval past the switch, and (c) **every depth it held under the
    persistence rule** (below) in its own samples up to the fifth decile's end, settling
    window included, the run of 5 completed by then.
  - **The rise rule.** A child **rises late** where its last-decile median `logic_depth_max`
    is at least **the bar + 1**. It is **measured** where both medians are read and it is not
    extinct. Why a bar and not the fifth-decile median alone, as study §3 drafted: the pilot
    validation above saw every arm lose its parent's depth 5 within 200 epochs of the switch
    and re-climb, and study §2.4 reads "keeps rising" as a depth the lineage had not reached
    ("not passing 5, or reaching any single depth"). Fed by the fifth decile alone, the rule
    would count a slow re-climb to the parent's own depth, a dip at the fifth decile and back,
    or a lineage that lost ECHO and regained it (−1 → 0) as rising. Against the bar, only a
    depth deeper than any the lineage held, its parent's included, counts. No fixed depth
    (6, past EQU) is required, for the same §2.4 reason: no single depth is evidence of a
    sustained rise. A child that held nothing at descent and nothing since still rises at
    ECHO; a parent holding any rung at its last epoch sets its children's bar at ECHO or
    above, so that can only be a child whose parent's world was read holding nothing.
  - **Ceilinged.** The 604 open four-input functions are credited at 13, a floor, so 13 is
    both the floor value and the deepest depth any reading can show; the table's true maximum
    is at least 13 and unknown. A child whose **bar is already 13** is ceilinged, read as
    **no rise**, and printed apart: by the rule it could not rise. Any child reaching 13 in
    any sample is named (`reached_floor`) and its depth reported as "13 or more". This
    replaces the earlier entries' demand that the open functions be closed before the sweep:
    a child that would need them is read apart rather than wrongly.
  - **First epochs** under the **persistence rule, k = 5**: depth d is first held at the first
    of 5 consecutive own samples at d or deeper. Descriptive: the deepest depth so held and
    when, and the depths first held in the second half of the settled samples (from the
    sixth decile), the "repeated, late" steps of §2.4.

  **The tests.** One-sided sign tests over the discordant pairs at p < **0.05**, Logic's
  machinery and outcome rules: **shown** at p < 0.05; **refuted** where the pairs favouring
  the control are at least as many as those favouring the rise arm, ties included; **not
  shown** otherwise; **no measured pairs** where none is measured on both sides. A pair is the
  rise child and the control child of the same parent; it favours the side that rises late
  alone. Each test carries the **per-parent agreement** (one pair a parent) and the
  **leave-one-or-two-parents-out** rule. With the control at no rise each needs **5**
  discordant pairs (p = 1/32), and **7** to survive leaving out any two parents (5 to 0 left,
  p = 1/32). The bar makes a rise rarer in every arm alike: the none and capped children are
  read under it too, and a drift child that never re-reaches its parent's depth reads no
  rise, so the tests stay one-sided against a control near no rise. With 54 pairs the tests
  can be shown if about one rise child in eight clears its bar and no control does.
  - **H-rise** (rise against none): the rise rule.
  - **H-rise-paid** (rise against capped): the rise rule.
  - **The deep subgroup**, a declared secondary: both tests re-read on the pairs of the 9 deep
    parents alone. It decides no outcome.
  - **Extinct kept**, a sensitivity reading: both tests with the pairs of extinct children
    kept. It decides no outcome.
  - **H-rise-code (descriptive, tested nowhere).** The load-bearing bytes of the dominant
    deepest solver, the fifth-decile world against the last, on every rise child that rises late and on
    its twins, measured offline on the stored worlds. The method, locked now:
    - **six fixed four-input case sets**, `topless::Cases::draw(Inputs::Four, ·)` six times in
      turn off `rng::seeded(0xdee9, 4, 0)`, frozen as constants; a tape is credited a class
      "on all 6 sets" where the topless assay, under the child's own instruction set and
      NAND, credits it on each;
    - **the world's deepest solid rung**: the deepest class credited on all 6 sets to at least
      a tenth of the cells (1 639 of 16 384); **the dominant deepest solver**: the commonest
      metabolism tape so credited, ties broken by byte order;
    - **load-bearing bytes** (study §2.3): the positions at which at least 7 of the 13 other
      symbols of the 14-symbol alphabet leave the tape credited, on all 6 sets, no class as
      deep;
    - **the worlds**: the earliest stored world at or past the first settled sample, the
      last stored world at or before the fifth decile's end, and the last stored world
      (pruning keeps one every 1 000 epochs, so all three exist);
    - printed: the three counts and depths. New code where the depth rose from the
      fifth-decile world to the last and the count rose by 2 or more; co-option where the
      depth rose and the count did not. The fifth-decile world, not the first, is the base, so
      the comparison spans the half the rise rule reads and not the re-climb after the
      switch. The other cases are labelled too, descriptively: **neither** where the depth
      rose and the count rose by exactly 1, **no rise in depth** where it did not rise, and
      **unread** where the fifth-decile or the last world holds no class by a tenth, so has
      no dominant deepest solver to count.
    - **A tool slice comes first.** `research/landscape` reads the two-input assay only and
      has no load-bearing count; a slice adding the topless assay and that count lands before
      the sweep is read.
  - **No distance-from-dominant rule and no planting-heritability test**, because of
    Meta-stack's offline lessons above: in worlds of 10–14 k distinct tapes the distance from
    the dominant tape measures drift, not a crossing, and a planting whose control re-derives
    the rung within the window cannot resolve. Heritability is read instead as persistence:
    a depth held 5 samples running and carried to the last decile.

  **What each outcome means** (study §3).
  - **H-rise shown, and H-rise-paid shown.** On a paid ladder with no near top, the deepest
    feature keeps getting deeper late in long runs, and only when depth pays. That is the
    rung-4 claim on this substrate, "complexity keeps rising", under the imports below. It is
    **co-option** where load-bearing bytes stay flat, and **new code** where they rise.
  - **H-rise shown, H-rise-paid refuted.** Depth rises without being paid for: it is
    hitchhiking on the paid lower rungs, not selection for depth.
  - **H-rise refuted or not shown.** The climb stops: the soup takes the jumps a
    reorganisation offers early and then plateaus, as the pilots did at 9. That is the
    open-endedness answer here, a negative one: paid parts buy a deeper feature, not a climb.
  - **Most children ceilinged** (more than half of the rise arm's children with both deciles
    read have a bar of 13). The ladder had a near top after all, and the question needs more
    inputs; the tests are printed but not read as an answer.

  **What is not claimed.** The substrate imports **an objective, a primitive, a hereditary
  channel and the primitive's semantics** (Meta-stack's four), **plus an imported ladder of
  growing input arity**. Whatever rises says nothing about fitness-free emergence, and **rung
  4 on Soup stays "not shown"** whatever it reads. It is one substrate, one budget, one seed a
  parent, and its parents are three correlated children of 18 worlds. Every constant above
  lives in `Lab::ToplessRiseReading`.

  **Seeding rule.** `lab:sweep[topless_rise]` is run **only after** the topless ladder's
  engine slice and this entry are deployed (one runner restart), **and after reach-cap128 has
  finished and its post-run readings pass has completed**: the restart would interrupt that
  pass. It should create 162 runs.

  **When it is read.** `lab:topless_rise_report` (text, or CSV with `FORMAT=csv`) and the
  sweep's page read it, labelled **interim** until the parent pool is terminal and every
  child of every qualifying parent has finished (`Experiments::DescendantSweepSettledService`),
  then **final**.
