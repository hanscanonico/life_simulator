# Design study: a metabolism substrate, where computing earns the energy to copy (rung 4, option 4)

2026-10-01. This is a design study and seeds nothing. The repository was not touched. The lab
was read with SELECTs only: eight stored worlds, their params, and the from-emerged children's
`compute_seconds`. Numbers marked *pilot* come from a throwaway copy of the engine
(a session scratchpad, not kept) with the assay and payer rule below added; they are a pilot's,
not findings. The pilot code, its raw outputs and the copied worlds were pilot artefacts and
were not kept.

## 0. Recommendation in brief

1. **Present tasks in a separate assay with one new op.** The cell's tape runs alone on
   `T ++ 0^L`. The environment writes two inputs into the last two bytes. The byte `!` (0x21)
   emits the byte under head0. `!` is an instruction only inside the assay; in the soup it is
   always a no-op. Three cases per assay are drawn so that no constant and no wrong task can
   pass, and credit is given per output slot.
2. **Use an arithmetic ladder of eight tasks, not a bitwise one.**
   - The tasks are ECHO, INC, DEC, ADD, SUB, NOT, DOUBLE and MUL. Their minimal programs have
     2, 3, 3, 10, 10, 15, 15 and 32 BFF ops.
   - Rewards are additive. They double with difficulty (1, 2, 2, 4, 4, 8, 8, 16 units), as
     Avida's 2^n does, and are paid into the existing stock at each assay.
3. **The existing economy cannot carry a reward, so add one rule.** Under today's rule
   (`pair`), the poorer cell of a pair sets the budget and both cells pay. A solver's extra
   income is therefore neutral at its frontier with non-solvers, and in practice harmful.
   - The proposed rule is `energy_payer = initiator`: the initiating cell alone pays a fixed
     price of `max_steps` per interaction, and initiates only when it can pay. Income then
     *is* the initiation rate, which is Avida's merit and 2607.09211's interaction
     probability.
   - *Pilot:* every planted solver went extinct within 500 epochs under `pair` (17 of 17
     runs), while its sham — the same tape, computing identically but never emitting —
     outlasted it in all 5 matched runs. Under `initiator`, every planted solver took 69–97%
     of the world by epoch 1 500 (11 of 11), and its sham drifted out or stayed small.
4. **Start from the 18 from-emerged parents, with paired arms.** Every child runs the
   `initiator` economy, with the reward on in one arm and off in the other, paired by
   (parent, seed).
   - *Pilot, de novo:* the one-mutation rungs swept in all 9 rewarded worlds: ECHO first,
     then INC, DEC or both. The 4 worlds read to 20 000 epochs ended solving all three. Every
     unrewarded twin ended at zero tasks above 10%.
   - **No rung that needs a loop appeared in any world** (≤ 3 cells, ever).
5. **Label it a second substrate.** In the engine it is Soup plus opt-in parameters. In the
   record and on the site it is "Metabolism", a substrate that imports an objective. It is
   read as a test of the record's explanation of the plateau: does complexity rise once
   computation pays?

## 1. What the literature does

### arXiv 2607.09211 (Cicala et al., 2026, Z80)

- **Setup.** 2^19 programs of 32 bytes, in 32 niches of 128×128 cells, with von Neumann
  pairing and 5% of partners drawn from other niches. The budget is 512 steps.
- **How a task is presented.** Before a program that was selected to interact may do so, it
  is validated alone:
  - its second half is zeroed;
  - register D holds the input x ∈ {0..15};
  - it runs on three inputs drawn without replacement;
  - register E must hold f(x) mod 256 in all three runs.
- **How the reward works.** The reward is the right to initiate. A validated program
  interacts with probability 1 − C·k/B (C = 0.3, k = mean validation steps, B = 512). Any
  other program interacts with probability 0.3. The reward is not energy.
- **Tasks and scale.** 32 polynomials, one per niche, from n+1 and 2n up to n³+n²+n. Each run
  lasts 10^6 epochs, with 100 replicates.
- **What they saw.** The number of tasks solved (≥ 10% of a niche correct on all 16 inputs)
  tracked the turnover of replicator types. Isolated niches failed the non-trivial
  polynomials. With pollination between niches, harder tasks evolved from the solutions of
  easier ones, a curriculum the soup organised itself.

### Avida, Lenski et al. 2003 (Nature 423:139)

- **IO and tasks.** The IO instruction outputs a register and inputs a fresh random 32-bit
  value. Nine logic tasks are checked on all 32 bits, and each is rewarded once per lifetime.
- **Reward.** Merit is multiplied by 2, 2, 4, 4, 8, 8, 16, 16 and 32 (2^n, where n is the
  minimum number of NANDs). Energy per update is proportional to length × merit, so fitness
  is the energy rate divided by the energy needed to reproduce. ECHO is not rewarded.
- **Scale.** 3 600 organisms over 100 000 updates, about 15 873 generations.
- **Result.** EQU evolved in 23 of 50 populations when every task was rewarded, and in 0 of
  50 when only EQU was. With one or two simpler tasks unrewarded, it evolved in 124 of 360.
  The shortest hand-written EQU has 19 instructions; the first one to evolve used 35.

### BFF

- cubff has no task, reward, fitness or energy code; a grep of a fresh clone finds none.
- arXiv 2607.01483 has no reward either. It argues that interaction buys takeover, not
  construction.
- **No BFF work rewards computation.**

### The common thread

In both rewarded systems the reward buys **reproduction rate**: initiation probability in one,
CPU share in the other. That is the lever BFF's economy lacks (§3.3).

## 2. Pilot results

**Chance credit.**
- The assay of §3.1 was run once on every cell of each stored world (16 384 cells each).
- *Without* the separating rule, tapes that only echo the input were credited ADD/SUB when y
  was 0 in all three cases, and MUL when y was 1: 5 false credits in run 1007's world.
- *With* the rule:

| world | cells holding `!` | emitting | ECHO | INC | DEC | ADD–MUL |
|---|---|---|---|---|---|---|
| 1007 @20 000, cap 128 | 3 711 | 1 197 | 255 | 0 | 0 | 0 |
| 2577 @20 000, cap 128 | 5 041 | 1 269 | 0 | 0 | 0 | 0 |
| 1029 @20 000, cap 256 | 7 919 | 3 752 | 1 264 | 0 | 0 | 0 |
| 2862 @20 000, cap 256 | 8 082 | 5 809 | 774 | 0 | 9 | 0 |
| 3151 @40 000, economy 8192 child | 10 879 | 1 210 | 4 | 1 | 1 | 0 |
| 3580 @40 000, economy 2048 child | 3 276 | 8 | 0 | 0 | 0 | 0 |

These credits are genuine.
- **ECHO:** a junk `!` sits in a copy loop that steps head0 over the input, as in
  `[.<…!…>>{]`.
- **INC and DEC:** a drifted loop increments or decrements the input and emits it.

These rungs are one substitution away from today's copiers and already sit, unrewarded, in up
to 8% of cells.

**Planted solvers under each payer rule.**
- **World.** Run 2577's world under a theft-free economy.
- **Planted tapes.** 256 cells (a 16×16 block) received the solver S: a resident copier with
  task code written into its junk before the loop. The code is mirrored into the tail so that
  `reverse(S)` also solves the task. S passes the detector.
- **Sham.** The same tape with `!` replaced by a no-op byte, so it computes identically and
  never emits.
- **Reward.** Each solving cell received one extra income's worth (doubling it).
- **Reading.** Counts are cells still carrying the code, 1 500 epochs after planting.

| planted | economy | solver | sham |
|---|---|---|---|
| ADD, the parent's copier, at descent | `pair` 2048, 8192 | 0 by epoch 500 (6/6 seeds) | 0 by 750 (6/6) |
| ADD, the parent's copier, after 1 000 settling epochs | `pair` 2048, 8192 | 0 by 250–500 (6/6) | 0 by 750 (6/6) |
| ECHO, the settled residents' commonest copier | `pair` 2048 | 0 by 500 (5/5) | outlasted the solver in 5/5; one held 156 at 1 500 |
| ADD at descent | `initiator` 2048 | 15 222–15 839 (3/3) | 0–70 (3/3) |
| ADD after settling | `initiator` 1024 | 11 311–14 487 (3/3) | 0–2 (3/3) |
| ECHO, settled residents | `initiator` 1024 | 12 128–15 859 (5/5) | 0 in 3/5; 91 and 2 776 in the others |

Under `pair`, the reward never rescued a solver, and in the cleanest comparison (ECHO) it
hastened its loss. The likely reason: a rich cell is never starved, and so loses the immunity
an empty stock gives — it is always available to be overwritten.

**De novo, no planting.** Descendants under `initiator` at influx 1024, the assay every 8
epochs, with the reward on or off, read to 20 000 epochs:
- **Mini-sweep:** 4 parents at seed 1, ladder units of ⅛ of an influx.
- **First runs:** 3 worlds at 1024 and one at 512, read to 10 000 epochs, with units 4× as
  large.

| world | epoch ECHO ≥ 10% (reward) | tasks ≥ 10% at end (reward vs no reward) | loop rungs | dominant ops, early → late median (reward / no reward) |
|---|---|---|---|---|
| 1007 | 500 | 3 vs 0 (control ECHO drifted to 14%, ended at 7%) | 0 | 18 → 23 / 19 → 18 |
| 2577 | 11 000 | 3 vs 0 | 0 | 17 → 23 / 14 → 15 |
| 1029 (cap 256) | 500 | 3 vs 0 | 0 | 15 → 22 / 21 → 21 |
| 2862 (cap 256) | 500 | 3 vs 0 | 0 | 30 → 23 / 35 → 22 |
| first runs: 1007, 2577, 3151, 2577 @512 | 500–5 500 | 1–3 vs 0 | ≤ 3 cells | — |

**How the solvers evolved.** Run 1007's INC solver shows the path. Its head is
`{<+[…….<…!…>>{]`: `<+` increments x in place, the copy loop then emits y on lap 1 and x+1 on
lap 2, which earns INC on output slot 1. Within 7 500 epochs it had acquired the mirror tail
`[+<{`, so that both orientations solve.

**Survival.** `replicator_share` (a 128-cell draw) stayed between 0.34 and 0.95 in every run,
and no world died. The low end is the cap-256 controls at influx 1024 and the run at influx
512.

**Cost.** All five configurations ran concurrently on world 2577, single thread each, timed
over epochs 500–2 500 after descent:

| configuration | epochs/s |
|---|---|
| economy off (the continuation) | 8.4 |
| `pair` 2048 | 21.2 |
| `initiator` 1024 | 28.2 |
| `initiator` 1024 + assay | 24.1 |
| `initiator` 1024 + assay + reward, before any rung | 23.4 |

Once the rungs have swept, a reward arm costs 1.3–1.6× its twin (mini-sweep wall time).
Solvers run all three cases to the assay's budget.

## 3. Design

### 3.1 Task presentation

The design uses option (a), the separate assay, plus the emit op of option (c).

**Option (b) is rejected.** It would write the inputs into a real partner, which is a mutation
the soup never had. The copy would then overwrite the output, so a copier's "answer" would be
a byte of itself. And the reward would depend on whoever the partner happened to be.

**The emit op is required.** Every emerged copier never halts and rewrites its whole partner.
A fixed output cell read at the end of the run would therefore hold a byte of the copier,
constant across cases. No copier could ever be credited. The steal op `$` (2026-09-16) is the
precedent for a byte that becomes an instruction only under its own parameter.

**Exact semantics.** The constants are exported by `runner schema` under `tasks`, as
`self_replication` is.

- **Buffer.** The tape's live bytes T (length L), then L zeros: a fixed length of 2L, with no
  growth and both heads wrapping mod 2L. The inputs sit at `B[2L−1] = x` and `B[2L−2] = y`.
  Head0 reaches them with `<` and `<<`; head1 reaches them with `{`, where every emerged
  copier already sends it.
- **Execution.**
  - The run executes its own `ops` set. `!` emits `B[head0]`: where `.` writes head0's byte to
    head1, `!` writes it to the environment. `$` is a no-op.
  - The run stops at the end of the buffer, on an unmatched bracket, after
    `TASK_STEPS = 4096` steps, or at the fourth emit (`TASK_MAX_OUTPUTS = 4`).
- **Cases.** There are `TASK_CASES = 3`, with x and y uniform in 0..15.
  - They are drawn once per assay epoch from a new stream, `STREAM_TASK`, at (seed, epoch),
    and every cell shares them. A verdict is then a pure function of (tape, seed, epoch), so
    it is computed once per distinct tape (22–44% of cells in the pilot worlds), and cell
    order cannot matter.
  - The cases are redrawn until they **separate the tasks**: within each task the three
    expected outputs are pairwise distinct, so no constant can pass; and no two tasks expect
    the same three outputs, so one output slot matches at most one task. About 40% of draws
    are redrawn.
- **Credit.** Task t is credited when some output slot j < 4 holds f_t(x, y) in all three
  cases. Two shortcuts are exact:
  - a tape holding no `!` byte cannot emit, so it is credited nothing without being run;
  - a case with no output ends that tape's assay.
- **Why copying cannot fake a credit.**
  - A pure copier emits nothing.
  - A copier that reaches a junk `!` emits a byte of itself, the same in every case.
  - A sprayer such as `[!+]` emits a constant in each slot.

  All three fail. A function of the inputs that is not a task matches a given task in a given
  slot with probability about 256^-3. The input domain is small, as in 2607.09211, which keeps
  loops bounded. That small domain is why the separating rule is load-bearing (§2).

### 3.2 Task set and reward ladder

**Why arithmetic.** BFF's only data ops are ±1 at head0, copies between the heads, and a zero
test. AND, OR, XOR and EQU need bit extraction by repeated halving: nested-loop programs we
estimate at ≥ 100 ops, against the 11–35 ops the corpus's dominant tapes hold. NOT stays in the
set, computed arithmetically as 255 − x.

Every program below was verified by the pilot assay on all 256 (x, y). Each one returns head0
to 0, so a copy loop placed after it runs unchanged.

| task | f | minimal program | BFF ops | steps to emit (worst) | units |
|---|---|---|---|---|---|
| ECHO | x | `<!>` | 2 | 3 | 1 |
| INC | x+1 | `<+!>` | 3 | 4 | 2 |
| DEC | x−1 | `<-!>` | 3 | 4 | 2 |
| ADD | x+y | `<<[->+<]>!>` | 10 | ~80 | 4 |
| SUB | x−y | `<<[->-<]>!>` | 10 | ~80 | 4 |
| NOT | 255−x | `<[-<<->>]<<-!>>>` | 15 | ~115 | 8 |
| DOUBLE | 2x | `<[-<<++>>]<<!>>>` | 15 | ~130 | 8 |
| MUL | x·y | `<[-<[-<+<+>>]<<[->>+<<]>>>]<<!>>>` | 32 | ~3 530 | 16 |

MUL is the task that sets `TASK_STEPS` at 4 096.

**Rewards.** At each assay a cell is paid `task_reward × Σ units` over its credited tasks,
added to its stock and capped.

- **Additive, not multiplicative.** Under the payer rule below, income maps linearly onto the
  initiation rate, which is capped at one initiation per epoch. A multiplicative merit would
  hit that cap after two or three rungs.
- **A lump per assay, not an income per epoch.** A lump needs no new world state. An income
  per epoch would need a per-cell "credited" mask, stored in the snapshot and reset whenever
  the cell is overwritten.
- **The recommended scale.** Set `task_reward = influx · task_every / 4`, so one unit is a
  quarter of an influx per epoch. The pilot bracketed this value: units of ⅛ climbed in 4 of 4
  worlds, though run 2577 only after 11 000 epochs; units of ½ climbed in 4 of 4 within 5 500
  epochs, but saturate the top of the ladder.
- **What that scale gives.** The whole ladder is 45 units, 11.25 × influx. With an influx of
  `max_steps`/8 the initiation rate saturates only for a tape holding 28 or more units, which
  takes MUL, NOT or DOUBLE, and ADD or SUB together. Every lower rung is always worth
  climbing. A single lump of more than 32 units hits the stock cap.

### 3.3 Interaction with the economy: the payer rule is the crux

**Why `pair` cannot carry a reward.** Under `pair` an interaction runs
`min(stock_a, stock_b)` steps and debits both cells.
- A copy from solver S into a poorer cell N, and a copy from N into S, are both bounded by N's
  stock, so S's extra income is neutral at the frontier between them. It enriches only S–S
  interactions, which change no composition.
- A rich cell is also never starved, so it loses the immunity an empty cell enjoys.
- Every cell initiates once per epoch, so beyond the copy latency a stock buys nothing.

The pilot shows all of this (§2).

**`energy_payer`** takes `pair` (the default, today's rule to the bit) or `initiator`. Under
`initiator`:
- A cell initiates only if its stock is at least `max_steps`, the price of one interaction.
  Otherwise it is passed over as an initiator; the partner draw is still made, so no stream
  moves.
- The interaction's budget is `max_steps`. The initiator alone is debited the full price,
  whatever ran, so a halting copier saves nothing and the reward is the only route to more
  copies.
- The partner is never gated and never debited. Steals settle as they do now.
- The rule is refused without an `energy_influx`, with `energy_stock_cap < max_steps`, or
  together with `energy_per_epoch`.

**Two variants were weighed and rejected.**
- *The initiator's stock as the budget, with no price.* A copier that never halts spends
  everything every epoch. It then copies if and only if its influx covers its latency: a
  knife edge, not a rate.
- *Debiting the steps actually run.* This would favour halting copiers, which saturate at one
  initiation per epoch and make the reward worthless to them.

**Base influx: 1024 (`max_steps`/8).**
- *Headroom.* Income maps linearly onto initiations at any influx below `max_steps`, so tasks
  always matter. What the influx decides is the headroom (8×) and survival.
- *Survival.* An unrewarded copier initiates once per 8 epochs, against 1/64 (cap 128) and
  1/32 (cap 256) mutation hits per tape per epoch. In the pilot, controls held
  `replicator_share` between 0.34 and 0.92 over 20 000 epochs. At influx 512 the range was
  0.37 to 0.79, a thinner margin.
- *The held-out influxes do not transfer.* The influxes that kept the held-out colonies alive
  (2048 and 8192) were `pair` influxes, where budgets are shared and every cell runs every
  epoch.
- *Cap.* `energy_stock_cap` is 2^16, which is 8 prices.
- *No theft.* `steal_amount` is 0.

### 3.4 Start condition

**Descendants, not a random soup.** Emergence is rare: 1–18% of seeds per 20 000 epochs. The
paper needed 10^6 epochs on 2^19 programs for replication and function to co-emerge.

**The parent pool** is the 18 from-emerged parents.
- Cap 128: runs 944, 950, 967, 991, 1007, 2568, 2577, 2590, 2654, 2676 and 2700.
- Cap 256: runs 1029, 1087, 1089, 1103, 2771, 2802 and 2862.

They are already qualified (`oriented_census/1` share ≥ 0.5 at epoch 20 000), the existing
builder seeds them, and no metabolism child of theirs has been read.

**A later second pool.** Sweep 13's radius-4 worlds are where emergence peaks, which makes
them the natural home for a co-emergence arm later. They need a parent rule and a readings
pass first, and their fixed 64-byte tapes leave only about 45 junk bytes, against about 110 at
cap 128.

**Room to grow is not a lever here.** `max_tape_len` is structural, so a descendant keeps its
parent's. The parents' tapes already sit at their caps and are 80–90% junk, the raw material
that substitutions build task code in. Cap 256 doubles that raw material, but also the
mutational load, and it halves copy speed.

### 3.5 Observables

New fields are appended to `Metrics`. Each is null where `tasks = off`, on life, and on every
sample recorded before it existed.

- `task_share_echo` … `task_share_mul` (8 fields): the share of 256 cells, drawn uniformly
  with replacement, credited with each task. The draw uses `STREAM_TASK | 1` and its own cases
  at (seed, epoch), as `replicator_share` does.
- `task_capability`: the number of tasks with a share ≥ 1/10, which is ≥ 26 of 256, compared
  as integers. `task_capability_loop` counts the same over ADD, SUB, NOT, DOUBLE and MUL.
- `dominant_tasks` (a bitmask) and `dominant_task_count`, for the census's dominant tape,
  assayed on `STREAM_TASK | 2`.
- Read beside them, unchanged:
  - `dominant_instruction_count`, still the ten BFF ops; like `$`, `!` is not counted;
  - `dominant_self_replicates`;
  - `replicator_share`;
  - `copy_latency`, now descriptive only, since the fixed price removes the latency
    selection of #263.
- **The invariant holds.**
  - `!` is never an instruction in the soup.
  - The defaults are `energy_payer = pair`, `tasks = off` and `task_reward = 0`. The assay
    draws nothing from the run's own streams and adds no snapshot field.
  - A run with `task_reward = 0` is byte-identical to the same run with `tasks = off`, so the
    control arm carries the readings too.
  - The pinned digests split, as #247 and #255 split them.
- **Per-sample cost** is at most 256 × 3 × 4 096 steps, under 2% of ten epochs.

### 3.6 Pre-registrable hypotheses (sweep 14, `metabolism`)

**Arms**, each merged over its parent's params:
- **reward**: `{energy_payer: initiator, energy_influx: 1024, energy_stock_cap: 65536,
  steal_amount: 0, tasks: arith, task_every: 8, task_reward: 2048}`;
- **no-reward**: the same with `task_reward: 0`.

The no-reward arm is the paired control. It shares the new economy, so the comparison
isolates the reward.

**Seeds and budget.** Seeds 2001–2003 give 54 (parent, seed) pairs and 108 children. Each
child runs **40 000 epochs** past its parent. In the pilot the one-mutation rungs alone took
500–13 000 epochs to sweep, which leaves too little of a 20 000-epoch span for a rung that
needs several coordinated mutations.

**Readings per child** are taken over samples at epochs above `parent_epoch` + 1 000, the
settling window of #263. Deciles and lower-middle medians are cut as in the from-emerged
clarifications. Settled relapse and extinction follow #263.

**Each test** is a one-sided sign test over the discordant pairs, among pairs where neither
child is extinct. It reads:
- **shown** at p < 0.05;
- **refuted** when the pairs favouring the control are at least as many as those favouring
  the reward;
- **not shown** otherwise.

Each test carries per-parent agreement and the leave-one-or-two-parents-out rule.

- **H-capability.** A pair favours the reward when the reward child's last-decile median
  `task_capability` exceeds its twin's. The pilot predicts it is shown, carried by the
  one-mutation rungs: the reward world ended above its twin in 8 of 8 pilot pairs.
- **H-ladder** is the rung-4 question. It applies the same test to `task_capability_loop`.
  - *If refuted:* when computation pays, BFF copiers take the one-substitution rungs and
    stop. The drift–selection plateau then holds for every feature that needs several
    coordinated mutations, and the suspects become the substitution-only mutation operator
    and the instruction set — option 5.
  - *Pilot:* 0 of 9 rewarded worlds climbed a loop rung within 10 000–20 000 epochs. The 95%
    upper bound on the rate per child is 0.34. The sign test needs about 5 discordant pairs,
    and has power 0.64 at a rate of 0.1 per child (54 pairs) and 0.92 at 0.15.
- **H-complexity** applies the from-emerged complexity rule: `dominant_instruction_count`
  over self-replicating samples, with a rise meaning at least 1.2×. A pair favours the reward
  when its child rises and its twin does not. It is read only on pairs where both children
  are measured and neither relapsed.
  - *Pilot, crude early/late medians:* the reward children rose by 28–47% in 3 worlds; both
    arms of the fourth (2862) fell, as a short lineage took over. Mirroring and stacked rungs
    add 6–14 ops, so H-complexity can be shown without H-ladder. It then reads "paid
    complexity rises", not "open-ended".
- **Descriptive only:**
  - the first epoch at which each task reaches 10%, which gives the ladder order and asks
    whether loop rungs arise only in lineages that already hold INC or DEC (Lenski's
    stepping stones);
  - `dominant_tasks`, `copy_latency` and `replicator_share`;
  - the share of income that comes from tasks.

### 3.7 Cost

- **Assay.** Each assay epoch costs at most (distinct tapes holding `!`) × (1 case, or 3 if
  the tape emits) × 4 096 steps.
  - *Pilot:* the assay ran 57–124 steps per cell per epoch in the controls and up to 339 in
    the reward arms, against 840–1 180 soup steps. It cost 17% of wall time in the control.
  - *To cut it further:* emit inside `bff::execute`, where an emit is an acting step that
    stops lap replay, so copy loops in the assay are skipped as they are in the soup (slice 2).
- **Per child.** On the lab, from-emerged `pair`-2048 children took 1 513 s per 20 000 epochs
  at cap 128 and 1 941 s at cap 256 (12 runs at a time). The pilot ratios put a no-reward
  child at about 0.9× that and a reward child at about 1.4×. At 40 000 epochs:
  - no-reward: about 2 700 s (cap 128) and 3 500 s (cap 256);
  - reward: about 4 200 s (cap 128) and 5 400 s (cap 256).
- **Total.** 33 × (2 700 + 4 200) + 21 × (3 500 + 5 400) ≈ 415 000 run-seconds, about 115
  run-hours, or **about 10 hours of the mini-pc**. At 20 000 epochs it would be about 5 hours.
  The first finished children's `compute_seconds` replace this estimate.

## 4. Engineering slices (dependency order, each about 90 minutes or less)

1. **Engine: `energy_payer`.**
   - Files: `params.rs` (the enum, validation and schema), `world.rs` (in `step_soup`: the
     gate, the budget and the debit), and `config/engine_schema.json` regenerated by
     `make schema`.
   - Spec, `pair`: every pinned hash and observable digest is unmoved with the field named.
   - Spec, `initiator`:
     - a poor cell is passed over as initiator yet is still chosen as a partner;
     - the full price is debited whatever ran;
     - the partner is untouched;
     - the partner draw is unchanged;
     - the refused combinations are refused;
     - a new determinism pin.
   - Docs: a DESIGN §1.1 bullet and a record entry.
2. **Engine: the assay and the reward.**
   - Files: a new `task.rs` holds the `TASK_*` constants, the tasks and units, the separating
     case draw and the slot credit. The params `tasks`, `task_reward` and `task_every` are
     added. The reward is paid in `step_soup` before the influx, at epochs ≡ 0 mod
     `task_every`, memoised per distinct tape. Emit lives inside `bff::execute`, as described
     in §3.7.
   - Spec, credit:
     - each program of §3.2 is credited for its own task only, on all 256 (x, y);
     - copiers, constant emitters and `[!+]` are credited nothing;
     - the separating rule holds over 10^5 draws.
   - Spec, equivalence and invariant:
     - on `!`-free tapes, the emit-enabled interpreter equals the plain one;
     - `task_reward = 0` gives the same bytes as `tasks = off`;
     - a reward determinism pin;
     - the constants appear in `runner schema`.
3. **Engine: the observables of §3.5.**
   - Spec: each draws on its own stream, is null when off, and has its digest split.
   - Spec: the cost is measured on a restored emerged world.
   - Slices 1–3 deploy together. The lab queue is empty, so there is one runner restart.
4. **Rails: the sweep and its pre-registration.**
   - `Lab::SWEEPS["metabolism"]` reuses `from_emerged`'s `parents:` rule and adds the two
     treatment bundles, seeds 2001–2003, 40 000 epochs and priority 40.
   - `Lab::MetabolismReading` holds the constants.
   - The record entry carries the pre-registration and the label. DESIGN gains §1.3 item 14
     and §1.4.
   - Spec: the builder makes 108 children, idempotently.
5. **Rails: the reading.**
   - `Experiments::MetabolismReadingService` and `lab:metabolism_report`, with CSV.
   - They reuse `Lab::FromEmergedHeldout`'s pairs, sign test and settling window, and
     `DescendantReading`'s deciles, agreement and leave-out.
   - Spec: hand-built children for every outcome branch.
6. **Later: the finding page**, with the label, once the reading is final.

## 5. Risks

- **Reward hacking.** Each route found is blocked:
  - constants, by the rule that the outputs within a task are distinct;
  - wrong tasks, by the rule that the tasks' outputs differ from one another;
  - sprayers, by crediting per output slot.

  Coincidences from the small domain were zero outside genuine computation in 6 worlds ×
  16 384 cells. They were not zero without the rule.
- **ECHO is nearly free.** It already sits in 0–8% of cells, and in one control it drifted to
  14%. So the rung-4 claim rides on H-ladder, not on H-capability.
- **The mirror problem.** A reverse copier's offspring, `reverse(S)`, lacks S's head code
  until a mirror mutation adds it, which halves selection on the first step. The pilot's
  lineages acquired mirrors within about 7 500 epochs.
- **The economy itself changes the world.** Latency selection disappears. Descent mints full
  stocks, so the first ~8 epochs burst. Both arms share the economy, and readings skip a
  settling window.
- **Determinism and the invariant.** The assay draws only from `STREAM_TASK` and writes only
  stocks. Its verdict is a function of (tape, seed, epoch). The defaults reproduce every run.
  No snapshot version is needed, because the reward lives in the existing stock (format 8).
- **Cost.** Without emit-aware lap skipping and memoisation, a full-world assay costs several
  soup epochs.
- **The ladder may stop at INC.** That would be a finding (H-ladder refuted), and it points to
  option 5: a richer instruction set, or insertion and deletion mutations, which Avida has
  and BFF lacks.

## 6. "Imports an objective": the label

**The engine-side substrate stays `soup`.** A descendant may not change `substrate`, which is
structural, and the world's shape is Soup's.

**The label lives in the record, the sweep and the registry:**
- every run with `task_reward > 0` is a **Metabolism** run;
- DESIGN §1.4 is titled "Metabolism: a second, labelled substrate that imports an objective";
- the record entry names the choice as the orchestrator's (option 4 of 2026-09-24), taken
  after the user's instruction to "continue, don't stop until life exists";
- findings carry an "imports an objective" badge;
- its runs are never pooled with fitness-free arms;
- rung 4 on Soup stays "not shown", whatever this substrate reads.

**What it can claim is the mechanism.** The record's 2026-09-16 explanation of the plateau is
that "a byte off the copy path costs nothing and buys nothing".
- If complexity rises when paid and not in the unpaid twin, under the same economy, the
  plateau was "nothing pays", not "BFF cannot express more".
- If nothing rises, the expressiveness of the instruction set or the mutation operator binds
  first.
