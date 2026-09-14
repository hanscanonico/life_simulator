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
  is off by default and optional (`energy_per_epoch`, sweep 6 below).
- **Interaction** (one per cell per epoch, cells visited in a random order): the cell
  picks a random neighbour within `radius` (Moore neighbourhood, default 1). The two
  tapes are concatenated (`A ++ B`, 2×`tape_len` bytes) and the concatenation is
  executed as a program for at most `max_steps` instructions (default 2^13). The result
  is split back into the two cells. Execution mutates the tapes in place: the program
  *is* the data.
- **Instruction cost** (`energy_per_epoch`, default `0` = off): with a budget set, every
  cell starts each epoch with that many instructions to spend, an interaction may execute
  no more than what the poorer of its two cells has left — so it halts early once they run
  dry — and both cells are debited what it executed. At `0` nothing is counted and the
  soup is exactly the substrate above.
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
  tape, at `max_steps`, or on an unmatched bracket. Heads wrap modulo the concatenation's
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
  visiting order and neighbour choice come from that stream only.

The ordinary Game of Life (`B3/S23`) is also shipped, as the `Life` substrate, because it
is what visitors recognise. It shares the viewer and the run pipeline but no research
claim rests on it.

### 1.2 Observables (recorded every `sample_every` epochs)

- `compress_ratio`: `zlib(all tapes).len / raw.len`. Random soup ≈ 1.0; a soup of
  replicators collapses well below 0.5. This is the BFF paper's headline signal.
- `distinct_tapes`: number of distinct tape values in the world.
- `top_share`: fraction of cells holding the single most common tape.
- `op_density`: fraction of bytes that are one of the 10 instructions (random ≈ 10/256).
- `replicator_count`: how many cells pass the replicator test (below).
- `entropy_bits`: Shannon entropy of the byte distribution.
- `alphabet_size`: how many of the 256 byte values the world still holds, 1–256. Only
  `+` and `-` can mint a byte value, so with `mutation_rate = 0` the alphabet is a
  one-way coalescent: it can collapse onto a couple of instruction bytes, which reads
  compressible and all-ops while replicating nothing. Life cells are `0`/`1`, so it
  reads 2.
- `copy_rate`: share of the sampled epoch's interactions that ended with one tape copied
  byte-exactly over the other half (either direction), among the pairs whose two halves
  started out different — halves that arrive identical end that way whatever runs, so
  they are not a copy. Replication caught in situ, so it sees the replicators the
  replicator test misses — those that only copy with a kin partner or into a particular
  layout. Counted only on the epochs a sample reads; the life substrate reports 0.
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
- `copy_cost`: interpreter steps per byte-exact copy by the **dominant replicator** — the
  most populous tape among the `top_k` tested that passes the replicator test. The test
  already executes four trials per tape; the reading is the **median** of the steps the
  passing trials took, the lower of the two middles on an even count, so it is always a
  price some trial paid. Null when no tested tape replicates, and on the life substrate.
  It is read off the runs the test performs — same order, same stream, no trial re-run —
  so it moves no tape byte and draws nothing. The hand-written replicator of the engine's
  test suite costs 1 794 steps.
- `dominant_compressed_len` / `dominant_instruction_count`: how much tape the **dominant
  replicator** is, read two ways — the length in bytes of its tape under the same zlib
  compressor `compress_ratio` uses, and how many of its bytes the run's own instruction set
  executes (all ten unless `ops` ablates some). Read off the very tape `copy_cost` is priced
  on, so the three observables describe one tape; null when no tested tape replicates, and on
  the life substrate. Together they are the open-endedness baseline every later substrate is
  measured against: a world whose replicator keeps getting more complicated after emergence
  reads a rising length, a world that found one recipe and stopped reads a flat one. The
  hand-written replicator of the engine's test suite reads 36 bytes and 15 instructions.
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
  are read by the `op_density` half of the guard alone.

**Replicator test**: a tape `T` is a replicator if executing `T ++ R` for a random tape
`R` (fresh, seeded) yields `T` in the second half for at least 3 of 4 trials. Run on the
`top_k` (default 16) most common tapes each sample; `replicator_count` counts cells
holding a tape that passed.

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
   selects for efficient copiers and opens a second niche.
7. **Environmental structure** — `structure ∈ {uniform (off), gradient, patchwork}` at
   `structure_amplitude` 0.75, the uniform arm being the world every earlier sweep ran.
   Hypothesis: environmental structure raises the plateau the dominant replicator's
   complexity settles at, refuted if a world whose regions differ plateaus where a uniform
   world does. Secondary prediction: a heterogeneous world keeps more lineages alive after
   emergence.
8. **Room to grow** — `max_tape_len ∈ {64 (= tape_len, off), 128, 256, 512}`, the arm at
   the initial length being the fixed-tape world every earlier sweep ran. Hypothesis:
   room to grow raises the plateau the dominant replicator's complexity settles at,
   refuted if tapes free to lengthen plateau where fixed-length tapes do — which would
   say the 64-byte ceiling was never the binding constraint.

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
  `snapshots` (compressed world bytes + a PNG thumbnail rendered by the engine).
- **The runner is a stateless worker.** In lab mode it polls `POST /api/runs/claim` with
  a bearer token, executes the run, streams sample batches to
  `POST /api/runs/:id/samples`, snapshots to `POST /api/runs/:id/snapshots`, and finishes
  with `POST /api/runs/:id/finish`. Heartbeats every 30 s, each beat carrying the wall
  seconds it covers (`interval_seconds`, optional) which the app sums into the run's
  `compute_seconds`, so a run's cost survives resumes. A run claimed but not
  heartbeated for 5 min is released. Several runs execute in parallel (one thread each,
  `RUNNER_PARALLELISM`, default = cores − 2).
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
