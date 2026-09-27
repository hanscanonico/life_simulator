# 0002. Runs are deterministic, and nothing added may change an existing run

- **Status:** Accepted
- **Date:** 2026-09-10; invariant stated 2026-09-11 (#143); descendant identity 2026-09-25
  (#243)
- **Source:** `docs/DESIGN.md` §1.1 ("Determinism"), §3; `docs/design_record.md`
  2026-09-11 ("The evolution programme") and 2026-09-25 ("Runs that start from an emerged
  world")

## Context

Every claim the lab publishes has to be re-examinable from the seed of every run, and the
programme keeps adding observables and optional substrate parameters to a corpus of runs
that already exist. If an addition shifted an RNG stream or a byte, earlier runs could no
longer be reproduced, and their arms would stop being comparable to the new ones.

## Decision

- A run is fully determined by `(params, seed)`, byte for byte, on native and on wasm. The
  RNG is `xoshiro256**` seeded from the run seed, and visiting order and neighbour choice
  come from that stream only.
- A **descendant run** is fully determined by `(parent run's world at parent_epoch,
  params, seed)`. It never falls back to a fresh soup. When the parent world cannot be
  fetched, the run fails.
- **Invariant:** a new observable or an optional substrate parameter must leave every
  existing run byte-identical. A new observable reads the world and writes neither to it
  nor to the RNG stream. Where it needs randomness, it draws from a stream of its own that
  is a pure function of `(seed, epoch)`. A new parameter defaults to the value that makes it
  invisible and draws nothing while it is off.

## Consequences

- Determinism tests in `engine/crates/life-engine/src/world.rs` pin `(params, seed) → hash`
  for every substrate plus the observable strings. An addition that moves a pinned value
  breaks the gate.
- A sweep's default arm replays earlier sweeps' runs digit for digit, which several sweeps
  have checked rather than assumed. Its arms stay comparable across sweeps.
- Samples recorded before an observable existed carry no value for it, and no backfill is
  possible from samples. Readers tolerate nulls, and stored worlds are read separately
  (ADR 0004).
- The resume path has to carry every piece of state the world has, or a resumed run would
  diverge from an uninterrupted one (ADR 0003).
