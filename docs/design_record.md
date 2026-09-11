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
