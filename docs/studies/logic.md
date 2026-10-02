# Design study: what holds the Metabolism ladder at one substitution, and the cheapest change that lifts it

2026-10-01. This is a design study. It seeds nothing and touches neither the repository nor
the lab. The lab was read with SELECTs only: run progress, sample maxima, and the stored
worlds of six rewarded `metabolism` children (944 and 950 × seeds 2001–2003) plus two more
from-emerged parents (944 and 2700, epoch 20 000), which I copied out. Every number marked
*pilot* comes from a throwaway copy of main's engine (`c0cb7ba`) in
a session scratchpad, not kept. The exception is the live sweep's interim maxima, which
are lab readings. Pilot numbers come from a pilot, not from findings. The tools (`scape`) and
their raw outputs were pilot artefacts and were not kept; the landscape methods the later
readings lock are preserved, ported to the merged engine, in `research/landscape/`.

## 0. Recommendation in brief

1. **Why the loop rungs stay empty.** The cause is the instruction set, not the variation
   operator.
   - BFF has no data op that takes two inputs, so every two-input task needs a counted loop.
   - The only loop a copier owns is its copy loop.
   - Within three substitutions, the soup can reach a loop solver only by turning the copy
     loop into a counted loop. That kills the copier.
   - The nearest loop solver that still copies is 5–7 coordinated substitutions away by
     construction. None exists within 2 substitutions anywhere, or within 3 in the code
     window.
   - No partial kernel on the way computes anything new, so the arithmetic ladder has no
     stepping stone to reward.
2. **Indels and duplications do not shorten that distance.**
   - Distance under length-keeping insertions: 6–9.
   - 127 million single and two-edit mutants that involve an insertion, deletion or
     duplication: no loop solver among them.
   - *Pilot:* adding indels to the Metabolism ladder gave 0 loop rungs in 4 of 4 worlds.
3. **The change: Logic.** Make one byte, `~`, a NAND of the bytes under the two heads,
   active only inside the assay as `!` is. Swap the arithmetic ladder for Avida's nine
   logic tasks (Lenski et al. 2003), paid as Metabolism pays.
   - The soup stays byte-identical, and every rung is a composition of one primitive.
   - *Pilot:* 2 of 4 cap-128 worlds climbed NOT/NAND → ORN → OR/ANDN → NOR within 20 000
     epochs.
   - *Pilot:* with the lower rungs unpaid (Lenski's control), the same two worlds climbed
     nothing, like the no-reward twin.
4. **Keeping it honest.** Measured on the evolved worlds, OR, ANDN and NOR are 1–2
   substitutions from the rung below them, so they are the new one-step rungs. XOR and EQU
   are the rungs no measured evolved solver reaches: not within 2 substitutions anywhere,
   and not within 3 in its code window. Rung 4 is read on those two only.
5. **The sweep.** H-deep (XOR or EQU, reward against no-reward) and H-stones (full ladder
   against deep-only reward, Lenski's control) are paired by (parent, seed) on the 18
   from-emerged parents.
   - 162 children, about 85 run-hours: roughly 7 h of the mini-pc.
   - About 5 h if the no-reward arm is read off Metabolism's own no-reward children, which
     are byte-identical to it.

## 1. The landscape around evolved solvers (question 1)

### 1.1 Material

**Twelve focal tapes**, two per world, from six rewarded `metabolism` children:
- 4573–4575 (parent 944) and 4579–4581 (parent 950);
- their latest stored worlds, 9 200–33 300 epochs past the parent;
- every world 128×128 with all 16 384 tapes at the 128-byte cap.

**How each pair was picked.** The first focal tape is the world's commonest tape that
- the real assay (`life_engine::task::assay`) credits with INC or DEC on each of 6 fixed
  separating case sets ("solid" below), and
- `replicator::self_replicates` passes.

The second is the commonest such tape at Hamming distance ≥ 16 from the first.

**Two copier families appear:**
- 4573 and 4575 are reverse copiers whose loops copy with `,` (`[,!·}·<···-·,]` and
  `[·!·}·<···-·,·.······]`). 4573 also loads x with `{,` at the front;
- 4579–4581 are `.`-copiers built on `[·{.···>···]`.

4574 is a third layout. Every focal tape holds ECHO, INC or DEC in at least one orientation.

### 1.2 Exhaustive neighbourhoods: no loop solver within two edits of any kind

Each mutant is scored on the 6 case sets and on 12 probe inputs, so that any function of
(x, y) a slot emits can be classified. The sets, per focal tape:

| set | mutants per tape |
|---|---|
| every single substitution, full byte alphabet | 32 640 |
| every single insertion (the last byte falls off) | 32 768 |
| every single deletion (a no-op byte enters at the end) | 128 |
| every tandem duplication of 1–48 bytes | 5 016 |
| every double substitution, over 13 values (the ten ops, `!`, 0, a no-op) | ≈1.33 M |
| an insertion or deletion, then any substitution, insertion or deletion | ≈6.15 M |
| a duplication of 2–24 bytes, then a substitution | ≈4.37 M |

- **Total:** 143.2 million mutants.
- **Loop-task credit (ADD, SUB, NOT, DOUBLE, MUL): exactly one.**
  - It is the double substitution that turns 4573's second tape's copy loop `[,!·}·<···-·,]`
    into `[,>·-·<···-·,]`.
  - It counts x down while decrementing the byte beside it, which holds 255, so it emits
    NOT.
  - It no longer copies (the detector fails it).
- **No partial computation either.** Apart from that one mutant, the best agreement of any
  slot with any loop task was 3 of 12 probes, which is chance.
- **What the neighbourhood does emit.** 0–687 distinct novel input functions per tape and
  set. They are offsets of an input (x+c, y+c) and zero-test quirks such as "1 if x = 1,
  else 255".
- **The cost of a mutation.** A single substitution loses existing credit in 2.7–6.4% of
  cases, a double in 12–42%.

### 1.3 Three substitutions: loop solvers exist only where the copy loop is spent

**The search.** Every triple substitution over the same 13 values, inside the executed
window, 20–37 M mutants per tape. The window is the first 40 or 48 bytes: the code in front
of the copy loop and all of the loop (4573, 4579) or its head (4574, 4575).

| focal | mutants | loop solvers | loop solvers that replicate |
|---|---|---|---|
| 4573 #0 | 19.9 M | 58 (DOUBLE) | **0** |
| 4575 #0 | 36.4 M | 36 (ADD) | **0** |
| 4579 #0 | 36.0 M | 0 | 0 |
| 4574 #0 | 36.7 M | 0 | 0 |

Every one of the 94 solvers spends a part of the copier on the counted loop, and none
copies:
- in 4573, it rewrites the copy loop itself (`sub(25,+) sub(26,{) sub(36,>)`);
- in 4575, it opens a loop in front of the copy loop around the head set-up
  (`sub(17,[) sub(32,<) sub(39,])`). In the soup that loop runs once per unit of a partner
  byte and moves head1 each time, so the copy lands at a different offset per partner.

### 1.4 The nearest loop solver that still copies: 5–7 substitutions, 6–9 insertions

**Search.** 26 loop kernels (`[->+<]`, `[-<+>]<!`, `<<[->-<]>!>`, `[-<<++>>]<<!` and
others) were written into every position of each focal tape:
- by overwriting (substitutions);
- by inserting (the tail falls off: a length-keeping indel operator; distance =
  Levenshtein minus the free tail drops).

A construction counts only if:
- the real assay credits a loop task on all 6 case sets;
- the detector passes the result.

| focal (family) | substitutions | insertions | path never below the start's credit, every step copying |
|---|---|---|---|
| 4573 #0, #1 (`,`) | **5** (DOUBLE/NOT) | 8 | sub: from d = 7; ins: from d = 8 |
| 4575 #0 (`,`) | **5** (NOT) | 6 | sub: at d = 5; ins: at d = 6 |
| 4575 #1 (`,`) | **5** | 6 | sub: from d = 7; ins: at d = 6 |
| 4579 #0, #1 (`.`) | **7** (ADD) | 8 | **none** (best path bottoms at 0–3 of the start's 6 units) |
| 4580 #0, #1 (`.`) | **7** (ADD) | none found | **none** (bottoms at 1) |
| 4581 #0, #1 (`.`) | **7** (ADD/SUB) | 9 | **none** (bottoms at 0–5) |
| 4574 #0, #1 | none in the library | none | — |

**The five-substitution solvers reuse what the `,` family already does.** In 4573, `{,`
loads x into the tape's own byte 0, where head0 starts. A balanced loop on that byte then adds it
into x, one step left through the wrap (`{,[-<+>]`: DOUBLE). Or it subtracts it from a 255
beside it (`[->-<]`: NOT).

**The path test (the subset lattice).** For the cheapest constructions, every one of the
2^d intermediate states was assayed, forward and reversed, and run through the detector.
- The `,` family has paths on which every step copies and lineage credit never drops below
  the start's: 54 of 129 constructions for 4573, 64 of 195 for 4575.
- **Those paths are neutral, not uphill.** No intermediate earns more.
- The `.` family has no such path under either operator. Every route through an ADD kernel
  passes a state that loses ECHO/INC credit or stops copying.

**What the intermediates compute.** Every subset of every near-minimal construction was
checked:
- 4573: 71 of 184 intermediate states emit a function the parent did not. They are x+1,
  x+254, x+2 and zero-test quirks.
- 4575: 129 of 370; 4579: 165 of 380; 4581: 290 of 760.
- They are dominated by y+1, y+0, x+255 and x+2.

No intermediate computes a partial sum, difference or product. The loop body
(`[`, `-`, `>`, `+`, `<`, `]`) has no partial form that computes anything.

### 1.5 What binds

**Not the variation operator.**
- Under insertions the nearest solver is no nearer (6–9 against 5–7).
- No one- or two-edit combination of insertions, deletions, duplications and substitutions
  reaches one (127 M mutants of those kinds over the 12 tapes).
- Insertions add neutral paths only in the family that already had them.
- *Pilot (§4.1):* indels on the live ladder climbed no loop rung.

**The instruction set.**
- BFF's only data ops are ±1 at head0 and copies between the heads, so no two-input
  function exists without a counted loop.
- A counted loop costs at least six bytes (`[`, a decrement, a move, an accumulate, a move
  back, `]`).
- The copier's one loop is spoken for.

**So there is a gap with no stepping stone in it.** Every arithmetic function a stepping
stone could reward on the way is an input plus a constant. Those are straight-line,
one-step rungs that lead to no loop. The ladder of §3.2 of the Metabolism study has three
one-step rungs, and then a ≥ 5-step gap that no reward can bridge.

**The time scale is consistent with the observed plateau.**
- A specific byte becomes a specific value at u = (1/8192)/256 ≈ 4.8 × 10⁻⁷ per epoch.
- A neutral 5-step walk, even with ~100 alternative target paths, needs on the order of
  10⁴–10⁶ epochs.
- A path with a valley needs simultaneous double mutants: N·u² ≈ 4 × 10⁻⁹ per epoch.
- Each child runs 4 × 10⁴ epochs.
- The one-step rungs swept in 500–13 000 epochs because each was paid.

**The live sweep agrees (interim, lab, read only).**
- The 6 finished reward children (parents 944 and 950) each reached 2–3 one-step
  capabilities.
- Not one of 4 000 samples per child has a loop-task share above 0; the same holds for the
  11 running children.
- Nothing is claimed from this interim reading.

## 2. What the soup's variation actually is (question 2)

From `engine/crates/life-engine/src/{bff,world}.rs`, and from replaying 3 000–4 000 of each
world's own pairs offline under the run's bounds (budget `max_steps` as under `initiator`;
`scape variation`).

**Mutation (`World::mutate`).** After every epoch, each live byte is replaced by a uniform
random byte with probability `mutation_rate`: 1/8192 in every parent and child. So:
- a specific value lands at a specific site with probability 4.8 × 10⁻⁷ per epoch;
- there is no insertion, deletion or duplication operator;
- `structure` only rescales the rate.

**Copying is exact and in register.** No interpreter op errs; a "copy error" is a mutation
of the source. Partner outcomes of one interaction, as shares of interactions:

| world | exact (reverse) copy | copy rotated by 1, 2 or 127 | partial overwrite in register | unchanged |
|---|---|---|---|---|
| parent 1007 (cap 128) | 76% | 0.6% | 1.3% | 20% |
| parent 1029 (cap 256) | 76% | 6% | 1.5% | 16% |
| parent 2862 (cap 256) | 36% | 32% | 4% | 17% |
| child 4573 | 2.6% + 43% with 1–2 odd bytes | 36% | 9% | 6% |
| child 4579 | 0.1% | 74% | 19% | 1.6% |
| child 4574 | 70% | 1.6% | 3.6% | 16% |
| child 4581 | 78% | 1.8% | 1.2% | 16% |

- **A rotated copy is not an indel.** It is the whole tape turned by the copier's head
  offset, and two generations of a reverse copier undo it: rev(rot_s(rev(S))) = rot_−s(S).
- **A partial overwrite is homologous recombination.** The partner keeps its own bytes past
  the point the copy reached. Positions never shift.
- **Copying changes nothing local.** It acts as neither an indel nor a duplication operator.

**Growth is spent.** A head stepping past the end appends a zero byte only while the tape
is under the cap (`bff::step_right`), and a tape never shortens. Every tape of every world
read sits at its cap:
- 16 384 of 16 384 in 1007 and 2577 (cap 128), 1029 and 2862 (cap 256), and all six
  children.

So the effective insertion operator stops working before emergence ends.

**Summary.** The soup's only local variation is the per-byte substitution, plus homologous
recombination through partial copies and whole-tape rotation through offset copiers.

## 3. Candidate changes (question 3)

| candidate | what it changes | why it would lift the constraint | measured here | build cost | risk | literature |
|---|---|---|---|---|---|---|
| **Indel mutations** | A share of mutation events (at mutation time) inserts a random byte, with the last falling off, or deletes one, with a random byte entering. At copy time it would need error hooks in `.`/`,`. | Code can be added without overwriting. | Distance 6–9 against 5–7; no loop solver in 6.15 M one-indel-then-one-edit mutants per tape; *pilot*: 0 loop rungs in 4/4 worlds (§4.1). | 1 slice (`mutate`, one param) | Shifts absolute offsets: the mirror structure of reverse copiers and head-offset copiers break. Mutational load rises. Off by default, so the byte identity of existing runs holds. | Avida (Ofria & Wilke 2004); Lenski 2003 used 0.05 insertions and 0.05 deletions per divide |
| **Duplication (Ohno)** | Tandem duplication of a segment | Copy existing code (the copy loop) and modify it. | 5 016 duplications and 4.37 M duplication+substitution mutants per tape: no loop solver. A second copy loop never exits in the soup, and its body still needs rewriting. | 1 slice | As indels | Ohno 1970 |
| **Add-from-head1 op** (B[h0] += B[h1], assay-only) | One two-input primitive | ADD becomes `<<{=!` | *Pilot, exhaustive ≤ 2 substitutions with `=` on (3 tapes)*: DOUBLE is 1 step (4573: 10 replicating singles) or 2 (4579, 4581: 41–92 replicating doubles). ADD is 2 steps (4573: 8). SUB, NOT and MUL: none. **The ladder gets taller and keeps its gap.** | 1–2 slices | Inflates H-ladder with one-step rungs (the brief's warning) | 2607.09211's Z80 has ADD |
| **NAND op** (B[h0] = ¬(B[h0] ∧ B[h1]), assay-only) **+ Avida's nine logic tasks** | One primitive; a compositional ladder | Every task is a composition of NANDs (1, 1, 2, 2, 3, 3, 4, 4, 5), so lower rungs are parts of higher ones: stepping stones exist by construction. | *Pilot*: 2 of 4 worlds climbed to 3–4-NAND rungs in 20 000 epochs. XOR and EQU: none, and not within 2 substitutions (anywhere) or 3 (in the code window) of the measured solvers (§4.2). With the lower rungs unpaid, nothing climbed (2 of 2). | 4 slices + sweep | Imports a primitive as well as an objective (label). The soup is untouched: `~` is a no-op there, and a reward of 0 runs no assay. | Lenski et al. 2003 (Nature 423:139); Ofria & Wilke 2004 |
| **Conditional or register** | New control or state | Shorter loops | No measured target. A conditional does not remove the counted loop's six bytes, and a register is a new machine. | ≥ 3 slices | Large interpreter change | — |
| **Stepping-stone arithmetic tasks** (x+2, y, y+1, "x+y when y ≤ 1") | Denser rewards | Lenski's EQU needed rewarded intermediates. | The intermediates on every path to a loop solver emit only input offsets and zero-test quirks (§1.4). Rewarding y, y+1 or x+2 adds one-step rungs and pays at most a kernel's head moves, never its loop body. "x+y when y ≤ 1" cannot be posed: the separating rule refuses an input held constant, and a loop has no partial form for per-case credit to pay. | 1 slice | A taller ladder of one-step rungs | Lenski 2003 |
| **Longer runs / more mutation** | Time or supply | Crossing a neutral or valleyed 5–7-step gap | Order 10⁴–10⁶ epochs for a neutral walk, and ~10⁸ for a valley | 0 slices, ≥ 10× compute | Mutational load | — |

## 4. Pilots (question 4)

All of these are pilots.
- **Engine.** A copy of main's engine, with:
  - `indel_share`, the share of mutation events that are insertions or deletions, half
    each, length kept;
  - `tasks = logic`, with the assay-only `~` and the nine tasks;
  - `logic_from`, which pays only the rungs from a given index up.
- **Start.** Each run descends from a from-emerged parent at epoch 20 000 under the
  Metabolism economy: `initiator`, influx 1 024, cap 65 536, no theft, an assay every 8
  epochs, 2 048 per unit, seed 1, 20 000 epochs.
- **Readings.** Shares were read every 500 epochs over all 16 384 cells on one fresh case
  set, alongside a 128-cell detector share.
- **Budget.**
  - About 2 core-hours of pilot runs: 11 runs, plus one cap-256 run (1029) cancelled at
    start to stay in budget.
  - About 1.5 core-hours of landscape enumeration.
  - About 1.7 h of wall time on a Mac shared with another session.
  - The data volume stayed at 82–85%, and one end-of-run world was saved per run
    (≈ 300 KB, 3.6 MB in all).

### 4.1 Pilot A: indels on the Metabolism ladder

`indel_share = 0.5` at the parents' own rate, so half of all mutation events are
insertions or deletions.

*Pilot.* Cells credited with each task, out of 16 384, read every 500 epochs:

| parent | one-step rungs (first epoch at ≥ 10%) | most cells ever credited with a loop task | detector share at the end |
|---|---|---|---|
| 1007 | ECHO 500, INC 2 500 | **0** | 0.98 |
| 944 | ECHO 500, INC 1 000, DEC 2 500 | **0** | 0.93 |
| 2577 | ECHO and INC 5 000, DEC 6 500 | **0** | 0.97 |
| 2700 | ECHO 9 000, INC 13 000 | **0** | 0.93 |

**Indels did not open the loop rungs.**
- No loop-task credit appeared in any cell at any reading, in any of 4 worlds, over
  20 000 epochs each.
- The one-step rungs climbed as fast as before, or faster.
- The worlds kept copying: detector share 0.93–0.98 at the end, never below 0.51.

**Baseline.** The same parents under the arithmetic ladder without indels give the same
picture:
- the Metabolism pilot: 1007 and 2577, 0 loop rungs;
- the live sweep's 6 finished 944/950 reward children, interim: a loop share of exactly 0
  in every sample.

### 4.2 Pilot B: the NAND op and the logic ladder

**The assay.**
- The assay is Metabolism's: buffer, emit, budget, 3 cases and 4 slots.
- x and y are uniform bytes.
- A case set is redrawn until it separates the ladder, 73% acceptance:
  - x pairwise distinct, and y pairwise distinct;
  - every form of every task expects three distinct outputs;
  - no two forms of different tasks, and no form and an input, expect the same three;
  - no form is an input plus a constant.

**The ladder** (NOT and ORN and ANDN credit either form):

| task | units | minimal NANDs |
|---|---|---|
| NOT | 1 | 1 |
| NAND | 1 | 1 |
| AND | 2 | 2 |
| ORN | 2 | 2 |
| OR | 4 | 3 |
| ANDN | 4 | 3 |
| NOR | 8 | 4 |
| XOR | 8 | 4 |
| EQU | 16 | 5 |

That is 46 units against the arithmetic ladder's 45.

**Hand-written solvers** (head0 and head1 start at 0):

| task | program | ops |
|---|---|---|
| NOT | `<{~!` | 4 |
| NAND | `<<{~!` | 5 |
| AND | `<<{~{~!` | 7 |
| OR | `<{~<{~}~!` | 9 |
| XOR | `<<<{,{~>>{~<~}}~!` | 17 |
| EQU | `<<<{,{~>>{~<~}}~{~!` | 19 |

Each is credited with its own task alone on 200 of 200 case sets. Echo, a pure copier and
the sprayer `[!+]` are credited nothing.

*Pilot, full ladder.* Cells of 16 384:

| parent | first epoch at ≥ 10% (rungs by minimal NANDs) | end, cells | XOR/EQU ever | detector share, end |
|---|---|---|---|---|
| 1007 | NOT, NAND 2 000 (1); ORN 7 500 (2); OR 8 500 (3); NOR 9 500 (4) | OR 15 254, NOR 12 330, NOT 2 524, ORN 282 | **0** | 0.93 (379/400 by the census check) |
| 944 | NOT 3 000 (1); ORN 14 500 (2); NAND 15 000 (1); AND 15 500 (2); ANDN 16 500 (3) | ANDN 9 447, ORN 8 156, NAND 2 420, NOT 1 667, AND 749 | **0** | 0.10 (37/400), see §5.6 |
| 2577 | none (at most 2 cells) | — | 0 | 0.84 |
| 2700 | none (at most 9 cells) | — | 0 | 0.89 |

**The credits are genuine.** For each world's commonest credited tape per task:
- per-input accuracy of the best slot over 4 000 random input pairs is 0.988–0.997 in 1007
  and 0.996–1.000 in 944;
- they are credited on 194–200 of 200 fresh case sets;
- the failures are zero-byte branches, about 1 input in 100–250.

The commonest OR/NOR solver in 1007:
`······+··<·[.·····~····.<··~····~·!····>·,>~{···~]·······…`
That is the parent's reverse copier, with `~`, `!` and head moves woven into the code before
and inside its copy loop.

**Controls, *pilot*:** Both controls ran on the two worlds that climbed, seed 1, 20 000 epochs.

| world | arm | most cells ever credited | rungs ever at ≥ 10% |
|---|---|---|---|
| 1007 | full ladder (above) | OR 15 254, NOR 12 450 | NOT, NAND, ORN, OR, NOR |
| 1007 | **deep-only** (pays OR and up) | NOT 241, NAND 38, everything else ≤ 2 | **none** |
| 1007 | **no reward** | NOT 248, NAND 51, everything else ≤ 2 | **none** |
| 944 | full ladder (above) | ANDN 12 199, ORN 11 203 | NOT, ORN, NAND, AND, ANDN |
| 944 | **deep-only** (pays OR and up) | NOT 8, NAND 1 | **none** |

With the stepping stones unpaid, the rungs that climbed in the full arm did not appear:
- OR by 8 500 epochs in 1007's full arm;
- ANDN by 16 500 in 944's.

The deep-only worlds look like the no-reward world. That is Lenski's contrast on 2 of 2
worlds, at the 3–4-NAND level the pilot reached. It is a pilot: one seed, and a floor at OR
rather than XOR.

**The depth of each rung, measured on the pilot worlds** (exhaustive, over the 13 values
plus `~`, 6 case sets, and the detector for "replicating"):

| focal tape | single substitutions gaining … (replicating) | double substitutions gaining … |
|---|---|---|
| 1007, ORN solver | OR 16 (11), NOR 18 (14), ANDN 47 (10), NAND 21 (13), AND 11 (9) | XOR 0, EQU 0 |
| 1007, OR+NOR solver | ORN 43 (29), NOT 126 (40) | XOR 0, EQU 0 |
| 944, NAND+ORN+ANDN solver | AND 60 (58), NOT 119 (89) | OR, NOR, XOR, EQU 0 |
| 944, NOT solver | ANDN 3 (3), NAND 19 (0), ORN 39 (0) | OR 1 141, XOR 0, EQU 0 |
| parent 1007's commonest copier | nothing | nothing (NOT needs `~` and `!` together, and more) |

**Triples.** In the first 56 bytes, over 13 values plus `~`:
- 1007's NOR solver: 71.2 M triple mutants, XOR or EQU on all 6 case sets 0 (48 on one set);
- 944's ANDN solver: 72.3 M, 0.

**What this means.**
- Up to NOR, the logic ladder is a staircase of one- and two-substitution rungs. The pilot's
  climb to 3–4-NAND rungs is a climb up that staircase, and it is no evidence of
  open-endedness by itself.
- XOR and EQU sit beyond the staircase: they need a stored intermediate (`,` into a scratch
  cell) and three or more coordinated changes. They are the logic ladder's analogue of the
  loop rungs, but with paid parts (ORN is a sub-computation of XOR).

**Cost, *pilot*.** The logic runs took 400–515 s per 20 000 epochs on the loaded Mac. That
is no slower than the arithmetic-plus-indel runs beside them (548–645 s at 14 000–18 500
epochs).

## 5. Recommendation (question 5)

**One change: Logic.**
- An assay-only NAND byte and Avida's nine logic tasks, paid exactly as Metabolism pays: the
  `initiator` economy, an assay every 8 epochs, 2 048 per unit.
- In the engine it is Soup plus `tasks = logic`. In the record and on the site it is a
  variant of the Metabolism substrate: it imports an objective **and a primitive**, and it
  carries Metabolism's label and pooling rule.

It is the cheapest change the measurements support:
- indels, duplication and denser arithmetic rewards were each measured not to shorten the
  gap, nor to put a reward inside it;
- an add-from-head1 op makes the ladder taller and keeps the gap;
- NAND is the one primitive whose ladder has a known compositional depth and a stepping-
  stone result to test against (Lenski 2003).

### 5.1 Keeping the question honest

The logic ladder has its own one-step rungs, so H-ladder cannot simply move over.

**Measured on the pilot worlds:**
- From evolved ORN solvers, OR, NOR and ANDN are each one substitution away (10–14
  replicating single mutants).
- From an evolved NAND solver, AND is one substitution away (58 replicating single mutants).
- XOR and EQU are reached by **no** single or double substitution of any evolved solver
  (1007's OR and ORN solvers, 944's NAND and NOT solvers: ≈ 6 M double mutants, 0).
- No triple substitution in the code window reaches XOR or EQU either. Over 13 values plus
  `~` in the first 56 bytes: 1007's NOR solver, 71.2 M mutants, 48 credited on one case set
  and 0 on all six; 944's ANDN solver, 72.3 M, 0. Within that window, XOR and EQU are
  at least four substitutions beyond the solvers measured.

**The pre-registration therefore names:**
- XOR and EQU as the **deep** rungs: the analogue of Metabolism's loop rungs, and the only
  ones rung 4 is read on;
- NOT through NOR as **capability**: the analogue of ECHO, INC and DEC.

It also carries Lenski's control: a **deep-only** arm in which every rung below XOR pays
nothing. That separates "deep features are built on paid parts" from "deep features are
directly reachable".

The claim stays Metabolism's (design study §6): a mechanism, not open-endedness. The
ladder is finite, the objective and the primitive are imported, and Soup's rung 4 stays
"not shown".

### 5.2 The sweep and its hypotheses

**Shape.** A descendant sweep under the from-emerged parent rule: the 18 parents, seeds
2001–2003, 40 000 epochs past the parent. Three bundles, each merged over the parent's
params:
- **full**: `{energy_payer: initiator, energy_influx: 1024, energy_stock_cap: 65536,
  steal_amount: 0, tasks: logic, task_every: 8, task_reward: 2048}`;
- **deep-only**: the same, with `task_floor: xor`;
- **none**: the same, with `task_reward: 0`.

**The none arm is a duplicate.** It is byte for byte Metabolism's no-reward arm, because
`~` is a no-op in the soup and a reward of 0 runs no assay. A readings pass over that arm's
stored worlds could stand in for it. The plan runs it anyway: it is simpler, and it checks
the identity.

**Readings, as Metabolism's.**
- #263's settling window of 1 000 epochs.
- Deciles over the settled samples, with lower-middle medians.
- Extinct where the last-decile median `replicator_share` is below 0.1.
- Pairs with an extinct child are left out.
- One-sided sign tests: shown at p < 0.05; refuted where the control's pairs are at least
  as many.
- `Lab::FromEmergedHeldout`'s pairs, sign test and settling window.
- `Lab::DescendantReading`'s deciles, per-parent agreement and leave-one-or-two-out.

**The four tests:**
- **H-capability-L** (full against none): the last-decile median `logic_capability`, the
  rungs at a share ≥ 1/10. *Pilot:* 2 of 4 full worlds held ≥ 3 capabilities at 20 000
  epochs. The no-reward 1007 twin held none: at most 248 cells
  ever credited with NOT, 51 with NAND, and 2 or fewer with anything else.
- **H-deep**, the rung-4 question (full against none): the same test on
  `logic_capability_deep`, the count of XOR and EQU at ≥ 1/10.
  - *Pilot:* 0 of 4 full worlds reached XOR or EQU within 20 000 epochs. That is an upper
    rate bound of 0.6, so the power is unknown.
  - The test needs 5 discordant pairs. Its power is 0.64 at a rate of 0.1 per child over
    54 pairs, and 0.92 at 0.15, the same arithmetic as Metabolism's H-ladder.
- **H-stones**, Lenski's (full against deep-only): the same key.
  - *Pilot proxy*, deep-only from OR up: in 1007 and 944, neither world reached any rung at
    1/10 in 20 000 epochs, where their full-ladder twins reached OR/NOR and ANDN (§4.2).
- **H-complexity**: the from-emerged rise rule on `dominant_instruction_count`, as
  Metabolism reads it. It reads "paid complexity rises", never "open-ended".

**Descriptive:**
- the first epoch each rung reaches 1/10, which gives the ladder order;
- whether a deep rung appeared only in worlds already holding OR, ANDN or NOR (Lenski's
  stepping stones);
- per child, the substitution distance from its parent's commonest copier to its deepest
  solver, measured with this study's landscape tool on the stored end worlds.

### 5.3 What each outcome means

- **H-deep shown and H-stones shown.**
  - A BFF soup assembles features several coordinated substitutions beyond any solver it
    holds (≥ 4 in the measured window), and only when the parts are paid: Lenski's
    mechanism, in a soup.
  - Read beside a refuted Metabolism H-ladder, the plateau of arithmetic was the missing
    stepping stones of BFF's instruction set, not an inability to accumulate.
- **H-deep shown, H-stones refuted.** The deep rungs are directly reachable, so the depth
  this study measured overstates the barrier. Complexity rises when paid, with or without
  parts.
- **H-deep refuted.**
  - With a composable primitive and every lower rung paid, the soup still stops short of a
    feature four or more substitutions deep.
  - The binding constraint is then the copier and its population, not the instruction set:
    - the code must run before a copy loop that never exits;
    - the reverse copier's mirror halves selection on a new feature;
    - a specific byte arrives at 4.8 × 10⁻⁷ per epoch.
  - The next suspects are mutational supply (a rate arm) and a code region separate from
    the copied tape. The "ladder of compositions" route is closed.
- **H-deep not shown.** The rate of deep climbing is below what 54 pairs resolve.
  Metabolism's power arithmetic applies.


**If Metabolism's own H-ladder reads shown, or merely not shown, rather than refuted.**
Then loop rungs were reached at scale despite the 5–7-substitution gap measured here.
- The first step is to read its loop-rung children with this study's tools: the depth they
  crossed, and whether through a neutral path (§1.4).
- Only then build Logic.
- The diagnosis above predicts refuted, or all pairs tied at zero.

### 5.4 Engineering slices (dependency order, each about 90 minutes)

1. **Engine: the NAND byte, the logic assay and the reward.**
   - Files:
     - `bff.rs`: `~` (0x7E) is an instruction only behind the emit switch, so the soup's
       table never holds it. A lap holding `~` is not replayed, exactly as a lap holding
       `!` is not.
     - a new `logic.rs`: the nine tasks and their forms, units, the separating draw and
       credit, and a memo;
     - `params.rs`: `tasks = logic`, and `task_floor`, the lowest rung paid (default the
       first);
     - `world.rs`: `pay_tasks` dispatches on `tasks`;
     - `runner schema` exports the ladder.
   - Spec:
     - the six hand-written solvers of §4.2 are each credited with their own task alone
       over 10^5 separating draws;
     - copiers, echo and sprayers are credited nothing;
     - the separating rule holds over 10^5 draws;
     - every soup pin and digest is unmoved;
     - `tasks = logic` at reward 0 is byte-identical to `tasks = off`;
     - the emit-plus-NAND interpreter equals the stepper written by the book, skipping or
       not;
     - `task_floor` pays only rungs at or above the floor;
     - a logic reward determinism pin.
2. **Engine: the observables.**
   - `logic_share_<task>` (9 keys), `logic_capability`, `logic_capability_deep` and
     `dominant_logic_tasks`.
   - Live-only, null unless `tasks = logic`, each on a stream of its own, digest split.
   - The prefix keeps the arithmetic keys unambiguous: bitwise NOT of a byte is 255 − x,
     the same function as the arithmetic NOT.
   - Slices 1 and 2 deploy together, as one runner restart, **after the Metabolism sweep is
     final**, since a merge restarts the runner and kills live runs.
3. **Rails: the sweep and its pre-registration.**
   - `Lab::SWEEPS["logic"]` reuses the from-emerged parent rule and adds the three bundles.
   - `Lab::LogicReading` holds the constants.
   - The record entry carries the pre-registration, the measured depths of §5.1 and the
     label. DESIGN gains §1.3 item 16 and a §1.4 paragraph.
   - Spec: 162 children, built idempotently.
4. **Rails: the reading.** `Experiments::LogicReadingService` and `lab:logic_report`, with
   CSV, over both pairings. Spec: hand-built children for every outcome branch.
5. **Later: the finding page**, with the label, once the reading is final.

### 5.5 Cost on the mini-pc (12 slots)

**Per child**, from Metabolism's finished children (`compute_seconds`, cap 128, 40 000
epochs):
- reward: 1 650–2 520 s, about 2 000;
- no-reward: 1 230–1 740 s, about 1 420.

**Per arm:**
- The full arm should cost what Metabolism's reward arm costs. *Pilot:* the logic runs
  ran no slower than the arithmetic runs beside them (§4.2).
- Deep-only pays for the assay but rarely rewards, so about 1.17 × no-reward (the
  Metabolism study's assay-on/assay-off ratio): about 1 660 s.
- Cap 256 at 1.3×.

**Total:**
- 3 × (11 × 5 080 + 7 × 6 600) ≈ 306 000 run-seconds, about 85 run-hours, or **about 7 h
  of the mini-pc**.
- About 5 h without the none arm.
- The first finished children's `compute_seconds` replace this estimate.

### 5.6 Risks

- **Partial copiers read as extinct.** *Pilot:* 944's full world ended with 81% of cells
  credited and its commonest solvers passing the detector. Yet only 9% of 400 sampled cells
  passed (§4.2), because most interactions there are short in-register overwrites of kin:
  1 376 steps per interaction on average, against 7 100–8 000 in copier worlds.
  - Metabolism's extinction rule (last-decile `replicator_share` < 0.1) would drop that
    pair.
  - The pre-registration should report, beside each test, the reading with such pairs
    kept.
- **The first rung is two bytes, not one.** NOT needs `~` and `!` placed together, where
  ECHO needed only `!`. 2577 and 2700 climbed nothing in 20 000 epochs. An ECHO rung of 1
  unit at the bottom would restore Metabolism's entry. It is a choice to make in slice 1;
  the pilot did not test it.
- **Near-solvers.** Evolved solvers fail on 0–1.2% of inputs (zero-byte branches). They are
  credited on 194–200 of 200 case sets, and the credit is genuine computation; the full
  check is in §4.2.

