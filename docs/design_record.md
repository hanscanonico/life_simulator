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
