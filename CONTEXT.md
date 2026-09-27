# Life Simulator — domain glossary

The words this codebase, its findings and its issues use, each in a sentence or two with a
pointer to where it is defined. The definitions of record are `docs/DESIGN.md` (cited as
§) and the dated entries of `docs/design_record.md` (cited by date and title); where this
file and they disagree, they win. Engineering decisions live in `docs/adr/`.

Use these words and not synonyms: the 2026-09-11 entry ("The evolution programme") says
findings and issues use the locked vocabulary.

## The substrate

- **Soup** — the research substrate: a spatial soup of BFF programs that execute each
  other, with no fitness function (§1.1). The other substrate, **Life** (`B3/S23`), shares
  the viewer and pipeline but carries no research claim.
- **World** — a 2D torus of `width × height` cells; its tapes (plus lineage tags, and
  energy stocks when an economy is on) are its whole state (§1.1).
- **Cell** — one position of the world, holding one tape (§1.1).
- **Tape** — the bytes a cell holds, `tape_len` long (default 64); it can lengthen up to
  `max_tape_len` when room to grow is on and never shortens (§1.1, "Room to grow").
- **Interaction** — one cell and a random neighbour within `radius` (0 = well-mixed): the
  two tapes are concatenated, run as one program for at most `max_steps`, and split back
  (§1.1). Not to be confused with the parameter `interaction` (`concat` default, `host`),
  the execution mode that decides whose bytes the instruction pointer ranges over.
- **Epoch** — every cell initiates one interaction, in a random visiting order, then
  mutation runs over every byte (§1.1). Samples are taken every `sample_every` epochs.
- **head0 / head1** — the two data heads of the interpreter, both starting at 0 and
  wrapping over the concatenation (or claiming a fresh byte under room to grow); `.` copies
  head0 → head1, `,` head1 → head0 (§1.1, "Instruction set").
- **Ops** — the ten BFF instructions `< > { } + - . , [ ]`; every other byte is a no-op.
  The parameter `ops` ablates that set (§1.3 sweep 5); the steal op `$` is not one of the
  ten (§1.1, "Steal op").

## Detection: transition, emergence, census

- **Transition / crossing** — `transition_epoch`: the first sampled epoch whose sample
  qualifies (`compress_ratio < 0.6`, `op_density <= 0.9`, `alphabet_size >= 16`) and the
  next 3 do too (§1.2). It is a **crossing**, a *candidate* that reads compression, not a
  copier (2026-09-15, "A crossing is a candidate"), and it stays the primary dependent
  variable of every sweep.
- **Constant vs relative** — `transition_epoch` is the constant rule above.
  `transition_epoch_relative` reads `compress_ratio <= 0.61 × baseline` (baseline: mean of
  samples at epoch ≤ 500) under the same guards; it is a companion and relocks nothing
  (2026-09-19). Relocking the transition on it is pending with the user (#229, PR #237).
- **Emergence / emerged** — `emergence_epoch` (with `emergence_witness`): the earliest of a
  run's crossings that the census or `copy_rate` confirms within
  `Runs::EmergenceEpochService::CONFIRM_WINDOW` (10) samples either side (2026-09-15, both
  entries; #172, #189). A run
  **emerged** when it has one; the open-endedness findings read it, not
  `transition_epoch`.
- **Replicator test** — a tape `T` passes when running `T ++ R` on fresh random `R` leaves
  `T` in the second half in at least 3 of 4 trials, tried on the `top_k` (16) commonest
  tapes (§1.2). It asks for `T` in `T`'s own orientation.
- **Census / `replicator_count`** — the cells holding a tape that passed, on draw 0 of 8
  seeded draws; `replicator_pass_rate` and `replicator_count_mean` read all eight (§1.2;
  2026-09-18, "read over 8 draws"). **Census peak**: its maximum and first epoch, derived
  in Rails (2026-09-11).
- **`replicator_share` / orientation-aware detector** — the share of 256 randomly drawn
  cells whose tape passes `replicator::self_replicates` aligned: 5 chains of 5 runs against
  fresh noise, the carried first half compared with the original, a position agreeing on a
  strict majority of chains, a pass at 3 of every 4 positions. Modelled on the 2026 BFF
  paper; the odd chain reads a reverse copier back in its own orientation (§1.2,
  "Orientation-aware detector"; #247). With `replicator_share_rotated` and `dominant_self_replicates` it is a companion:
  the census, emergence and persistence stay locked, and whether they relock on it is the
  user's decision (2026-09-25, "The corpus read by the orientation-aware detector").
- **Reverse copier** — a tape that writes a byte-exact `reverse(T)` into its partner, so a
  colony is `X` and `reverse(X)`. The emerged worlds are mostly these, and the locked census
  and `copy_rate` count them as nothing; `reverse_copy_rate` sees them (2026-09-25, "The
  replicator census is blind to replicators that copy in reverse").
- **`copy_rate`** — the share of a sampled epoch's interactions that ended with one half a
  byte-exact forward copy of its partner's arriving tape, among pairs that did not arrive
  as copies already (§1.2).

## Lineage and complexity

- **Lineage / lineage tag** — a lineage is the tapes descended by copying from one ancestor.
  Its id is a **tag** beside each cell, unique at init, taken from the partner when a cell
  ends Hamming-closer to the partner's arriving tape than to its own (2026-09-13, "Lineage
  id is a tag carried by descent"). This replaced the 2026-09-11 skeleton-digest definition.
  Snapshots carry the tags from format version 3.
- **`lineage_rule`** — how "closer" is read: `aligned` (default, every run before it) or
  `oriented`, where a cell overwritten by `reverse(A)` takes `A`'s tag (2026-09-25, "The
  lineage rule becomes a parameter"; #257).
- **Lineage readings** — `distinct_lineages`, `top_lineage_share`,
  `lineage_effective_count` (inverse Simpson; ≥ 2 reads **polyphyletic**, < 1.5
  **monophyletic** in sweep 12) and `lineage_variation` against each lineage's **modal
  tape** (§1.2; 2026-09-25, "Lineage diversity after a transition").
- **Persistence / relapse** — a transitioned world **persisted** while its transitioned
  state held and **relapsed** at the first `hold_samples + 1` consecutive rejecting samples,
  a Rails-side rule (`Runs::PersistenceSummaryService`; 2026-09-12). The from-emerged sweep
  reads persistence on `replicator_share` instead: a child **held** when its last-decile
  share is at least 0.5 and never sat below 0.1 for 3 samples running, **relapsed**
  otherwise (`Lab::DescendantReading`; 2026-09-25). Relocking the locked reading on the
  share is option 3 of 2026-09-25 "The corpus read by the orientation-aware detector",
  undecided.
- **Dominant tape / dominant replicator** — the most populous tape among the `top_k` that
  passes the replicator test; where none passes, the world's most populous tape, with
  `dominant_replicates` false (§1.2; 2026-09-15, "read whether or not it replicates").
- **Complexity of the dominant replicator** — read off `dominant_instruction_count`, not
  `dominant_compressed_len`, which saturates at the cap plus zlib's 11 bytes (2026-09-16,
  "Complexity is read off the instruction count"). The **conserved core**
  (`conserved_core_bytes` / `_ops`) is the positions 9 of 10 of the largest lineage agree
  on, its partner reading (2026-09-16).
- **Plateau / keeps rising / measured run** — a measured run keeps rising when the median
  instruction count of its last post-crossing decile beats its first by ≥ 20% with the core
  not falling, and plateaus within ±10%. An arm keeps rising or plateaus when at least half
  its measured runs do, reads **mixed** when it clears both bars and **neither** when it clears
  none, and reads at all only on two measured emerged runs or a barren block (§1.3 sweep 9).
  **Measured** is the post-hoc amended rule of 2026-09-21.
- **Copy cost / copy latency** — `copy_cost`: median interpreter steps of the replicator
  test's passing trials for the dominant replicator, null when none passes and undefined for
  a reverse copier, whose loop never halts (2026-09-13). `copy_latency` (with
  `copy_latency_orientation`): the step at which the partner first holds a complete image
  of the dominant tape in either orientation, median of 5 trials, its companion (§1.2;
  2026-09-25, "Oriented companions"; #255).

## The lab record

- **Sweep / experiment** — a sweep is one `Lab::SWEEPS` entry and one `Experiment` row: a
  numbered item of §1.3, or a re-run or control beside them (`mutation_rate_long`,
  `bff_control`). Its slug is its key in URL form (`from_emerged` → `from-emerged`).
- **Arm** — one parameter point of a sweep; the **control** arm has the sweep's treatment
  off. An **economy** is sweep 9's `(energy_influx, steal_amount)` bundle,
  one arm value (§1.3 sweep 9).
- **Seed / seed-block** — the seed fixes a run given its params; a seed-block is ten seeds.
  An arm with ten or more terminal runs and none emerged is **barren** ("never emerged"):
  evidence, not an untested arm (2026-09-15, "An arm run to ten seeds").
- **Run** — one `(params, seed)` execution, `pending → claimed → running → finished |
  failed`. A **descendant run** starts from its **parent**'s stored world at
  `parent_epoch` and is determined by `(parent world, params, seed)`; its `epochs` is
  absolute (§1.1, "Determinism"; 2026-09-25, "Runs that start from an emerged world").
- **Sample** — one row of observables every `sample_every` epochs: the live record,
  written only while the run runs (§2).
- **Snapshot** — a compressed world plus a PNG thumbnail, with a reason (`cadence`, `age`,
  `crossing`, `transition`, `census`); a terminal run keeps only some (§2; 2026-09-10,
  "Snapshot retention"). Format versions: ADR 0003.
- **Reading / instrument** — a `snapshot_readings` row: a stored world restored, stepped
  and read by a named, versioned **instrument**. `oriented_census/1` reads the census
  companions and both copy rates; `oriented_census/2` adds the oriented lineage variation,
  the oriented core and `copy_latency`. An instrument version never changes once readings
  exist under it (§2; #246). A **rescore** is the older kind: a stored world re-read at
  another `top_k`, in `rescores` (2026-09-18).

## How claims are made

- **Pre-registration** — a design-record entry that fixes a sweep's hypotheses, arms,
  seeds and reading rule before any of its runs is read; the numbers live in a `Lab::`
  reading module (`Lab::LineageDiversityReading`, `Lab::LocalityEmergenceReading`, …).
- **Clarification** — an entry that closes places a pre-registered rule could read two
  ways, written before any run it governs was read (2026-09-25, "six clarifications" and
  "five clarifications"). A rule changed after the data were seen is a **post-hoc
  amendment**, and every finding using it says what the registered rule read (2026-09-21).
- **Exploratory** — a pattern seen before any rule was written; it is put to fresh worlds,
  not claimed (2026-09-27, "Does emergence peak at an intermediate reach?").
- **Finding** — a published claim: a `Findings::Finding` in `Findings::Registry` with an ERB
  body, not a database row (#15). Its **registry status** is `open` (sweep running),
  `partial` (read, not final), `published` (every run finished, claim stands) or `negative`
  (the effect was not there). An **instrument note** is its caveat about the census blind
  spot (#252).
- **Theft evolved** — a steal arm whose `steal_rate` leaves zero; one that never does reads
  "theft never evolved", never "theft does not help" (§1.3 sweep 9).

## The rungs

The ladder from emergence up, each rung with its observable and refutable sweep
(2026-09-11, "The evolution programme", #143):

0. **Emergence** — does a self-replicator arise from a random soup at all, and how fast;
   §1's question, called rung 0 in the 2026-09-27 locality entry.
1. **Persistence** — a colony that does not collapse (relapse hazard).
2. **Heredity with variation** — lineages that share ancestry and drift apart.
3. **Adaptation** — later replicators outcompeting earlier ones; copy cost falling.
4. **Open-ended evolution** — the complexity of the dominant replicator rising rather than
   plateauing.
