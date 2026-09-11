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
  already past their transitions and their census peaks. Seven runs flagged, six
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
