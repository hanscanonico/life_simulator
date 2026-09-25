# Life Simulator — design of record

simulator-life.com is a research instrument and a public window on it. The question it
exists to answer:

> Under what conditions does life (a self-replicating, evolving structure) emerge
> spontaneously from non-living matter, and how does the time to emergence scale with the
> properties of the substrate?

Everything below is a locked decision unless a later entry in `docs/design_record.md`
revises it. Implementers follow it; scouts do not propose against it.

## 1. Research programme

### 1.1 The substrate: a spatial program soup ("Soup")

The only known minimal system in which self-replicators arise *without any fitness
function or selection pressure* is a soup of tiny programs that execute each other
(Agüera y Arcas et al., "Computational Life", 2024 — the "BFF" substrate). We take that
substrate and make it spatial, so it looks and behaves like a cellular automaton:

- **World**: a 2D torus, `width × height` cells. Every cell holds one **tape** of
  `tape_len` bytes (default 64). Tapes are the only state. There is no fitness and no
  reproduction rule: any copying that happens is done by the programs themselves. Energy
  is off by default and optional — as a per-epoch allowance (`energy_per_epoch`, sweep 6
  below) or as a stock that carries across epochs (`energy_influx`, below).
- **Interaction** (one per cell per epoch, cells visited in a random order): the cell
  picks a random neighbour within `radius` (Moore neighbourhood, default 1). The two
  tapes are concatenated (`A ++ B`, 2×`tape_len` bytes) and the concatenation is
  executed as a program for at most `max_steps` instructions (default 2^13). The result
  is split back into the two cells. Execution mutates the tapes in place: the program
  *is* the data.
- **Execution mode** (`interaction`, default `concat`): at `concat` the whole
  concatenation is the program, which is the substrate above. At `host` the pairing is
  asymmetric — the instruction pointer ranges over the **first tape's bytes only**, so a
  bracket whose match lies past them jumps out of the code and ends the run, exactly as
  stepping off the end does. Both heads still range over the whole concatenation, so the
  partner is pure read/write substrate: what a tape does is decided by its own code, and
  what happens to a tape is decided by how the tapes that host it treat it as data. That
  asymmetry is the precondition for parasitism and defence, which the symmetric pairing
  cannot express. At `concat` the pointer stops where it always stopped and the soup is
  exactly the substrate above.
- **Instruction cost** (`energy_per_epoch`, default `0` = off): with a budget set, every
  cell starts each epoch with that many instructions to spend, an interaction may execute
  no more than what the poorer of its two cells has left — so it halts early once they run
  dry — and both cells are debited what it executed. At `0` nothing is counted and the
  soup is exactly the substrate above.
- **Energy stock** (`energy_influx`, default `0` = off; `energy_stock_cap`): with an influx
  set, every cell holds a stock of instruction energy that **carries across epochs** rather
  than being refilled to an allowance. Each epoch adds `energy_influx` to every cell's
  stock, never past `energy_stock_cap` (the stock every cell also starts the run with, so
  the world's total energy never exceeds cell count × cap); an interaction may execute no
  more instructions than the poorer of its two cells holds and debits both of them what it
  ran; and a cell whose stock is empty is passed over entirely until a later epoch's influx
  has recharged it. The stock is state of the world: it is hashed with the tapes and travels
  in the snapshot, so a resumed run carries the energy its cells had. At `0` no stock is
  allocated, no cell is gated and the soup is exactly the substrate above. Independent of
  `energy_per_epoch`: a run may carry either, both (an interaction is then bounded by
  whichever is poorer) or neither.
- **Steal op** (`steal_amount`, default `0` = off; `steal_loss`): with an amount set, the
  byte `$` (0x24) becomes an eleventh instruction on a world whose cells hold an energy
  stock. Each execution moves `steal_amount` of instruction energy out of the **partner**
  cell's stock into the stock of the cell whose code is executing, destroying the
  `steal_loss` share of what that one op moved on the way — theft is possible, costly to the world, and
  something a tape can be structured to resist. The thief is read off the instruction
  pointer: the first tape's bytes are the first cell's code and everything past them is the
  second cell's, which under `interaction = host` makes every steal the host's, exactly as
  the execution cost is already charged to both cells of the pair. A partner poorer than the
  amount gives up what it holds and no more, an empty partner gives up nothing, and the
  thief's gain is capped at `energy_stock_cap` like any other, so the world's total energy
  still never exceeds cell count × cap. The move is settled **after** the interaction has
  been debited for the instructions it ran, so a cell can never be robbed of energy it has
  already spent. An interaction's steals settle **one op at a time**, in order, each taking
  from what the partner still holds, and the share the thief receives of each is **rounded
  down** — theft never pays the thief more than the fraction says. Taking the loss per op
  rather than on an interaction's total is what makes a small amount pure destruction: one
  steal of `1` at a loss of `0.5` delivers `floor(0.5) = 0`, so a sweep has to pick an amount
  and a loss whose per-op yield `floor(steal_amount * (1 - steal_loss))` is non-zero for
  theft to pay at all. The op is not one of the ten: `op_density` and the
  instruction counts read the BFF instruction set, and `ops` ablates that set alone. At `0`
  the byte is a no-op like any other non-instruction byte, nothing is settled and the soup is
  exactly the substrate above; an amount without an `energy_influx` behind it is refused,
  since there would be no stock to take from.
- **Room to grow** (`max_tape_len`, default `0` = off): with a cap set above `tape_len`,
  a head that steps right off the end of the concatenation claims a fresh zero byte and
  moves onto it instead of wrapping, while the second tape is shorter than the cap. The
  split back into the two cells keeps the first tape's length, so the tape that lengthens
  is the one a copier writes into; a tape never shortens. At `0` — and at a cap equal to
  `tape_len` — no head ever claims a byte and the soup is exactly the substrate above.
- **Instruction set** (BFF, 10 ops on the byte value; every other byte is a no-op):
  `<` `>` move head0 −1/+1; `{` `}` move head1 −1/+1; `+` `-` inc/dec byte at head0;
  `.` copy byte at head0 → head1; `,` copy byte at head1 → head0; `[` jump forward past
  matching `]` if byte at head0 is 0; `]` jump back to matching `[` if byte at head0 is
  non-zero. Both heads start at 0; the instruction pointer starts at 0 and stops at end of
  tape, at `max_steps`, at the end of the host's code under an asymmetric `interaction`,
  or on an unmatched bracket. Heads wrap modulo the concatenation's
  current length — 2×`tape_len` unless the tapes have room to grow.
- **Mutation**: after every epoch each byte is replaced by a uniformly random byte with
  probability `mutation_rate` (default 1/4096 per byte per epoch... tune by measurement).
- **Environmental structure** (`structure`, default `uniform` = off): with a structure
  set, the mutation rate a cell lives under scales with where the cell sits, between
  `1 - structure_amplitude` and `1 + structure_amplitude` times `mutation_rate` (clamped
  to a probability). `gradient` runs a triangle across the columns, driest at column 0 and
  wettest half a world east; `patchwork` runs four quadrants alternating dry and wet. At
  `uniform` the rate is `mutation_rate` everywhere and the world is exactly the one above:
  the same bytes are offered the same draws in the same order.
- **Initial state**: every byte uniformly random (`init = random`), or every byte zero
  (`init = zero`) — a control that must never produce replicators without mutation.
- **Determinism**: a run is fully determined by `(params, seed)`. Same inputs, same
  bytes, on native and on wasm. RNG is `xoshiro256**` seeded from the run seed; per-epoch
  visiting order and neighbour choice come from that stream only. A **descendant** run,
  which starts from a finished parent run's stored world instead of an initial state, is
  fully determined by `(parent run's world at parent_epoch, params, seed)`, its epoch count
  continuing the parent's; it may change the parent's dynamics but not the world's shape
  (`docs/design_record.md`, 2026-09-25, "Runs that start from an emerged world").

The ordinary Game of Life (`B3/S23`) is also shipped, as the `Life` substrate, because it
is what visitors recognise. It shares the viewer and the run pipeline but no research
claim rests on it.

### 1.2 Observables (recorded every `sample_every` epochs)

- `compress_ratio`: `zlib(all tapes).len / raw.len`. Random soup ≈ 1.0; a soup of
  replicators collapses well below 0.5. This is the BFF paper's headline signal.
- `distinct_tapes`: number of distinct tape values in the world.
- `top_share`: fraction of cells holding the single most common tape.
- `op_density`: fraction of bytes that are one of the 10 instructions (random ≈ 10/256).
- `replicator_count`: how many cells pass the replicator test (below), on the first of
  the census's draws — the reading every sample in the record carries.
- `replicator_pass_rate`: the share of the census's 8 independent draws in which some
  tape passed. A tape at the edge of the test passes or fails at random, so this is what
  says whether a count of 0 is an empty world or a draw that missed.
- `replicator_count_mean`: the mean of what those 8 draws counted.
- `replicator_share` / `replicator_share_rotated` / `dominant_self_replicates`: the
  **orientation-aware companions** of the census. `replicator_share` is the share of 256
  cells, drawn uniformly with replacement, whose tape passes the orientation-aware detector
  (below) aligned; `replicator_share_rotated` reads the same draw under the detector's best
  rotation, so it is never below the first; `dominant_self_replicates` says whether the
  dominant tape — the one `dominant_replicates` describes — passes aligned.
  `replicator_count` and `copy_rate` stay exactly as locked, and they are orientation-blind
  by definition: each asks for a copy in the tape's own orientation. These companions exist
  because the dominant replicators of the corpus copy themselves in **reverse**, which both
  locked readings count as nothing (docs/design_record.md 2026-09-25). They draw from
  streams of their own, a pure function of `(seed, epoch)`, and write nothing back, so no
  run and no other observable moves. The census's `top_k` window does not bound them: the
  cells are drawn from the whole world. Null on the life substrate and on every sample
  recorded before they existed.
- `entropy_bits`: Shannon entropy of the byte distribution.
- `alphabet_size`: how many of the 256 byte values the world still holds, 1–256. Only
  `+` and `-` can mint a byte value, so with `mutation_rate = 0` the alphabet is a
  one-way coalescent: it can collapse onto a couple of instruction bytes, which reads
  compressible and all-ops while replicating nothing. Life cells are `0`/`1`, so it
  reads 2.
- `copy_rate`: share of the sampled epoch's interactions that ended with one tape copied
  byte-exactly over the other half (either direction), among the pairs that did not
  arrive a copy already — a pair that arrives one ends one whatever runs, so it is not a
  copy. A half counts as copied when it ends holding a byte-exact image of the tape its
  partner arrived with, read from its first byte: bytes past the image — the room a tape
  free to grow claimed — do not unmake the copy, and a half too short to hold the whole
  source is no copy of it. The exclusion reads that same rule on the pair as it arrived,
  so a frozen world of tapes and the tapes they lengthened into reports no copies; on two
  halves of equal length both readings are the plain equality they always were. Replication caught in situ, so it sees the replicators the
  replicator test misses — those that only copy with a kin partner or into a particular
  layout. Counted only on the epochs a sample reads; the life substrate reports 0.
- `reverse_copy_rate`: `copy_rate` with the image reversed — the share of the same
  interactions that ended with one half holding the byte-exact **reverse** of the tape its
  partner arrived with, read from the half's first byte over the partner's arriving length,
  among the pairs that did not arrive that way. A companion (docs/design_record.md
  2026-09-25): `copy_rate` is untouched by it to the bit. A palindrome's copy satisfies both
  rules and counts in both rates. Counted only on the epochs a sample reads; the life
  substrate reports 0, and every sample recorded before it existed carries none.
- `distinct_lineages`: how many lineage ids the cells hold. Every cell starts its own at
  init; after an interaction a cell takes its partner's lineage id when the tape it ends
  with is closer — Hamming distance over the tape's bytes — to the tape its partner
  arrived with than to the tape it arrived with itself, and keeps its own on a tie. The
  reading counts descent rather than shape, so two lineages that drifted onto the same
  tape still read as two. Tags sit beside the tapes: they are never written into a tape,
  never drawn from the RNG stream, and mutation never moves one, so a run's bytes are what
  they were before lineages existed. A snapshot (format version 3) carries the tags beside
  the tapes, so a run resumed from one continues the census it was keeping; a version 1 or
  2 blob, written before the tags existed, restores with one id per cell. The life
  substrate reports 0.
- `top_lineage_share`: fraction of cells held by the largest lineage.
- `lineage_variation`: heredity with variation, measured, in bytes per cell. Rank the
  lineages that hold **at least 2 cells** by population and take the 8 largest (ties by
  lowest lineage id). For each the reading takes that lineage's **modal tape** — the tape
  most of its cells hold, the lowest tape of any that tie — and the mean number of bytes by
  which a member differs from it, Hamming distance again, **pooled** over those lineages'
  cells rather than averaged per lineage, so a big lineage weighs what it holds. A colony
  of clones reads 0 and a lineage drifting under mutation reads more the further it has
  drifted; a world with no lineage of 2 reads 0. Singletons are excluded because a cell
  alone in its lineage sits at distance 0 from itself, and the crowd of them a young soup
  carries would dilute a drifting colony to nothing. The 8 is a constant of the engine
  (`metrics::VARIATION_TOP_LINEAGES`), not a parameter. The life substrate reports 0.
- `lineage_variation_oriented`: `lineage_variation` read after each member of those same
  lineages is put **the way round** — its live bytes as they are, or last to first — that is
  Hamming-closer to its lineage's modal tape, a tie keeping it as it is; the modal tape and
  the pooled mean are then read exactly as above, over the oriented members. A companion
  (docs/design_record.md 2026-09-25): the emerged replicators copy themselves in reverse, so
  a lineage of near-clones is half `X` and half `reverse(X)`, and the aligned reading counts
  every reversed member as most of a tape of variation. A tape that grew is reversed over
  its own live length, never over its slot. The lineage tags themselves are still inherited
  by the aligned rule above, so after a takeover one lineage can hold unrelated tapes and
  neither reading can see past that. It draws nothing; the life substrate reports 0, and
  every sample recorded before it existed carries none.
- `conserved_core_bytes` / `conserved_core_ops`: what the largest lineage holds
  invariant across its members — the reading that tells a conserved copy loop with junk
  around it from turnover at a flat size, which `lineage_variation` alone cannot. The
  sampling rule is the one `lineage_variation` ranks by: the largest lineage that holds
  **at least 2 cells** (ties by lowest lineage id), read off the cells the sample has
  already ranked, so the reading draws nothing and no RNG stream moves. A byte **position**
  counts as conserved when at least **9 of every 10** members hold one and the same value
  there — a ratio of two integers, so exactly nine in ten is inside the core and eight is
  not, and never a rounded 0.9 (`metrics::CONSERVED_CORE_SHARE_NUMERATOR` over
  `_DENOMINATOR`, a constant of the engine and not a parameter). A member too short to
  reach a position holds nothing there and agrees with nobody, the same reading
  `lineage_variation` makes of a tape that grew. The first count is those positions; the
  second is how many of them hold a byte the run's own instruction set executes, so a core
  of program can be told from a core of junk held still. A lineage of clones reads its whole
  tape length; a lineage whose every position drifts reads 0. Both are null where no lineage
  holds two cells, on the life substrate, and on every sample recorded before they existed.
  The reading costs one pass over the top lineage's tapes — members × tape length — per
  sample.
- `conserved_core_bytes_oriented` / `conserved_core_ops_oriented`: the same two counts over
  the same lineage, read after each member is put the way round that is Hamming-closer to
  that lineage's modal tape, as `lineage_variation_oriented` puts them. A lineage of a tape
  and its reverse agrees aligned only on the positions the two happen to share, and on its
  whole length oriented. Null exactly where the aligned counts are, and on every sample
  recorded before they existed.
- `copy_cost`: interpreter steps per byte-exact copy by the **dominant replicator** — the
  most populous tape among the `top_k` tested that passes the replicator test. The test
  already executes four trials per tape; the reading is the **median** of the steps the
  passing trials took, the lower of the two middles on an even count, so it is always a
  price some trial paid. Null when no tested tape replicates, and on the life substrate.
  It is read off the runs the test performs — same order, same stream, no trial re-run —
  so it moves no tape byte and draws nothing. The hand-written replicator of the engine's
  test suite costs 1 794 steps.
- `copy_latency` / `copy_latency_orientation`: how soon the **dominant tape** — the tape
  `dominant_replicates` describes — has written itself: the interpreter step at which the
  partner half first holds a complete byte-exact image of the tape, **in either
  orientation**, whatever the program goes on to do. A companion of `copy_cost`
  (docs/design_record.md 2026-09-25), which stays as locked: it prices a copy that halted,
  and is undefined for the reverse copiers that dominate every emerged world, whose loop
  never exits and runs out `max_steps`. The setup is the orientation-aware detector's —
  the fixed `2·len` buffer, a fresh noise partner, `max_steps` — one generation per trial
  over `SELF_REP_TRIALS` (5) trials, on a stream of its own. The reading is the **median**
  trial, a trial that never completes an image ranking after every one that does, so it is
  null where fewer than half the trials complete one; the orientation is that trial's —
  `forward`, `reverse`, or `both` for a palindrome. The watch runs in a replica of the
  interpreter kept only for this reading, pinned step for step against it, so the soup's own
  interactions pay nothing for it. The hand-written replicator reads 1 790 steps forward, four
  before it halts; a reverse copier that copies a byte every four steps reads `4L − 1`,
  reverse. Null on the life substrate and on every sample recorded before they existed.
- `dominant_compressed_len` / `dominant_instruction_count` / `dominant_replicates`: how much
  tape the **dominant tape** is, read two ways — the length in bytes of its tape under the
  same zlib compressor `compress_ratio` uses, and how many of its bytes the run's own
  instruction set executes (all ten unless `ops` ablates some) — with the boolean saying
  whether that tape passed the replicator test. The dominant tape is the most populous tape
  among the `top_k` tested that passes the test, which is the very tape `copy_cost` is priced
  on, so wherever something replicates the three readings describe one tape and
  `dominant_replicates` is true. Where nothing among the tested tapes passes, the reading is
  of the most populous tape of the world and `dominant_replicates` is false: an emergence
  confirmed by `copy_rate` alone would otherwise be unmeasurable, and after such a crossing
  the tape most cells hold is the thing that is copying (`docs/design_record.md`,
  2026-09-15). Exactly one tape is compressed per sample either way. Null only on the life
  substrate, which has no tapes. Together the lengths are the open-endedness baseline every
  later substrate is measured against — read after a confirmed emergence: a world whose
  dominant tape keeps getting more complicated reads a rising length, a world that found one
  recipe and stopped reads a flat one. The hand-written replicator of the engine's test suite
  reads 36 bytes and 15 instructions.
- `dominant_raw_len` / `dominant_tape_hash`: the same tape's own length in bytes before
  zlib, and a stable digest of those bytes. The length is what makes the compressed reading
  readable: zlib's envelope on an incompressible tape is 11 bytes, so a tape of random bytes
  compresses to `raw + 11` and `dominant_compressed_len` alone cannot be told from the tape
  cap (`docs/design_record.md`, 2026-09-16). Compressed over raw near 1 is junk; well under 1
  is a tape with structure in it. The hash is **FNV-1a 64** of the tape bytes — the engine's
  own `hash::fnv1a64`, not a platform hasher — written as sixteen lowercase hex digits, so it
  is the same value on every platform and every build and survives a JSON reader that parses
  numbers as doubles. It carries no magnitude and is only ever compared for equality: two
  consecutive samples with different hashes are two different dominant tapes, which is what
  the run page's turnover series counts. Both are null exactly where the two readings above
  are — the life substrate — and both are null on every sample recorded before they existed.
- `lineage_compressed_len` / `lineage_instruction_count`: the two readings above, taken of
  a tape chosen by **descent** rather than by population — the representative of the largest
  lineage. The dominant tape is whichever tape most cells hold at that sample, and it
  rotates: a lineage that keeps getting more complicated while its modal tape turns over
  reads flat through the dominant series (`docs/design_record.md`, 2026-09-19). The lineage
  is the one `conserved_core` and `lineage_variation` already rank — the largest that holds
  **at least 2 cells**, ties by lowest lineage id — and the representative is its **modal
  tape**, ties by the lowest tape value, the rule `lineage_variation` already reads a modal
  tape by. Both halves are functions of the world alone, so a run resumed from a snapshot
  reads the representative the run that wrote it read. One more tape is compressed per
  sample and no RNG stream moves. Null where no lineage holds two cells, on the life
  substrate, and on every sample recorded before they existed. The per-tape series stays
  exactly as it is: every finding in the record reads it, and no backfill is possible.
- `steal_rate`: share of the sampled epoch's interactions in which a steal executed — at
  least one `$` op ran, whichever half of the pair ran it and whatever it managed to take,
  so an interaction against an empty partner counts like any other. Counted over the
  interactions that ran, on the epochs a sample reads, exactly as `copy_rate` is: a pair the
  stock starved never ran and is in neither half. Theft caught in situ, and the reading that
  tells an arm where theft never evolved from one where it was suppressed — or never
  possible. 0 wherever the steal op is off, which is every run at the defaults, and on the
  life substrate.
- `transition_epoch` (per run, once): first sampled epoch at which a *qualifying* sample
  appears and the next 3 samples all qualify. A sample qualifies when `compress_ratio <
  0.6` **and** `op_density <= 0.9` **and** `alphabet_size >= 16` — the last two guard
  against alphabet collapse, which produces a compressible world with no replication at
  all (run 183: two byte values, `op_density` exactly 1.0, `copy_rate` 0). Null until it
  happens. The primary dependent variable of every sweep is this number. The engine's
  tracker is the single authority on this rule; Rails only re-reads stored samples by it,
  from the one place that spells the predicate out (`Lab::TransitionRule`) — to recover
  the epoch of a run measured before the tracker survived a resume
  (`Runs::TransitionEpochService`) and to read what became of the world after that epoch
  (`Runs::PersistenceSummaryService`). Samples recorded before `alphabet_size` existed
  are read by the `op_density` half of the guard alone. The crossing is a *candidate*: it
  reads `compress_ratio` and its two guards, never a copier, so a world whose random fill
  merely settled can carry one. `emergence_epoch` is the first of the run's crossings a
  witness confirms, the detector's stored one or any later crossing its samples hold
  (`Runs::CrossingsService`) — the replicator census or `copy_rate` positive within the
  confirmation window (`Runs::EmergenceEpochService`, docs/design_record.md 2026-09-15) —
  and it, not `transition_epoch`, is what the open-endedness findings read.
- `transition_epoch_relative` (per run, once): the same measurement read against the run's
  own start instead of the constant threshold — the first sampled epoch at which
  `compress_ratio <= 0.61 x baseline` and the next 3 samples do too, under the same two
  collapse guards, where `baseline` is the mean `compress_ratio` of the samples with epoch
  <= 500 (docs/design_record.md 2026-09-19). A **companion** reading: a fresh soup's
  `compress_ratio` depends on `max_tape_len`, so the constant threshold means different
  things across the cap, and this says how far a run fell in its own terms.
  `transition_epoch` above remains the primary dependent variable of every sweep and what
  every finding is stated in; this one is reported beside it and relocks nothing.

**Replicator test**: a tape `T` is a replicator if executing `T ++ R` for a random tape
`R` (fresh, seeded) yields `T` in the second half for at least 3 of 4 trials. Run on the
`top_k` (default 16) most common tapes each sample; `replicator_count` counts cells
holding a tape that passed. The trial is seeded per epoch, so a rescore of a stored world
is comparable only with the live sample at the same epoch (docs/design_record.md
2026-09-18). The census runs the test **8 times**, each draw on its own seeded stream and
a pure function of `(seed, epoch, draw)`: `replicator_count` is draw 0, and
`replicator_pass_rate` and `replicator_count_mean` read across all eight. The test asks for
`T` itself in the partner, so a tape that writes `reverse(T)` fails it however exactly it
copies; it stays locked as it is, and the orientation-aware detector below reads beside it.

**Orientation-aware detector** (`replicator::self_replicates`, modelled on the 2026 BFF
paper's Algorithm 1 and cubff's `CheckSelfRep`): a chain of **5** runs, each the soup's own
interaction — the tape of the moment and fresh seeded noise of its length on the fixed
`2·len` buffer, `max_steps` as the run's. After each run the partner half carries forward
into the first half and fresh noise refills the second; after the fifth, the first half —
the fourth copy down the chain — is compared with the original, position by position. The
chain is odd so that a tape whose copy is its own reverse is read after an even number of
copies, back in its own orientation. **5** independent chains per tape; a position agrees
when a strict majority of them hold the original byte there, and the tape passes
**aligned** when at least **3 of every 4** positions agree (the paper's 48 of 64 bytes, as
a ratio of integers so it scales to any length). It passes **rotated** when some cyclic
rotation of the comparison, one rotation for all five chains, passes the same bar — a
separate boolean, so the aligned reading stays the paper's. It departs from the paper in
three places, each toward a stricter or plainer reading: 5 chains where the paper runs 9
(cubff 13), and a position agrees on a strict majority of them where the paper asks for 3
of its 9 (cubff more than 3 of 13); only the carried first half is scored, where both also
score how far the chains' second halves agree with one another and keep the smaller score;
and every run draws fresh noise, where cubff reuses one chain's noise down its runs. The
census companions run it on **256** cells a sample. The chain length, the trials, the 3/4
and the 256 are constants of the engine (`replicator::SELF_REP_*`), exported through
`runner schema` under `self_replication`; they are not parameters. Measured on the
terminal worlds of runs 1007, 1029 and 1087 (128×128, every interaction running out the
step budget), one sample's companions cost about 4% (3.7–4.1%) of the ten epochs they
sample.

### 1.3 The sweeps (in order; each is one `Experiment`)

1. **Mutation rate** — `mutation_rate ∈ {0, 2^-16 … 2^-8}` at fixed 128×128, 10 seeds
   each. Hypothesis: there is a window; zero mutation delays emergence, too much
   destroys it (error threshold, as in Eigen's quasispecies).
2. **World size** — `{32², 64², 128², 256²}`. Does time to emergence scale with cell
   count (more lottery tickets) or is it a per-cell rate?
3. **Neighbourhood radius** — `{1, 2, 4, ∞ (well-mixed)}`. Spatial locality is the
   variable the original BFF work never varied. Hypothesis: locality speeds emergence
   (a replicator only has to beat its neighbours) and stabilises diversity afterwards.
4. **Max steps per interaction** — `{2^8, 2^10, 2^13, 2^16}`.
5. **Instruction set ablations** — remove `,`, remove loops, etc. Which ops are
   necessary for abiogenesis?
6. **Instruction cost** — `energy_per_epoch ∈ {0 (off), 2^15, 2^13, 2^11}`, the arm at 0
   being the costless substrate every earlier sweep ran. Hypothesis: a cost pressure
   selects for efficient copiers and opens a second niche. 30 seeds per arm rather than
   the usual 10: emergence at 128×128 runs about 1 in 10 and the open-endedness findings
   need two emerged runs in an arm before they read that arm.
7. **Environmental structure** — `structure ∈ {uniform (off), gradient, patchwork}` at
   `structure_amplitude` 0.75, the uniform arm being the world every earlier sweep ran.
   Hypothesis: environmental structure raises the plateau the dominant replicator's
   complexity settles at, refuted if a world whose regions differ plateaus where a uniform
   world does. Secondary prediction: a heterogeneous world keeps more lineages alive after
   emergence. 30 seeds per arm rather than the usual 10, for the same reason as sweep 6.
   The gradient and patchwork arms run 90 seeds and the uniform control 30: after 30 seeds
   gradient has one emerged run carrying a complexity reading and patchwork none, short of
   the two the finding reads an arm on, while the control already has both.
8. **Room to grow** — `max_tape_len ∈ {64 (= tape_len, off), 128, 256, 512}`, the arm at
   the initial length being the fixed-tape world every earlier sweep ran. Hypothesis:
   room to grow raises the plateau the dominant replicator's complexity settles at,
   refuted if tapes free to lengthen plateau where fixed-length tapes do — which would
   say the 64-byte ceiling was never the binding constraint. 30 seeds per arm rather than
   the usual 10: emergence at 128×128 runs about 1 in 10 and the complexity finding needs
   two emerged runs in an arm before it reads that arm. The 128 and 256 arms run 90 seeds
   and the control and 512 arms 30: only those two have an emerged run whose plateau is
   measured and need a second one, the control is already comparable, and 512 emerged in
   none of a full seed-block.
9. **Host–parasite economy** — does complexity keep rising when energy is a contested
   stock? Sweeps 6–8 are spent: complexity rises at emergence and plateaus within 20 000
   epochs on every substrate tested, because a byte off the copy path costs a tape nothing
   and there is no quantity any tape can take from another. This sweep prices that. Arms
   are an **economy** bundle — `(energy_influx, steal_amount)` travelling together, since
   the cartesian product would otherwise pair theft with no stock to steal from, which the
   engine refuses — crossed with the two **room-to-grow caps** whose plateau sweep 8
   measured:
   `economy ∈ {(0, 0) = off, (2^13, 0), (2^13, 2^10), (2^11, 0), (2^11, 2^10), (2^9, 0),
   (2^9, 2^10)}` × `max_tape_len ∈ {128, 256}`, at `energy_stock_cap` 2^15 and
   `steal_loss` 0.5 throughout, 128² for 20 000 epochs at the emergent mutation rate.
   The influx levels are one full-length interaction's worth per epoch (`max_steps` is
   2^13), a quarter of one and a sixteenth: a cell pairs about twice an epoch, so even the
   richest arm cannot pay for everything it could run, and the poorest is the ladder's
   bottom rung sweep 6 walked for the per-epoch tax, one notch lower because a stock
   accumulates. The cap is four full interactions — the same hoard ceiling in every arm,
   so the influx is the only energy quantity the sweep varies — and it is inert in the
   `(0, 0)` control, which is the substrate every earlier sweep ran. At the default loss
   one steal delivers 2^9: a whole epoch's influx in the poorest arm, an eighth of one in
   the richest, and never the zero a smaller amount would round to. Every arm runs 90 seeds,
   the control included: every priced arm so far lowered the emergence rate, the reading
   needs two emerged runs, and thirty seeds of this very substrate — sweep 8's 128 and 256
   arms — left one emerged run under each cap. Three arms then run seeds 1–270
   (`docs/design_record.md`, 2026-09-25): `(2^11, 2^10)` at cap 128, the one priced arm that
   read keeps rising at 90 seeds, on one of two measured runs, and its `(0, 0)` control at
   cap 128, so more emerged runs decide it; and the `(0, 0)` control at cap 256, whose
   emerged worlds join cap 128's as the parent pool of runs started from an emerged world.
   Dependent variables: `transition_epoch` and the confirmed `emergence_epoch` as in every
   sweep, then `dominant_instruction_count` and `conserved_core_bytes` as the complexity
   pair, with `dominant_compressed_len` and `steal_rate` beside them.
   **Pre-registered reading**, on emerged runs only — a crossing the replicator census or
   `copy_rate` confirmed, any crossing of the run, not the detector's first alone. Per run,
   take the samples at or after that crossing and compare the **median of the last decile**
   of them against the median of the first decile. A run is **measured** where its
   `dominant_instruction_count` first-decile median is nonzero over that span; a run
   carrying no `conserved_core_bytes` sample at all is unmeasured, since the core clause
   cannot be read. A measured run **keeps rising** when its `dominant_instruction_count`
   median rises by at least **20%** and its `conserved_core_bytes` median does not fall over
   the same span — an **absolute** comparison in bytes, so a core at zero on both ends did
   not fall; it **plateaus** when the last decile sits within **±10%** of the first. The
   measured rule and the core clause are the post-hoc amendment of `docs/design_record.md`,
   2026-09-21, made after this sweep's data were seen; the pre-registered rule required a
   nonzero first-decile median of both observables and read 25 of the 26 emerged runs as
   unmeasured, and every finding taken under the amended rule says so. An arm keeps rising when at least half of
   its measured emerged runs do, and plateaus when at least half plateau; an arm clearing
   **both** bars — one run rising against one plateauing — reads **mixed**, never rising,
   and an arm clearing **neither** bar, its runs having mostly fallen, reads **neither**.
   `dominant_compressed_len` is reported beside them and never decides: it saturates at the
   cap plus zlib's 11-byte envelope (`docs/design_record.md`, 2026-09-16). An arm reads at
   all only with **two measured emerged runs**, or a **blank block of ten** — which reads as
   an arm holding no replicator to read, not as an arm still to be tested. And a steal arm
   whose `steal_rate` never leaves zero reads **"theft never evolved"**, never "theft does
   not help": the op was available and no lineage picked it up — while an arm no
   `steal_rate` was ever sampled on reads **unmeasured**, which is no null at all.

10. **Asymmetric execution** — does complexity keep rising when only one partner's code
    runs? Sweep 9 prices energy; this one prices *whose program runs*. Under
    `interaction = host` the instruction pointer ranges over the first tape's bytes only
    while both heads still range over the whole pair, so the second tape is pure
    read/write substrate and never runs a byte of its own: its fate depends on how the
    tapes that host it treat it as data, which is a pressure on what a tape *looks like*
    and not only on what it does — the asymmetry every host–parasite system in the
    literature rests on. Arms: `interaction ∈ {concat (off, the control), host}` ×
    `max_tape_len ∈ {128, 256}`, the two room-to-grow caps whose plateau sweep 8 measured,
    since an asymmetry is only readable where the dominant tape has room to get more
    complicated. `tape_len` 64 throughout, 128² for 20 000 epochs at the emergent mutation
    rate. Every arm runs 90 seeds, the control included: the reading needs two emerged runs
    in an arm, thirty seeds of this very substrate — sweep 8's 128 and 256 arms — left one
    emerged run under each cap, and a host interaction runs only half of a pair as code, so
    its emergence rate can only be lower.
    Dependent variables: `transition_epoch` and the confirmed `emergence_epoch` as in every
    sweep, then `dominant_instruction_count` and `conserved_core_bytes` as the complexity
    pair, with `dominant_compressed_len` and `distinct_lineages` beside them.
    **Pre-registered reading**, identical to sweep 9's: on emerged runs only, the median of
    the last decile of a run's post-crossing samples against the median of its first
    decile; a run is **measured** where its `dominant_instruction_count` first-decile median
    is nonzero over that span; a measured run **keeps rising** when
    `dominant_instruction_count` rises by at least **20%** with `conserved_core_bytes` not
    falling in bytes — the absolute clause amended post hoc in `docs/design_record.md`,
    2026-09-21, and read beside what the pre-registered rule read — and **plateaus** when
    the last decile sits within **±10%** of the first; an arm keeps rising or plateaus when at least
    half of its measured runs do, reads **mixed** where it clears both bars and **neither**
    where it clears none, and reads at all only on two measured emerged runs or a blank
    block of ten. `dominant_compressed_len` is reported beside them and never decides.
    Secondary reading: a `host` arm's `distinct_lineages` in the last decile stays above
    that of the `concat` control **at the same cap**, which reads as an arms race keeping
    lineages from fixating. Refuted if the `host` arms plateau where their own `concat`
    controls plateau — same caps, same rate, same world — which would say an asymmetric
    interaction buys this substrate no structure.
11. **From an emerged world** — does an existing replicator keep getting more
    complicated once a treatment is switched on, and does it hold at all? A descendant
    sweep: every run starts from the terminal world of a sweep-9 economy-off control whose
    orientation-aware census reads at least half replicators, and continues it under its
    parent's own dynamics (the control), sweep 9's rising priced arm, the rich economy, or
    host mode — seeds 1001–1003 under every treatment, paired by (parent, seed), 20 000
    epochs past the parent. Readings per child over its own samples: persistence (held or
    relapsed, on `replicator_share`) and complexity (`dominant_instruction_count` over the
    samples whose dominant tape self-replicates), with paired sign tests against the
    continuation. Pre-registered in `docs/design_record.md`, 2026-09-25, "Runs that start
    from an emerged world", whose numbers live in `Lab::DescendantReading`.

An arm run to ten seeds — one seed-block — with nothing emerged in any of them reads as an
arm that did not raise the plateau, not as an arm still to be tested: it holds no
replicator to read (`docs/design_record.md`, 2026-09-15).

Every run records its full metric series and periodic snapshots so a claim can be
re-examined. A finding is published on the site with its phase diagram, the raw runs,
and the seed of every run.

Emergence is the first rung, not the whole programme. The ladder above it — persistence,
heredity with variation, adaptation, open-ended evolution — with the observable and the
refutable sweep for each, is the "evolution programme" entry in `docs/design_record.md`.

## 2. Architecture

```
engine/            Rust workspace — the simulation, no web code
  crates/life-engine   lib: substrates, metrics, deterministic RNG, snapshots
  crates/runner        bin: executes jobs; local mode (files) and lab mode (HTTP to Rails)
  crates/wasm          cdylib: wasm-bindgen wrapper over life-engine for the browser
app/, config/, …   Rails 8 — the site, the lab database, the runner API
deploy/            docker compose stack for the mini-pc (db, app, runner, cloudflared)
docs/              this file, design_record.md, findings
```

- **The engine is the single authority** on rules, metrics and rendering colours. Rails
  never re-implements a rule; the browser never re-implements a metric. The same crate
  compiles natively for the lab and to wasm for the viewer.
  A soup cell's colour is HSV: hue from an FNV-1a hash of the tape's *instruction
  skeleton* (its BFF ops in order, non-op bytes dropped), saturation and brightness from
  its op density, dark and grey below 25 % ops. Tapes that differ only where the
  interpreter does not look share a colour, so a colony of near-identical replicators
  reads as one hue against a near-black random soup.
- **Rails owns experiments, runs, results and the public pages.** Postgres holds
  `experiments`, `runs`, `samples` (one row per metric sample, `values jsonb`),
  `snapshots` (compressed world bytes + a PNG thumbnail rendered by the engine). Each
  snapshot records why the run loop took it: `cadence` (an epoch multiple of
  `snapshot_every`), `age` (the runner's wall-clock ceiling on snapshot age),
  `crossing` (the first *qualifying* sample — the epoch `transition_epoch` names, stored
  before the next 3 samples confirm it; at most one per `snapshot_every` epochs),
  `transition` (the sample that settled the transition) or `census` (the replicator census
  rising off zero, at most one per `snapshot_every` epochs).
- **Readings from stored worlds live in `snapshot_readings`, never in `samples`.** A
  pass over the corpus restores a kept world at `source_epoch`, steps it a few epochs
  and reads it with a named, versioned instrument (`oriented_census/1`); the runner posts
  the engine's values to `POST /api/runs/:id/readings`, keyed `(run, instrument, epoch)`
  so a repeat pass overwrites. Samples are the live record, written only while the run
  runs, and an instrument added later must not rewrite that record or pass for it.
  Readings outlive the worlds they came from: pruning snapshots never deletes them.
  `runner readings-corpus` is that pass for the orientation-aware observables: it reads
  the census companions at each stored epoch E (with `replicator_count` as the control
  against the live sample), then steps to the next sample epoch E′ and reads both copy
  rates there, which is the only place a restored world can count them. What an instrument
  version reads never changes once readings exist under it: `oriented_census/2` reads
  everything `/1` reads and adds `lineage_variation_oriented`, the oriented conserved core
  and `copy_latency` with its orientation, each beside the aligned reading it accompanies.
  It is a pass of its own (`--instrument oriented_census/2`); `/1` stays the default, and
  every summary that reads `/1` goes on reading it.
- **The runner is a stateless worker.** In lab mode it polls `POST /api/runs/claim` with
  a bearer token, executes the run, streams sample batches to
  `POST /api/runs/:id/samples`, snapshots to `POST /api/runs/:id/snapshots`, and finishes
  with `POST /api/runs/:id/finish`. Heartbeats every 30 s, each beat carrying the wall
  seconds it covers (`interval_seconds`, optional) which the app sums into the run's
  `compute_seconds`, so a run's cost survives resumes. A run claimed but not
  heartbeated for 5 min is released. Several runs execute in parallel (one thread each,
  `RUNNER_PARALLELISM`, default = cores − 2). A descendant run (the claim carries
  `parent_run_id` and `parent_epoch`) with no snapshot of its own starts from its parent's
  stored world at `parent_epoch` under its own params and seed (`World::descend`), and
  fails rather than ever starting from soup when that world cannot be fetched or read.
- **The viewer** is a `<canvas>` driven by the wasm build through one Stimulus controller.
  The engine exposes `World.new(params_json, seed)`, `step(n)`, `render_rgba(buffer)`,
  `metrics_json()`. No other custom JavaScript.
- **Charts** are server-rendered SVG (a small presenter + partial). No chart library.

## 3. Conventions

- Rails: the project guide in `CLAUDE.md` (services with `Callable`, presenters,
  Hotwire hierarchy, RSpec + FactoryBot, system specs for Stimulus controllers).
- Rust: 2021 edition, `cargo clippy -- -D warnings` clean, `cargo fmt` clean, unit tests
  beside the code, no `unsafe` outside the wasm glue. Determinism tests pin a known
  `(params, seed) → hash of world after N epochs` for every substrate.
- Gate: `make verify` (Rails specs + RuboCop + Brakeman + `cargo test` + clippy + fmt +
  wasm build). Green before any PR.
- Parameters are data: every substrate parameter has a name, a default and a validated
  range in one place in the engine (`Params`), and is exposed to Rails as JSON schema
  via `runner schema`.
- Secrets never enter the repo; `deploy/.env.example` lists them.

## 4. Deployment

Copied from the `grid_commanders`/`stock_market` pattern on the mini-pc
(`mini-pc@192.168.1.37`, checkout at `~/Documents/life_simulator`):

- `deploy/docker-compose.yml`: `db` (postgres 17, volume `pgdata`), `app` (Rails,
  `127.0.0.1:8070:8080`, healthcheck `/up`, Solid Queue in Puma), `runner` (the Rust
  binary in lab mode, talking to `app`), `cloudflared` (token from `.env`).
- `deploy/deploy`: fetch + ff-only merge, build, `up -d`, wait healthy, roll back to the
  `:previous` image on failure. Same shape as `grid_commanders/deploy/web/deploy`.
- `deploy/systemd/`: nightly `pg_dump` timer like the stock market one.
- Cloudflare: one tunnel `life-simulator` in the existing account, public hostname
  `simulator-life.com` → `http://app:8080`.
