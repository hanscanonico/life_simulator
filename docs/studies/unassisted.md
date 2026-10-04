# Design study: from imported scaffolding toward unassisted open-endedness

2026-10-03. A design study. It seeds nothing and touches neither the repository nor the lab. The lab was read with
SELECTs only; three stored worlds and their params were copied out to a session scratchpad. Every number marked *pilot*
comes from a throwaway copy of main's engine (`b30196a`) in that scratchpad, not kept, and is not a finding. The
literature was read by a literature agent of this study against primary sources (§3).

## 0. In brief

1. **The ablation ladder (§2).** Of Meta-stack's four imports, the semantics (S) is known load-bearing (H-stack, a
   finding), the primitive (P) is load-bearing by construction (BFF has no bitwise op), and removing the channel (C)
   is predicted to fail for two measured reasons, the copier valley and the error threshold. Removing the objective
   (O) bare is answered too: every none arm collapses. So **O comes off first, by substitution**: replace the paid
   ladder with an interaction rule that reads what tapes compute and names no computation. Then make P and S part of
   the soup's own instruction set, re-showing emergence; then make heredity the program's. Direct −C and −S sweeps
   are specified with predictions (both refuted) and costs, and not recommended.
2. **The literature (§3).** Every system that plateaus has this programme's shape: once replication is optimised,
   nothing pays for more (Tierra, Avida with no tasks, Lenia, BFF, the 2026 Z80 soups). The one controlled
   demonstration of escalating complexity with an endogenous gradient is Zaman et al. (2014): parasites that infect a
   host computing a function they compute drove EQU in 17 of 50 host populations against 0 of 50, but the hosts were
   paid a flat rate to compute at all, and the scale stopped at EQU. Arms races escalate only when the key is the
   computed phenotype, diversity is kept, and dominance is transitive; sustained growth anywhere (MCC 2019, Geb 2019)
   needed an unbounded representation and was linear or logarithmic.
3. **The best unassisted bet (§4): out-compute to eat.** A cell takes energy from a neighbour whose every computed
   function class it also computes. It names no function (relabelling-invariant) and grades nothing absolutely
   (relational); silence is everyone's prey, so no minimal criterion is needed; dominance is transitive, so the race
   ratchets; clones eat each other, so novelty is paid by the population itself.
4. **The pilot (§4.3)**, about 2.7 CPU-hours under a heavy external load (§6). From two fitness-free reach-cap128
   worlds whose metabolism tapes computed nothing at descent, with nothing paid, out-compute (×8 rate) held **depth 5
   and 6** functions by a tenth of the world (EQU is 5) and depth 7 by a hundredth, with 5–6 classes per cell and 13–15
   classes held by a tenth; drift and "be different" held depth 0. The climb came in the first 10 000 epochs and then
   stopped: by the topless-rise rule one world rises late by one NAND on a flickering series, the other does not; the
   bottom of the distribution never moved. At Meta-stack's ×32 rate (with half the take) the same rule held only depth 1; over exact
   functions (not classes) it rewarded echoing the inputs; and Meta-stack's paid depth did not survive without pay.
5. **The second mechanism (§4.5)** is not a second objective but room to grow in the computing channel (a growable
   metabolism tape with duplication, and a widening input window): every sustained rise in the literature needed an
   unbounded representation, and topless-rise's paid children already stop at 8–10 on four inputs and 32 bytes.
6. **The bar (§5).** Six clauses, all required: spontaneous origin on the same physics; no imported objective
   (relabelling-invariant and relational); a function-side and a program-side measure on a channel with no near top;
   at least three persistent new maxima with the last in the final quarter; drift, no-ratchet and shadow controls,
   plus McShea's rising minimum; many worlds, pre-registered, at least 10⁶ epochs (~10⁵ generations). Today the
   programme meets the first clause on plain Soup only, and the pilot meets the second and part of the fifth.
7. **Pilot 2 (§7): room to grow does not keep the climb going.** A growable metabolism tape (32 → up to 256 bytes,
   segment duplication and deletion at Lenski's 0.05 per divide) under out-compute, 60 000 epochs on both worlds:
   one NAND deeper and one or two more classes per cell than the fixed channel, reached within 15 000 epochs, then
   flat; neither growable run meets §5.4 (one fixed run does, by one NAND); the minimum stays at 1. The tapes grow to
   ~210 bytes, but every load-bearing byte is in the first 16: one stack-NAND loop spends the emit budget, so
   appended code is never read, and a changed loop replaces its classes rather than adding to them, so the subset
   ratchet does not pay it. Not recommended as a sweep arm; the next lever is what a tape can add without losing a
   class, not the channel's length.
8. **Pilot 3 (§8): out-count and an emit budget that grows with the tape.** Out-count (a cell may eat a neighbour
   that computes strictly fewer classes) passes both tests of clause 2, is transitive and keeps silence as prey; ties
   stay neutral (a ties-as-prey probe moved 50% more energy for no consistent gain). Alone on the fixed channel it
   sits within a NAND of subset (4428) or two to three above it (4381), then stands still for 52 000 epochs. An emit
   budget of max(16, L/2) alone, under subset, lets the commonest loop's whole orbit be read (one NAND more), then
   stops. Together, from worlds computing nothing, they hold 54–63 classes and depth 10 by a tenth within 10 000
   epochs (11–28 classes and depth 4–7 in the other arms, 1 class and depth 0 under drift). The worlds get there
   through stack loops of 21–27 load-bearing bytes whose orbits stay open, with appended junk buying about one class
   per two bytes until the 128-byte cap. Then the top stands; only the middle of the distribution climbs late, and
   the minimum rose once (A on 4428, 1 → 2). The next step is a pilot at a cap the run cannot reach, read on
   load-bearing bytes, before an out-count sweep.
9. **Pilot 4 (§9): A+B at a cap of 512, read on the program side.** The cap was reached in 9 000–10 000 epochs, as
   128 was in pilot 3. At it, 4428 holds 219–221 classes by a tenth and depth 13 (the end of the four-input scale) and
   4381 46–174 (its top fell and recovered); drift holds one class. Past about 600 bytes the fixed 4 096-step budget
   binds instead, so on this machine length never becomes free. The program side does not compose: in 154 solver
   readings every repertoire is one stack-NAND loop of 21–29 load-bearing bytes, never two top-level loops, and it steps
   only by editing that loop while length grows (4428: 14 → 21 bytes, then flat for the last 4 000 epochs; 4381 flat at
   22–28, a longer body appearing in its last 1 000). A lap budget per loop entry, which makes every loop exit, was
   beaten within 3 500 epochs by nesting the loop inside another. Horizons 10 000–15 000 epochs, cut to the budget.
   Recommendation: no count-grow rise sweep; a level sweep at cap 128 (count-grow, subset-grow, shadow-grow,
   drift-grow), and a machine pilot with independent entry points before any rise sweep.
10. **Pilot 5 (§10): independent entry points ("genes").** The assay runs each 32-byte segment of the tape as a gene,
   alone on its own buffer with its own 16 emits and 4 096 steps, and credits the union; nothing is graded, and a gene
   cannot touch another's result. Under out-count the program side composes for the first time: from 5 000–7 500 epochs
   the top solvers hold two (4381) or two to three (4428) load-bearing genes with distinct bodies, a main loop of 12–14
   classes beside a second loop or a satellite emit, new code rather than copies. Then it stops: essential genes held by
   a tenth stand at 2 and 3 from 4 500 and 8 000 epochs to 20 000 while the tapes fill the 512-byte cap with 15–16 genes,
   about 12 of them silent; classes held by a tenth 19–22 (A: 11–15; A+B: 54–220); the minimum stands; whole-gene
   duplication (Ohno) changes nothing by 10 000. The load-bearing code totals 18–33 bytes on every out-count machine of
   pilots 3–5. Recommendation: no genes rise sweep; genes may join §9.10's level sweep as two arms (count-genes,
   drift-genes); and a mutation-load pilot (×2, ×4) before any rise sweep.

11. **Pilot 6 (§11): the mutation load.** The plateau is Eigen's error threshold. The out-count economy gives the top
   tier σ ≈ 1.28–1.37 a generation (lineage-tag growth; 1.0 under drift), and at ×8 the top solvers' load per
   generation is U = 0.27–0.33, so σ ≈ 1/Q: the reference worlds sit at the threshold. Lowering `meta_rate` to 4/8192
   and 2/8192 lifts the code held, read at 15 000 epochs, from 25–29 to 49–53 and 79–94 class-losing byte-equivalents
   (count-bearing bytes 26–29 → 59–62 → 98–102; load-bearing genes 2 → 3 → 5), close to the predicted 24, 48 and 84,
   while U stays 0.25–0.30 at every rate. Classes held by a tenth go 21–22 → 25–27 → 37–62, and McShea's minimum moves
   for the first time (max depth p10 1 → 5–6 → 7). The climb is not slower at the lower rates, and ×2 stands too: its
   code is flat from about 8 000 epochs (one more gene late in each world) and its plateau comes at 8 000–10 000 epochs,
   against ×8's 5 500–8 000: the level scales with 1/μ, the time to reach it does not. Recommendation: engineer
   heritable fidelity next, and run the level sweep's count arms at 2/8192 with an H-load key.

12. **Pilot 7 (§12): evolvable fidelity.** A heritable fidelity level per cell, outside the tape, carried with the
   metabolism tape and moved ±1 at 5% of inheritances, sets that cell's substitution rate (×8 · 2^(−f/2)); it names no
   function and passes both tests of clause 2. **Free**, it runs from ×8 to ×0.044 (the floor is ×1/32) within 12 500
   epochs in both worlds while drift leaves it wandering; the substitution load falls to 0.01–0.04, the error threshold
   stops binding (the frameshift is now most of the load), held code doubles past fixed ×2 (`sub` 140–190, 9–10
   load-bearing genes) and fills the 512-byte cap, then creeps; at cap 1 024 it keeps climbing (81 classes held against
   54) to the new cap. But free fidelity buys code, not repertoire (classes held as fixed ×2), and the world thins to a
   near-monoculture. A **cost** (price ∝ rate^−α) sets a continuous balance: the top lineage's substitution load
   settles at α, not at the knife-edge α_c ≈ 0.2 predicted (fidelity reaches the balance before code does). α = 0.4:
   the ×8 machine; α = 0.1: the top lineage at ×1–×2.8, code 30–55; **α = 0.03: the most classes, depth and minimum
   of any arm** (4428: 80, 11, 10 against free's 54, 8, 7; 4381: 40 against 32–34). Where sloppiness can be bought
   below the base price, every costly arm collapses within 1 000 epochs (the price refuge out-pays computing's σ).
   Recommendation: staged, costly fidelity (α ≈ 0.03), a larger cap with marker-defined genes, and pilot 8 across α,
   cap and seeds before any sweep.

13. **Pilot 8 (§13): the late climb at a cap the run does not reach.** Pilot 7's machine (strict out-count, genes,
   the growable channel, staged fidelity) at cap 4 096 on both worlds at α 0.01 and 0.03, each lane with a matched
   twin forked to cap 1 024 (the two are one run until a tape needs the room), a second seed for one cell, drift, and a
   probe with marker-defined genes; 30 000–35 000 epochs, about 4.1 CPU-hours. With the cap out of reach (longest
   tapes 1 900–2 500 bytes) **every one of six count lanes is still climbing late**: the rise rule and §5.4 pass on
   classes held by a tenth (84–182 at the horizon; markers 315), essential genes held (21–30; markers 50), the top
   solver's count-bearing bytes
   and load-bearing genes, and the minimum's repertoire (classes p10), while drift holds one class. The capped twins
   flatten within a few thousand epochs of 1 024 (the unreached twin holds 1.15–1.6 times the classes at 30 000). The
   climb runs on selected length: code and genes grow in proportion to it, classes less than in proportion and
   slowing (each new gene adds fewer new classes; nothing composes). At α 0.03 the top lineage's U_sub stays near α
   until the fidelity menu's floor, reached at 21 500–28 000 epochs. Markers cut the frameshift by 40% and doubled the
   level, confounded by the full budget they give each short gene. The rule and §5.4 also pass on the capped twins'
   creep, so a sweep needs a magnitude or a paired room control. Recommendation: engineer the machine and run a
   pre-registered 60 000-epoch rise sweep (count, capped, shadow, drift on 30 parents; about 16–24 hours of the 12
   slots), stated as short of clause 6, which this machine cannot reach at affordable cost because its climb rides on
   length.

## 1. Where the programme stands (read from the sources)

### 1.1 Shown, fitness-free

- **Emergence**: on growable tapes (cap 128) at radius 4, 119 of 270 worlds against 11 of 270 at radius 1, one-sided
  Fisher p = 1.5 × 10⁻³⁰ (`reach-4-carries-to-growable-tapes`, 2026-10-03); 108 of those worlds end with replicators
  on at least half the world, the eligible-parent pool.
- **Persistence and heredity**: 52 of 54 continuations held their replicators (`complexity-from-an-emerged-start`);
  the emerged worlds are 74–99% orientation-aware replicators that copy in reverse.
- **Adaptation**: under an energy economy the dominant tape's copy latency falls, 20 of 24 and 21 of 24 held-out
  pairs (`copying-gets-faster-under-an-economy`).
- **Rung 4 on plain Soup: not shown.** Five fitness-free bets (instruction cost, environmental structure, room to grow,
  contested energy with theft, asymmetric execution) plateaued or were barren. The record's mechanism (2026-09-16):
  a drift–selection balance in which "a byte off the copy path costs nothing and buys nothing"; junk is free and
  length cannot be selected for. The BFF group's 2026 paper (arXiv 2607.01483) expects the plateau.

### 1.2 With imports (each carries the "imports an objective" label)

| substrate | imports | rung-4 reading | why it stopped |
|---|---|---|---|
| Metabolism | objective (arithmetic ladder) | refuted: ECHO, INC, DEC, no loop rung, 0 to 0 | the only loop a copier owns is its copy loop (`logic.md`) |
| Logic | + primitive (`~`, in place) | refuted: every read-once rung, no XOR/EQU, 0 to 0 | fan-out under an in-place NAND, and the copier valley (`meta-stack.md` §2) |
| Meta-stack | + channel (metabolism tape) + semantics (stack NAND) | **shown**: XOR or EQU at a tenth in 9 of 54 children, 9 to 0, p = 0.00195; the in-place twin built none | a population property re-derived within ~500 epochs, not a lineage's invention; the ladder tops out at EQU |
| Topless-rise (running) | + a ladder of growing input arity (4 inputs, depth-scaled pay) | interim | see below |

**Topless-rise, interim** (my own SELECTs, 2026-10-03 ~15:20, a rough reading and not the locked report): 48 of 162
children finished. Over the finished children's settled samples:

| arm | finished | median last-decile `logic_depth_max` | median fifth-decile | last decile above the fifth |
|---|---|---|---|---|
| rise | 15 | 10 | 10 | 0 |
| capped (paid as 5) | 17 | 7 | 7 | 3 |
| none | 16 | 0 | 0 | 0 |

- 13 of the 15 finished rise children reached their maximum (8, 9 or 10) within the first 25 500 epochs of 100 000,
  8 of them within 3 330; the other two touched 8 and 10 only in their last 5 000 epochs and their last-decile
  medians sit below it (6 and 8).
- Child 5011 (parent 4845, the start world of the topless pilots) reached 8 at 2 260 epochs and read 8 in every
  10 000-epoch block to 100 000; its **capped** twin 5012 also reads 8 throughout: depth past 5 that pay did not ask
  for, so at least part of the climb is hitchhiking or passive.
- The maximum any finished child shows is 10. On four inputs 10 is the **mode** of the depth scale: 959 of the 3 982
  input-permutation classes cost exactly 10 NANDs, more than any other cost (16 804 of 65 534 non-constant functions).

So even with pay, and on the ladder built to have no near top, the deepest rung jumps early and stands still, at the
depth where function space is densest. This is the study's most important input: **whatever replaces the objective
must be read on a computing channel that can grow, or "keeps rising" is unreadable by construction** (§5).

## 2. The ablation ladder (question 1)

### 2.1 The four imports, and what is already known about each

Meta-stack's claim (`paid-parts-assemble-deep-logic-on-a-stack-nand`) imports four things, and topless-rise a fifth
(a ladder of growing input arity, part of the objective). Each row says what removing that import alone would test,
and what the record already says about it.

| import | what it is in the engine | removing it alone tests | what is already known |
|---|---|---|---|
| **O, the objective** | `task_reward > 0`: the assay pays energy per credited rung, scaled by depth on the topless ladder | whether anything but pay makes computing worth carrying | Removing it bare is every sweep's **none** arm: nothing is read, the metabolism tape drifts, and computing decays. Logic's none arm (Meta-stack's twin as well): no deep rung in any child, and every measured pair favoured the paid arm on capability (53 to 0, 54 to 0). Topless-rise none (interim, my own SELECT, 16 finished children): depth 0 in every last decile. This study's pilot of Meta-stack child 4845 at reward 0 on four inputs: depth held by a tenth 5 → 0 within 500 epochs, 85% of cells computing nothing by then, and the replicating tape's detector share down from 0.86 to a low of 0.13 before it recovered to 0.76 (§4.3). **Bare removal is answered: collapse.** |
| **P, the primitive** | the assay-only byte `~`, a NAND (with `!` and the input layout, the assay's "chemistry") | whether BFF's own ten ops can compute what the ladder asks | Metabolism (no NAND, arithmetic, woven): one-substitution rungs only, H-ladder refuted 0 to 0. The logic study (`logic.md` §1): BFF has no two-input data op, so every two-input task needs a counted loop, and the only loop a copier owns is its copy loop. On the logic ladder BFF needs about a hundred ops per bitwise task. **Removing P from a logic ladder is answered by construction: nothing bitwise is reachable.** |
| **C, the hereditary channel** | the 32-byte metabolism tape, never executed in the soup, copied whole by the world onto a near copy | whether the replicator can carry its own computing | **Pilot only**: `meta-stack.md` §7.4, last row: the stack NAND on the woven tape of 1007's world (μ × 1, no metabolism tape) climbed to NOR at 10 000 epochs and held no deep rung in 20 000. Meta-stack's H-decouple (meta-inplace against Logic full) tied 53 of 53, but both arms there ran the in-place NAND, so it does not isolate C under the stack NAND. |
| **S, the semantics** | `logic_nand: stack`: `~` writes NAND(B[h0], B[h1]) to B[h0−1] and moves head0 onto it | whether a NAND that destroys an operand can build fan-out | **Finding**: Meta-stack's meta-inplace arm (C, O, P kept, S removed) reached every read-once rung but AND and no deep one, 0 of 54; H-stack shown 9 to 0 (p = 0.00195). `meta-stack.md` §7.1–7.3: of six semantics, only the stack form f brings XOR within reach of what a soup evolves. **Removing S is answered: the deep rungs go.** |

**Why the deep study §7 says these fail.** Three measured reasons, each of which is a property of the machine
rather than of the objective:
- *Fan-out.* XOR and EQU are the two-input functions that are not read-once: any NAND circuit for them uses an input
  or an intermediate twice. An in-place NAND overwrites its own operand, so reuse needs a stored copy and re-aligned
  heads: ≥ 3–4 coordinated substitutions through credit losses (`meta-stack.md` §2.4). The stack NAND keeps both
  operands and stacks results leftward, so a loop's later laps read earlier laps' results: fan-out for free (`meta-stack.md` §7.4).
- *The copier valley.* On the woven tape no byte is free (0 of 128 in both pilot worlds, `meta-stack.md` §2.2). Every route to a
  deep rung moves data, and in those tapes data is moved by the copy loop, so every intermediate of the 20
  replicating 3-substitution EQU paths stops copying, and the endpoint copies with a one-byte rotation and is not
  heritable (`meta-stack.md` §2.4–2.5).
- *Supply under the error threshold.* A specific substitution arrives on the replicating tape at 1.4 × 10⁻⁶ per
  site per generation; the metabolism tape's `isa` draws at ×32 give about 8 × 10⁻⁴, some 570 times more. The
  copier melts between × 8 and × 16 (`meta-stack.md` §4.1), so the replicating tape cannot be given the metabolism tape's rate.

### 2.2 The order: the objective first, by substitution

S and P are the machine. They are now known to be load-bearing (S as a finding, P by construction), and they decide
*what a computation is*, not *which computation is wanted*. C is predicted to fail for two measured reasons, the
copier valley and the error threshold, neither of which any objective changes. O is the one import whose removal
is not yet answered in any useful form: removed bare it collapses (the none arms), but no sweep has ever replaced it
with something the world itself generates. It is also the import the user's bar is about: "imports an objective" is
the label that keeps rung 4 on Soup at "not shown".

So the ladder removes **O first, by substituting an endogenous pressure for it** (an interaction rule that reads
what the tapes compute and is blind to which function they compute: §4), then **C**, then makes **P and S** part of
the soup's own physics rather than removing them. Each step is one sweep and changes exactly one import.

| step | removes | keeps | the sweep, from evolved worlds | predicted outcome | cost on the mini-pc's 12 slots |
|---|---|---|---|---|---|
| **1 (−O)** | the paid ladder, replaced by the out-compute rule (§4) | P, C, S | *construction*: 54 fitness-free reach-cap128 parents (metabolism tapes switched on from their own bytes, so nothing computes at descent), arms **out-compute**, **equal** (the same transfers, no ratchet), **shadow** (the same transfers by a coin), **none** (§4.4). *Maintenance* from topless-rise's paid end worlds is not run first: in the pilot, pay-built depth did not survive the switch (§4.3) | **level shown, late rise not shown** (pilot: depth 5–6 and 5–6 classes per cell against 0 in every control, reached within ~10 000 epochs, then flat) | 54 × 100 000 epochs × (80 + 80 + 80 + 45 s per 1 000) ≈ 1.5 M run-s ≈ **36 h**; without shadow ≈ 26 h |
| **2 (−C)** | the world-copied metabolism tape: the assay reads the replicating tape (`meta_len: 0`) | O, P, S | from the 54 topless-rise rise-arm end worlds (epoch 160 000), arms **woven-rise** (`tasks: logic4`, reward 512, stack NAND, `meta_len` 0), **woven-rise ×4** (the replicating tape's `mutation_rate` × 4, still under the copier's threshold) and **woven-none** | **H-deep refuted**: depth falls to the read-once rungs the woven Logic sweep held (≤ 4 on the two-input ladder) and nothing deep re-climbs; ×4 changes nothing (`meta-stack.md` §1.3: a K ≥ 3 valley moves as μ^−K, a factor 64 against 10¹⁰). Copying holds. | 54 × 40 000 × (55 + 55 + 36) s ≈ 315 000 run-s ≈ **7 h** |
| **3 (−S)** | the stack semantics: `logic_nand: in_place` | O, P, C | from those 54, arms **inplace-rise** and the topless-rise rise arm as its twin | **refuted**: H-stack is already shown on the two-input ladder; on four inputs the re-expressed solvers lose their depth at the switch (`meta-stack.md` §7.3) and re-climb read-once functions only | ≈ **5 h**; low information, so **skip unless step 1 is shown** |
| **4 (P and S become physics)** | the assay-only status of `~`: `~` with the stack semantics becomes a soup instruction beside the ten, as `$` is, so the replicators run on the machine they compute with | O (endogenous by then), C | not a descendant sweep: emergence must be re-shown on the new instruction set from random soup (reach-cap128's world at radius 4, 270 seeds, its rule), then step 1 re-run on that substrate's emerged worlds | open; the risk is rung 1 (one more op in random soup changes what copy loops look like and how often they arise). This is the 2026-09-24 entry's option 5 | ≈ 270 × 21 min ≈ **8 h** for emergence, then step 1 again |

Steps 2 and 3 are listed because the brief asks for each removal. Both are predicted by measured mechanisms, and
neither tells the user anything about unassisted life that step 1 does not. The ladder's real sequence is
**1 → 4 → C made the program's**: first make the objective endogenous, then make the machine native, then make
heredity the program's. The last needs engineering, not a parameter: the metabolism tape becomes part of what an
interaction executes on (each cell's tape and its metabolism tape joined, so a copy loop that copies the cell must
copy its computing region too, and the world copies nothing). Whether the copier valley of `meta-stack.md` §2 returns
when the channel is copied by the program but never executed by the soup is the question that step answers.

## 3. What makes computation pay without an imported task (question 2)

Read on 2026-10-03 by a literature agent of this study, against primary sources (arXiv abstracts and full texts,
PMC, author PDFs). "Imported" means the experimenter chose which computations pay; "endogenous" means the payoff comes
from interactions that name no computation. Numbers are the sources'. Points the agent could not confirm from a
primary source are marked *unverified*.

### 3.1 The mechanisms, one by one

| mechanism | what it is | evidence for **sustained** complexity growth | objective | maps onto this soup as |
|---|---|---|---|---|
| **Avida, limited resources** (Cooper & Ofria 2002; Chow et al. 2004, *Science* 305:84) | each of the nine logic tasks tied to a depletable resource | diversity only: stable coexistence only when resources are limited (30 vs 39 populations); richness peaks at intermediate productivity. No complexity claim | imported tasks, endogenous frequency dependence | metabolism-tape pay depleted per class. Buys diversity, which escalation needs, not depth |
| **Avida with no tasks** (Dolson et al. 2019, MODES) | the "empty" environment | informative-site complexity rises fast, then "a decrease and leveling out", selection favouring efficient replication; in Logic-9 "an ongoing upward trajectory" | none | **this programme's plateau, already published for Avida** |
| **Avida parasites** (Zaman et al. 2014, *PLoS Biol* 12:e1002023) | parasites infect a host that performs **at least one function in common** and take 80% of its CPU; parasites are not paid for tasks | EQU in **17 of 50** coevolving host populations against **0 of 50** without parasites (p ≪ 0.001); host complexity (minimal NANDs of its most complex function) rose faster and higher; function-switching mutations > 10× more common. Capped at 5 (EQU) by construction; whether still rising at 500 000 updates *unverified* | hosts got **flat pay for any function** (no progressive ladder): the reason to compute is imported, the gradient endogenous | the steal op keyed on the victim's computed function. **The hole**: without flat pay, a tape that computes nothing is immune. §4's rule closes it |
| **Avida predator–prey** (Wagner, Zaman, Dworkin & Ofria, arXiv 1310.1369) | predators and prey in Avida | "coevolution induced **non-escalating** exploration of behavioral space" | endogenous | a warning: antagonism alone does not escalate |
| **Tierra** (Ray 1991) and **Network Tierra** (Ray 1998; Ray & Hart 2000) | self-replicating machine code competing for CPU and memory; template matching | parasites, hyper-parasites, social hyper-parasites, cheaters; size optimisation to 22 instructions; stasis in the size-80 range for 178 M–1.44 G instructions. Ray: "Tierra inevitably enters a period of permanent evolutionary stasis … the individual replicators generally do not increase in complexity". Network Tierra: cell types 2 → 3, judged a failure to raise them (Taylor 2014). Standish 2003: size grew, organismal complexity did not | endogenous (replication only) | sweeps 9 and 10, already run: theft evolved, host mode was barren |
| **Adami** (Adami, Ofria & Collier 2000, *PNAS* 97:4463) | physical complexity = genome length − Σ per-site entropy: information about the environment | rises almost monotonically over ~10⁵ updates, bounded by genome length and by the information a **fixed** environment holds | imported (computations buy CPU) | the program-side measure for §5; and the argument that a fixed task list bounds complexity |
| **Amoeba** (Pargellis 1996, 2001) | Tierra-like; replicators emerge spontaneously from random code | emergence only; post-emergence evolution *unverified* (a secondary source: replicators "shed redundant code") | endogenous | the closest prior art to rung 1 here; nothing for rung 4 |
| **Geb** (Channon 2001, 2006, 2019) | neural agents, biotic selection only | passes Bedau–Packard (Class 4) activity tests; maximum individual complexity "asymptotically bounded when scaling either parameter alone", indefinitely scalable only when population and neurons per agent scale together, and then **logarithmically** | endogenous | the cap lesson: any rise must survive raising *both* the world and the channel |
| **PolyWorld** (Yaeger, Griffith & Sporns 2008) | neural agents with energy, food, mating, fighting | driven complexity grows faster for ~4 000 steps then **plateaus**; a lockstep **passive** control overtakes it (0.33 against 0.275); 3 of 10 driven runs made late transitions | endogenous | the passive control (§5, clause 5) |
| **Chromaria** (Soros & Stanley 2014) | a minimal criterion to reproduce; planted agents reshape the landscape | stagnates when any of four conditions fails; no claim of sustained growth when all hold | semi-endogenous | the four conditions: a minimal criterion, new ways to meet it, individual choice of interaction, **unbounded representation** |
| **Minimal criterion coevolution** (Brant & Stanley 2017, 2019, 2020) | mazes and solvers, each must meet a criterion against the other | capped mazes hit the cap (2017); unbounded mazes grow **linearly without levelling off** over 2 000 batches (2019), but the **minimum stays flat** (a passive-trend signature) and growth comes through a size-adding mutation operator | semi-endogenous (criterion imposed, difficulty coevolved) | tapes that pose probes others must transform, a two-sided criterion |
| **Lenia / Flow-Lenia** (Chan 2019, 2020, 2023; Plantec et al. 2023, 2025) | continuous CA; Flow-Lenia adds mass conservation and local parameters so species evolve in the world | evolution inside Lenia converges "toward dominance by rapidly-expanding patterns" (a takeover plateau); Flow-Lenia's evolutionary activity declines with mutation rate; **no claim of open-ended evolution** | endogenous | nothing to import; the takeover plateau is BFF's |
| **BFF / Z80 soups** | see §3.2 | none claims sustained growth | — | — |
| **Arms races** (Hillis 1990; Dawkins & Krebs 1979; Seoane & Solé 2023) | antagonists change each other's selective environment | Hillis: test-case parasites took sorting networks from 65 to 61 exchanges (best known 60), bounded, imported. Seoane & Solé (bit-string model): "to escape their parasites, the host agents expand their computational complexity despite the cost". **Counter-evidence**: mediocre stable states (Ficici & Pollack 1998), loss of gradient and intransitive cycling (Watson & Pollack 2001), disengagement (Cartlidge & Bullock 2004), non-escalation in Avida predator–prey, convergence in the 2026 "Digital Red Queen" | endogenous | escalation needs the key to be the victim's **computed phenotype**, standing diversity, a gradient that persists, and **transitivity** |
| **Niche construction** (Laland, Odling-Smee & Feldman; Taylor 2004) | organisms change the environment that selects their neighbours | Taylor 2004 reports an intrinsic drive toward more genes (run length and boundedness *unverified*); no long-run demonstration found | endogenous | the metabolism tape's world copy is already ecological inheritance |
| **Predation by reading code** (Tierra templates; Stringmol, Hickinbotham et al. 2016; Coreworld) | binding or exploitation by sequence complementarity | arms races that end in stasis or sweeps; Stringmol parasite evasion 32/100 with probabilistic binding vs 0/100 obligate; no growth claim | endogenous | **not recommended**: keys on code, not on what code computes |
| **Food computed from the environment** (Gerlee & Lundh 2010; squirm3; Evoloops) | energy ≈ the entropy increase a CA-rule organism makes in a shared string | cross-feeding and diversity, no complexity growth; Evoloops keep changing at **minimal** size | endogenous | pay the metabolism tape for the information change it makes; cleanest unassisted pay rule, untested for growth |

### 3.2 The BFF and primordial-soup papers, 2024–2026 (abstracts fetched from arXiv)

- **2406.19108**, Agüera y Arcas et al., "Computational Life": replicators in 40% of runs within 16 000 epochs;
  high-order entropy rises in the first 1 000 epochs and falls back; on Z80, stack replicators are overtaken by
  memory-copy ones. "How much complexity can spontaneously arise…?" is left open.
- **2607.01483**, Knierim, Versari, Obryk, Agüera y Arcas & Saurous, "BFF: Simple explanations for complex phenomena":
  how replicators are found and detected (≥ 48/64 over 10 tests × 5 iterations); capping the ancestry tree stops
  takeover, not emergence. No post-takeover analysis.
- **2607.09211**, Cicala et al., "Coevolution of self-replication and function in a digital primordial soup": an
  **imported** polynomial check gates interaction (1.0 against 0.3); segregated niches solve only first-order
  polynomials, single-task populations at most 15 of the simplest tasks; cross-niche pollination makes a curriculum;
  replicators shrink to ~5-byte LDIR loops, freeing tape. Ceiling stated: the 32-byte tape.
- **2609.10817**, Jha et al., "Tapes Together Strong: The Co-evolution of Computation and Cooperation": a Z80 soup with
  an energy stock (24 per epoch, cap 255), execution shared by energy, and a STEAL op at 80% efficiency; defectors are
  suppressed (0.17–0.23), space raises higher-order entropy; optional math tasks are completed *less* as free energy
  rises. Assumes unrestricted partner memory access. **No claim of sustained growth.** (The record's 2026-09-16 entry
  cited it as the best fitness-free evidence of rising structure; read in full it reports structure measures, not a
  sustained climb.)
- Newer and adjacent: 2607.28219 (Horiguchi & Sayama, "Hash Chemistry", a regime transition), 2509.03534 (Vimal et
  al., endogenous selection in a lambda-calculus chemistry), 2603.01701 (ToLSim, judged not open-ended), 2601.03335
  ("Digital Red Queen", Core War with LLMs, converges), 2603.08463 (Barricelli replication). **None reports sustained
  complexity growth in a program soup.**

### 3.3 What the literature says, in four lines

1. Every system that plateaus has the same shape as this programme's: once replication is optimised, nothing pays for
   more (Tierra, empty Avida, Lenia's takeover, BFF, Jha et al.).
2. The one controlled demonstration of complexity escalation with an endogenous gradient is a parasite keyed on the
   host's **computed function** (Zaman 2014), and it still imported the reason to compute (flat pay) and capped the
   scale at EQU.
3. Arms races escalate only when the key is the computed phenotype, diversity is maintained, the gradient persists,
   and the dominance relation is transitive; otherwise they cycle or disengage.
4. Where growth was sustained (MCC 2019, Geb 2019), it was linear or logarithmic, it needed an unbounded
   representation, and its minimum stayed flat. A rise to a cap is not open-endedness (Geb, Zaman, Cicala's 32 bytes).

## 4. The best unassisted bet (question 3): out-compute to eat

### 4.1 The mechanism

**The out-compute rule.** A cell may take energy from a neighbour **whose every computation it also performs**.

- *What a cell computes* is read exactly as the assay reads it today: its metabolism tape runs alone on environmental
  inputs (four bytes, the topless ladder's designed cases, drawn on the rule's own stream and shared by every cell),
  and every output slot that the assay's refusals credit as a bitwise function (no constant, no input plus an offset,
  no contradiction across bit positions) is one of its computations, read as its input-permutation class. Nothing
  about any class is looked up: no depth, no unit, no ladder.
- *The relation.* Once per 8 epochs on average (each cell with probability 1/8 every epoch, so the pass hits stocks at
  every phase of the initiation cycle; see §4.2), a cell picks one partner by the soup's own neighbour rule. If the
  partner's set of classes is a subset of its own, it takes up to `transfer` of the partner's stock, and `loss` of
  what moves is destroyed. Otherwise nothing happens.
- *Energy is income.* Under the `initiator` economy a cell initiates, and so copies itself, only when it can pay
  `max_steps`; what it takes is offspring, what it loses is offspring lost.

**Why this one, of everything in §3.**

1. **It passes both tests of §5, clause 2.** Relabel the functions any way: the rule is unchanged; it names no
   function, no class and no depth. And it is relational: in a world where every cell computes the same set, whatever
   that set is, every cell covers every other and all payoffs are equal. What a cell must compute is defined only by
   what its neighbours compute.
2. **Silence is everyone's prey.** The empty set is a subset of every set, so a cell that computes nothing is food
   for any neighbour, including another silent one. No minimal criterion is needed to stop the cheapest escape
   (computing nothing), which is what sinks the plain matching rules of the host–parasite literature transplanted
   here: under "a parasite infects a host that shares one of its functions", a host that computes nothing is immune.
3. **The arms race is transitive, so it ratchets.** If A covers B and B covers C, A covers C. A superset dominates
   everything below it, so escalation has a direction; intransitive matching games (matching alleles, rock–paper–
   scissors) cycle instead. The coevolution literature's diagnosis of arms races that stall (cycling, mediocre stable
   states) is intransitivity; this rule has none.
4. **Kin eat kin.** Offspring land near their parent (within the reach) and inherit its metabolism tape whole, so a patch of clones
   covers itself and pays `loss` on every encounter. A mutant that adds one class escapes its kin and eats them; a
   mutant that loses one is eaten by them. Novelty is paid for by the population's own success, not by a grader.
5. **Classes, not functions, make breadth cost depth.** The four input projections are one class (ECHO), so a
   superset needs a new *kind* of computation. Classes are scarce at low depth: 1, 2, 3, 9 and 23 four-input classes
   cost 0, 1, 2, 3 and 4 NANDs. Holding seven classes needs a depth-3 function; holding sixteen, depth 4; and a
   stack-NAND loop's later laps emit deeper functions with the same bytes (`topless.md` §2.3), so a deeper loop is
   also a broader one. (With exact functions, the cheapest superset is the four projections, at depth 0: §4.3.)
6. **It reuses the machinery.** The energy economy and the transfer-with-loss of the steal op, the metabolism tape and
   its inheritance, the stack NAND, the topless assay's draw and refusals, and the soup's spatial reach. The engine
   change is one pass in `step_soup` and three parameters.

**What it still imports.** The machine (P, S), the channel (C), an environment of input bytes, the emit op and an
interaction rule. It does not import an objective: nothing says which computation is wanted. In the label's terms it
"imports a machine, not an objective", and rung 4 on Soup stays "not shown" until §2's step 4 makes the machine native.

**Literature behind it.** It is Zaman et al.'s (2014) parasite, keyed on the victim's computed function, with three
changes the literature's failures point to:
- **no flat pay**: the empty set is everyone's prey, so the reason to compute comes from the neighbours too, where
  Zaman's hosts were paid for any function;
- **subset, not intersection**: the predator must cover *all* of the prey's functions, which makes dominance
  transitive (the cycling and disengagement of Watson & Pollack 2001 and Cartlidge & Bullock 2004 come from
  intransitive or gradient-free relations);
- **every cell is both host and parasite**, in space, so diversity is kept by kin competition rather than by a
  separate parasite population that can go extinct (it did in 12 of Zaman's 50 runs).
Seoane & Solé's (2023) model reports the outcome this bets on: hosts "expand their computational complexity despite
the cost" to escape their parasites.

### 4.2 The pilot (design)

All *pilot*, on a throwaway copy of main's engine at `b30196a` in a session scratchpad, not kept. The copy adds,
and changes nothing else:
- `task::EMIT_CAP`, the number of emits an assay run collects before it stops, process-wide: the engine's 4, raised to
  **16** by the pilot. The engine's own readings still read slots 0–3, so they are unchanged.
- `topless::functions`: the exact functions every output slot computes on one case draw, by the assay's refusals.
- `World::predate`, called in `step_soup` before the epoch's influx, on a stream of its own: the rule of §4.1 with
  three variants, **eat** (subset over exact functions), **eatclass** (subset over input-permutation classes) and
  **equal** (the partner's set equals the predator's: "be different or be eaten", the same transfers and no ratchet).
  Cases are redrawn every 8 epochs and each tape's set is cached until then.
- A `pilot` binary that descends a stored world under a merged bundle, switches the rule on, and every 500 epochs
  censuses all 16 384 cells: the classes each metabolism tape computes **on all six** of the topless-rise entry's
  fixed four-input case sets (off `rng::seeded(0xdee9, 4, 0)`), and the engine's own `metrics()` (its
  `logic_depth_max`, the orientation-aware `replicator_share` of the replicating tapes, `meta_diversity`).

**Start worlds** (copied out with SELECTs):
- **4381** and **4428**: reach-cap128 radius-4 runs (seeds 79 and 126) that emerged at epochs 1 260 and 2 650 and end
  at 0.96 and 0.996 replicators, at their terminal epoch 20 000. **Fitness-free history.** Their metabolism tapes are
  switched on at descent from each cell's own first 32 bytes (`meta_seed: own_tape`, Meta-stack's start), so nothing
  that computes is planted: at descent **100%** of cells compute nothing on the six sets.
- **4845**: Meta-stack's first deep child at epoch 60 000 (XOR and EQU on its metabolism tapes; on four inputs, depth
  5 held by a tenth at descent, 83% of cells computing). The maintenance test: does the rule keep what pay built?

**Bundle**, merged over each parent's params: the `initiator` economy (influx 1 024, cap 65 536, theft off), `tasks:
logic4` at `task_reward: 0` (nothing is paid; the engine's depth readings still read), `logic_nand: stack`,
`meta_len: 32`, `meta_draw: isa`. Two rule strengths:
- **×32**: Meta-stack's `meta_rate` 32/8192, `transfer` 4 096, `loss` 0.5;
- **×8**: `meta_rate` 8/8192 (the topless study's untested option iii), `transfer` 8 192 (one initiation), `loss` 0.5.

Seed 5001 throughout; one seed per arm and world: a pilot, not a sample.

**A trap the engine slice must avoid.** The first version ran the pass for every cell on epochs divisible by 8. Under
the `initiator` economy the cells of a descended world initiate in lockstep, every 8 epochs, and their stocks are
empty exactly at the pass: nothing moved, and the predation arms were indistinguishable from drift (88% of cells
computing nothing after 5 000 epochs in all three arms). The pass was made asynchronous (each cell acts with
probability 1/8 every epoch, against whatever its partner holds then), and only that version is reported.

### 4.3 Pilot results

All *pilot*: one seed per arm and world, read every 500 epochs on all 16 384 cells. "Depth held" is the minimal
NAND count of the deepest class credited, on all six fixed sets, to at least a tenth of the cells (1 639) or a
hundredth (164). "Classes per cell" is the mean number of distinct classes a cell's metabolism tape computes there.
Medians of the first and last tenth of the samples after descent.

**The first rule strength (×32 rate, transfer 4 096), 20 000 epochs past descent**, first tenth → last tenth:

| world | arm | cells computing nothing | functions per cell | depth held, 10% | depth held, 1% | mean of per-cell max depth | replicator share (last) |
|---|---|---|---|---|---|---|---|
| 4381 | none | 0.88 → 0.88 | 0.15 → 0.16 | 0 → 0 | 0 → 0 | 0.08 → 0.10 | 0.81 |
| 4381 | equal | 0.64 → 0.63 | 0.49 → 0.48 | 0 → 0 | 1 → 1 | 0.09 → 0.08 | 0.81 |
| 4381 | eat (exact functions) | 0.28 → 0.25 | 1.58 → 1.90 | 0 → 0 | 1 → 1 | 0.13 → 0.13 | 0.79 |
| 4381 | eatclass | 0.28 → 0.25 | 1.17 → 1.27 | 1 → 1 | 2 → 2 | 0.53 → 0.61 | 0.84 |
| 4428 | none | 0.88 → 0.89 | 0.16 → 0.14 | 0 → 0 | 0 → 1 | 0.10 → 0.13 | 0.84 |
| 4428 | eat (exact; 8 500 epochs) | 0.29 → 0.27 | 1.27 → 1.90 | 0 → 0 | 1 → 1 | 0.14 → 0.15 | 0.82 |
| 4428 | eatclass | 0.27 → 0.26 | 1.20 → 1.25 | 1 → 1 | 2 → 2 | 0.53 → 0.57 | 0.72 |
| 4845 | none (18 500 epochs) | 0.17 at descent → 0.88 | 2.03 → 0.15 | **5 → 0** | 5 → 0 | 3.57 → 0.10 | 0.76 (low 0.13) |
| 4845 | eat (exact) | 0.17 at descent → 0.34 | 2.03 → 1.25 | **5 → 0** | 5 → 1 | 3.57 → 0.09 | 0.65 (low 0.44) |

**The second rule strength (×8 rate, transfer 8 192), 40 000 epochs past descent:**

| world | arm | cells computing nothing | classes per cell | depth held, 10% | depth held, 1% | classes held by 10% | mean of per-cell max depth | replicator share |
|---|---|---|---|---|---|---|---|---|
| 4381 | none | 0.89 → 0.88 | 0.11 → 0.12 | −1 → 0 | 0 → 0 | 0 → 1 | 0.08 → 0.11 | 0.80 → 0.84 |
| 4381 | equal | 0.38 → 0.36 | 0.65 → 0.70 | 0 → 0 | 1 → 1 | 1 → 1 | 0.12 → 0.16 | 0.79 → 0.80 |
| 4381 | **out-compute** (eatclass) | 0.06 → 0.08 | 3.44 → 5.28 | **3 → 5** | 4 → 7 | 7 → 13 | 2.17 → 3.50 | 0.80 → 0.70 |
| 4428 | **out-compute** (eatclass) | 0.09 → 0.06 | 3.49 → 6.28 | **3 → 6** | 5 → 7 | 7 → 15 | 2.26 → 4.01 | 0.82 → 0.76 |

The out-compute worlds over time, medians of 2 500-epoch blocks (epochs past descent):

| block | 4381 classes per cell | 4381 depth held | 4428 classes per cell | 4428 depth held |
|---|---|---|---|---|
| 0.5–2.5 k | 2.96 | 2 | 3.23 | 3 |
| 3–5 k | 3.99 | 3 | 4.80 | 4 |
| 5.5–7.5 k | 4.58 | 4 | 5.38 | 5 |
| 8–10 k | 5.28 | 5 | 5.62 | 5 |
| 10.5–15 k | 5.36–5.49 | 5 | 5.66–6.01 | 4–5 |
| 15.5–20 k | 5.53–5.73 | 5–6 | 6.13–6.21 | 5–6 |
| 20.5–30 k | 5.69–5.92 | 5–6 | 6.13–6.42 | 5–6 |
| 30.5–40 k | 5.28–5.80 | 5–6 | 6.2–6.4 | 5–6, flickering |

**The distribution inside the out-compute worlds**, over the cells that compute. For 4381, a deterministic replay of
the run (identical sample for sample) saved its world at 2 000 and 10 000 epochs past descent; the rows at 40 000 are
the runs' own end worlds:

| epochs past descent | per-cell max depth: p10 / p25 / p50 / p75 / p90 / max | classes per cell: p10 / p50 / p90 / max |
|---|---|---|
| 4381, 2 000 | 1 / 1 / 2 / 3 / 4 / 7 | 1 / 3 / 6 / 11 |
| 4381, 10 000 | 1 / 2 / 4 / 5 / 6 / 9 | 1 / 5 / 11 / 15 |
| 4381, 40 000 | 1 / 2 / 3 / 5 / 6 / 8 | 1 / 5 / 10 / 12 |
| 4428, 40 000 | 1 / 3 / 4 / 6 / 6 / 7 | 1 / 6 / 12 / 12 |

At least 90% of computing cells keep ECHO at every reading (their shallowest class is depth 0): a superset keeps what it covers. The
**minimum does not rise** (the 10th percentile of per-cell max depth is 1 at every reading), while the middle and the
top did, then stopped: McShea's test reads this as a rise of the upper part of the distribution, not as a trend that
lifts the whole population.

**What the pilot says.**

1. **An endogenous rule makes computing pay.** From worlds whose metabolism tapes computed nothing at descent, and with
   nothing paid, out-compute at ×8 put 92–94% of cells computing, held five or six classes per cell, and held
   depth-5 and depth-6 functions by a tenth of the world (EQU, Lenski's deepest, is 5) and depth 7 by a hundredth, in
   both worlds. Every control sits at depth 0: drift (none) leaves 88% of cells computing nothing, and "be different"
   (equal) leaves 36% silent and the rest on ECHO. The two arms differ only in the relation that decides a transfer,
   so **transitivity is what climbs**, not antagonism. At the end, 26 classes are held by at least 1% of 4381's cells and 36 of 4428's, up to depth 7.
2. **It climbs fast, then mostly stops.** Most of the rise came in the first 8 000–10 000 epochs. In the last 30 000
   epochs 4381's repertoire drifted between 5.3 and 5.9 and ended where it was at 10 000; 4428's crept from 5.6 to 6.4
   and its depth from 5 to 6. By the topless-rise rule applied to this series (500-epoch samples, k = 5), **4428 rises
   late**, barely: its last tenth reads 6 against a bar of 5, depth 6 first held five samples running from 30 500
   epochs past descent, on a series that flickers between 5 and 6 to the end. **4381 does not**: it held 6 for seven
   samples (29 500–32 500 past descent), fell back to 5, and its last tenth reads 5 against a bar of 5, with its
   repertoire down from 6.1 to 5.0 classes over the last 10 000 epochs. One late step in one of two
   worlds is the same shape as everything else in the record: a rise, then a plateau, here at the depth and repertoire
   a 32-byte channel at this mutation rate can hold against its load.
3. **The rule's strength against the channel's mutation rate decides how high the plateau is.** At Meta-stack's ×32
   rate and a take of half an initiation, the same rule held one class and depth 1; at ×8 and a take of one whole
   initiation, five to six classes and depth 5–6. The pilot changed both at once, so it does not say which mattered.
   The likely reading is the topless study's untested option (iii): a deep tape is held by selection against a steady
   loss of load-bearing bytes, and at ×32 the rule's selection cannot pay the load.
4. **Exact functions reward the cheapest breadth.** Over exact functions the superset race was won by tapes that echo
   the four inputs (depth 0): 1.9 functions per cell and nothing deeper in both worlds. In Meta-stack's deep world 4845
   it replaced XOR and EQU loops with input echoes within 500 epochs. Classes, which count the four echoes as one,
   are what made breadth cost depth.
5. **Without pay, what pay built does not survive.** 4845's depth 5 fell to 0 within 500 epochs under drift and under
   exact-function predation alike. Maintenance from a paid world is not the test to run first; construction from a
   fitness-free world is.
6. **The replicators carry the cost.** The replicating tapes' detector share drifted from about 0.82 to 0.70–0.76
   under out-compute (0.80–0.84 in the controls); no world went extinct. The predation pass destroys energy (half of
   every take), and a world that spends its income on theft initiates less.
7. **The engine's own reading would miss most of it.** `logic_depth_max` reads four output slots on 256 cells and
   read 3 in both out-compute worlds where the full census holds 5–6: the deeper functions come on later emits. An
   engine slice must read every slot the cap allows.

### 4.4 How it would be pre-registered

A draft for a record entry, in the form the topless-rise entry took. It is step 1 of §2.

**Engine slice** (one, about 90 minutes, plus its observables):
- `predation` (`off` by default, `subset_class`, `equal`, `shadow`), `predation_transfer` (0 = off), `predation_loss`
  (0.5), `predation_every` (8), all dynamics so a descendant may set them; refused without a metabolism tape, an
  energy stock and the `initiator` payer, and with `task_reward > 0` (a run is either paid or predatory, never both,
  so the label stays clean).
- `task_max_outputs` (4 by default, the engine's rule; at most 16), dynamics, accepted only beside `predation`.
- The pass in `step_soup` before the influx, cases on `STREAM_PREDATION` at (seed, epoch) every `predation_every`
  epochs, each cell acting with probability 1/`predation_every` per epoch, in an order shuffled on the same stream.
  At `off` no stream is drawn and every pin is unmoved. `shadow` decides each encounter by a coin at a fixed,
  pre-registered probability (0.30, the out-compute arm's eat rate in both pilot worlds after the first 5 000 epochs,
  §4.3), moving the same transfer.
- **Observables** (live-only): `predation_rate` (encounters that moved energy), `repertoire_mean` (mean distinct
  classes per sampled cell, the 256 cells and `STREAM_TASK | 6` draw the depth readings already make),
  `silent_share`; and `logic_depth_max` / `logic_depth_classes` read over all `task_max_outputs` slots.
- **Offline** (`research/landscape`): the six-set census of this pilot (per-cell max and min depth percentiles,
  repertoire, held classes) and the topless-rise load-bearing count.

**The sweep** (`out-compute`, a descendant sweep):
- **Parents**, construction: the reach-cap128 radius-4 eligible parents (terminal `replicator_share ≥ 0.5`), the 54
  with the lowest run ids, each from its terminal world at 20 000. Fitness-free history: none has ever been paid.
- **Bundle**, merged over each parent's params: `initiator` economy (influx 1 024, cap 65 536, theft off), `tasks:
  logic4`, `task_reward: 0`, `logic_nand: stack`, `meta_len: 32`, `meta_rate: 8/8192`, `meta_draw: isa`, `meta_seed:
  own_tape`, `task_max_outputs: 16`, `predation_transfer: 8192`, `predation_loss: 0.5`.
- **Arms**: **out-compute** (`subset_class`), **equal**, **shadow**, **none** (`predation: off`). Seed 6001, one per
  parent; **100 000 epochs** past the parent; priority 40. 216 children.
- **Cost** (an out-compute child at about 3.7 × the Mac's unloaded 22 s per 1 000 epochs, the ratio of the mini-pc's
  topless-rise rate to the Mac's for the same bundle, so about 80; a none child at about 45):
  54 × 100 × (80 + 80 + 80 + 45) s ≈ 1.5 M run-seconds ≈ **36 h of the 12 slots**; without shadow ≈ 26 h.

**Readings, per child**, the topless-rise entry's machinery unchanged: settling window 1 000, deciles by index,
lower-middle medians, extinct where the last-decile `replicator_share` is below 0.1, a decile unread under 10 numbers.
- **The rise rule** on `logic_depth_max` with **the bar** (the deepest the child held persistently before the second
  half, its depth at descent included); and the same rule on `logic_depth_classes`, the repertoire.
- **McShea's minimum**: the 10th percentile of per-cell max depth among computing cells, read offline on the
  fifth-decile and the last stored worlds; a driven trend raises it, a passive one need not.
- **H-code**: the load-bearing bytes of the dominant deepest solver, fifth-decile world against the last, the
  topless-rise method.

**Tests**, one-sided sign tests over discordant pairs at p < 0.05, Logic's outcome rules:
- **H-endogenous** (out-compute against none): the last-decile median `logic_depth_max`, as a level. The pilot
  predicts it **shown**.
- **H-ratchet** (out-compute against equal): the same key. The pilot predicts **shown**.
- **H-driven** (out-compute against shadow): the same key. Not piloted; expected shown, since the shadow arm moves
  energy without reading computation and should sit where none does. A tie would mean the climb is passive.
- **H-rise-unassisted** (out-compute against none): the rise rule, the rung-4 question. The pilot predicts it **not
  shown, or refuted**: both worlds made most of their climb in the first 10 000 epochs, so a 100 000-epoch child's bar
  is set at 5–6 by its fifth decile, and only one of two pilot worlds read a late rise, by one NAND, on a series that
  flickers between 5 and 6.
- **H-repertoire** (out-compute against none): the rise rule on `logic_depth_classes`. Predicted the same way.
- Each re-read with extinct pairs kept, and per parent with the leave-one-or-two-out rule.

**What each outcome means.**
- *H-endogenous, H-ratchet and H-driven shown, H-rise-unassisted shown*: on a machine that imports no objective,
  computing climbs and keeps climbing late, driven by what neighbours compute. That is rung 4 with an endogenous
  objective, still on an imported machine (§2, step 4 is next).
- *The level tests shown, H-rise-unassisted refuted*: an endogenous objective makes computing pay and builds depth
  and repertoire, then stops at a mutation–selection balance on a fixed 32-byte channel. The next bet is room to grow
  in the channel (§4.5), not a different objective.
- *H-ratchet not shown*: being different is enough; transitivity adds nothing.
- *H-endogenous refuted*: the pilot was a fluke of two worlds.

**What is not claimed.** The machine is imported (P, S, C, the emit op, the input bytes, the emit cap of 16), and so
is the predation rule itself. No objective is. Rung 4 on Soup stays "not shown".

### 4.5 The second mechanism: room to grow in the computing channel

The out-compute rule supplies a drive. It cannot supply a space: on a 32-byte channel, four inputs and sixteen emits,
the repertoire and the depth both have a top (3 982 classes, depth 13 or a little more, and in practice what 32 bytes of stack loops
can hold). Chromaria's fourth condition, MCC 2019's unbounded mazes and Geb's two-cap result all say the same thing:
growth that is sustained needs a representation that is not bounded, and a rise toward a cap is not open-endedness.
So the second mechanism is not a second objective but the channel's room to grow, under the same rule:

- **A growable metabolism tape**, as `max_tape_len` grows the replicating one: `meta_max_len` above `meta_len`, with
  the variation that lets a channel grow without breaking what it computes, a **duplication** of a random segment
  appended at a small rate (Ohno; Lenski et al. 2003 used insertions and deletions at 0.05 per divide). The logic
  study measured no gain from indels on the woven tape, because the copier and the mirror pin every offset; a free
  channel removes both (`meta-stack.md` §3, last row).
- **An input window that widens with what tapes read**: inputs on `B[2L−1]` leftward as now, but as many as a slot's
  truth table can be read for (the designed draw reads each of the 2^k rows three times on 8-bit columns: four
  inputs take 2 cases a read, 6 in all; five would take 4 a read, 12 in all, and the minimal-NAND table would need
  sampling or bounds past four), so a deeper loop that walks further left meets new inputs rather than zeros.
- **Read the repertoire, not one depth**: on an unbounded channel the measure must be unbounded too: the number of
  distinct classes held, and the minimal circuit size of the held set (§5, clause 3).

The two together are the bet the bar asks for. Neither was piloted here; both are small engine slices on the
machinery the pilot already used.

*Pilot 2 (§7) built the growable tape and found it does not climb late: the room fills with junk behind one
stack-NAND loop whose orbit, not the channel's length, sets the top.*

**Alternatives ranked lower**, from §3: *co-constructed probes* (MCC transplanted: some tapes write the inputs others
must transform, a probe surviving only while someone solves it), endogenous but with an imposed criterion and a flat
minimum in its only long run; *information-paid food* (Gerlee & Lundh: energy equal to the entropy change a tape makes
in a shared string), the cleanest unassisted pay rule but with no growth result anywhere; *depletable class-specific
food* (Cooper & Ofria; Chow), which buys diversity, not depth.

## 5. The honest bar (question 4)

### 5.1 What "life exists" should mean here

The programme's question is a self-replicating, **evolving** structure arising from non-living matter. Rungs 1–3 are
shown on plain Soup (emergence at 119/270 against 11/270, persistence and heredity, one held-out adaptation). What the
user's instruction asks for, and what a skeptic would withhold the word "life" without, is the fourth rung **on a
world that was not told what to become**. I propose the bar as six clauses, all required, each stated so a reading
can fail it.

1. **Spontaneous origin on the same physics.** The replicators whose complexity rises arose from random soup under
   exactly the rules the rise is read under, at a reproducible rate (a pre-registered emergence test on that
   substrate, as reach-cap128's). A descendant sweep from emerged worlds is allowed for the rise, but the physics it
   runs (instruction set, interaction rule, energy, channel) must be the physics emergence was shown on. Today that
   fails for every import: the stack NAND, the emit op and the metabolism tape exist only in descendants (§2, step 4).

2. **No imported objective, as two checkable properties of the update rule.**
   - *Relabelling*: permute the functions (or behaviours) a tape can compute any way, and the dynamics are the same.
     That excludes a task ladder, depth-scaled pay, a minimal criterion that names a function, and any `task_floor`.
   - *Relational*: in a world where every cell computes the same thing, every choice of that thing gives the same
     payoffs. That excludes rules that pass the first test but grade in absolute terms, such as "pay per distinct
     class held", which is relabelling-invariant and still an imported objective ("be broad").
   Both admit energy, space, mutation, an instruction set, and rules that compare two tapes' behaviour to each other
   (`$`, host mode, the out-compute rule of §4: in a monoculture of any set, every cell covers every other). An
   *environment* (inputs the world supplies) is admitted; a *grader* of outputs is not. A reviewer can check both on
   the engine's code path.

3. **A complexity measure with no near top, read on both sides of the genotype–phenotype map.**
   - **Function side**: what the population computes, unprompted by pay: the minimal NAND count of the deepest
     function held by a tenth of the world (`logic_depth_max`), and, because depth alone has a ceiling and comes in
     lumps (`topless.md` §2.3), the **size of the held repertoire** (distinct input-permutation classes held by a
     tenth, `logic_depth_classes`) and the minimal circuit size of that set where it can be computed.
   - **Program side**: **load-bearing bytes** of the dominant deepest solver (the topless-rise entry's method) and the
     lineage's **physical complexity** in Adami's sense (the bytes a lineage holds still against mutation: the
     conserved-core reading, `conserved_core_bytes_oriented`, applied to the computing channel, a new reading). A
     rise in function with a flat program side is co-option and counts as half.
   - **No near top**: on 4 inputs and a 32-byte channel the depth scale is credited at most 13 (a floor for 604
     functions) and its bulk sits at 10 (959 of
     3 982 four-input classes cost exactly 10, more than any other cost); topless-rise's paid children reach 8–10 and
     stop (§1.2). Any claim of "keeps rising" must therefore be read on a channel that can grow (a growable metabolism
     tape, as `max_tape_len` grows the replicating one) and an input window that can widen, or the rise is an
     approach to a ceiling built into the probe.

4. **Sustained and late.** The rise rule of topless-rise, applied at two scales: a child rises late when its
   last-decile median exceeds **the bar** (the deepest it held, persistently, before the second half, its parent's
   depth included) by at least one, *and* it has at least **three** distinct persistent new maxima (k = 5 samples
   each) of which the last falls in the **final quarter**. One jump, however large, is a reorganisation, not
   open-endedness (topless pilot B: 5 → 9 in one lump, then flat for 36 000 epochs).

5. **Against controls that remove the drive, not the machine.** At least three, the same physics in each:
   - **drift**: the interaction rule off (the none arm), which reads the passive baseline;
   - **no ratchet**: the rule replaced by one with the same transfers that cannot escalate (§4's equal rule), which
     separates "be different" from "out-compute";
   - **shadow**: the same transfers between the same pairs, at the treatment's own eat rate, decided by a coin
     instead of by what the two tapes compute: Bedau and Packard's neutral shadow, which keeps the energy flow and
     removes selection on computation, so it separates a driven rise from passive diffusion into the bulk of
     function space.
   And McShea's test for a **driven** trend: the *minimum* (the 10th percentile of per-cell depth among computing
   cells) rises, not only the maximum, since a passive trend from a lower wall raises the maximum and the mean alone.

6. **Scale and length.** Many independent worlds, a pre-registered one-sided test, leave-two-out robustness (the
   programme's machinery). **Length**: at least **10⁶ epochs** past descent, about 10⁵ generations at the initiator
   economy's 8–10 epochs per generation (`meta-stack.md` §1.1), the order of the *E. coli* long-term evolution
   experiment's tens of thousands of generations and more than six times the ~15 900 generations of Lenski et al.'s
   (2003) Avida runs; and in every case at least **ten times the epoch at which the paid control first plateaus** (topless-rise: 1–25 k epochs to its maximum), so "late" means late relative to the
   fastest thing the machine does.

### 5.2 What would and would not count

- **Counts**: on a substrate where emergence is shown, under a rule that passes both tests of clause 2, the deepest
  function held and the repertoire's size both keep reaching new persistent maxima into the last quarter of 10⁶-epoch
  runs, load-bearing bytes rise with them, the minimum rises too, and none of the drift, no-ratchet or shadow arms
  does the same, in a pre-registered sign test over at least 30 parents.
- **Does not count**: a deep function held once (Meta-stack's EQU, topless pilot B's 9); a rise to a fixed ceiling
  (topless-rise's 8–10 on 4 inputs, interim); a rise under pay; a rise that the shadow arm matches (passive diffusion);
  a rise in tape length or instruction count (the record's 2026-09-16 entry: that is junk under drift).

### 5.3 Cost of meeting it

A 10⁶-epoch child costs about 80 000 s on the mini-pc at the rate §4.4 assumes, 22 h. Four arms on 30 parents is
120 children, about 2 700 run-hours, **9–10 days of the 12 slots**. It is affordable once, and only after a
100 000-epoch sweep (§4.4) has shown the rise is there to be extended.

## 6. Budget, what was not done, and where things are

**Compute.** Thirteen pilot runs (§4.3) plus calibration and two replays: about 360 000 epochs on 128 × 128 worlds.
At the unloaded rates measured at the start (about 22 ms an epoch with the predation pass, 12 ms without) that is
about **1.9 core-hours**. The Mac carried a load average of 60–137 from other sessions for most of the study, which
inflated the per-epoch CPU time to about 34–40 ms, so the processes were charged roughly **3 CPU-hours**. To stay near
the brief's 2 core-hours, the ×32 runs were stopped at 20 000 epochs past descent (4428's exact-function run at 8 500,
the 4845 and ×32 drift runs at 18 500–21 500) once their trajectories had been flat for over 15 000 epochs; the ×8 runs
ran their full 40 000.

**The lab.** SELECTs only on `ssh mini-pc-lan`: experiments, runs, samples, snapshot readings, snapshots. Three worlds
copied out (4381 and 4428 at 20 000, 4845 at 60 000). Topless-rise was read interim with my own SQL, which is not
`lab:topless_rise_report` and decides nothing.

**Not done.**
- The shadow arm (§5, clause 5) was not piloted; it is specified in §4.4.
- Out-compute was not run from a paid world at ×8 (only exact-function predation at ×32 from 4845), so maintenance is
  read only for that weaker rule.
- One seed per arm and world; no second seed of the ×8 controls on 4428.
- No load-bearing count on the out-compute solvers: `research/landscape` reads four output slots, and these tapes'
  deeper functions come on later emits.
- The second mechanism (§4.5) and the program-copied channel (§2.2) were not built.
- The topless-rise reading is interim; its final report may move §1.2's numbers.

**Files.** The material was pilot artefacts and was not kept: the throwaway engine copy and its `pilot` binary, every
census row of every pilot run (with the three commonest metabolism tapes and their classes at each census), the end
worlds of the ×8 runs and the two replays, the three copied worlds, the scripts behind §4.3's readings, the section
drafts and the literature agent's extracted texts. The engine slice of §4.4 is the out-compute rule as the engine now
carries it (`docs/design_record.md`, 2026-10-03, "Predation").

## 7. Pilot 2: room to grow in the computing channel (§4.5)

2026-10-03, all *pilot*: a throwaway copy of main's engine (`origin/main`, `b30196a`) in a session scratchpad, not kept, one
seed (5002) per arm and world. A pilot, not a sample. Nothing in the repository or the lab was touched.

### 7.1 What was built

**The out-compute pass of §4.2**, re-implemented on the fresh copy: asynchronous (each cell acts with probability
1/8 every epoch), subset over input-permutation classes, cases redrawn every 8 epochs on the rule's own stream and
shared by every cell, emit cap 16, `meta_rate` 8/8192 (×8), `transfer` 8 192, `loss` 0.5. One change of
implementation, not of rule: a cell's class set is read only when it acts or is picked (a pass moves energy only,
so every set is what it was at the start of the pass).

**The growable metabolism tape.**
- Each cell's tape lives in a slot of `meta_max_len` **256** bytes with a live length of its own, **32** at descent:
  each cell's own first 32 bytes (`own_tape`), the slot past them zeroed. Nothing that computes is planted: at
  descent 100% of cells compute nothing on the six sets, as in §4.2.
- **At every inheritance** (the world copying a metabolism tape onto a near copy's partner: the channel's divide)
  the child's copy takes, with probability **0.05**, a **duplicate of a random segment** of 1–16 bytes **appended
  at its end** (cut at the cap), then, with probability **0.05**, **loses a random segment** of 1–16 bytes from
  anywhere, never below 8 bytes. Appending moves no existing offset, so a duplication never disturbs the code that
  computes; the deletion lets length fall as well as rise.
- Substitutions as before (`meta_draw: isa`, 8/8192 per live byte per epoch), drawn over live bytes only.
- The **fixed** arm runs through the same code at `meta_max_len` 32 with neither duplication nor deletion, so the
  two out-compute arms differ only in the channel.

**The rate.** Lenski et al. (2003) ran 0.05 single-instruction insertions and 0.05 deletions per divide beside 0.0025
point mutations per copied instruction (0.1–0.25 per divide). A metabolism tape here is inherited about every 10
epochs per cell (1.7 million inheritances per 1 000 epochs on 16 384 cells), so the substitution draws give about
0.3 substitutions per 32-byte tape per divide, and 0.05 duplications and 0.05 deletions per divide keep Lenski's
order of indels against point mutations. A segment of up to 16 bytes holds a whole stack loop and its emit
(`<<<<[!{~!~]` is 11 bytes), which a one-byte insertion cannot copy. The cap was raised from 128 to 256 after a
1 000-epoch calibration at 128 already had a tenth of the out-compute tapes at 105 bytes or more.

**The input window stayed at four inputs.** Five would need a 12-case designed draw and has no minimal-NAND table;
it could not be scored honestly in the budget. Every depth below is the four-input minimal NAND count.

**Arms**, on 4381 and 4428 (the §4.2 start worlds, fitness-free, `own_tape`), **60 000 epochs past descent**:
**growable out-compute**, **fixed out-compute** (the replication of §4.3), **growable drift** (no predation). The
census of §4.2 every 500 epochs on all 16 384 cells (six fixed four-input sets, every emit slot to 16), with the
per-cell max-depth percentiles, the repertoire, the classes held by a tenth and by a hundredth, and the tape
lengths. Every 10 000 epochs, the **load-bearing count of the dominant deepest solver**: `research/landscape`'s
method (the commonest tape credited a deepest class held by a tenth; a position bears where at least 7 of the 13
other alphabet symbols leave no class that deep on all six sets), ported, since the landscape crate reads four
emit slots and fixed-length tapes.

**Cost.** 2.7 CPU-hours for the six runs (growable out-compute 38 and 39 min, fixed 23 and 26, drift 16 and 19) at
`nice 19`, plus about 0.35 for calibration, the offline tape readings and the tandem probe of §7.3: about 3.05 in
all. The runs were stopped at 60 000 rather than 100 000 epochs past descent to stay inside the budget; at 40 000
the growable arms had stood still for 25 000 epochs.

### 7.2 Results

Medians of 5 000-epoch blocks, epochs past descent: depth held by a tenth · classes per cell (mean over all cells) ·
classes held by a tenth · mean tape length (growable). Drift's mean length in the last column.

| k epochs | 4381 fixed | 4381 growable | 4428 fixed | 4428 growable | drift length 4381 / 4428 |
|---|---|---|---|---|---|
| 0–5 | 3 · 3.34 · 7 | 5 · 4.13 · 9 · 122 | 5 · 4.36 · 11 | 3 · 3.56 · 8 · 100 | 44 / 48 |
| 5–10 | 3 · 3.73 · 8 | 5 · 5.33 · 13 · 179 | 5 · 5.42 · 13 | 7 · 6.34 · 15 · 146 | 74 / 84 |
| 10–15 | 4 · 4.39 · 10 | 5 · 5.54 · 14 · 218 | 5 · 5.44 · 13 | 7 · 6.42 · 16 · 175 | 82 / 109 |
| 15–20 | 4 · 4.56 · 11 | 4 · 5.45 · 13 · 222 | 4 · 5.24 · 12 | 7 · 6.45 · 16 · 191 | 92 / 121 |
| 20–25 | 4 · 4.53 · 11 | 4 · 5.30 · 13 · 213 | 5 · 5.55 · 13 | 6 · 6.63 · 14 · 206 | 91 / 121 |
| 25–30 | 4 · 4.70 · 11 | 5 · 5.65 · 13 · 221 | 5 · 5.56 · 13 | 6 · 6.54 · 14 · 211 | 82 / 102 |
| 30–35 | 4 · 4.51 · 11 | 6 · 5.98 · 14 · 210 | 5 · 4.98 · 12 | 6 · 6.58 · 14 · 209 | 72 / 119 |
| 35–40 | 4 · 4.50 · 11 | 5 · 6.00 · 14 · 211 | 5 · 4.78 · 11 | 6 · 6.56 · 15 · 206 | 103 / 124 |
| 40–45 | 4 · 4.49 · 11 | 6 · 6.23 · 14 · 209 | 5 · 4.65 · 13 | 6 · 6.67 · 16 · 207 | 120 / 136 |
| 45–50 | 4 · 4.52 · 11 | 6 · 6.44 · 14 · 206 | 5 · 4.66 · 12 | 6 · 6.63 · 16 · 206 | 109 / 150 |
| 50–55 | 5 · 4.58 · 12 | 6 · 6.52 · 13 · 201 | 5 · 4.88 · 12 | 6 · 6.59 · 16 · 192 | 128 / 140 |
| 55–60 | 5 · 4.56 · 12 | 6 · 6.59 · 13 · 210 | 6 · 5.71 · 14 | 6 · 6.66 · 16 · 214 | 151 / 145 |

Both drift arms held depth 0 and one class by a tenth, with 86–89% of cells silent, from start to end.

**The last census** (60 000 past descent); depth percentiles over computing cells:

| world | arm | silent | per-cell max depth p10 / p25 / p50 / p75 / p90 / max | classes per cell p50 / p90 / max | depth held 10% / 1% | classes held 10% / 1% | length p10 / p50 / p90 | replicator share |
|---|---|---|---|---|---|---|---|---|
| 4381 | fixed | 0.11 | 1 / 2 / 3 / 5 / 5 / 8 | 4 / 10 / 12 | 5 / 8 | 12 / 28 | 32 | 0.66 |
| 4381 | growable | 0.06 | 1 / 2 / 4 / 6 / 7 / 9 | 6 / 12 / 14 | 6 / 7 | 13 / 29 | 180 / 229 / 256 | 0.84 |
| 4381 | drift | 0.89 | 0 / 0 / 0 / 0 / 1 / 2 | 0 / 1 / 3 | 0 / 1 | 1 / 2 | 26 / 141 / 242 | 0.83 |
| 4428 | fixed | 0.06 | 1 / 2 / 4 / 5 / 6 / 8 | 5 / 12 / 14 | 6 / 7 | 14 / 30 | 32 | 0.76 |
| 4428 | growable | 0.06 | 1 / 3 / 5 / 6 / 7 / 7 | 6 / 12 / 12 | 7 / 7 | 18 / 27 | 169 / 223 / 256 | 0.94 |
| 4428 | drift | 0.86 | 0 / 0 / 0 / 0 / 0 / 2 | 0 / 1 / 4 | 0 / 1 | 1 / 2 | 17 / 120 / 241 | 0.92 |

**The rise rule and §5's bar.** The topless-rise rule (settling window 1 000, deciles by index, lower medians; the
bar is the fifth-decile median, the depth at descent or the deepest held five samples running before the end of the
fifth decile, whichever is highest), and §5 clause 4 (at least three persistent new maxima, k = 5, the last in the
final quarter, past 45 000). A persistent maximum is dated by the sample that completes its five.

| world | arm | depth: bar → last decile | depth: persistent maxima (k epochs: depth) | §5.4 | repertoire held by a tenth: bar → last | its last persistent maximum | §5.4 |
|---|---|---|---|---|---|---|---|
| 4381 | fixed | 4 → 5, **rises** | 2.5: 1, 3: 2, 4: 3, 14: 4, 58.5: 5 | **passes**, by one NAND | 11 → 12, rises | 58.5: 12 | passes |
| 4381 | growable | 5 → 6, **rises** | 2.5: 1, 3: 2, 3.5: 3, 4.5: 5, 33.5: 6 | fails (last at 33.5) | 13 → 13 | 33.5: 14 | fails |
| 4428 | fixed | 5 → 5 | 2.5: 1, 3: 2, 4: 5 | fails | 13 → 14, rises | 11: 13 | fails |
| 4428 | growable | 7 → 6 | 2.5: 1, 3: 2, 3.5: 3, 5: 4, 6.5: 5, 7.5: 7 | fails | 16 → 16 | 13.5: 16 | fails |
| both | drift | 0 → 0 | 5.5–12.5: 0 | fails | 1 → 1 | 5.5–12.5: 1 | fails |

**Length.** The out-compute tapes climbed to 205–220 bytes within 10 000–15 000 epochs and stood there (rise rule:
4381 bar 221 → 209, 4428 bar 213 → 210). The drift tapes climbed more slowly to 142–151 at the end, and 4381's
drift length passes both the rise rule (bar 92 → 150) and §5.4, its last new maximum at 58 500: a length that walks
between a floor of 8 and a cap of 256 drifts toward the middle of its range. Out-compute holds tapes about 60–90
bytes longer than drift does; §5.2 already counts length as no complexity, and the program side below says why.

**The minimum.** The 10th percentile of per-cell max depth among computing cells is **1** in all four out-compute runs
from 3 500–5 500 epochs to the end, in both channels. McShea's minimum does not rise.

**The program side**: the dominant deepest solver every 10 000 epochs, as depth · load-bearing bytes (· tape length
in the growable arms). The growable solvers are held by 4–7 cells each (their tails differ almost tape by tape),
the fixed ones by 21–35.

| world | arm | 10k | 20k | 30k | 40k | 50k | 60k |
|---|---|---|---|---|---|---|---|
| 4381 | fixed | 3 · 12 | 4 · 13 | 4 · 10 | 4 · 11 | 4 · 13 | 5 · 16 |
| 4381 | growable | 5 · 13 · 240 | 4 · 12 · 98 | 5 · 13 · 245 | 5 · 11 · 202 | 6 · 11 · 155 | 6 · 12 · 149 |
| 4428 | fixed | 5 · 13 | 4 · 9 | 4 · 8 | 5 · 16 | 5 · 12 | 6 · 16 |
| 4428 | growable | 6 · 12 · 182 | 6 · 12 · 47 | 6 · 12 · 227 | 6 · 12 · 203 | 6 · 11 · 178 | 7 · 11 · 233 |

Every load-bearing byte of every growable solver sits in its **first 16 positions**. Read offline (the pilot
binary's tape reading): the final census's three commonest growable tapes in each world and both deepest solvers, cut to their first
32 bytes, compute exactly the classes they compute whole, and none has a position past 12 whose substitution loses
any of its classes. The 40–220 bytes past the core are neither depth- nor repertoire-bearing: junk, as the record's
2026-09-16 entry found for the replicating tape. Read with topless-rise's H-code labels, 30 000 against 60 000 epochs
past descent (single censuses on flickering series), both fixed arms' depth steps are *new code* (4381 4 · 10 → 5 ·
16, 4428 4 · 8 → 6 · 16) and both growable arms' are *co-option* (4381 5 · 13 → 6 · 12, 4428 6 · 12 → 7 · 11).

### 7.3 Why the channel does not help: the loop's orbit, and dead appendices

Both channels converge on one motif, a stack-NAND loop whose laps emit successively deeper functions (`topless.md`
§2.3): `<<<<[!{~!~]` in both growable worlds (the head moves vary: `<0<<<`, `<<.<<`), `[~_!~{!]` and `[{~!~}}!]` in
the fixed ones. Read offline on the six sets:

- The 11-byte `<<<<[!{~!~]` alone, padded with zeros or fillers to any length from 32 to 256, computes the **same 12
  classes up to depth 6** (`bfff`). At 11 bytes (a 22-byte buffer) it computes 8. So a growable channel gives
  this loop nothing past 32 bytes.
- Its laps fill the 16-emit cap. With the cap at 32, 64 or 128 it computes **14 classes up to depth 7** (`0080`) and
  then nothing more: the loop's orbit closes. Its depth 6–7 and its 12 classes are the growable worlds' depth held
  and the top of their per-cell repertoire (p90 12).
- **Appended copies are dead code.** The loop followed by a second copy of itself, with or without a head move
  between (`<<<<[!{~!~]<<<<[!{~!~]`, `…]{[!{~!~]`, `…]+[!{~!~]`, `…]>>[!{~!~]`), computes the same 12 classes at the
  16-emit cap and the same 14 at 64: the first loop spends the whole emit budget itself, so code appended after it
  is never read. A duplication appended at the end cannot add a computation to a tape whose core is such a loop.
- **Tandem copies are not.** The same loop with a segment of its own body duplicated in place reaches further:
  `<<<<[!{~!{~!~]` (the `{~!` repeated) computes **16 classes up to depth 8** at the 16-emit cap and **28** at 64;
  `<<<<[{~!~!{~!~]` 13 to depth 7; `<<<<[!{~!~{~!~]` 12 to depth 7. Insertion inside the loop changes its orbit;
  appending after it does not.

So the plateau of §4.3 and of this pilot is not the channel's length: it is the orbit of the commonest loop, which
the 16-emit cap stops one NAND short (depth 6, not 7). An append-only growable channel cannot change that orbit;
tandem duplication can, which is why it was probed.

**A probe of tandem duplication** (*pilot*, exploratory, not a pre-planned arm): the same growable out-compute arm with
the duplicate inserted right after its original segment instead of appended, 15 000 epochs past descent on both
worlds, seed 5002.

Over 15 000 epochs past descent, medians of 2 500-epoch blocks across 10 000–15 000 (the window in which every
out-compute arm has made its climb), against the appended and fixed arms over the same window:

| world | arm | depth held 10% | classes per cell | classes held 10% | depth held 1% | mean length |
|---|---|---|---|---|---|---|
| 4381 | fixed | 3–4 | 4.35–4.60 | 9–11 | 5–8 | 32 |
| 4381 | appended | 5 | 5.38–5.60 | 14 | 6–7 | 209–223 |
| 4381 | tandem | 4 | 4.36–4.49 | 12 | 5 | 194–199 |
| 4428 | fixed | 5 | 5.44–5.47 | 12–13 | 6–7 | 32 |
| 4428 | appended | 7 | 6.42–6.50 | 16 | 7 | 175–178 |
| 4428 | tandem | 6 | 6.17–6.51 | 13 | 7 | 186–197 |

Tandem duplication did no better than appending: depth 4 and 6, p10 of per-cell max depth 1, tapes grown to about
200 bytes, and the dominant deepest solvers' 10–16 load-bearing bytes again within the first 18 positions. No tape
like `<<<<[!{~!{~!~]` was held.

**Why: the deep variants are not supersets.** `<<<<[!{~!{~!~]`'s 16 classes share only `0fff` and `aaaa` with the
incumbent loop's 12; `<<<<[{~!~!{~!~]` gains `0080/7` and `8aaa/4` and loses `afff/4`; `<<<<[!{~~!~]` shares three.
Changing a loop changes its whole orbit, so the variant replaces classes rather than adding them: under the subset
rule it can eat none of its incumbent neighbours, they cannot eat it, and it gains nothing over them. The ratchet
pays additions only, and on these tapes there are two kinds: a longer orbit of the same loop (bounded: 12 classes at
the 16-emit cap, 14 without) or code that runs before the loop and leaves its laps intact (code after it is never
read). Neither growth operator supplies either better than substitution does, and room in the channel supplies
neither.

### 7.4 What pilot 2 says

1. **No late climb.** The growable channel under out-compute does not keep climbing late. In both worlds depth,
   repertoire and length made their whole climb in the first 10 000–15 000 epochs and then stood. Neither growable
   run meets §5.4 on depth or repertoire; 4381's depth steps once, to 6, at 33 500 epochs (the rise rule reads +1,
   §5.4 fails), and 4428's fell back from the 7 it held at 7 500. The only §5.4 pass on depth or repertoire is
   4381's **fixed** arm, one NAND (4 → 5) first held at 56 500–58 500 on a series that had flickered between 4 and 5:
   the same single late step §4.3 read in 4428's fixed arm, here in the other world.
2. **It raises the level a little.** One NAND deeper held by a tenth (6 against 5 at the end of each world's pair),
   6.6 classes per cell against 4.6 and 5.7, and the replicators' detector share held at the drift arm's level
   (0.83–0.94) where the fixed arm's fell to 0.66–0.76, as in §4.3. At the end the growable solvers' cores carry
   11–12 load-bearing bytes against the fixed solvers' 16, which would make them cheaper to hold under the same
   per-byte mutation; two worlds cannot separate that from chance.
3. **The extra room is junk.** Out-compute grows the tapes to about 210 of 256 bytes, 60–90 above drift, and every
   byte that carries their depth or any class is in the first 16.
4. **The minimum does not rise**: the 10th percentile of per-cell max depth is 1 in all four out-compute runs,
   throughout.
5. **The fixed arm replicates §4.3 in shape**: depth 4–5 and 4.5–5.7 classes per cell reached within ~15 000 epochs,
   then flat; its levels sit a little below §4.3's seed 5001 (depth 5 and 6, 5.3 and 6.3 classes at 40 000), within
   what one seed per world can show.
6. **The plateau is the loop's orbit**, at any channel length from 32 up, and appended duplication is dead code
   behind it (§7.3).

### 7.5 Recommendation

**Do not include the growable-channel arm as built here** (segment duplication appended at the end) in the
out-compute sweep of §4.4. It costs about 1.6 times the fixed arm (≈ 39 against 25 ms an epoch on this Mac), and the
pilot predicts it ties the fixed arm on the rise rule and §5.4 and raises the level by about one NAND, which the
sweep's H-endogenous key reads on the fixed arm already.

**Nor with tandem duplication**: in its 15 000-epoch probe it did no better than appending. If a growable arm is
run anyway, as a level contrast only: `meta_max_len` 128 (the room past 32 went to junk, and 256 doubled the cost),
duplication 0.05 and deletion 0.05 per inheritance of a 1–16-byte segment, floor 8, with its own growable drift arm.

**The pilot moves the bet of §4.5.** Room in the channel is not what stops the climb. Two properties of this machine
under this rule are: (1) the commonest computing core is one loop whose laps spend the whole emit budget, so nothing
a tape adds after it is ever read; (2) changing a loop changes its whole orbit, so the variant is not a superset and
the subset ratchet does not pay it. A next pilot aimed at the plateau should change one of these, not the channel's
length. For (1), an assay that reads code past a loop (an emit or step budget per loop exit rather than per tape) is
a change to the machine and must keep §5 clause 2; for (2), the relation cannot change without giving up
transitivity, so the variation has to make additions reachable (insertions before a loop that leave its laps
intact). Both are hypotheses from offline reads of a handful of tapes from two worlds, not findings.

Whatever the channel, the sweep should read every emit slot (§4.3, point 7) and pair any growable arm with its own
**growable drift** arm: length alone passes the rise rule and §5.4 under drift. The widening input window of §4.5 was
not piloted; on four inputs the loop's orbit, not the window, set the top here.

**Files.** Pilot 2's material was pilot artefacts and was not kept either: the throwaway engine copy and its
`pilot` binary (with the offline tape reading of §7.3 and its emit cap), every census row of every pilot-2 run (with
the three commonest tapes at each census and the load-bearing readings at a tenth and a hundredth), and the scripts
behind the rise rule, §5.4's persistent maxima and the block medians.

## 8. Pilot 3: out-count, and an emit budget that grows with the channel

2026-10-03, all *pilot*: a throwaway copy of pilot 2's engine (itself `origin/main`, `b30196a`) in a session scratchpad, not
kept, one seed (5002, pilot 2's) per arm and world. A pilot, not a sample. Nothing in the repository or the lab was
touched. It tests the two blockers §7.5 named: (1) one stack-NAND loop spends the whole 16-emit budget, so appended
code is never read; (2) a changed loop changes all its classes, so a variant that computes more classes is not a
superset of the incumbent's and the subset rule does not pay it.

### 8.1 What was built

- **(A) Out-count.** A cell may take energy from the partner it picks when the partner computes **strictly fewer**
  input-permutation classes than it does, on the pass's case draw (every emit slot up to the cap, the assay's
  refusals). Everything else is §7's pass: asynchronous (each cell acts with probability 1/8 per epoch), cases
  redrawn every 8 epochs on the rule's own stream, `transfer` 8 192, `loss` 0.5, ×8 `meta_rate`.
- **(B) An emit budget that scales with the tape.** An assay run of a tape of length L stops at its
  `max(16, L/2)`-th emit (`task::EMIT_PER_LEN = 2`), in the predation pass, the census and the offline reader alike;
  the step budget stays at the engine's 4 096. At 32 bytes the budget is 16, so on the fixed channel B is the
  identity. B runs on §7's growable channel at §7.5's suggested size: live length 32 at descent, `meta_max_len`
  **128**, a duplicate of a random 1–16-byte segment appended at the end with probability 0.05 per inheritance, a
  random 1–16-byte segment deleted with probability 0.05, floor 8. So at the cap a tape may emit 64 times.
- **A replay check.** The pilot-3 binary, at the fixed 32-byte channel with B switched on and the subset rule,
  reproduces §7's fixed out-compute arm census for census (epochs 500 and 1 000 past descent, every column and the
  three commonest tapes). So §7's fixed arm (seed 5002, 60 000 epochs) is this pilot's **subset reference**, the
  §4.3 arm in its §7 replication, and was not re-run.

**Arms**, from 4381 and 4428 at their epoch 20 000 (`own_tape`, nothing computing at descent; §4.2's bundle):

| arm | rule | channel | emit budget | horizon past descent |
|---|---|---|---|---|
| **A** | out-count (strict) | fixed 32 | 16 | 60 000 |
| **B** | subset over classes | growable to 128 | max(16, L/2) | 25 000 |
| **A+B** | out-count (strict) | growable to 128 | max(16, L/2) | 30 000 |
| **drift** | none | growable to 128 | max(16, L/2) | 30 000 |
| ties probe | out-count, ties are prey (≤) | fixed 32 | 16 | 20 000 |
| subset reference | subset (§7's fixed arm) | fixed 32 | 16 | 60 000 |

**Cost and horizons.** The Mac's load average stood at 90–136 for most of the runs, and the A+B arm's pass costs
about 1.5 CPU-minutes per 1 000 epochs there once its tapes compute 50 classes on 128 bytes (A 0.4, B 0.9–1.1,
drift 0.3). Running every arm to 60 000 would have cost about 6.5 CPU-hours, so B, A+B and drift were cut to
25 000–30 000 epochs past descent (A+B then stood at its top for the last 20 000 of them); A ran its full 60 000. All in,
about **3.5 CPU-hours** charged at `nice 19` (A 51 min, A+B 77, B 51, drift 20, ties probe 13, replay and offline
reads 2), inflated by the load as in §6. The horizons are short of §5.1 clause 6's "ten times the plateau epoch"
for every arm but A.

### 8.2 Out-count against the honesty properties

**Relabelling.** The rule reads only |C(a)| and |C(b)|, the sizes of the two cells' class sets. Any bijection of the
classes preserves sizes, so the dynamics are unchanged; it is blind even to a relabelling applied differently to
each cell, which subset is not. It names no class, no depth, no ladder. **Passes clause 2's first test.**

**Relational.** In a world where every cell computes a set of the same size (a monoculture of any set among them),
no encounter moves energy, whatever the set: every choice gives the same payoffs. **Passes the second test.** Like
subset, it builds in a direction ("more beats fewer"), but it grades a cell only against its partner, never against
a scale.

**Transitive.** |C(a)| > |C(b)| > |C(c)| implies |C(a)| > |C(c)|: the eat relation is the strict part of the total
preorder "computes at least as many classes". Every pair of cells with different counts is comparable, so the ratchet
has one direction everywhere, where subset has one only along chains of nested sets. **It ratchets.**

**Silence is prey.** |∅| = 0 is below every computing cell's count. Two silent cells tie and do not eat each other.

**What it gives up against subset.**
- *Containment.* The predator need not compute what its prey computes: a variant that loses k classes and gains k + 1
  eats its parent. That is the point (blocker 2), and it means the population is no longer made to keep its old
  functions: breadth is graded by count, which is still relational, rather than by containment, which is still not a
  lookup. ECHO, which at least 90% of computing cells kept under subset (§4.3), is no longer protected.
- *Refuges.* Under subset, cells with incomparable sets do not interact, a standing source of diversity; under count
  only equal counts are refuges.
- *A route-blind count.* Count pays any way of adding a class. Classes are scarce at low depth (38 classes cost 4
  NANDs or fewer), so a large count still needs depth, but the rule pays a longer emit budget exactly as it pays new
  code. Under B this turned out to be the route the worlds took (§8.4).

**Should ties be prey?** Under subset a tie (A ⊆ B and B ⊆ A) means equal sets, so "kin eat kin" (§4.1, point 4)
was a by-product of reflexivity. Under count a tie means equal size: kin, and every stranger of the same size. Ties
as prey would therefore tax every equal-count encounter, kin or not, and make every encounter an eat for at least one
side. It would not pay novelty, since a new set of the same size is still eaten by its parent's kin. The faithful
transcription of point 4 is **"fewer, or exactly my set"** (kin are prey, equal-count strangers are not), which is
also transitive, relabelling-invariant and relational. It is built (`outcountkin` in `pilot3_bin`) but was not run.
The probe ran plain ties-as-prey (≤) on the fixed channel for 20 000 epochs:

| world | rule | eat rate | depth held 10% | classes per cell | classes held 10% / 1% | replicator share |
|---|---|---|---|---|---|---|
| 4381 | strict | 0.35 | 7 | 8.10 | 15 / 21 | 0.84 |
| 4381 | ties prey | 0.57 | 8 | 8.37 | 25 / 52 | 0.85 |
| 4428 | strict | 0.39 | 5 | 6.03 | 11 / 30 | 0.81 |
| 4428 | ties prey | 0.58 | 5 | 4.83 | 12 / 29 | 0.77 |

(medians of the last 5 000 of the 20 000 epochs.) Ties as prey move about 50% more energy, and destroy half of it.
In 4381 they hold one NAND more and spread more classes (25 against 15 at a tenth, 52 against 21 at a hundredth); in
4428 they hold the same depth and spread, 1.2 fewer classes per cell, and a lower replicator share. Neither world
rises late under either rule. **Decision: strict.** The upward push needs no tie (a +1 mutant eats every kin
neighbour and none eats it, either way), the tie tax falls on a count level rather than on a genotype, and the
replicators carry it. If a sweep finds that strict out-count loses its standing diversity, kin-tie is the variant to
try, not ties-as-prey.

### 8.3 Results

Medians of 5 000-epoch blocks past descent: depth held by a tenth · classes per cell (mean over all cells) ·
classes held by a tenth · mean length (growable channels).

| k epochs | 4381 subset ref. | 4381 A | 4381 B | 4381 A+B | 4428 subset ref. | 4428 A | 4428 B | 4428 A+B |
|---|---|---|---|---|---|---|---|---|
| 0–5 | 3 · 3.34 · 7 | 4 · 3.36 · 8 | 4 · 3.98 · 9 · 102 | 8 · 13.6 · 50 · 107 | 5 · 4.36 · 11 | 5 · 6.04 · 11 | 3 · 3.64 · 7 · 96 | 5 · 8.19 · 16 · 109 |
| 5–10 | 3 · 3.73 · 8 | 7 · 7.82 · 15 | 4 · 4.66 · 13 · 104 | 10 · 22.5 · 57 · 123 | 5 · 5.42 · 13 | 5 · 6.00 · 11 | 5 · 6.26 · 14 · 106 | 10 · 16.4 · 60 · 121 |
| 10–15 | 4 · 4.39 · 10 | 7 · 8.07 · 15 | 4 · 4.96 · 14 · 105 | 10 · 22.9 · 56 · 124 | 5 · 5.44 · 13 | 5 · 5.97 · 11 | 7 · 6.77 · 17 · 106 | 10 · 17.2 · 55 · 121 |
| 15–20 | 4 · 4.56 · 11 | 7 · 8.10 · 15 | 7 · 6.38 · 18 · 100 | 10 · 24.4 · 56 · 124 | 4 · 5.24 · 12 | 5 · 6.03 · 11 | 7 · 6.87 · 18 · 105 | 10 · 18.1 · 56 · 122 |
| 20–25 | 4 · 4.53 · 11 | 7 · 8.18 · 15 | 7 · 6.37 · 16 · 104 | 10 · 24.9 · 56 · 124 | 5 · 5.55 · 13 | 5 · 6.09 · 11 | 7 · 7.84 · 20 · 105 | 10 · 18.6 · 56 · 122 |
| 25–30 | 4 · 4.70 · 11 | 7 · 8.33 · 15 | | 10 · 25.6 · 55 · 124 | 5 · 5.56 · 13 | 5 · 6.20 · 11 | | 10 · 21.3 · 56 · 122 |
| 30–40 | 4 · 4.50–4.51 · 11 | 7 · 8.35 · 15 | | | 5 · 4.78–4.98 · 11–12 | 5 · 6.21 · 11 | | |
| 40–50 | 4 · 4.49–4.52 · 11 | 7 · 8.43–8.45 · 15 | | | 5 · 4.65–4.66 · 12–13 | 5 · 6.23–6.29 · 11 | | |
| 50–60 | 5 · 4.56–4.58 · 12 | 7 · 8.33–8.42 · 15 | | | 5–6 · 4.88–5.71 · 12–14 | 5 · 6.01–6.11 · 11 | | |

Both drift arms held no class by a tenth beyond ECHO (depth 0 or none, 0–1 class) with 87–89% of cells silent
throughout; their mean lengths (5 000-epoch medians) walked to 46–74 and ended the last block at 69 and 64.

**The last census**, each arm at its horizon; per-cell max depth over computing cells:

| world | arm | silent | per-cell max depth p10 / p25 / p50 / p75 / p90 / max | classes per cell p50 / p90 / max (mean) | depth held 10% / 1% | classes held 10% / 1% | length p10 / p50 / p90 | replicator share |
|---|---|---|---|---|---|---|---|---|
| 4381 | subset ref. (60 k) | 0.11 | 1 / 2 / 3 / 5 / 5 / 8 | 4 / 10 / 12 | 5 / 8 | 12 / 28 | 32 | 0.66 |
| 4381 | A (60 k) | 0.11 | 1 / 2 / 7 / 7 / 7 / 7 | 12 / 14 / 14 (8.09) | 7 / 7 | 15 / 21 | 32 | 0.80 |
| 4381 | B (25 k) | 0.09 | 1 / 3 / 4 / 6 / 7 / 9 | 5 / 14 / 14 (6.52) | 7 / 7 | 17 / 30 | 70 / 110 / 128 | 0.83 |
| 4381 | A+B (30 k) | 0.12 | 1 / 3 / 9 / 10 / 10 / 11 | 13 / 54 / 54 (25.3) | 10 / 10 | 54 / 107 | 114 / 128 / 128 | 0.88 |
| 4381 | drift (30 k) | 0.87 | 0 / 0 / 0 / 0 / 1 / 3 | 0 / 1 / 4 (0.14) | 0 / 1 | 1 / 2 | 17 / 77 / 121 | 0.84 |
| 4428 | subset ref. (60 k) | 0.06 | 1 / 2 / 4 / 5 / 6 / 8 | 5 / 12 / 14 | 6 / 7 | 14 / 30 | 32 | 0.76 |
| 4428 | A (60 k) | 0.09 | **2** / 3 / 5 / 5 / 5 / 10 | 8 / 10 / 16 (5.92) | 5 / 7 | 11 / 29 | 32 | 0.81 |
| 4428 | B (25 k) | 0.08 | 1 / 3 / 5 / 6 / 7 / 8 | 8 / 16 / 19 (7.99) | 7 / 8 | 23 / 43 | 77 / 111 / 128 | 0.83 |
| 4428 | A+B (30 k) | 0.08 | 2 / 3 / 6 / 10 / 10 / 11 | 10 / 55 / 55 (21.3) | 10 / 10 | 63 / 129 | 112 / 128 / 128 | 0.82 |
| 4428 | drift (30 k) | 0.89 | 0 / 0 / 0 / 0 / 0 / 3 | 0 / 1 / 3 (0.12) | 0 / 0 | 1 / 1 | 11 / 52 / 117 | 0.86 |

A+B's depth held by a hundredth reached 12 (4381) and 13 (4428) during the climb, and 4428 held 12 by a tenth for
one sample; at the end both hold 10 by a tenth, the mode of the four-input scale (§1.2), and 4381 flickers between 10
and 11 at a hundredth. Its eat rate is 0.43–0.46 against A's 0.34–0.39 and B's
0.31–0.32, and its replicators' detector share (0.82–0.88) sits at drift's level.

**The rise rule and §5's bar**, `analyze3.py` (§7's rule unchanged: settling window 1 000, deciles by index, lower
medians, the bar the highest of the fifth-decile median, the depth at descent and the deepest held five samples
running before the fifth decile ends; §5.4 at least three persistent new maxima, k = 5, the last in the final quarter
of each arm's horizon). Persistent maxima are dated by the sample that completes their five.

| world | arm | depth held 10%: bar → last | its last maxima (k epochs: depth) | §5.4 | classes held 10%: bar → last | last maximum | §5.4 |
|---|---|---|---|---|---|---|---|
| 4381 | A | 7 → 7 | 3: 4, 7: 7 | fails | 15 → 15 | 8: 15 | fails |
| 4381 | B | 4 → 7, **rises** | 16.5: 5, 17: 6, 17.5: 7 | fails (final quarter from 18.75) | 13 → 16, rises | 17.5: 18 | fails |
| 4381 | A+B | 10 → 10 | 5: 9, 6.5: 10 | fails | 57 → 55 | 5.5: 57 | fails |
| 4381 | drift | 0 → 0 | 3.5: 0 | fails | 1 → 1 | 3.5: 1 | fails |
| 4428 | A | 5 → 5 | 3: 3, 3.5: 5 | fails | 11 → 11 | 3.5: 11 | fails |
| 4428 | B | 7 → 7 | 6.5: 5, 12.5: 7 | fails | 16 → 21, rises | 25: 20 | **passes** |
| 4428 | A+B | 10 → 10 | 4: 5, 7: 10 | fails | 60 → 63, rises | 9.5: 60 | fails |
| 4428 | drift | 0 → 0 | 11.5: 0 | fails | 1 → 1 | 11.5: 1 | fails |

**Per-cell repertoire and median depth** (the mean classes per cell, floored, and its median; the median of per-cell
max depth). A: flat in both worlds (8 → 8, 6 → 6; last maxima at 15 000 and 4 500). B: rises in both (4 → 6, 6 → 7),
§5.4 passes in 4428 only. **A+B: rises in both and passes §5.4 in both**: mean 23 → 25 and 17 → 21, median 9 → 13
and 7 → 10, median depth 7 → 9 and 5 → 6, last persistent maxima at 26 500–30 000. The top does not move: the 90th
percentile of classes per cell holds 54–55 from 6 500 (4381) and 24 500 (4428) to the end, and the depth and the
repertoire held by a tenth stand still. What climbs late is the middle of the distribution catching up with a top
that stands at the channel's cap: more cells carry the cap-filling solver.

**The minimum.** The 10th percentile of per-cell max depth among computing cells is 1 throughout in every arm (A+B on
4428 reads 2 at its last census only; its last-decile median is 1), with one exception: **A in 4428 rises from 1 to 2** at 33 500 epochs past descent and holds 2 to 60 000. The rise rule
reads it (bar 1, last decile 2); §5.4 does not (three maxima, 0, 1 and 2, the last before the final quarter). It is
the first time in this study that McShea's minimum moved. One step in one of two worlds is a lead, not a finding.

**Length.** B's tapes reached 104–106 bytes by 6 000 epochs and stood; A+B's reached 121–124 of 128 by 7 000 and stood
at the cap (rise rule +1, §5.4 passes in 4428 as the mean creeps toward 128); drift's walked to 59–69, and 4381's
drift length again passes both the rise rule (60 → 69) and §5.4, as in §7.

**The program side**: the dominant deepest solver every 10 000 epochs, depth · load-bearing bytes (· length):

| world | arm | 10 k | 20 k | 30 k | 40 k | 50 k | 60 k |
|---|---|---|---|---|---|---|---|
| 4381 | subset ref. (§7) | 3 · 12 | 4 · 13 | 4 · 10 | 4 · 11 | 4 · 13 | 5 · 16 |
| 4381 | A | 7 · 20 | 7 · 20 | 7 · 20 | 7 · 18 | 7 · 18 | 7 · 19 |
| 4381 | B | 4 · 10 · 42 | 7 · 11 · 81 | | | | |
| 4381 | A+B | 10 · 22 · 128 | 10 · 21 · 128 | 10 · 21 · 128 | | | |
| 4428 | subset ref. (§7) | 5 · 13 | 4 · 9 | 4 · 8 | 5 · 16 | 5 · 12 | 6 · 16 |
| 4428 | A (at a hundredth) | 5 · 17 (6 · 22) | 5 · 14 (6 · 25) | 5 · 9 (7 · 25) | 5 · 12 (7 · 22) | 5 · 13 (6 · 24) | 5 · 10 (7 · 25) |
| 4428 | B | 5 · 12 · 86 | 5 · 13 · 121 | | | | |
| 4428 | A+B | 10 · 27 · 128 | 10 · 26 · 127 | 10 · 26 · 128 | | | |

Out-count's solvers carry more code: 18–20 load-bearing bytes in 4381's A, 21–27 in A+B, against 8–16 under every
subset arm here and in §7. Once found (by 10 000 epochs), that code does not grow: in A, over 50 000 epochs; in A+B,
over 20 000. Every load-bearing byte of every A+B solver lies in its first 30 positions.

### 8.4 What the solvers are (offline reads, `pilot3_bin tape`)

The census shows tapes with a non-instruction byte as `_` and the reader puts back a filler; each tape below
reproduces its census classes. Classes on the six fixed sets, with the budget scaled (`PILOT_EMIT_PER_LEN=2`) and
the tape padded with zeros or cut to each length:

| tape | 24 | 32 | 48 | 64 | 96 | 128 | 160 | 192 | 256 |
|---|---|---|---|---|---|---|---|---|---|
| §7's loop `<<<<[!{~!~]` (11 bytes) | | 12 | | 14 | | 14 | | | |
| the same, a second copy appended | | 12 | | 14 | | 14 | | | |
| B 4381 `<<_<<[{~!~]…` (11 load-bearing) | | 12 | 14 | 14 | | 14 | | | |
| B 4428 `_<<<.<[~!_~{!0]…` (14) | | 10 | | 14 | 14 | 14 | | | |
| A+B 4381 `<<.<}<[_{~!~{>~_~>-,<_]…` (23) | 8 | 13 | 22 | 29 | 41 | **54** | 62 | 67 | 68 |
| A+B 4428 `[,0<<<.<!0[~_!0~_{~0}!_~~!.{]…` (26) | | 14 | | 26 | 39 | **52** (127) | | 65 | 67 |

At 128 bytes with the budget fixed instead, A+B 4381's tape computes 15, 29, 54, 61 and 61 classes at 16, 32, 64,
128 and 256 emits. The A solvers on their 32 bytes: 4381's `!{>,[.{!~}}0}!~{{{]…` (18 load-bearing) 14, 15 and 17
classes at 16, 32 and 64 emits; 4428's `{-_,~,[.0<<<[~!~.~!<,!{~]…` (24) 12 at every budget.

So each fix removes one blocker and stops at the next:
- **A alone** pays new code (longer loops, 18–24 bytes) but sees at most 16 emits, and a loop whose orbit is longer
  than 16 laps is worth no more than one that closes at 14. Its solvers' orbits close at 12–17 at any budget; the
  climb was over by 8 000 epochs and nothing moved in the 52 000 after.
- **B alone** lets the commonest loop's whole orbit be read (14 classes and depth 7 rather than 12 and 6 at 16 emits),
  which the subset rule pays, since a longer prefix of the same orbit is a superset of the shorter one. Then the
  orbit closes, appended copies are still dead (the loop does not exit before the budget ends), and a different loop
  is still not a superset. B ends one NAND above §7's growable arm and its solvers are 11–14-byte loops.
- **A+B** pays a loop whose orbit stays open: within 5 000–7 000 epochs both worlds found stack loops with 21–27
  load-bearing bytes that emit a new class on almost every lap for about 60 laps. From then on, **length is
  repertoire**: each two bytes of junk appended by duplication buy one emit, and each emit one more class, at about
  one class per two bytes from 24 to 128 bytes. The tapes ran into the 128-byte cap by 7 000 epochs, with 54–55 classes on the top cells; the same cores
  would compute 62–68 at 160–256 bytes before their own orbits close.

### 8.5 What pilot 3 says

1. **Together the two fixes lift the plateau a long way, in both worlds; neither does much alone.** A+B, from worlds
   that computed nothing at descent and with nothing paid: 54–63 classes held by a tenth (against 11–28 in every
   other arm and 1 under drift), depth 10 held by a tenth (A: 5–7, B: 7, subset: 4–6), 21–25 classes per cell with
   the top cells at 54–55, all within 7 000–10 000 epochs. The replicators held their detector share (0.82–0.88).
2. **No arm keeps climbing late at the top.** The depth and the repertoire held by a tenth stop in every out-count
   arm before 10 000 epochs past descent. A is flat for 52 000 epochs. B's last steps come at 12 500–17 500 of 25 000
   (4381 rises by the rule and misses §5.4's final quarter by 1 250 epochs; 4428's held repertoire passes §5.4, by
   one or two classes a step). A+B stands at the cap from 6 500–9 500 to 30 000.
3. **What climbs late in A+B is the middle, toward a fixed top.** The per-cell repertoire and median depth rise by the
   rule and pass §5.4 in both worlds, as the cap-filling solver spreads through the population. The 90th percentile
   stays at 54–55 and the 10th at depth 1. On a horizon of 30 000 epochs this is diffusion to a ceiling, not a
   rising ceiling.
4. **The new ceiling is the channel's cap, and length is what reaches it.** Under a budget that scales with length,
   the count rule pays length directly once a long-orbit loop exists: the 100 bytes behind the core are junk that
   buys emits. That is exactly what §5.2 refuses to count ("a rise in tape length … does not count"), unless the
   program side rises with it. Here it rose once (to 21–27 load-bearing bytes, a new loop), then stood for 20 000
   epochs, because at the cap a loop with a longer orbit is worth nothing more.
5. **The minimum rose once**, in A on 4428 (depth 1 → 2 at 33 500 epochs, held to 60 000). Everywhere else it is 1.
6. **Ties stay neutral** (§8.2): ties-as-prey moved 50% more energy for no consistent gain.
7. **Depth is now near its top.** A+B reached depth 10–12 on four inputs, where the scale ends at 13 and has its mode
   at 10 (§1.2). On this input window, depth can no longer show a sustained rise; only the repertoire (up to 3 982
   classes) and the program side have room.

### 8.6 Recommendation: the next sweep after out-compute

**Keep the out-compute sweep (§4.4) as pre-registered.** Out-count on the fixed channel (A) moves its level by one
NAND down to three up (4428, 4381) and does not change its late-rise prediction (flat for 52 000 epochs in both
worlds). It need not replace
subset there; subset's containment is what makes that sweep's H-ratchet reading clean.

**The next sweep should be A+B, on a channel whose cap the run cannot reach, and one pilot should come first.**
Pilot 3 cannot say whether the climb would go on once length stops binding: at 128 bytes a loop with a longer orbit
earns nothing. The cores it found would reach 62–68 classes at 160–256 bytes and then close their orbits, so a
continuing rise past that needs new code. The question that decides the sweep is therefore a program-side one:
with the cap out of reach, do the load-bearing bytes and the orbit keep stepping, or does length carry the repertoire
to the first long-orbit loop's close and stop?

- **Pilot 4** (needed before the sweep): A+B and its drift at `meta_max_len` 512 (budget up to 256 emits; check
  whether the 4 096-step budget then binds instead, which for a loop of about 10 steps a lap would be near 400 laps),
  both worlds, 30 000–60 000 epochs. Extrapolating this pilot's cost per emit, roughly 2–2.5 CPU-hours a world on
  this Mac under its load; it should run on the mini-pc as an engine slice rather than here.
- **The sweep**, if pilot 4 shows the program side stepping: an engine slice for `predation: count` (strict),
  `task_max_outputs: per_len` (max(16, L/2)) and the growable metabolism tape (append duplication and deletion at
  0.05, floor 8, a cap well past the run's reach). Arms: **count-grow** (A+B), **drift-grow** with the same channel and
  budget, **shadow-grow** at count-grow's eat rate (0.45), and **subset-grow** (B) as the no-count reference. Key on
  the **classes held by a tenth**, with the **load-bearing bytes** of the dominant solver as a co-key. Under this budget
  length alone buys repertoire, so a function-side rise with a flat program side would count as half (§5, clause 3).
  Add the minimum and the per-cell repertoire's 90th percentile, so that the top and the middle are read apart. Depth
  needs the widened input window of §4.5 to be readable at all past 10.
- **If pilot 4 shows only length**, then the plateau has moved from the 16-emit cap to one loop's orbit, and the next
  lever is the machine, not the rule. The dominant loops do not exit before the budget ends (§7.3; here the tails
  behind them bear nothing), so code after a loop is still never run, and no tape composes two computations. An exit condition that loops can evolve to meet, or a
  budget per loop exit (§7.5's point 1), is a change to the machine that must keep §5 clause 2.

**Files.** Pilot 3's material was pilot artefacts and was not kept: the throwaway engine copy (out-count and its tie
and kin variants, the length-scaled emit budget) and its `pilot3_bin` binary (the arms above, `--emit-per-len`, and the
offline tape reader of §8.4), every census row of every pilot-3 run (with the three commonest tapes and the
load-bearing readings at each census; runs stopped by the stopper may hold a few samples past their horizon), the
scripts behind the readings and tables above (`analyze3.py`, `tables3.py`), the bundle, and the stopper's targets and
log.

## 9. Pilot 4: A+B at a cap of 512, the program side, and a lap budget per loop

2026-10-03, all *pilot*: a throwaway copy of pilot 3's engine (itself `origin/main`, `b30196a`) in a session scratchpad, not
kept, one seed (5002, pilots 2 and 3's) per arm and world. A pilot, not a sample. Nothing in the repository or the lab
was touched. It asks §8.6's question: under out-count with a length-scaled emit budget on a growable channel (A+B),
once length stops binding, does the **program side** keep stepping (load-bearing bytes, the number of computations
composed, the orbit), read late in the run?

### 9.1 What was built

- **A plain interpreter for the assay** (`bff::run_plain`): the emit-and-stack-NAND machine on the assay's fixed 2L
  buffer, every step executed, bracket matches memoised and cleared on any write that makes or unmakes a bracket.
  Without a lap cap it is the engine's `run_emitting` step for step: **0 mismatches** in outputs, steps and halt over
  231 336 case runs (1 426 tapes from pilot 3's censuses and 5 000 random tapes of 16–512 bytes, every case of the six
  sets, budget max(16, L/2)). The runs use it because it is about 20% cheaper on long emitting loops. The pilot-4
  binary on it reproduces pilot 3's A+B census on 4381 (cap 128, seed 5002) **column for column** at 500 and 1 000
  epochs past descent.
- **The assay-budget reading**, every census: each distinct computing tape's six case runs on the first fixed set,
  run in full; the share stopped by the 4 096-step budget and by the emit budget, and the mean steps, over all
  computing cells and over the top cells (classes at or above the computing cells' 90th percentile).
- **The program-side reading** (§9.2), every 500 epochs, of two solvers: the **dominant deepest solver** of §7.1 (the
  commonest tape credited a deepest class held by a tenth) and the **top-repertoire solver** (the commonest tape among
  the cells computing at least the computing cells' 90th percentile of classes: out-count pays the count, not the
  depth). In these growable worlds each is held by 3–16 cells (3–5 late), since the tails differ tape by tape, so single
  readings are noisy; the series are what is read.
- **The machine variant** (`--lap-cap 16`, §9.3).
- §8's census otherwise unchanged, plus the classes per **computing** cell's 10th, 50th and 90th percentiles beside the
  per-cell max depth's, so the bottom and the top of the distribution are read apart.

### 9.2 The program-side measures

For one solver tape T, with C(T) its classes on all six fixed sets at its own budget:

- **Depth-bearing bytes** (`nbd`): §7.1's load-bearing count against the depth the solver was chosen for, so the
  series continues §7–§8's.
- **Count-bearing bytes** (`nbc`): positions where at least 7 of the 13 other symbols leave |C(T)| smaller. Out-count
  pays the count, so these are the bytes selection holds still; the depth rule misses bytes that carry breadth but not
  the deepest class.
- **Load-bearing code length** (`span`): the last bearing position minus the first, plus one, over both rules: a
  compact core or code spread along the tape.
- **Computations composed.** Each class of C(T) is dated to the slot where it first appears on the first fixed set,
  the slot to the instruction pointer of its emit in a traced run of the first case, and the pointer to the innermost
  static loop (bracket pair) that holds it, or to straight-line code. `contrib` counts the distinct regions so
  credited; `tops` names the outermost loops among them (two named loops there is sequential composition: a second
  loop that adds classes after the first exits); `bodies` counts the distinct byte strings of the contributing
  innermost loops, so a copied loop counts once and a new loop again.
- **The orbit**: the slots emitted in the traced case, the budget, `last_new` (the slot of the last new class: how
  long the orbit stays productive), the halt and the steps; `free`, the classes with the emit budget lifted to 4 096
  (steps kept at 4 096); and offline, the core alone, zero-padded to longer lengths and run with more steps.

**Why these.** On this machine a computation that yields a run of functions is a loop: every A+B solver in §8 is one
stack-NAND loop whose laps are its emits. "Composes two computations" therefore means that at least two code regions
each add classes, which emit attribution reads directly, while substitution reads what each region is needed for (a
second loop that only extends the stack the first left is credited by attribution, and the first stays bearing for
it). Distinct bodies separate the two ways a tape can add loops, copies and new code. The span and the orbit separate
"more code" from "the same code run longer". A function-side rise with these flat is length or co-option, which §5.1
clause 3 counts as half.

### 9.3 The machine variant: a lap budget per loop entry

**What changed.** In the assay's machine (the metabolism channel only; the soup's interpreter is untouched), every
loop entry may run its body at most **16** times: when a `]` would jump back a 16th time, it falls through and
execution goes on past the loop. A body's count starts when its `[` is executed on entry with head0 non-zero, so a
nested loop re-entered by its outer loop starts a fresh count (16 outer laps around an inner loop still run 256 inner
laps). Everything else is A+B@512's: the per-tape emit budget max(16, L/2), the 4 096-step budget, strict out-count,
the growable channel, every rate. At lap cap 0 the machine is the engine's (§9.1's check).

**Why this one.** §7.5 and §8.6 named the blocker: the dominant loops never exit before the budget ends, so code after
a loop never runs and no tape composes two computations. Of the two changes the brief offered, a per-emit step budget
does not make a loop exit, and running the tape from several entry points gives independent runs on fresh buffers
(no composition through the shared stack) at a cost that grows with the number of entries. A lap budget per loop entry
is the smallest change that makes every loop exit: the per-tape emit cap of §4–§7 (16) becomes a per-loop budget, which
is §7.5's "a budget per loop exit rather than per tape". A second loop then runs on the buffer the first left, so it can
read and extend the first loop's stack.

**Why it is honest.** It reads no output, names no function, class or depth, and acts identically on every tape: a
relabelling of the functions leaves the dynamics unchanged, and in a monoculture of any set every payoff is still equal,
since the rule (out-count) is untouched. It is a change of the machine (S in §2's terms), which the out-compute family
already imports; it imports no objective. It does change what programs compute: one loop now yields at most 16 laps
per entry, so §8's route (one open-orbit loop, length buys laps) is capped, and breadth past 16 laps must come from a
second loop, a copy, or nesting.

**On known tapes** (offline): §7's `<<<<[!{~!~]` keeps its 14 classes (its orbit closes inside 16 laps). Pilot 3's 4428
A+B core keeps 38 of its 48 classes at 128 bytes, and a second copy appended behind it now runs and lifts it to 45,
with two contributing loops, 46 count-bearing bytes and a span of 52: under this machine a duplicated loop is no longer
dead code.

### 9.4 Arms, horizons, cost

From 4381 and 4428 at their epoch 20 000 (`own_tape`, nothing computing at descent; §4.2's bundle; ×8 `meta_rate`,
`transfer` 8 192, `loss` 0.5, the asynchronous pass every 8 epochs on average), strict out-count; the growable channel
of §8 (live 32 at descent, duplication of a 1–16-byte segment appended at 0.05 per inheritance, deletion at 0.05, floor
8) with the cap raised to **512**, emit budget max(16, L/2) (so up to 256), steps 4 096:

| arm | rule | machine | horizon past descent | CPU |
|---|---|---|---|---|
| **A+B@512** | out-count | engine's | **15 000** (planned 30 000) | 74 and 80 min |
| **lap16** | out-count | lap budget 16 per loop entry | **10 000** | 27 and 25 min |
| **drift@512** | none | both: one trajectory (without predation the assay never feeds back), censused under both machines | 30 000, read at 15 000 | 9 and 11 min |

Plus the replay check (about 1 minute) and the offline reads (about 10): **about 3.9 CPU-hours** at `nice 19`, the Mac's
load average between 13 and 193 throughout. The horizons were cut to stay inside the budget: at the cap A+B@512 costs
about **7 CPU-minutes per 1 000 epochs** on this Mac (top cells running near 4 096 steps per case), about five times
§8's A+B at 128. They are short of §5.1 clause 6 for every arm, and of §8's 30 000.

### 9.5 Results: the function side

Medians of 2 500-epoch blocks past descent: depth held by a tenth · classes per cell (mean over all cells) · classes held
by a tenth · classes per computing cell at p90 · mean length.

| k epochs | 4381 A+B@512 | 4428 A+B@512 | 4381 lap16 | 4428 lap16 |
|---|---|---|---|---|
| 0–2.5 | 6 · 5.7 · 14 · 10 · 87 | 7 · 7.8 · 15 · 14 · 74 | 5 · 4.6 · 13 · 8 · 93 | 4 · 4.5 · 11 · 10 · 86 |
| 2.5–5 | 8 · 24.8 · 63 · 61 · 297 | 11 · 28.9 · 48 · 46 · 267 | 11 · 18.5 · 49 · 39 · 249 | 9 · 12.1 · 46 · 38 · 153 |
| 5–7.5 | 10 · 31.9 · 98 · 96 · 443 | 11 · 58.9 · 177 · 165 · 393 | 12 · 22.2 · 63 · 57 · 314 | 10 · 18.8 · 70 · 64 · 307 |
| 7.5–10 | 10 · 22.2 · 49 · 46 · 505 | 12 · 88.4 · 220 · 215 · 507 | 10 · 30.5 · 93 · 108 · 402 | 11 · 21.7 · 93 · 87 · 456 |
| 10–12.5 | 10 · 21.3 · 49 · 46 · 506 | 13 · 96.4 · 221 · 219 · 507 | | |
| 12.5–15 | 10 · 23.3 · 50 · 48 · 503 | 13 · 96.4 · 221 · 219 · 508 | | |

Both drift arms: 86–89% of cells silent, ECHO alone held by about a tenth (depth 0, one class), 0.10–0.15 classes per
cell; under the lap machine the same (one class, depth 0); mean length walked to 110 and 99 by 15 000 (117 and 166 by
30 000).

**The last census**; per-cell max depth over computing cells:

| world | arm | silent | max depth p10 / p25 / p50 / p75 / p90 / max | classes per computing cell p10 / p50 / p90 / max (mean, all cells) | depth held 10% / 1% | classes held 10% / 1% | length p10 / p50 / p90 | replicator share |
|---|---|---|---|---|---|---|---|---|
| 4381 | A+B@512 (15 k) | 0.11 | 1 / 3 / 7 / 10 / 11 / 11 | 1 / 13 / 148 / 151 (37.9) | 11 / 11 | 174 / 253 | 461 / 503 / 512 | 0.83 |
| 4428 | A+B@512 (15 k) | 0.03 | 1 / 2 / 8 / 13 / 13 / 13 | 2 / 21 / 219 / 219 (94.1) | 13 / 13 | 220 / 277 | 497 / 512 / 512 | 0.79 |
| 4381 | lap16 (10 k) | 0.04 | 1 / 2 / 6 / 10 / 11 / 13 | 2 / 10 / 120 / 148 (33.1) | 10 / 12 | 107 / 394 | 371 / 425 / 507 | 0.76 |
| 4428 | lap16 (10 k) | 0.09 | 1 / 2 / 5 / 8 / 11 / 13 | 1 / 9 / 87 / 159 (19.6) | 11 / 11 | 91 / 176 | 452 / 492 / 512 | 0.86 |
| 4381 | drift (15 k) | 0.86 | 0 / 0 / 0 / 0 / 1 / 3 | 1 / 1 / 1 / 4 (0.15) | 0 / 1 | 1 / 2 | 18 / 95 / 235 | 0.79 |
| 4428 | drift (15 k) | 0.89 | 0 / 0 / 0 / 0 / 1 / 3 | 1 / 1 / 1 / 5 (0.12) | 0 / 1 | 1 / 2 | 16 / 80 / 202 | 0.85 |

Eat rates 0.43–0.45 (A+B@512) and 0.47 (lap16), as §8's A+B.

- **The cap of 512 is not out of reach.** Both A+B worlds took their tapes to a mean of 495–508 bytes by 9 000–10 000
  epochs past descent (4428's lap16 to 485 by 10 000), as fast as §8's took them to 128.
- **The level rises with the cap.** 4428 holds **219–221 classes by a tenth** with its top cells at 219 (against 55–63 and
  54–55 at a cap of 128, §8) and **depth 13** by a tenth from 12 500 epochs: the top of the four-input scale (§1.2). 4381
  climbed to 96–106 classes on its top cells by 8 000, **fell back to 46–49 at 8 500–9 000** as its tapes reached 500
  bytes and stood there for 5 000 epochs (the cause was not diagnosed), and in its last two censuses a new core spread
  (148 classes at p90, 174 held by a tenth at 15 000).
- **The minimum does not move.** The 10th percentile of classes per computing cell is 1–2 and of per-cell max depth 0–2
  in every out-count run, throughout, as in §4.3, §7 and §8: the middle and the top climb, the bottom stays at ECHO.

### 9.6 Results: the assay budget

- **Population.** At 15 000 epochs, 51% of 4428's computing cells' case runs stop at the 4 096-step budget (81% of its top
  cells', mean 4 023 steps); 12% of 4381's (0% of its top cells', which all stop on the emit budget at a mean of 2 331
  steps); 6–8% under lap16; 15–20% under drift (random tails that spin).
- **But the step limit is not what binds 4428's top at 512.** Its 21-byte core makes all of its 251 emits within 4 096
  steps and then spins without emitting (with no step limit the run ends at 8 510 steps, still 251 emits). At 512 the
  orbit ends where the stack, written leftward from the inputs at two NANDs per emit, has used the buffer's empty half,
  which is L bytes: **length binds through the buffer as well as through the emit budget.** Padded to 640 bytes the same
  core makes 293 emits and computes **253** classes, and there the **4 096-step budget binds** (with 65 536 steps: 263
  classes, the last new one at slot 305, the end of its orbit). So the step budget binds at about 600 bytes for 4428's
  core.
- **4381's final core** (29 bytes, alone): 56, 90, 151 and 184 classes at 128, 256, 512 and 1 024 bytes; at 1 024 its orbit
  closes at slot 390 inside the 454 emits that 4 096 steps allow, so the step budget would not bind for it below about
  900 bytes.
- **Answer to the check:** at 512 the step budget does not yet bind on the dominant cores, but it is the next constraint:
  one step past the cap (4428) or about twice the cap (4381). "A cap the run cannot reach" on this machine is a cap at
  which the fixed 4 096-step budget binds instead.

### 9.7 Results: the program side

The two solvers every 2 500 epochs (block medians): depth · classes · depth-bearing · count-bearing · span · bodies ·
length · last new slot.

| k epochs | 4381 A+B@512, top-repertoire solver | 4428 A+B@512 (deep = top) | 4381 lap16, top | 4428 lap16, top |
|---|---|---|---|---|
| 0–2.5 | 7 · 14 · 21 · 23 · 23 · 1 · 49 · 22 | 7 · 14 · 14 · 14 · 14 · 1 · 49 · 21 | 5 · 10 · 20 · 21 · 21 · 1 · 64 · 18 | 5 · 11 · 22 · 22 · 22 · 1 · 62 · 22 |
| 2.5–5 | 9 · 66 · 23 · 23 · 23 · 1 · 222 · 106 | 11 · 46 · 16 · 16 · 16 · 1 · 270 · 124 | 11 · 40 · 24 · 26 · 26 · 1 · 236 · 114 | 9 · 38 · 27 · 32 · 33 · 1 · 124 · 60 |
| 5–7.5 | 10 · 96 · 26 · 28 · 28 · 1 · 471 · 219 | 11 · 167 · 20 · 20 · 20 · 1 · 434 · 209 | 10 · 66 · 24 · 29 · 30 · 1 · 290 · 122 | 10 · 71 · 28 · 30 · 34 · 1 · 337 · 168 |
| 7.5–10 | 10 · 46 · 23 · 25 · 26 · 1 · 512 · 218 | 12 · 215 · 21 · 21 · 21 · 1 · 512 · 251 | 10 · 107 · 26 · 32 · 32 · 1 · 354 · 165 | 11 · 88 · 26 · 27 · 34 · 1 · 495 · 231 |
| 10–12.5 | 10 · 82 · 23 · 28 · 29 · 1 · 512 · 143 | 13 · 219 · 21 · 21 · 21 · 1 · 512 · 251 | | |
| 12.5–15 | 10 · 89 · 22 · 24 · 26 · 1 · 512 · 141 | 13 · 219 · 21 · 21 · 21 · 1 · 512 · 251 | | |

- **One loop, always.** Over 154 solver readings (48 and 41 in A+B@512, 34 and 31 in lap16; a top-repertoire solver that is the deep
  one is read once), every class is credited from **one
  top-level loop**, plus at most straight-line code before it (an emit ahead of the loop, in 61 readings). **No reading has
  two top-level loops contributing**: no tape composes two computations sequentially, under either machine. Two distinct
  bodies appear only as a loop nested in another that emits too (7 readings in 4381's A+B, 10 in its lap16, 3 in 4428's
  lap16, none in 4428's A+B).
- **Load-bearing code stays a compact core**: 21–29 bytes, every bearing byte in the first 30 positions of 480–512-byte
  tapes, the same size as §8's 21–27 at a cap of 128. The final cores alone, zero-padded, compute exactly the classes of
  the whole tapes (4428: `<<<<!.[~!{~{~_~~.}_>]`, 21 bytes, 219 classes at 512; 4381: `-[<0<<.<[_[{_{0~{~.!.}}~!>,<]`,
  29 bytes, 151 at 512). Every other byte is junk, as in §7 and §8.
- **Where it steps, it steps by editing the one loop, and the edits make length buy more.** 4428's core grew 14 → 16 →
  18 → 20 → 21 bearing bytes (persistent maxima at 3 000–3 500, 5 500, 7 000–7 500, 8 500 and 10 500–11 000 epochs past descent), each step
  a variant of the same `[~!{~{~…~~.}…>]` loop whose orbit stays productive for longer per byte: at 512 bytes this core
  credits 219 classes from 251 emits, where §8's 4428 core credits 69 at the same length. 4381's top solvers sat at 22–28
  count-bearing bytes from 4 000 to 14 000 epochs; in the last 1 000 a longer body (`…~!>,<]`, 27–29 bytes) spread and
  lifted its top cells from 89 to 148 classes. Two samples: a lead, unreadable by the rule at this horizon.
- **After the cap is reached** (about 9 500 epochs in both worlds), 4428's program side stepped once more by one byte
  (20 → 21, at 10 500–11 000) and then stood for the last 4 000 epochs while its classes and depth crept up to the top
  of the per-cell distribution (215 → 219, depth 12 → 13) as the core spread. 4381's stood at 22–23 depth-bearing bytes
  for 5 000 epochs until the late variant above.
- **The lap budget was circumvented by nesting, in 3 000–3 500 epochs.** Both lap16 worlds wrapped their loop in an
  outer loop (4381 `[<[.~!{~!>{~~.}~!,]}>-]`, 4428 `[[.<~_~~{_~!_0~0{~!>!]]`): 16 outer laps re-enter the inner one and
  restore one long orbit. Flattened (one bracket pair removed), the same tapes compute 43 and 35 classes under the lap
  budget against 124 and 87 nested, and 126 and 86 flattened on the engine's machine. The cheapest way past a per-loop
  budget was two bytes that rebuild the single open orbit, not a second computation; the duplicated loop that §9.3
  showed would now run was not what the worlds found. On the function side lap16 ran behind A+B@512 at equal
  horizons in 4428 (93 against 220 classes held by a tenth at 7 500–10 000) and ahead of 4381's post-crash A+B (93
  against 49), with load-bearing cores of 23–29 bytes.

### 9.8 The rise rule and §5.4

§8's rule unchanged (settling window 1 000, deciles by index, lower medians, the bar the highest of the fifth-decile
median, the value at descent and the deepest held five samples running before the fifth decile ends; §5.4 at least
three persistent new maxima, k = 5, the last in the final quarter of the arm's horizon). Bar → last decile; ✓ = rises
(at least bar + 1), and §5.4 pass or fail with the date of the last persistent maximum (k epochs past descent).

| world | arm (horizon) | depth held 10% | classes held 10% | count-bearing bytes, top solver | depth-bearing bytes, deep solver | minimum: per-cell max depth p10 · classes p10 | length |
|---|---|---|---|---|---|---|---|
| 4381 | A+B@512 (15 k) | 10 → 10; fails (8) | 98 → 64; fails (8) | 28 → 26; fails (8) | 27 → 23; fails (8) | 0 → 1 ✓, fails · 1 → 1 | 481 → 498 ✓; fails (11) |
| 4428 | A+B@512 (15 k) | 11 → 13 ✓; **passes** (12.5) | 191 → 221 ✓; **passes** (12) | 20 → 21 ✓; fails (10.5) | 20 → 21 ✓; fails (11) | 2 → 1 · 2 → 2 | 506 → 507 ✓; passes (13) |
| 4381 | lap16 (10 k) | 12 → 10; fails | 47 → 91 ✓; **passes** (8.5) | 29 → 32 ✓; fails (6.5) | 24 → 23; fails | 1 → 1 · 2 → 1 | 265 → 402 ✓; passes |
| 4428 | lap16 (10 k) | 9 → 11 ✓; **passes** (7.5) | 50 → 91 ✓; **passes** (8) | 30 → 27; fails | 23 → 26 ✓; **passes** (9.5) | 0 → 1 ✓, fails · 1 → 1 | 179 → 478 ✓; passes |
| both | drift (15 k) | 0 → 0; fails | 1 → 1; fails | — | — | 0 → 0 · 1 → 1 | 70 → 114, 91 → 98 ✓; pass |

Read with the length column. Every function-side pass is in an arm whose length rises by the rule and passes §5.4 over
the same window: 4428's A+B passes are the core spreading to the top of the distribution at the cap (top cells 215 →
219, the core unchanged at 21 bytes, depth reaching the scale's end at 13), and the lap16 passes come while the tapes are
still growing (to 402 and 478 of 512 at 10 000). The only program-side pass, 4428's lap16 depth-bearing bytes (23 → 26,
last at 9 500), is the nested loop's edits during that growth. McShea's minimum does not rise anywhere by §5.4; the
rule's two "rises" (0 → 1) are cells leaving ECHO-only, back to §8's floor of 1. On these horizons (10 000–15 000 epochs),
and with drift's length passing §5.4 too, none of this is a sustained rise in §5's sense.

### 9.9 What pilot 4 says

1. **Length did not stop binding: the cap of 512 was reached in 9 000–10 000 epochs**, as the cap of 128 was in §8, and both
   final cores would compute more at greater length (4428: 219 → 253 at 640 bytes; 4381: 151 → 184 at 1 024). Past about
   600 bytes (4428) the fixed 4 096-step budget binds instead. On this machine there is no regime in which length is
   free and nothing else binds: length's room is handed to a machine constant.
2. **The program side does not compose.** In 154 solver readings over four out-count runs, no tape has two top-level
   loops that each add classes; every repertoire, up to 219 classes and depth 13, is one stack-NAND loop's orbit,
   21–29 load-bearing bytes in the first 30 positions, the rest junk.
3. **The program side steps by editing that loop, while length grows, and the edits make length buy more classes.**
   4428: 14 → 21 bearing bytes in five persistent steps to 10 500 epochs, the last one a byte after the cap was reached,
   then flat for 4 000 epochs. 4381: flat at 22–28 for 10 000 epochs, then a longer body (27–29 bytes, 89 → 148 classes on
   its top cells) in the last 1 000, too late to read. In §5's terms: the function side rises with length to the cap
   (half credit at best, clause 3), and the program side shows edits of one computation, not new ones.
4. **Making every loop exit does not produce composition.** Under a lap budget of 16 per loop entry, both worlds nested
   their loop inside another within 3 000–3 500 epochs and restored one long orbit; the duplicated-loop route that the
   machine now opened was not taken. The cheapest response to a per-loop budget is a wrapper, so a per-loop budget does
   not make a second computation pay.
5. **The level rises with the cap and depth hits its top.** 4428 at 512 holds 219–221 classes by a tenth and depth 13
   (the end of the four-input scale) against 55–63 and depth 10 at 128; 4381's top fell and recovered (46–49 for 5 000
   epochs, then 148 on its top cells). Drift holds one class (ECHO). On four inputs depth can no longer show a rise.
6. **The minimum stays at the floor** (classes p10 1–2, max depth p10 0–2) in every out-count run.
7. **Cost.** At its cap A+B@512 costs about 7 CPU-minutes per 1 000 epochs here, about five times A+B at 128, for no
   change in the program side (21–29 bearing bytes in both).

### 9.10 Recommendation: the sweep after out-compute

Pilot 4 lands on §8.6's second branch: what climbs is length and one loop's orbit, so the next lever is the machine,
not the rule or the cap. Concretely:

**Do not run a count-grow rise sweep, at 512 or at any cap the run can reach.** Its keyed repertoire tracks the cap
(reached within 10 000 epochs) and then a fixed step budget; its program side is one loop edited while length grows.
The predicted reading is "rises to the cap, then stands", at about five times the cost per epoch at 512.

**The sweep after out-compute should be a level sweep of A+B at the cap of 128 (`count-grow`)**, which establishes on many
parents what pilots 3–4 show on two (out-count with a length-scaled budget builds two to four times the classes and
about twice the load-bearing code of subset, from worlds that compute nothing, with nothing paid), and pre-registers the
rise as predicted refuted:

- **Parents**: §4.4's, the 54 reach-cap128 radius-4 eligible parents with the lowest run ids, each from its terminal world
  at 20 000 (fitness-free history).
- **Bundle**, merged over each parent's params: `energy_payer: initiator`, `energy_influx: 1024`, `energy_stock_cap:
  65536`, `steal_amount: 0`, `tasks: logic4`, `task_reward: 0`, `logic_nand: stack`, `meta_len: 32`, `meta_max_len:
  128`, `meta_dup: 0.05`, `meta_del: 0.05`, `meta_seg_max: 16`, `meta_min_len: 8`, `meta_rate: 8/8192`, `meta_draw: isa`,
  `meta_seed: own_tape`, `task_max_outputs: per_len` (max(16, L/2)), `predation_transfer: 8192`, `predation_loss: 0.5`,
  `predation_every: 8` (the engine slice of §4.4 plus §8.6's three keys).
- **Arms**: **count-grow** (`predation: count`, strict), **subset-grow** (`predation: subset_class`), **shadow-grow**
  (`predation: shadow` at p = 0.45, count-grow's eat rate in pilots 3 and 4), **drift-grow** (`predation: off`). Seed 6101,
  one per parent, **30 000 epochs** past the parent (§8's A+B stood at the cap from 7 000); 216 children.
- **Keys**, one-sided sign tests over discordant pairs at p < 0.05, the last-decile median of each child:
  - *H-level* (count-grow against drift-grow), *H-driven* (against shadow-grow) and *H-count* (against subset-grow): the
    **classes held by a tenth**. Predicted shown, shown and shown (§8 at 128: 54–63 against 1 under drift and
    17–23 under subset).
  - *H-code* (count-grow against subset-grow): the **count-bearing bytes of the top-repertoire solver** (§9.2). Predicted
    shown (§8 at 128: 21–27 against 10–13).
  - *H-rise* (count-grow against drift-grow): the rise rule and §5.4 on classes held by a tenth, with count-bearing bytes
    as co-key and **contributing top-level loops** as a third reading. Predicted **refuted**: the climb ends at the cap
    within 10 000 epochs, the program side is one loop.
  - Read apart, as §8.6 asked: the per-cell repertoire's 90th percentile (top) and 10th (minimum), and per-cell max
    depth's 10th; and length beside every key, since drift's length passes §5.4 by itself.

**Before any rise sweep, one machine pilot (pilot 5): independent entry points with their own budgets.** The two
blockers are now both on the machine: a loop never yields to code after it (wrappers defeat a per-loop budget), and a
changed loop changes its whole orbit, so an addition is not reachable without loss (§7.5). The smallest machine on
which an addition is reachable and length alone buys nothing: the assay runs the live tape from every entry point at
offsets 0, 32, 64, … (each run from its offset to the buffer's end, on a fresh 2L buffer, with its own fixed budget of
16 emits and 4 096 steps), and a tape's classes are the union. A duplicated segment then adds nothing until it diverges,
and once diverged adds classes without touching the first segment's orbit, which out-count pays; the program side reads
as the number of load-bearing entry segments and their distinct bodies. It reads no output and names no function, so it
keeps §5.1 clause 2; it imports a fixed segment size, which a marker-defined entry (a byte the tape itself places) would
remove at some cost in simplicity. Arms: **count-genes**, **drift-genes**, **subset-genes**, cap 512, both worlds, 30 000
epochs, read on the classes held by a tenth and on the number of load-bearing segments with distinct bodies. Only if
that number keeps stepping late does a rise sweep have a program side to read.

**Files.** Pilot 4's material was pilot artefacts and was not kept: the throwaway engine copy (the lap budget, the
plain-loop and step-budget switches, the trace and slot readings) and its `pilot4b_bin` binary (the arms of
`pilot3_bin` plus the lap-budget options, and the offline equivalence check, the §9.2 solver reading, the class-and-orbit
reading and the tape reader; the runs used the identical binary before the offline-only additions), every census row of
every pilot-4 run (with the commonest tapes, the deepest and top solver readings and, for drift, the lap lines), the
scripts behind the readings above (`analyze4.py`, `tables4.py`), the offline reads of §9.6–§9.7 and the tape checks, and
the launch and stopper scripts, targets and log.

## 10. Pilot 5: independent entry points ("genes")

2026-10-03, all *pilot*: a throwaway copy of pilot 4's engine (itself `origin/main`, `b30196a`) in a session scratchpad, not
kept, one seed (5002, pilots 2–4's) per arm and world. A pilot, not a sample. Nothing in the repository or the lab was
touched. It tests §9.10's machine change: §9 found that the program side never composes (one stack loop, a 21–29-byte
core, length buying repertoire through one open orbit), and that a per-loop lap budget was beaten by nesting. Here the
assay runs a tape from several entry points, each on its own buffer with its own budget, so an addition can be made
without breaking what an earlier segment computes, and junk length buys nothing.

### 10.1 What was built

**The genes machine** (`topless::GENE_LEN`, the metabolism channel's assay only; the soup's interpreter is untouched):
- A tape of live length L is read as ⌈L/G⌉ **genes**: the segments at offsets 0, G, 2G, …, the last one zero-padded
  to G bytes. **G = 32.**
- Each gene runs **alone, as a G-byte tape**, on a fresh 2G-byte buffer (its bytes, then zeros, the four inputs on the
  buffer's last four bytes, as the engine places them), with its **own emit budget of 16** and its **own step budget of
  4 096**. A gene holding no emit byte is not run. The refusals are the assay's.
- A tape's functions on a case draw are the **union** of its genes' functions; its classes are their
  input-permutation classes. The predation pass reads that union on its own draw; the census reads, per gene, the
  classes credited on all six fixed sets, and takes their union (so a function that different genes credit on
  different sets is not credited, where an intersection over the whole tape would credit it; not counted here).
- Gene results are memoised by (draw, gene bytes), so a tape whose genes are unchanged is not re-run.

**Why G = 32.** At descent every tape is 32 bytes, so the genes machine starts as exactly the fixed-channel machine of
§4–§8 (one gene, 16 emits, a 64-byte buffer): the census at descent is
identical to pilot 4's in all 38 function-side columns. And
every computing core found so far fits in one gene: §7's 11-byte loop, §8's A solvers (18–24 load-bearing bytes on 32),
pilot 4's 21–29-byte cores. A smaller G (16) would cut those cores; a larger one changes nothing a gene can do with 16
emits except give it a larger buffer, and halves the number of genes the cap allows (16 at 512 with G = 32).

**Why each gene's buffer holds only its own segment.** The alternative, the whole tape run from offset kG on the whole
2L buffer, does not make a gene independent: a run from offset kG falls through into every later segment's code once
its own ends (or its loop exits), reads and writes the whole buffer, and finds the inputs at 2L − 1, so what entry k
computes depends on every later segment and on the tape's length; an edit to segment k + 1 changes entry k's orbit,
and appended junk moves the inputs. On a segment-only buffer, nothing outside segment k can reach gene k's run: a later
segment can neither read nor overwrite an earlier one's result, and an edit in one gene changes only that gene's
classes. That is the property the pilot tests. The price is that no gene can use another's result (no composition
between genes); additions are only side by side.

**The growable channel** is §9's at **cap 512**: live length 32 at descent (`own_tape`, nothing computing), a duplicate
of a random 1–16-byte segment appended at the end with probability 0.05 per inheritance, a random 1–16-byte segment
deleted with probability 0.05, floor 8; ×8 `meta_rate` substitutions over live bytes. A deletion before the last gene
shifts the frame of every later gene (they start at fixed offsets): the machine's frameshift.

**Gene duplication in Ohno's sense** (the optional arm, cheap enough to run): on top of that channel, with probability
**0.02** per inheritance the live tape is zero-padded to a multiple of G (which changes no gene: a partial last gene is
read zero-padded anyway) and a copy of one of its whole genes, uniformly chosen, is appended (cut at the cap); with
probability **0.02** one whole gene is removed, the later genes keeping their alignment (never below the floor). A copy
adds a gene that computes nothing new until it diverges.

**The census** (every 500 epochs, all 16 384 cells, the six fixed four-input sets) is §9's function side (silent share,
classes per cell, per computing cell p10/p50/p90, depth and classes held by a tenth and a hundredth, per-cell max depth
percentiles, length), plus the **gene census**:
- per cell, its genes, its **live genes** (computing at least one class), and its **essential genes**: its genes grouped
  by their class sets (copies with the same class set are one group), a group counted when it computes a class no other
  group of the tape computes. So a duplicate counts once, a diverged copy that adds a class counts again, and a gene
  whose classes another gene also computes counts nothing. The essential-gene count's p50 and p90 over computing cells,
  and **essential genes held by a tenth** (the largest k that a tenth of all cells reach);
- the **gene pool**: the number of distinct essential-gene class sets carried by a tenth and by a hundredth of the cells.

**The solver reading** (every 500 epochs, three tapes: §7's dominant deepest solver, §9's top-repertoire solver, and the
**top-genes solver**, the commonest tape among the computing cells whose essential genes reach the computing cells'
90th percentile): count-bearing bytes (`nbc`, at least 7 of 13 substitutions leave the tape fewer classes) and
depth-bearing bytes (`nbd`), on the whole tape; the **load-bearing genes** (`bseg`, genes holding a count-bearing byte)
and their **distinct bodies** (`bbod`, distinct cores, a gene's core being its bytes from its first bearing byte to its
last, so two copies that differ only in junk count once); per gene its classes, its unique classes, its bearing bytes
and its core. An exact duplicate is not load-bearing by substitution (the other copy covers it), so `bseg` counts genes
that each add something; the essential count reads the same thing by class sets, cell by cell.

**Checks** (offline, `pilot5_bin genes`): §7's `<<<<[!{~!~]` alone reads 12 classes, as on the fixed 32-byte channel;
two copies of it at offsets 0 and 32 read 12 classes, one essential gene, no load-bearing gene (each covers the other);
it beside §7.3's tandem variant `<<<<[!{~!{~!~]` reads **26** classes (12 + 16 − 2 shared), two essential genes, two
load-bearing genes with 11 and 14 bearing bytes, in either order. Under §7's subset rule that pair is the superset the
single-loop machine could never reach: the variant's classes are added, not swapped.

### 10.2 Honesty: what genes import, and what they do not

**No objective.** The change is to the machine, in how the assay runs a tape: from fixed offsets, each run alone, with
the same budgets and the same refusals for every gene of every tape. It reads no output to decide anything, names no
function, class or depth, and pays nothing: no rule says which computations a gene should make, or that a tape should
have more genes. The interaction rules are untouched. Both tests of §5.1 clause 2 still pass:
- *Relabelling.* Permute the functions any way: the union of the genes' permuted sets is the permutation of the union,
  so sizes (out-count) and containment between two cells (subset) are unchanged, and so are the dynamics.
- *Relational.* In a monoculture of any genotype every cell computes the same union, so no encounter moves energy,
  whatever that union is.

**What it does import (machine, S and C in §2's terms).**
1. **A fixed gene length, G = 32**: boundaries the organisms do not place. A marker-defined entry (a byte the tape
   itself places, as a promoter) would remove it, at a cost in simplicity.
2. **Independence by construction.** Each gene sees the environment on its own buffer, and no gene can read another's
   result. The machine forbids interference between genes, which is the property being tested, and also forbids
   composition between them (one gene's output as another's input).
3. **Union as the phenotype.** A tape computes whatever any of its genes computes; a gene can add classes and can never
   remove another gene's. Additions are therefore reachable without loss by construction. That is a design choice that
   favours accumulation; it is not an objective (it does not say which additions), but a rise read on this machine is a
   rise on a machine built so that additions are free to keep.
4. **A budget that grows with the number of genes**: each gene has its own 16 emits and 4 096 steps, so total budget
   scales with length in steps of G. Length buys budget only through a gene's own code: junk appended to a loop is in
   another gene and never runs with it.
5. **Frameshift**: a deletion inside the tape moves every later gene's frame, a cost of fixed offsets the organisms
   cannot avoid except by holding their genes early.
6. The Ohno arm's operator knows G: gene-aligned duplication and deletion import the gene length into variation too.

In the label's terms, the genes arms "import a machine, not an objective", as every out-compute arm already does.

### 10.3 Arms, horizons, cost

From 4381 and 4428 at their epoch 20 000 (`own_tape`, nothing computing at descent; §4.2's bundle; ×8 `meta_rate`,
`transfer` 8 192, `loss` 0.5, the asynchronous pass every 8 epochs on average), the genes machine (G = 32, 16 emits and
4 096 steps per gene) and §10.1's channel at cap 512:

| arm | rule | channel | horizon past descent | CPU (4381, 4428) |
|---|---|---|---|---|
| **count-genes** | out-count (strict) on the union | 1–16-byte dup/del | **20 000** (planned 30 000) | 48, 53 min |
| **subset-genes** | subset over classes on the union | the same | **15 000** | 18, 19 min |
| **drift-genes** | none | the same | **25 000** | 6, 8 min |
| **count-Ohno** | out-count | the same, plus whole-gene dup and del at 0.02 | **10 000** | 25, 27 min |
| **drift-Ohno** | none | as count-Ohno | 17 500 and 15 500, read at **15 000** | 5, 5 min |

About **3.6 CPU-hours** in all at `nice 19` (runs 3.58, calibration and offline reads under 0.1), the Mac's load average
between 4 and 116. The horizons were cut to stay inside the budget: at the cap count-genes costs about **4 CPU-minutes per
1 000 epochs** here (about 0.6 of A+B@512's 7, §9.4), and the Ohno arms as much at fewer epochs. They are short of §5.1
clause 6 for every arm. Census every 500 epochs; the three solvers read every 500 epochs.

### 10.4 Results: the function side

Medians of 5 000-epoch blocks past descent: depth held by a tenth · classes per cell (mean over all cells) · classes held
by a tenth · **essential genes held by a tenth** · live genes per computing cell · genes per computing cell · mean length.

| k epochs | 4381 count-genes | 4428 count-genes | 4381 subset-genes | 4428 subset-genes | 4381 count-Ohno | 4428 count-Ohno |
|---|---|---|---|---|---|---|
| 0–5 | 5 · 6.0 · 11 · 2 · 1.6 · 4.1 · 115 | 6 · 6.7 · 17 · 2 · 1.8 · 5.7 · 164 | 6 · 6.1 · 13 · 1 · 1.4 · 3.2 · 87 | 4 · 4.1 · 10 · 1 · 1.5 · 4.2 · 120 | 6 · 8.0 · 21 · 2 · 3.0 · 12.4 · 386 | 5 · 6.1 · 14 · 2 · 2.4 · 10.2 · 313 |
| 5–10 | 5 · 8.0 · 16 · 2 · 2.5 · 10.1 · 308 | 7 · 10.7 · 21 · 3 · 3.1 · 13.0 · 402 | 7 · 7.0 · 16 · 1 · 1.6 · 5.8 · 170 | 6 · 6.6 · 14 · 1 · 1.6 · 6.4 · 187 | 8 · 11.8 · 22 · 3 · 3.3 · 14.9 · 464 | 7 · 8.5 · 19 · 2 · 3.0 · 14.8 · 463 |
| 10–15 | 6 · 9.4 · 21 · 2 · 3.2 · 14.8 · 458 | 7 · 11.1 · 21 · 3 · 3.3 · 15.8 · 496 | 7 · 7.2 · 20 · 2 · 1.8 · 7.7 · 229 | 6 · 6.6 · 14 · 1 · 1.7 · 7.6 · 226 | | |
| 15–20 | 6 · 9.5 · 22 · 2 · 3.2 · 14.9 · 462 | 7 · 10.8 · 20 · 3 · 3.3 · 15.9 · 499 | | | | |

Both drift arms hold ECHO alone by a tenth (one class, depth 0, one essential gene) from start to end; their live genes
per computing cell go 1.1 → 1.3 while their genes go 2.3 → 5.8 and their mean length 44 → 112 and 48 → 142 (25 000).
Drift-Ohno, with 13–14 genes per tape from 10 000 epochs, comes to hold a second class (a one-NAND class) and depth 1 by
a tenth at 10 500 and 12 500 epochs: with many junk genes per tape, a shallow class is held by lottery.

**The last census** (each arm at its horizon); per-cell max depth over computing cells, essential genes over computing
cells:

| world | arm | silent | max depth p10 / p25 / p50 / p75 / p90 / max | classes per computing cell p10 / p50 / p90 / max (mean, all cells) | depth held 10% / 1% | classes held 10% / 1% | essential genes mean / p50 / p90 / held 10% / max | live / genes per cell | gene pool 10% / 1% | length p10 / p50 / p90 | replicator share · eat rate |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 4381 | count-genes (20 k) | 0.00 | 1 / 3 / 5 / 6 / 6 / 8 | 2 / 9 / 17 / 23 (9.4) | 6 / 7 | 19 / 40 | 1.70 / 2 / 2 / 2 / 4 | 3.2 / 14.9 | 2 / 24 | 404 / 472 / 510 | 0.79 · 0.46 |
| 4428 | count-genes (20 k) | 0.01 | 1 / 3 / 7 / 7 / 7 / 9 | 2 / 15 / 18 / 22 (10.8) | 7 / 8 | 19 / 37 | 1.95 / 2 / 3 / 3 / 4 | 3.2 / 15.8 | 3 / 18 | 471 / 501 / 512 | 0.80 · 0.44 |
| 4381 | subset-genes (15 k) | 0.02 | 1 / 2 / 4 / 6 / 7 / 8 | 2 / 6 / 12 / 15 (6.8) | 6 / 7 | 18 / 30 | 1.18 / 1 / 2 / 2 / 4 | 1.9 / 8.0 | 2 / 16 | 151 / 234 / 347 | 0.86 · 0.32 |
| 4428 | subset-genes (15 k) | 0.03 | 1 / 3 / 4 / 6 / 7 / 7 | 1 / 6 / 12 / 13 (6.6) | 6 / 7 | 14 / 32 | 1.10 / 1 / 2 / 1 / 3 | 1.8 / 8.0 | 2 / 20 | 129 / 221 / 376 | 0.80 · 0.31 |
| 4381 | count-Ohno (10 k) | 0.01 | 1 / 4 / 7 / 8 / 8 / 9 | 2 / 14 / 22 / 25 (12.4) | 8 / 8 | 26 / 50 | 1.86 / 2 / 3 / 3 / 4 | 3.2 / 14.9 | 4 / 24 | 402 / 474 / 512 | 0.77 · 0.46 |
| 4428 | count-Ohno (10 k) | 0.01 | 1 / 2 / 4 / 7 / 7 / 8 | 2 / 8 / 19 / 19 (9.7) | 7 / 7 | 19 / 24 | 1.68 / 2 / 2 / 2 / 4 | 3.1 / 14.7 | 4 / 11 | 393 / 471 / 512 | 0.78 · 0.44 |
| 4381 | drift-genes (25 k) | 0.66 | 0 / 0 / 0 / 0 / 1 / 6 | 1 / 1 / 1 / 4 (0.37) | 0 / 1 | 1 / 2 | 1.03 / 1 / 1 / 1 / 2 | 1.4 / 5.7 | 1 / 3 | 21 / 90 / 239 | 0.85 · — |
| 4428 | drift-genes (25 k) | 0.61 | 0 / 0 / 0 / 0 / 1 / 4 | 1 / 1 / 1 / 5 (0.42) | 0 / 1 | 1 / 2 | 1.03 / 1 / 1 / 1 / 2 | 1.3 / 5.8 | 1 / 3 | 44 / 129 / 250 | 0.88 · — |
| 4381 | drift-Ohno (15 k) | 0.22 | 0 / 0 / 0 / 0 / 1 / 4 | 1 / 1 / 2 / 5 (0.93) | 1 / 1 | 2 / 3 | 1.09 / 1 / 1 / 1 / 3 | 2.0 / 14.0 | 1 / 5 | 315 / 447 / 511 | 0.79 · — |
| 4428 | drift-Ohno (15 k) | 0.22 | 0 / 0 / 0 / 0 / 1 / 5 | 1 / 1 / 2 / 6 (0.90) | 1 / 1 | 2 / 3 | 1.07 / 1 / 1 / 1 / 3 | 2.0 / 13.7 | 1 / 4 | 252 / 446 / 510 | 0.85 · — |

- **The level sits between the one-gene machine and the length-scaled budget.** Count-genes holds 19–22 classes by a
  tenth and depth 6–7, with 9.4–10.8 classes per cell, against A's 15 and 11 classes, depth 7 and 5 and 8.1 and 5.9 per
  cell on the fixed 32-byte channel (§8, same seed), and against A+B's 54–63 at a cap of 128 and 174–220 at 512 (§8–§9).
  The route by which length bought repertoire is gone, as designed: a gene's budget does not grow with the tape.
- **It is reached early and stands.** Classes held by a tenth make their last persistent new maximum at 16 000 (4381, 22,
  then back to 19) and 8 000 (4428, 21), and the last decile reads 19 in both against bars of 21.
- **Subset-genes holds less**: 14–18 classes by a tenth, one essential gene by a tenth in 4428 and two from 11 500 in
  4381, and its top solvers are one gene in every late reading.
- **The minimum stands**: under count-genes the 10th percentile of per-cell max depth is 1 from 4 500–5 000 epochs and of
  classes per computing cell 2 from 5 500–8 000, to the end (§9: 1–2); under subset 1 and 1–2.
- **Under drift the genes machine wakes more cells than the one-run assay**: 61–66% silent at 25 000 (86–89% in §7–§9),
  and 22% under drift-Ohno, because each junk gene is a fresh draw for an ECHO.

### 10.5 Results: the genes

**How many genes compute, and how many count.** Under count-genes a computing cell carries 15–16 genes at the end, of
which 3.2 compute anything and 1.7–2.0 are essential; a tenth of all cells carries at least 2 (4381) or 3 (4428)
essential genes. The essential count reached 2 by 4 500 epochs (4381) and 3 by 8 000 (4428) and stood for the remaining
15 500 and 12 000 epochs, while the genes per cell went on growing to 15–16 (the cap, reached by 12 500). The ratio of
essential genes to genes falls from about a third at 2 500 epochs to 0.11–0.12: **gene count does not track length; it
stops while length goes on.**

**The top solvers** (every 500 epochs; load-bearing genes · distinct bodies · count-bearing bytes · classes), medians of
2 500-epoch blocks:

| k epochs | 4381 count-genes | 4428 count-genes | 4381 subset-genes | 4428 subset-genes | 4381 count-Ohno | 4428 count-Ohno |
|---|---|---|---|---|---|---|
| 0–2.5 | 1 · 1 · 16 · 8 | 1 · 1 · 20 · 9 | 1 · 1 · 14 · 10 | 1 · 1 · 16 · 7 | 2 · 2 · 29 · 12 | 1 · 1 · 20 · 7 |
| 2.5–5 | 2 · 2 · 28 · 10 | 1 · 1 · 22 · 16 | 1 · 1 · 13 · 12 | 1 · 1 · 11 · 12 | 3 · 3 · 30 · 18 | 1 · 1 · 20 · 12 |
| 5–7.5 | 2 · 2 · 29 · 12 | 2 · 2 · 27 · 18 | 1 · 1 · 12 · 12 | 1 · 1 · 11 · 12 | 2 · 2 · 30 · 20 | 2 · 2 · 25 · 16 |
| 7.5–10 | 2 · 2 · 29 · 17 | 2 · 2 · 26 · 18 | 1 · 1 · 11 · 12 | 1 · 1 · 11 · 12 | 2 · 2 · 29 · 22 | 2 · 2 · 29 · 19 |
| 10–15 | 2 · 2 · 29 · 17 | 2 · 2 · 27 · 20 | 1 · 1 · 11 · 12 | 1 · 1 · 11 · 12 | | |
| 15–20 | 2 · 2 · 29 · 17 | 2 · 2 · 29–30 · 21 | | | | |

- **Genes compose side by side: the first composition in this study.** From 5 000–7 500 epochs the top solvers of every
  count arm hold two load-bearing genes (block medians), every top and genes-solver reading from 10 000 on holds two or three
  (4381: two in 33 of 34, three in one; 4428: two in 21 of 32, three in 11), and in all 843 solver readings of the pilot no two
  load-bearing genes share a core (distinct bodies = load-bearing genes, every time). Late (10 000–20 000), in 66 top and
  genes-solver readings of count-genes, a second load-bearing gene computes at least 4 classes in 45. 4381's final top
  solver (17 classes) is two loops in genes 0 and 1, `{,,[~[<]0>!~!_~{]` (8 classes) and `<{<~!.<[~!~{]` (12), sharing
  3; 4428's (21 classes) is `<<<<[~{!_>~<>!.]` (14 classes, depth 7) in gene 1, a 6-class gene 9 (`00ee`, `00ff`, `0aff`,
  `aaaf`, `aaee`, `aaff`, depths 1–5) and ECHO in two copies (genes 2 and 3). Under subset every late top solver is one
  12-class loop of 10–12 bearing bytes (`<<<<[{~!~]` in 4428), and its second genes, where they exist, are satellites.
- **The extra genes are new code, not copies.** Against the largest gene of the same reading, no other load-bearing
  gene shares a run of 8 or more instruction bytes in count-genes (78 pairs over 66 late readings) and one does in
  count-Ohno (1 of 39 pairs): they arose in a fresh segment from appended fragments and substitution, not by duplication
  and divergence of the main loop. The small ones are **satellites**, mostly a 2–6-byte emit (`<!`, `<{!`, `{<~!`,
  `.<~!`) that adds ECHO or a one-NAND class (`00ff`) the main loop does not emit. Of the 15–16 genes a tape carries,
  about 12 compute nothing and most of the rest repeat a class another gene has.
- **Ohno's duplication changes little at 10 000 epochs.** Over 5 000–10 000 epochs count-Ohno holds 3 and 2 essential
  genes by a tenth and 22 and 19 classes, against count-genes' 2 and 3, and 16 and 21. The one diverged paralog pair seen
  is in 4381's last reading (10 000): `<<<<{0[~{!_~0~~{!]` and `<<<<{0[~{!_~0!~{!]`, one byte apart, in genes 1 and 14,
  computing 10 and 16 classes with 3 shared (24 together), both load-bearing; the horizon ended there.
- **The load-bearing code totals about the same as on the one-loop machines.** The count-genes top solvers carry 28–32
  (4381) and 22–33 (4428) count-bearing bytes late, split over two or three genes (the main gene 13–16, the second
  6–19), against 20–29 count-bearing bytes in one loop under A+B@512 (§9.7–§9.8) and 18–27 depth-bearing bytes under A
  and A+B@128 (§8). Splitting the code into genes did not let the worlds hold much more of it. Under subset the one loop
  holds 10–12.
- **The per-gene budget binds little**: zero-padded to 32 bytes and run at 64 emits instead of 16, 4428's main gene and
  4381's two genes compute 14, 13 and 8 classes against 14, 12 and 8; only the Ohno paralog's orbit runs on (24 against
  16).

### 10.6 The rise rule and §5.4

§9.8's rule unchanged; bar → last-decile median (✓ = rises by at least one), and the number of persistent new maxima
(k = 5) with the date of the last (k epochs past descent); "§5.4" where at least three fall with the last in the final
quarter. §5.1 clause 4 needs both.

| world | arm (horizon) | essential genes held 10% | load-bearing genes, top solver (= distinct bodies) | count-bearing bytes, top solver | classes held 10% | depth held 10% | minimum: max depth p10 · classes p10 | length |
|---|---|---|---|---|---|---|---|---|
| 4381 | count-genes (20 k) | 2 → 2; 2 maxima, last 4.5 | 2 → 2; last 6.0 | 28 → 29 ✓; last 13.0 | 21 → 19; 12 maxima, last 16.0 (§5.4 count) | 6 → 6; last 11.5 | 1 → 1 · 2 → 2 | 380 → 462 ✓; last 14.5 |
| 4428 | count-genes (20 k) | 3 → 3; 3 maxima, last 8.0 | 2 → 2; last 7.0 | 26 → 29 ✓; last 19.0 (§5.4 count) | 21 → 19; last 8.0 | 7 → 7; last 5.5 | 1 → 1 · 2 → 2 | 480 → 496 ✓; last 15.5 (§5.4 count) |
| 4381 | subset-genes (15 k) | 1 → 2 ✓; 2 maxima, last 11.5 | 1 → 1 | 13 → 11 | 18 → 18; last 13.0 (§5.4 count) | 7 → 7; last 6.0 | 1 → 1 · 1 → 2 ✓ | 173 → 238 ✓ (§5.4 count) |
| 4428 | subset-genes (15 k) | 1 → 1 | 1 → 1 | 15 → 11 | 15 → 14; last 6.0 | 6 → 6; last 6.0 | 1 → 1 · 2 → 1 | 187 → 236 ✓ (§5.4 count) |
| 4381 | count-Ohno (10 k) | 3 → 3; last 6.5 | 2 → 2; last 3.5 | 30 → 28 | 22 → 25 ✓; last 5.0 | 8 → 8; last 5.0 | 1 → 1 · 2 → 2 | 470 → 459 |
| 4428 | count-Ohno (10 k) | 2 → 2; last 2.5 | 2 → 2; last 10.0 (2 maxima) | 25 → 29 ✓; last 10.0 (§5.4 count) | 15 → 19 ✓; last 8.0 (§5.4 count) | 6 → 7 ✓; last 7.5 (§5.4 count) | 1 → 1 · 1 → 1 | 463 → 455 |
| both | drift-genes (25 k) | 1 → 1 | 1 → 1 | 2 → 2 | 1 → 1 | 0 → 0 | 0 → 0 · 1 → 1 | 92 → 111 ✓, 102 → 142 ✓ (§5.4 count, both) |
| both | drift-Ohno (15 k) | 1 → 1 | 1–2 → 1 | 8 → 5, 6 → 7 | 1 → 2 ✓ (last 10.5, 12.5) | 0 → 1 ✓ | 0 → 0 · 1 → 1 | 376 → 423 ✓, 318 → 405 ✓ (§5.4 count) |

- **The number of distinct load-bearing genes does not rise late anywhere.** Essential genes held by a tenth: flat at 2
  and 3 under count-genes from 4 500 and 8 000 epochs, the last new maximum in the first half; the top solver's
  load-bearing genes flat at 2 from 6 000–7 000. Subset-genes 4381 steps 1 → 2 at 11 500 (the rule reads +1, two maxima,
  §5.4 fails). No arm passes both the rule and §5.4 on genes.
- **Classes held do not rise late either**: the last decile is below the bar in both count-genes worlds; 4381's §5.4
  count comes from a series that held 22 from 16 000 and fell back to 19. 4428's count-Ohno passes on classes held
  (15 → 19) and depth (6 → 7) at its 10 000-epoch horizon with its gene count flat at 2: a climb still going at a horizon
  too short to call late (§5.1 clause 6), carried by the same two genes.
- **What rises late is length, and in 4428 the code inside the same two genes**: 4428's top solver's count-bearing bytes
  go 26 → 29 by edits of its two genes (§5.4 count at 19 000), with its load-bearing genes flat at 2, its classes up by
  one (20 → 21) and its length at the cap; drift's length passes in both worlds, as in §7–§9.
- **The minimum** steps once in each count world before the second half and stands; McShea's test reads no driven trend.

### 10.7 What pilot 5 says

1. **Genes compose, side by side, and stop at two or three.** On a machine whose genes cannot interfere, out-count
   assembles tapes of two (4381) or two to three (4428) load-bearing genes with distinct bodies: a main loop of 12–14
   classes, a second computation of 4–12 classes or a satellite emit that adds ECHO or a one-NAND class. It is the first
   time in this study that two independently originated computations are held together (§9 found one loop in 154
   readings). They are new code, not diverged copies. Then nothing more: the essential-gene count reached its top by
   4 500 and 8 000 epochs and stood for 12 000–15 500 epochs while the tapes filled the cap with 15–16 genes, 12 of them
   silent.
2. **Junk length buys almost nothing, as designed.** The level falls from A+B's 54–220 classes held to 19–22, four to
   ten classes above the one-gene machine A (15 and 11). The exception is the lottery: with 14 junk genes a tape, drift comes to
   hold a one-NAND class by a tenth.
3. **No rise in §5's sense on either side.** Essential genes, load-bearing genes, classes held and depth held all fail
   the rule or §5.4 in every arm; length rises under drift too. The minimum stands at 1 (depth) and 2 (classes).
4. **Gene duplication in Ohno's sense does not change this at 10 000 epochs**; one diverged paralog pair appeared and
   was not held.
5. **The total load-bearing code is about the same on every out-count machine of pilots 3–5** (18–33 bytes: depth-bearing
   in §8, count-bearing in §9 and here), whether it sits in one loop or is split over genes. A lead, not a finding (two worlds, one seed): what stops the
   climb may be the mutation load on the computing channel at ×8 (about 0.01 per byte per generation, so 0.15–0.3 hits per
   generation on 28 bearing bytes), not the machine's composability. Pilot 4 removed the length route and found one loop;
   pilot 5 removes the interference route and finds the same amount of code in two or three pieces.

### 10.8 Recommendation

**Do not engineer genes into the engine for a rise sweep.** On these two worlds the predicted reading is "two or three
genes by 8 000 epochs, then flat", at about 0.6 times A+B@512's cost per epoch.

**The sweep after out-compute stays §9.10's level sweep at cap 128** (count-grow, subset-grow, shadow-grow at 0.45,
drift-grow; seed 6101; 30 000 epochs; 54 parents; keys H-level, H-driven, H-count, H-code, H-rise as written there).
**Genes may join it as two level arms**, worth the engine slice only for that, since it is the one machine on which the
program side composes:
- **Engine slice**: `meta_genes: 32` (0 = off): the topless assay of the metabolism tape runs each G-aligned segment
  alone on its own 2G buffer, with `task_max_outputs: 16` and `TASK_STEPS` per gene, and credits the union; refused
  without the growable metabolism tape and a predation rule or `predation: off`. Observables: the essential-gene census of
  §10.1 (per cell; held by a tenth) on the sampled cells; offline the top solver's load-bearing genes and distinct bodies.
- **Arms**: **count-genes** (`predation: count`, `meta_genes: 32`, `meta_max_len: 256` (8 genes; the worlds used 3 live),
  `task_max_outputs: 16` fixed, §9.10's dup/del 0.05, segments 1–16, floor 8) and **drift-genes** (`predation: off`, the
  same channel and assay). Same parents, seed and horizon.
- **Keys**: *H-compose* (count-genes against drift-genes): the **essential genes held by a tenth**, last-decile median,
  predicted **shown** (2–3 against 1). *H-compose-code* (count-genes against count-grow): the number of independent
  computations in the top solver (load-bearing genes under genes; contributing top-level loops, §9.2, under count-grow),
  predicted **shown** (2 against 1). *H-rise-genes* (count-genes against drift-genes): the rise rule and §5.4 on essential
  genes held by a tenth, with length beside it, predicted **refuted**. Read apart: classes held by a tenth (predicted
  below count-grow's), the count-bearing bytes of the top solver (predicted equal to count-grow's), the minimum.
- **Cost**: count-genes at 256 about 2 CPU-minutes per 1 000 epochs on this loaded Mac, about 1.3 times count-grow at 128
  (§8.1); drift-genes about a sixth of that. The two arms add about 40% to §9.10's sweep.

**Before any rise sweep, one more pilot (pilot 6): the mutation load.** Five pilots have changed the rule, the channel,
the budget and the machine, and the code selection holds has stayed at 18–33 bytes. Count-genes at `meta_rate` 4/8192
and 2/8192 (×4, ×2) against ×8, each with its drift-genes, on both worlds, 30 000 epochs or more (a lower rate also
slows the climb), on the mini-pc: read the top solver's count-bearing bytes and the essential genes held by a tenth.
If both rise as the rate falls, roughly inversely, the plateau is a mutation–selection balance on the computing channel
and the next lever is fidelity (the rate, or heredity the tapes can improve), not the machine; if they do not, the
machine's composability remains the bet and a marker-defined gene boundary is the next machine pilot.

**Not done.** One seed per arm and world; no shadow arm; count-genes cut to 20 000 epochs, subset-genes to 15 000 and
the Ohno arms to 10 000; G fixed at 32, no marker-defined entries; one Ohno rate (0.02); no lower-rate probe.

**Files.** Pilot 5's material was pilot artefacts and was not kept: the throwaway engine copy (the gene length, the
gene cut, the per-gene assay and its memo, gene duplication and deletion, the gene census and solver readings) and its
`pilot5_bin` binary (the arms of `pilot4b_bin` plus the genes machine, and the offline gene reading of a tape), every
census row of every pilot-5 run (with the commonest tapes and the deepest, top and gene solver readings), the scripts
behind the readings above (`analyze5.py`, `tables5.py`) and §10.5's offline reads (`copies.py`, `kinds.py`: per-gene
classes, kinship by shared instruction bytes) with their outputs, the launch and stopper scripts, targets and log, and
the section drafts.

## 11. Pilot 6: the mutation load

2026-10-03, all *pilot*: a throwaway copy of pilot 5's engine (itself `origin/main`, `b30196a`) in a session scratchpad, not kept,
one seed (5002, pilots 2–5's) per arm and world. A pilot, not a sample. Nothing in the repository or the lab was
touched. It tests §10.7's lead: across every rule, channel, budget and machine of pilots 3–5 the load-bearing code
stayed at 18–33 bytes. If that is Eigen's error threshold on the computing channel, the code held should rise as the
metabolism tape's mutation rate falls, roughly as its inverse.

### 11.1 The expected scaling, computed first

**The threshold.** A master of L sites copied with error μ per site per generation, with selective superiority σ
over its mutant cloud, is kept only while σ(1 − μ)^L > 1, so L < L_max ≈ ln σ / μ. Read on this channel:
- **μ** is `meta_rate` × T_gen. Substitutions hit every live byte every epoch (one isa draw over 14 symbols, the byte
  itself among them), so a lineage collects them between inheritances. **T_gen**, the epochs per inheritance per cell
  (the census's `inherits`), is 10.5–10.6 in pilot 5's count-genes runs (late half) and 9.1 under drift. At ×8 that
  is 0.0103 per byte per generation.
- **L** is the class-losing target of the top solver, `sub`: summed over its bytes, the share of the 14 draws that
  leave the tape fewer classes (a new offline reader, `pilot6_offline load`). A count-bearing byte whose 13
  alternatives all lose a class counts 13/14.
- **Frameshift.** A deletion (0.05 per inheritance) that starts before a load-bearing gene's end shifts its frame. The
  reader measures the share of the channel's deletions that lose a class; U_frame = 0.05 × that share, independent of
  the rate. Appended duplications never lost a class in any reading.
- So the load per generation is **U = rate × T_gen × sub + U_frame**, the master survives while σe^(−U) > 1, and
  **L_max = (ln σ − U_frame) / (rate × T_gen)** in `sub` units.

**Pilot 5's ×8 solvers, read offline** (the top solver every 2 500 epochs, 5 000–20 000): `sub` **25.1–29.1** (count-bearing
bytes 26–32: in 4428's final solver 26 of its 28 bearing bytes lose a class on all 13 alternatives); U_frame 0.004–0.015
in 4381 (its two genes at the front) and 0.030–0.034 in 4428 (a load-bearing gene 9 behind 280 bytes of frame); **U =
0.27–0.33 per generation, 1/Q = e^U = 1.31–1.40**. U stayed in that band while the classes went from 10 to 21.

**σ, before measuring it.** A cell's births are its initiations, one per 8 192 energy, and its income is the influx
(1 024 an epoch) plus half of what it eats less what is eaten from it. A one-cell model of that economy
(`stocksim.py`: acts as predator w.p. 1/8 an epoch, robbed of min(stock, 8 192) when a neighbour that outranks it
picks it, about once in 8 epochs) gives a top cell that eats 50–90% of its picks 0.139–0.150 initiations an epoch,
and a cell one class below the top 0.122, 0.104, 0.087 or 0.071 when 30, 50, 70 or 90% of its neighbours outrank it:
**σ ≈ 1.14–2.10**, 1.6–2.1 inside a master's own patch.

**The prediction**, L_max in `sub` units (`prior6.py`; T_gen 10.55, U_frame 0.0175):

| σ | ×8 | ×4 | ×2 |
|---|---|---|---|
| 1.2 | 16 | 32 | 64 |
| 1.35 | 27 | 55 | 110 |
| 1.6 | 44 | 88 | 176 |
| 2.0 | 66 | 131 | 262 |

×8 holds 25–29. So if σ is near 1.35 the ×8 worlds sit at the threshold and the code held should double at ×4 and
quadruple at ×2 (less the frameshift share), with U staying near ln σ at every rate; if σ is near 2, ×8 holds well
under half its threshold, the plateau has another cause, and lowering the rate should change the level little and
only slow the climb.

### 11.2 What was built, arms, cost

- **The engine** is pilot 5's binary rebuilt with two passive additions (a session scratchpad, not kept; `pilot6_bin`):
  a **lineage tag** per cell that rides the metabolism tape through every inheritance, and the inheritances counted by
  the parent's tag. No draw reads it. **Replay check:** at ×8 it reproduces pilot 5's 4428 count-genes census and
  solver lines byte for byte (19 lines to 1 000 epochs), and at genes 0, `--emit-per-len 2`, cap 128 pilot 3's A+B.
- **The σ reading** (`#fit`, every 1 000 epochs, every 500 in the σ runs): each cell is tagged with its six-set class
  count; 16 epochs later the cells carrying each tag are counted, with the births each tag parented. The **top tier**
  (count ≥ the computing cells' p90) against the computing cells below it gives σ_birth (birth-rate ratio) and σ_net
  (net lineage growth per epoch, carried to a generation as exp(s·T_gen)); against the p75–p90 band, the nearest
  mutants.
- **The load reader** (`pilot6_offline load`, `load6.py`): `sub`, `del_lose`, `dup_lose` and U of a solver (§11.1).
- **Arms**, from 4381 and 4428 at their epoch 20 000, pilot 5's bundle, channel (cap 512, dup/del 0.05) and genes
  machine (G = 32, 16 emits, 4 096 steps per gene), seed 5002, `meta_rate` overridden: **count-genes** and
  **drift-genes** at **4/8192** and **2/8192**; **σ runs** at 8/8192 (count-genes with the census off, for `#fit`
  only); the **×8 reference** is pilot 5's count-genes (20 000) and drift-genes (25 000), which the binary replays.
  Census every 500 epochs, solver readings every 1 000 (pilot 5: 500).
- **Not run:** count-grow at ×2 (budget); the ×1 rate.
- **Cost and horizons.** The Mac's load average stood at 100–220 during the runs, so the processes got about two
  cores between them. **This section is read at 7 000–8 500 epochs past descent for the count arms** (4381 ×4 7 000,
  ×2 8 500; 4428 ×4 7 000, ×2 7 500), 25 000 for drift ×2 on 4381, and 4 500–5 500 for the σ runs, at about **75
  CPU-minutes** charged. The runs then went on under `stopper.sh` to **15 000** past descent (count), 25 000 (drift) and
  9 000 (σ), **2.8 CPU-hours** in all (count arms 21–26 CPU-minutes each, drift 7–10, σ 17–20); `analyze6.py`,
  `load6.py` and `final6.py` give the final readings, reported beside the first ones in §11.3–§11.7. The horizons are
  short of §5.1 clause 6 for every arm.

### 11.3 σ, measured

`#fit` medians over the readings from 2 500 epochs on (5–8 readings each):

| world | rate | σ_birth | σ_net | σ_net against the p75–p90 band |
|---|---|---|---|---|
| 4381 | ×8 | 1.48 | 1.26 | 1.08 |
| 4381 | ×4 | 1.64 | 1.34 | 1.11 |
| 4381 | ×2 | 1.62 | 1.34 | 1.09 |
| 4428 | ×8 | 1.70 | 1.36 | 1.15 |
| 4428 | ×4 | 1.50 | 1.25 | 1.03 |
| 4428 | ×2 | 1.60 | 1.34 | 1.09 |
| 4381 | drift ×2 | 0.94–1.03 | 0.97–1.02 | — |

(means of the readings; single readings range 1.06–1.40 for σ_net.) The top tier's lineages out-grow the computing
cells below them by **σ ≈ 1.25–1.36 per generation**, the same at every rate; under drift the reading is 1.0, so it
reads selection, not the tagging. Top cells also die faster (they sit in dense, fast-copying patches), which is why
σ_net is below σ_birth. At ×8, **σ ≈ 1/Q (1.31–1.40)**: the reference worlds sit at Eigen's threshold. With
σ = 1.3, §11.1's L_max is (0.262 − U_frame)/(rate·T_gen): **24 at ×8, about 48 at ×4, about 84 at ×2** (U_frame 0.0175,
0.025 and 0.038 as measured at each rate; T_gen 10.6, 10.5 and 11.3).

**Final readings** (13 `#fit` readings from 2 500 to 15 000 in each count run, 14 to 9 000 in the σ runs; medians):
σ_net 1.28 and 1.34 at ×8 (4381, 4428), 1.37 and 1.35 at ×4, 1.33 and 1.35 at ×2; σ_birth 1.52–1.71; drift ×2 0.98.
The band holds at every rate to the end.

### 11.4 Results: held code and the function side, by rate

At matched horizons (×8 from pilot 5 at the same epochs; last readings, 2 500-epoch medians where they exist):

| | ×8 4381 | ×4 4381 | ×2 4381 | ×8 4428 | ×4 4428 | ×2 4428 |
|---|---|---|---|---|---|---|
| epochs read | 7 500 (20 000) | 7 000 | 8 500 | 7 500 (20 000) | 7 000 | 7 500 |
| **count-bearing bytes, top solver** | 29 (28–29) | 54–69 | 74–100 (92 last) | 26–30 (28–29) | 46–54 | 64–92 (92 last) |
| **`sub`, top solver** | 25.8–26.6 | 51–55 | 77–79 | 25.4–28.1 | 39–49 | 77 |
| **U per generation** | 0.27–0.29 | 0.30–0.32 | 0.25 | 0.29–0.30 | 0.22–0.27 | 0.25 |
| load-bearing genes (= distinct bodies) | 2 | 3 | 4 | 2 | 2–3 | 4 |
| essential genes held by a tenth | 2 | 3 | 4 | 3 | 3 | 5 |
| classes held by a tenth | 12–21 (19) | 20 | 38 | 18–25 (19) | 24 | 54 |
| classes per computing cell p90 | 14–17 | 17–19 | 29–30 | 15–18 | 23–24 | 44–47 |
| depth held by a tenth | 6 | 6 | 8 | 7 | 8 | 9 |
| **minimum**: max depth p10 · classes p10 | 1 · 2 | 4 · 6 | 7 · 12 | 1 · 2 | 3 · 4 | 9 · 20 |
| mean length | 440 | 264 | 440 | 400 | 279 | 429 |

**At 15 000 epochs** (the rise rule's last-decile medians, 13 500–15 000; `sub` and U from the top solver every 1 000
epochs, 9 000–15 000; ×8 from pilot 5 read to 15 000, its `sub` and U from §11.1):

| | ×8 4381 | ×4 4381 | ×2 4381 | ×8 4428 | ×4 4428 | ×2 4428 |
|---|---|---|---|---|---|---|
| **count-bearing bytes, top solver** | 29 | 62 | 102 | 26 | 59 | 98 |
| **`sub`, top solver** | 25–29 | 49–52 | 79–94 | 25–29 | 49–53 | 84–92 |
| **U per generation** | 0.27–0.33 | 0.26–0.28 | 0.25–0.30 | 0.27–0.33 | 0.26–0.28 | 0.27–0.29 |
| load-bearing genes | 2 | 3 | 5 | 2 | 3 | 5 |
| essential genes held by a tenth | 2 | 3 | 5 | 3 | 3 | 5 |
| classes held by a tenth | 22 | 25 | 37 | 21 | 27 | 62 |
| classes per computing cell p90 | 17 | 20 | 35 | 20 | 27 | 56 |
| depth held by a tenth | 6 | 8 | 8 | 7 | 8 | 9 |
| **minimum**: max depth p10 · classes p10 | 1 · 2 | 5 · 7 | 7 · 15 | 1 · 2 | 6 · 8 | 7 · 26 |
| mean length | 460 | 450 | 507 | 499 | 464 | 505 |

The scaling holds to the end: `sub` 1 : 1.9 : 3.3 at ×8, ×4, ×2 (against 1 : 2 : 4), U 0.25–0.30 at every rate. The
only late change in held code is a fifth load-bearing gene at ×2 (4381 at 14 000, `sub` 79 → 88–94; 4428 at 12 000).

Drift at ×4 and ×2 holds ECHO alone by a tenth (one class, depth 0, one essential gene) to 21 000–25 000 epochs, as at
×8; its lengths are the same trajectory at every rate (without predation the meta tape never feeds back).

- **Held code rises as the rate falls, close to inversely.** Count-bearing bytes 28–29 → 48–69 → 74–100 and `sub` 26 →
  39–55 → 77–79 at ×8, ×4, ×2: ratios about 1 : 1.8 : 3.0 against the 1 : 2 : 4 of a pure 1/μ, and within 10–25% of
  L_max computed from the measured σ, rates, T_gen and frameshift (24, 48, 84). What holds still is the load: **U =
  0.22–0.32 per generation at every rate**, ≈ ln σ. The frameshift share, which does not fall with the rate, takes
  0.035–0.04 of U at ×2 (15%), which is why ×2 falls short of 4×.
- **The code held at lower rates is more genes, not longer loops.** ×2's top solvers carry four load-bearing genes with
  four distinct bodies, 16–29 bearing bytes each (×8: two, ×4: two or three). In 4428 the four share motifs
  (`[_{_!~{~_}~_]`, `[_{_!~_~{!~_]`, `[[{_!~!~{!~_]`) and may be diverged paralogs; kinship was not read.
- **The function side moves with it.** Classes held by a tenth 19 → 20–24 → 38–54; the top cells' repertoire 17–18 →
  19–24 → 29–47; essential genes held by a tenth 2–3 → 3 → 4–5; depth by a tenth 6–7 → 6–8 → 8–9.
- **McShea's minimum moves for the first time.** The 10th percentile of per-cell max depth, 1 at ×8 in every pilot,
  is 3–4 at ×4 and 7–9 at ×2; of classes per computing cell 2 → 4–6 → 12–20. The bottom of the distribution was the
  mutational cloud: with U ≈ 0.27 a generation and a cell living about T_gen epochs, a fifth to a quarter of the cells
  carry a fresh class-losing hit at any census, and at ×8 that cloud fell all the way to ECHO.

### 11.5 Time to plateau

Lower fidelity did not make the climb faster, and higher fidelity did not make it slower. At matched epochs the ×2
worlds are ahead from about 2 000 epochs on (4428 at 3 000: 35 classes held by a tenth against ×8's 23; at 4 000: 50
against 18–25), and ×4 sits between. Mutations are not what limits the supply: the population is 16 384 cells and
duplication and deletion (0.05 each per inheritance, rate-independent) supply most of the variation; what ×8 loses
is the ability to keep what it finds. T90 (the first 5-sample median within 10% of the last-decile median): classes
held by a tenth 5 500–8 000 epochs at ×8, 2 000–2 500 at ×4 (still creeping), 5 500–6 500 at ×2 (still rising at the
horizon); essential genes 0.5–6 k, 2.5–5 k, 1.5–5.5 k. At 7 500–8 500 epochs the ×2 plateau was not yet seen.

**The ×2 plateau epoch, read at 15 000: about 8 000–10 000 epochs.** The top solver's `sub` stands at 77–89 from 8 000
to 13 000 (4381: 77, 79, 83, 79, 79; 4428: 87, 89, 89, 84, 85) and steps once, with a fifth load-bearing gene, to 88–94
at 14 000–15 000. Classes held by a tenth reach 90% of their last-decile level at 6 500 (4381, 37) and 9 500 (4428,
62), the last new persistent maximum at 14 000 (4381, by one class) and 10 000 (4428); depth held stands from
5 500–6 000, essential genes from 4 500–8 500, the minimum from 7 500–9 500. ×4 stands from 2 500–6 000 (classes held
T90 2 500–4 500; `sub` 49–53 from 7 000 to 15 000). So T90 of classes held is 5 500–8 000 at ×8, 2 500–4 500 at ×4
and 6 500–9 500 at ×2: no trend with the rate beyond a factor of about 1.2, where a 1/μ clock would give 4. **The level
reached scales with 1/μ; the time to reach it does not.** What still creeps after the plateau, at every rate, is the
middle of the distribution (classes per computing cell p10 and p90, §8's pattern) and length, which reached the cap at
×2 at 11 000–12 000 epochs.

### 11.6 The rise rule and §5.4

At 7 000–8 500 epochs, every ×2 series (classes held, top repertoire, minimum, essential genes in 4428) and most ×4
series pass the rule and count §5.4's three persistent maxima with the last in the final quarter, and the ×8 reference
at the same horizon passed them too (pilot 5 at 20 000 does not). This is the first climb, not a late rise: §5.1
clause 6 asks for ten times the plateau epoch, and none is known for ×2. Read at 15 000 (the runs' targets) the
question is whether ×2 stands, as every ×8 run did by 8 000.

**Read at 15 000, ×2 stands.** On classes held by a tenth, 4381 passes the rule and §5.4 by one class (36 → 37, the last
maximum at 14 000) and 4428 passes the rule (55 → 62) with its last maximum at 10 000 (§5.4 fails); the top solver's
count-bearing bytes pass both in both worlds by 6–11 bytes (the fifth gene); depth held and essential genes fail in
both. ×4 passes the rule on classes held in 4381 only (20 → 25, last maximum 6 000; 4428 27 → 27). What passes in every
count run is length and the middle of the distribution (classes per computing cell p10 and p90), as at ×8 in pilots
3–5. None of it is a late rise in §5.1's sense: ten times the ×2 plateau epoch is 80 000–100 000 epochs.

### 11.7 What pilot 6 says

1. **The plateau is a mutation–selection balance.** The selective advantage the out-count economy gives the top
   tier, measured from lineage growth, is σ ≈ 1.25–1.36 a generation at every rate (1.0 under drift), and the top
   solvers hold code until their load per generation reaches about ln σ: U = 0.27–0.33 at ×8, 0.22–0.32 at ×4, 0.25 at
   ×2. Held code is therefore about ln σ / (rate · T_gen): 25–29 class-losing byte-equivalents at ×8, 39–55 at ×4, 77–79
   at ×2, within 10–25% of the threshold computed beforehand from measured quantities. The 18–33 bytes of pilots 3–5
   were Eigen's error threshold at ×8, on every machine.
2. **The plateau level moves; its shape, at ×8 and ×4, does not.** A lower rate lifts the level of everything read:
   code, genes, repertoire, depth and, for the first time, the minimum. It does not make the climb late: the level is
   reached as fast or faster. At a fixed rate the balance is a ceiling like any other; "keeps rising" needs the load
   to keep falling or σ to keep rising.
3. **Two worlds, one seed, 15 000 epochs**: a lead, not a finding. ×2 stands from about 8 000–10 000 epochs at `sub`
   79–94 (one late gene in each world), so at ×2, as at ×8, the threshold is a ceiling.

### 11.8 Recommendation

- **Engineer fidelity next, and make it the organisms'.** A fixed `meta_rate` is a constant that sets the ceiling.
  The unassisted version is heredity the tapes can improve: a per-tape fidelity the lineage carries and mutates (a
  rate modifier inherited with the metabolism tape, or a copy instruction whose accuracy depends on the code that
  runs it), so that selection for more code can also select for the fidelity that holds it. That is the one lever
  under which a balance can keep moving, and it keeps §5.1 clause 2 (it names no function). Pilot 7 should be that
  machine at ×8 base rate, read on `sub`, U and the evolved rate.
- **Remove the frameshift load** with marker-defined gene boundaries (a byte the tape places), since at ×2 it is 15%
  of U and grows as the substitution share falls.
- **The sweep after out-compute** (§9.10, §10.8): run its count arms at **`meta_rate` 2/8192** (or include ×8 and ×2
  as a factor), since at ×8 every count arm is pinned at the threshold; machine **genes** (it composes four distinct
  genes at ×2), cap 512 (×2 used 376–440 bytes); horizon **at least 30 000 epochs** (×2's plateau comes at 8 000–10 000, so
  30 000 reads three times it; §5.1 clause 6's tenfold is 100 000). Add an **H-load** key, pre-registered: count-bearing bytes of the top solver at ×2 against
  ×8, predicted shown (ratio ≥ 2), with U per generation predicted equal. Read `sub` and U beside every program-side
  key, and the minimum, which now moves.
- **Before any rise sweep**: pilot 6's ×2 runs reached 15 000 and stand (§11.5); a ×1 arm and
  count-grow at ×2 (to see whether fidelity also lifts the one-loop machine) are the cheapest additions.

**Files.** Pilot 6's material was pilot artefacts and was not kept: the throwaway engine copy (the lineage tag and
the inheritances counted by it, the `#fit` readings and the offline `load` subcommand) and its `pilot6_bin` and
`pilot6_offline` binaries, every census row of every pilot-6 run (with the commonest tapes, the gene solver readings
and the `#fit` lines), the scripts behind the readings above (`analyze6.py`: rise rule, §5.4, T90/T100, T_gen, σ;
`load6.py`: U of a run's top solvers; `prior6.py`: §11.1's table; `final6.py`: the 15 000-epoch readings;
`stocksim.py`: the economy model), the launch, stopper and status scripts, targets and log, and the drafts.

## 12. Pilot 7: evolvable fidelity

2026-10-03 and 04, all *pilot*: a throwaway copy of pilot 6's engine (itself `origin/main`, `b30196a`) in a session scratchpad, not kept,
one seed (5002, pilots 2–6's) per arm and world. A pilot, not a sample. Nothing in the repository or the lab was
touched. §11 found the plateau is Eigen's threshold: held code stands where the load per generation reaches ln σ, so at
any fixed rate the balance is a ceiling. The question here: when the lineages carry and mutate their own copying
fidelity, does held code keep climbing as fidelity improves, or does it stall at a new balance, and what sets it?

### 12.1 The machine, and why it is honest

**Chosen: (a), a heritable rate modifier outside the tape.** Each cell carries a fidelity **level f**, an integer that
rides the metabolism tape through every inheritance (as pilot 6's lineage tag does) and sets that cell's substitution
rate: **rate(f) = ×8 · 2^(−f/2)**, so each step is a factor √2 (f = 0 is ×8, 2 is ×4, 4 is ×2, 6 is ×1, 16 is
×1/32). At each inheritance the child's level moves by one, up or down with equal odds, with probability **0.05** (the
channel's per-inheritance rate for duplication and deletion), clamped to **[−16, 16]** (×2048, a rate of 0.25 per byte
per epoch, to ×1/32): the floor is ×1/32, and the bounds are symmetric about the start so that a neutral walk has no
wall nearer on one side (the free, drift and first costly arms). The **staged** costly arms of §12.5 use **[0, 16]**: f
counts proofreading stages above the base machine, which is then the sloppiest and cheapest level. Every cell starts at
f = 0. Substitutions hit each live byte every epoch at its own cell's rate (the same law as before; one level
everywhere runs the old code path at that level's rate).

**Why not (a′), a level encoded in the tape** (the count of a marker byte): the isa draw makes a marker 1/14 of every
substitution's outcome and duplication copies markers, so a count rises with length, and length rises under drift in
every pilot (§7–§10: 92 → 111, 102 → 142 bytes, with nothing selected); fidelity would then rise for no reason, which is
exactly what the drift arm must exclude. A density instead would import a target density. Either couples heredity to
the computing channel's layout (frames, gene boundaries, frameshift), and the reading would confound the two.

**Why not (b), fidelity bought by code** (byte patterns that proofread): some rule must say which patterns lower the
error. It names no function, so it passes clause 2 on paper, but it is a designed motif, and the pilot would test
whether the tapes find our motif rather than whether fidelity lets code climb.

**(a) is the most favourable case for fidelity.** A perfectly heritable knob gives fidelity every chance to evolve: if
held code does not climb with it, no tape-encoded version will make it climb through fidelity; if it does, moving the
knob into the tape is the next honest step.

**Honesty (§5.1 clause 2).** The level reads no tape, names no function, class or depth, and pays nothing for any
output.
- *Relabelling*: permute the functions any way; the level's effect (a per-byte error rate) and its price (a function
  of f alone) are untouched, so the dynamics are the same.
- *Relational*: in a monoculture of any computed set at any level, no predation moves energy and every cell pays the
  same price, so every choice of set gives the same payoffs.
- *What it imports*: a machine feature, heredity's error rate as a heritable trait with a fixed menu (geometric steps
  of √2 between ×2048 and ×1/32) and a fixed step probability that the level's own fidelity does not protect; and, in
  the costly arms, an **exchange rate α** between fidelity and reproduction. In the label's terms, "imports a machine,
  not an objective".

**The cost.** The initiator's price, which is what one copy attempt costs (8 192 energy in every pilot), becomes
**P(f) = 8 192 · 2^(α f/2) = 8 192 · (rate(0)/rate(f))^α**: each halving of the error rate multiplies the price by
2^α. Why this form:
- It is **scale-free**: a step of fidelity costs the same fraction of reproductive output wherever the lineage sits.
  That is kinetic proofreading with discard (Hopfield 1974): each proofreading stage multiplies accuracy by a constant
  factor and discards a constant fraction of correct intermediates, so the cost per completed copy is multiplied by a
  constant per stage.
- It is the only family with **no preferred rate**. A linear energy cost per stage, or a cost that diverges at a
  thermodynamic floor, each carries a reference fidelity where the cost starts to bite, which is a target rate in
  disguise. The power law carries only α.
- It is paid **in time**. Births are income over price, so T_gen ∝ P(f); and because substitutions arrive per epoch,
  a slower lineage collects more of them per generation. The cost eats into the gain: the error per generation falls
  only as 2^(−(1−α)f/2).

On the symmetric range, levels below 0 are cheaper than the base by the same law (f = −16 costs 8 192 · 2^(−8α)):
that is the refuge of §12.5, which the staged range removes. The price is capped at the stock cap + 1, so a level whose
price exceeds 65 536 cannot reproduce (α = 0.4 past f = 14).

**Checks.**
- **Replay**: with the level on, no level moves, and α = 0.1 (so the price path runs, at 8 192), the binary reproduces
  pilot 5's 4428 count-genes census rows and all 15 `#top`/`#gsolv` lines byte for byte to 1 000 epochs. So with the
  level fixed at 0 the machine *is* pilot 5's, and pilot 5's count-genes runs (20 000 epochs, both worlds) are this
  pilot's fixed ×8 reference.
- **The law**: every census reports, per level, the substitutions made and the live byte-epochs exposed. In a 400-epoch
  smoke run with levels spread from −16 to 11, the realised rate matches 2^(−f/2)/1 024 at every level with at least
  10⁶ byte-epochs (f = −16: 0.2500 against 0.25; f = −8: 0.01570 against 0.01563; f = 0: 0.00100 against 0.00098;
  f = 2: 0.00050 against 0.00049); the runs' own checks are in §12.4.

### 12.2 Where the rate should go, computed first (`prior7.py`)

Written and run at 23:00, before the first arms were launched at 23:04, except where marked.

**The gradient.** Take a lineage at level f among residents. Per epoch its births are income over price,
b(f) = b₀ · 2^(−αf/2); its deaths (being overwritten) do not depend on its own level; its master loses a class at
rate(f) · `sub` per epoch (somatic substitutions on the load-bearing target, §11.1). Its Malthusian growth is
r = b − d − rate · `sub`, and

  dr/df = (ln 2 / 2) · b · (U_sub − α),  with U_sub = rate · T_gen · `sub`, the substitution load per generation.

So **fidelity improves exactly while the substitution load exceeds the cost exponent**, and worsens while it falls
short. §11 adds the second half: held code expands until the whole load reaches ln σ, so on the balance
U_sub ≈ ln σ − U_frame **at every rate** (Drake's rule in this world: the per-genome load is what stays fixed). On the
balance the gradient is therefore ln σ − U_frame − α, independent of the rate, and there is a **critical exponent**

  α_c = ln σ − U_frame ≈ 0.18–0.29 (σ 1.25–1.36, U_frame 0.02–0.04; 0.22–0.24 at σ = 1.3).

In whole steps of √2 the up-step gains U_sub · (1 − 2^−½) ≈ 0.068 a generation and the down-step loses U_sub · (√2 − 1)
≈ 0.096 (σ = 1.3, U_frame 0.03). With no code to protect (U_sub = 0) the gradient is −α.

**Predictions, by arm.**
- **Free (α = 0).** Fidelity improves while any code is held, at about 0.07 a generation per step while code sits at
  its threshold, and code follows L_max(rate) behind it: 22 `sub` at ×8, 45 at ×4, 90 at ×2, 180 at ×1, 360 at ×½.
  Nothing in the model stops this short of the floor (×1/32, L_max ≈ 5 700) except code that stops growing: once held
  code lags its threshold, U_sub falls with the rate and the drive on the level weakens geometrically. The cap (512
  bytes, 16 genes of 32) bounds code near L_max(×½–×¼), so **held code should keep rising until the cap's 16 genes
  fill, and the rate keep falling past the point where code can use it**, slowing as U_sub sinks. "Settles" here means
  the cap, not a balance.
- **Costly, α = 0.1 (below α_c).** The same direction at about half the drive (net +0.034 per step per generation on
  the balance): fidelity improves while U_sub > 0.1, that is, while code sits within a factor 2.5 of its threshold, so
  fidelity follows code. If code stalls at `sub` 80, 160 or 320 the level stops at ×0.76, ×0.35 or ×0.16 (T_gen grows
  with the price: 13.1 at ×1, 15.0 at ×¼).
- **Costly, α = 0.4 (above α_c).** Fidelity worsens at every rate (net −0.061 for a step up, +0.052 for a step down):
  the rate rises, L_max falls (15 `sub` at ×16, 6 at ×32), held code shrinks with it, and the computing collapses, an
  error catastrophe driven by the price; the floor of that slide is the cheapest level (f = −16, 0.25 per byte per
  epoch).
- **Any cost, from descent** (added after the first 500 epochs of the costly arms, §12.3). The worlds compute nothing
  at descent (`own_tape`), so for the first few hundred epochs U_sub = 0 and any α > 0 drives the rate up before code
  exists. Whether code can then establish at the high rates the cost has reached, and pull fidelity back, the model
  does not settle: at ×32 L_max is about 6. Hence the burn-in arms (level fixed at 0 for 5 000 epochs, which is
  pilot 5's run replayed, then evolvable), so that the cost first bites on an established ×8 code.
- **Drift (no predation).** No code, so free: a neutral walk, the median at 0 within drift, the spread growing
  (about one move every 20 generations per lineage, so ±√(moves)); costly α = 0.1: the rate rises at −α, to the bound.

### 12.3 Arms, horizons, cost

From 4381 and 4428 at their epoch 20 000 (`own_tape`, nothing computing at descent), pilot 5's bundle (×8 base rate,
`transfer` 8 192, `loss` 0.5, the pass every 8 epochs), the genes machine (G = 32, 16 emits and 4 096 steps per gene),
the channel at cap 512 (dup/del 0.05, segments 1–16, floor 8), strict out-count, seed 5002. Census every 500 epochs,
solver readings every 1 000, `#fit` every 1 000.

| arm | rule | levels | α | horizon past descent | CPU-min (4381, 4428) |
|---|---|---|---|---|---|
| **free** | out-count | −16…16 | 0 | 36 000, 30 000 | 17.5, 17.5 |
| **staged, costly** | out-count | 0…16 | 0.1 | 15 000 | 30.1, 30.2 |
| **staged, cheap** | out-count | 0…16 | 0.03 | 12 000, 15 000 | 9.0, 13.5 |
| **staged, dear** | out-count | 0…16 | 0.4 | 4428 only, 9 000 | 17.5 |
| **drift** | none | −16…16 | 0 | 25 000 | 8.2, 9.3 |
| **fixed ×8** (reference) | out-count | 0 only | — | pilot 5's count-genes, 20 000 (replayed, §12.1) | — |
| free at cap 1 024 | out-count | −16…16 | 0 | 4428 only, 15 000 | 12.1 |
| costly with a refuge, from descent | out-count | −16…16 | 0.1 | 3 000 | 14.7, 12.7 |
| costly with a refuge, burn-in 5 000 | out-count | −16…16 | 0.1 | 7 000, 6 500 | 16.1, 16.1 |
| costly with a refuge, burn-in 5 000 | out-count | −16…16 | 0.4 | 5 500, 6 000 | ≈8.5, 14.9 |
| drift, costly with a refuge | none | −16…16 | 0.1 | 5 000 | 2.6, 2.4 |

**What changed during the pilot, and why.** The costly arms were first run on the symmetric levels (the same machine
as free and drift). From descent they fell to the cheapest level within 500–1 000 epochs, before any code existed, so
burn-in arms were added at 23:08 to let the cost first bite on an established ×8 code (the α = 0.4 runs from descent
were stopped at descent and replaced). Those collapsed too, for a reason the local model of §12.2 misses (§12.5), so the
**staged** arms were added at 23:27, a cap-1 024 free arm at 23:31 (a cap of 2 048 was refused: `meta_len` is validated
at most 1 024), and α = 0.03 at 23:47 (4428) and 00:02 (4381). The staged predictions were written into `prior7.py`
before those arms were read past 1 500 epochs; α = 0.03 and the cap arm have none. Collapsed arms were stopped once the
collapse had held for 1 000–3 000 epochs: at 0.25 substitutions per byte per epoch every tape is unique, and they cost
3–4 CPU-minutes per 1 000 epochs.

**Total: about 4.4 CPU-hours** at `nice 19` (the runs 254 CPU-minutes, builds, replay and smoke checks about 6, offline
reads about 2), over the brief's 4 by the α = 0.03 run on 4381, added for the second world. The Mac's load average was
110–200 throughout. One seed per arm and world. Every horizon is short of §5.1 clause 6.

### 12.4 Results: free fidelity

**The rate falls to the floor, fast, in both worlds** (`analyze7.py`; the rate as a multiple of 1/8 192 per byte per
epoch, over all cells, p10 · p50 · p90; "top" is the rate of the cells carrying the top-repertoire solver's tape):

| epochs | 4381 all cells | 4381 top | 4428 all cells | 4428 top | drift p50 (4381, 4428) |
|---|---|---|---|---|---|
| 0 | ×8 | — | ×8 | — | ×8, ×8 |
| 2 500 | ×1 · ×2.8 · ×5.7 | ×2 | ×1 · ×2 · ×4 | ×1.4 | ×8, ×8 |
| 5 000 | ×0.13 · ×0.35 · ×0.71 | ×0.18 | ×0.09 · ×0.18 · ×0.71 | ×0.18 | ×11, ×5.7 |
| 7 500 | ×0.04 · ×0.18 · ×0.35 | ×0.03 | ×0.04 · ×0.09 · ×0.25 | ×0.09 | ×16, ×5.7 |
| 10 000 | ×0.03 · ×0.06 · ×0.18 | ×0.04 | ×0.03 · ×0.06 · ×0.18 | ×0.06 | ×32, ×5.7 |
| 15 000 → end | ×0.03 · ×0.044 · ×0.09–0.13 | ×0.03–0.04 | ×0.03 · ×0.044 · ×0.09–0.13 | ×0.03–0.04 | ×32–90, ×4–23 |

The level moves six steps (×8 → ×1) in the first 2 000 epochs and is at the floor's door (×0.044; the floor ×1/32 is
the p10) by 12 500, then stands there to 30 000–36 000. Under drift the median wanders both ways (4381 up to ×90, 4428
between ×4 and ×23) over a p10–p90 spread of ×0.2–×1 400: **the rate does not fall for no reason**, and the free arms'
fall, the same in both worlds with the whole distribution moving, is selection. Realised rates match the law at every
level in every run (cumulative substitutions against 2^(−f/2)/1 024 within ±2.5 sd).

**The threshold stops binding.** The top solver's load (`load7.py`, at its own cells' level, T_gen over the 2 000 epochs
before), `sub` · U_sub · U_frame · U:

| epochs | 4381 | 4428 |
|---|---|---|
| 1 000 | 17 · 0.041 · 0.021 · 0.062 | 35 · 0.120 · 0.048 · 0.168 |
| 2 000 | 28 · 0.013 · 0.025 · 0.038 | 41 · 0.036 · 0.041 · 0.078 |
| 4 000 | 90 · 0.022 · 0.050 · 0.072 | 91 · 0.011 · 0.043 · 0.054 |
| 8 000 | 128 · 0.017 · 0.047 · 0.064 | 182 · 0.022 · 0.047 · 0.070 |
| 16 000 | 140 · 0.015 · 0.047 · 0.062 | 187 · 0.021 · 0.049 · 0.069 |
| 30 000 | 166 · 0.020 · 0.050 · 0.070 | 190 · 0.014 · 0.050 · 0.064 |
| 36 000 | 168 · 0.017 · 0.050 · 0.067 | — |

Fidelity outruns code from 2 000 epochs on: the substitution load falls to 0.01–0.04 a generation and stays there,
the whole load is 0.04–0.09 against ln σ = 0.35–0.45 (σ_net 1.56 and 1.42, 34 and 28 `#fit` readings), and **the
frameshift is now 70–80% of it** (U_frame 0.047–0.050: with load-bearing code in 9–10 of 16 genes, 94–100% of the
channel's deletions lose a class). L_max at the floor is about 3 000 `sub`; the code holds 140–190.

**Held code: a large rise, then the cap.**

| | fixed ×8 (pilot 5, 15 000) | fixed ×2 (pilot 6, 15 000) | free 4381 (10 000 · 15 000 · 36 000) | free 4428 (10 000 · 15 000 · 30 000) |
|---|---|---|---|---|
| `sub`, top solver | 25–29 | 79–94 | 128 · 140 · 168 | 180 · 187 · 190 |
| count-bearing bytes, top solver | 29, 26 | 102, 98 | 156 · 174 · 202 | 204 · 206 · 216 |
| load-bearing genes | 2, 2 | 5, 5 | 7 · 8 · 9 | 10 · 10 · 10 |
| essential genes held by a tenth | 2, 3 | 5, 5 | 7 · 8 · 9 | 10 · 10 · 10 |
| classes held by a tenth | 22, 21 | 37, 62 | 32 · 33 · 37 | 54 · 54 · 58 |
| depth held by a tenth | 6, 7 | 8, 9 | 8 · 8 · 8 | 8 · 8 · 9 |
| **minimum**: max depth p10, classes p10 | 1, 2 | 7, 15–26 | 8, 21 → 8, 22 | 7, 39 → 8, 42 |
| mean length | 460, 499 | 507, 505 | 510 (the cap from 7 500) | 510 (the cap from 10 000) |

- **Code doubles past fixed ×2** and the load-bearing genes go 5 → 9–10; by 7 500–10 000 epochs the tapes fill the cap
  (16 genes) and the climb becomes a creep: +28 and +10 count-bearing bytes and +4 classes held over the last 21 000
  and 15 000 epochs.
- **The function side does not double.** Classes held end at 37 and 58 against fixed ×2's 37 and 62: the same
  repertoire in twice the code, over twice the genes (4–6 classes per load-bearing gene against ×2's 7–12). Depth is
  8–9, as at ×2. The minimum is a step above ×2's (max depth p10 8 against 7, classes p10 22 and 42 against 15 and
  26).
- **The cap binds.** The cap-1 024 arm replays the free 4428 run byte for byte until a tape needs room past 512 (about
  7 500 epochs), then goes on. At 15 000: classes held **81** (cap 512: 54), depth 9 (8), essential genes held 14 (10),
  `sub` 262 (187), count-bearing bytes 289 (206), load-bearing genes 14 (10), classes p10 59 (42); U 0.057–0.068, the
  rate at the floor; every series passes the rule and §5.4, and the tapes reached the new cap at 14 000.
- **The economy thins.** At the floor the meta tapes become a near-monoculture (meta diversity 3 100–3 800, against
  fixed ×8's 15 500, fixed ×2's 13 000 and α = 0.1's 14 300), the eat rate falls from 0.29–0.32 to 0.17–0.21, the
  soup's replicator share falls from 0.98 to 0.34–0.47, and T_gen rises from 11 to 14–25, so 30 000–36 000 epochs are
  about 2 000 generations, not 3 000.

### 12.5 Results: costly fidelity

**With a refuge in sloppiness, every costly arm collapses, at both α, and so does drift.** From descent (α = 0.1) the
level falls to the bound (f = −16, 0.25 substitutions per byte per epoch, price 4 705) within 500–1 000 epochs, before
code exists, and the worlds never compute again (classes held by a tenth 1–2 to 3 000 epochs, against fixed ×8's 21–23
at the same epoch). After a 5 000-epoch burn-in at ×8 (classes held 12 and 17, depth 5 and 7 at the unlock), α = 0.4
falls to the bound within **500** epochs and α = 0.1 within **1 000**, and the code goes with it (classes held 1–2,
depth 0–1, a quarter to a half of the cells silent). Drift at α = 0.1 falls to the bound in 1 000 epochs. The fall
accelerates itself: a cheaper level initiates more often (at α = 0.4 the bound costs 890, below the influx, so a cell
copies every epoch), so cheap lineages also move their level faster.

**Why §12.2 missed it.** Its gradient is local: one step either way, code held. The refuge is global. A lineage that
gives up its code loses at most what computing pays (σ ≈ 1.3–1.5 a generation, the top tier against the rest), and the
bottom of the price range pays more than that: 2^(8α) = 1.74 times the births at α = 0.1, 8 at α = 0.4. Out-count
makes computing optional (a cell's own replication never reads its metabolism tape), so any cost whose range lets
sloppiness save more than σ lets lineages defect from computing, and the code is lost in an error catastrophe driven
by the price. This is a property of the cost's **range**, not of its slope.

**Without a refuge (staged levels 0…16), the cost sets a balance, and not the one §12.2 predicted.** At the horizon
(rates over all cells and of the top solver's cells; U_sub of the top solver at its own level, 11 000–15 000):

| | free (α = 0) | α = 0.03 | α = 0.1 | α = 0.4 | fixed ×8 |
|---|---|---|---|---|---|
| horizon | 36 000, 30 000 | 12 000, 15 000 | 15 000 | 4428, 9 000 | 15 000 |
| rate, all cells p50 (p10–p90) | ×0.044 (×0.03–0.13) | ×0.35, ×0.25 (×0.13–×0.7) | ×5.7, ×4 (×2–×8) | ×8 (×5.7–×8) | ×8 |
| rate, top solver's cells | ×0.03–0.06 | ×0.18–0.25, ×0.09–0.18 | ×1.4–×2.8, ×1–×2.8 | ×8 | ×8 |
| **U_sub, top solver** | 0.01–0.02 | 0.018–0.045, 0.019–0.042 | 0.056–0.12, 0.057–0.20 | 0.24–0.31 | 0.24–0.32 |
| `sub`, top solver | 168, 190 | 131, 148–171 | 30–33, 40–55 | 23–28 | 25–29 |
| load-bearing genes | 9, 10 | 8, 9 | 2, 3 | 2–3 | 2 |
| classes held by a tenth | 37, 58 | **40, 80** | 26, 34 | 23 | 22, 21 |
| depth held by a tenth | 8, 9 | 9, **11** | 9, 9 | 7 | 6, 7 |
| minimum: max depth p10, classes p10 | 8, 22; 8, 42 | 8, 25; **10, 60** | 2, 3; 5, 7 | 1, 2 | 1, 2 |
| meta diversity · eat rate · T_gen | 3 100–3 800 · 0.17–0.21 · 14–25 | 6 300–7 900 · 0.26–0.36 · 11–12 | 14 300 · 0.42–0.46 · 10–12 | 15 200 · 0.45 · 11 | 15 500 · 0.45–0.46 · 10.6 |

- **The top lineage's fidelity settles where its own substitution load meets the cost.** U_sub of the top solver is
  0.02–0.045 at α = 0.03, 0.06–0.20 (median about 0.09) at α = 0.1, and at α = 0.4 the level never leaves 0 because
  U_sub (0.24–0.31) is below α. That is §12.2's gradient, U_sub − α. What §12.2 got wrong is which side moves: a level
  step sweeps in a few hundred epochs and code grows over thousands, so **fidelity, not code, reaches the balance**.
  U_sub is pinned at α with the code below its threshold, instead of U_sub = ln σ − U_frame with the code at it. There
  is no knife-edge at α_c ≈ 0.2; there is a continuous family in which the per-genome substitution load equals the
  cost exponent (Drake's rule, with α as its constant) and the rate falls as the code grows (rate × `sub` ≈ α/T_gen;
  the ratchet of §12.2's α = 0.1 bullet, which 4428 shows only weakly: its top solver's code 35 → 57 count-bearing
  bytes in 15 000 epochs, its cells at ×1–×2.8).
- **At α = 0.1 the bulk does not follow the top.** The population median stays at ×4–×5.7 while the top solver's
  cells sit at ×1–×2.8; held code is 30–55 `sub`, between fixed ×8 and fixed ×4. At α = 0.03 the bulk follows (median
  ×0.25–×0.35).
- **A small cost beats no cost.** With the same held code as the free arm (`sub` 131 and 148–171 against 140 and 187
  at matched epochs) and at the same cap, α = 0.03 holds more repertoire in both worlds: 40 classes by a tenth at
  12 000 in 4381 (free at 12 000: 32–34) and **80** at 15 000 in 4428 (free: 54), with depth 11 and a minimum of max
  depth p10 10 and classes p10 60 in 4428, the highest of any arm of this study on this machine. The difference is the
  population: at the floor the free world is a near-monoculture with a slow economy; at α = 0.03 the rate stays at
  ×0.1–×0.35, meta diversity is twice the free arm's (fixed ×8 and α = 0.1 hold 14 000–15 500), the eat rate 0.26–0.36
  against 0.17–0.21, the soup's replicator share 0.68–0.85 against mostly 0.34–0.54, T_gen 11–12 against 14–25. The
  suspicion that free fidelity would starve novelty holds in this form: it drives the rate to its minimum and the
  population stops exploring, though held code itself does not fall.
- α = 0.4 staged is the fixed ×8 machine with a thin cloud above it (classes held 23 against ×8's 21 at 9 000).

### 12.6 The rise rule and §5.4

§9.8's rule (bar → last-decile median, ✓ = rises by at least one) and the persistent new maxima (k = 5), with the epoch
of the last in thousands past descent; "§5.4" where at least three fall with the last in the final quarter (`rise7.py`).
The level is read as f, so a rise is a fall in the rate.

| arm (horizon) | classes held 10% | essential genes 10% | depth held 10% | min: max depth p10 | min: classes p10 | count-bearing bytes, top | load-bearing genes, top | level f, median |
|---|---|---|---|---|---|---|---|---|
| free 4381 (36 k) | 33 → 37 ✓; 16 max, last 34.5 (§5.4) | 8 → 9 ✓; 9 max, last 23.5 | 8 → 8; 3 max, last 3.5 | 8 → 8; 4 max, last 4.5 | 23 → 22; 12 max, last 16.5 | 174 → 202 ✓; 10 max, last 29 (§5.4) | 8 → 9 ✓; 7 max, last 25 | 15 → 15; 10 max, last 15.5 |
| free 4428 (30 k) | 54 → 58 ✓; 17 max, last 26.5 (§5.4) | 10 → 10; 9 max, last 10.5 | 8 → 9 ✓; 5 max, last 23.5 (§5.4) | 7 → 8 ✓; 6 max, last 23.5 (§5.4) | 42 → 42; 18 max, last 16.5 | 206 → 216 ✓; 11 max, last 29 (§5.4) | 10 → 10; 7 max, last 12 | 15 → 15; 11 max, last 12.5 |
| free, cap 1 024, 4428 (15 k) | 55 → 81 ✓; 18 max, last 15 (§5.4) | 8 → 14 ✓; 13 max, last 15 (§5.4) | 8 → 9 ✓; 5 max, last 15 (§5.4) | 7 → 8 ✓; 6 max, last 11 | 36 → 60 ✓; 22 max, last 14.5 (§5.4) | 161 → 289 ✓; 11 max, last 15 (§5.4) | 8 → 14 ✓; 9 max, last 15 (§5.4) | 13 → 15 ✓; 11 max, last 13 (§5.4) |
| α 0.03 4381 (12 k) | 35 → 40 ✓; 11 max, last 12 (§5.4) | 6 → 8 ✓; 8 max, last 10.5 (§5.4) | 8 → 9 ✓; 3 max, last 3.5 | 8 → 8; 6 max, last 6.5 | 18 → 25 ✓; 12 max, last 12 (§5.4) | 103 → 141 ✓; 7 max, last 12 (§5.4) | 6 → 8 ✓; 5 max, last 12 (§5.4) | 8 → 9 ✓; 6 max, last 7.5 |
| α 0.03 4428 (15 k) | 74 → 80 ✓; 12 max, last 14.5 (§5.4) | 9 → 9; 9 max, last 10.5 | 10 → 11 ✓; 6 max, last 6 | 9 → 10 ✓; 7 max, last 11 | 44 → 60 ✓; 17 max, last 12 (§5.4) | 161 → 191 ✓; 8 max, last 12 (§5.4) | 8 → 9 ✓; 6 max, last 11 | 9 → 10 ✓; 8 max, last 11 |
| α 0.1 4381 (15 k) | 26 → 26; 7 max, last 9.5 | 2 → 2; 3 max, last 13.5 (§5.4) | 9 → 9; 4 max, last 5 | 2 → 2; 3 max, last 8 | 3 → 3; 3 max, last 8 | 35 → 36 ✓; 4 max, last 8 | 2 → 2; 2 max, last 7 | 1 → 1; 1 max, last 8 |
| α 0.1 4428 (15 k) | 40 → 34; 8 max, last 8.5 | 3 → 4 ✓; 4 max, last 14 (§5.4) | 9 → 9; 6 max, last 11 | 2 → 5 ✓; 5 max, last 15 (§5.4) | 4 → 7 ✓; 6 max, last 15 (§5.4) | 38 → 51 ✓; 7 max, last 15 (§5.4) | 3 → 3; 3 max, last 11 | 1 → 2 ✓; 2 max, last 14.5 |
| α 0.4 4428 (9 k) | 23 → 23; 6 max, last 8 (§5.4) | 2 → 3 ✓; 3 max, last 7 (§5.4) | 10 → 7; 6 max, last 6 | 1 → 1; 2 max, last 3 | 2 → 2; 2 max, last 5.5 | — | — | 0 → 0 |
| fixed ×8 4381 (pilot 5) (20 k) | 21 → 19; 12 max, last 16 (§5.4) | 2 → 2; 2 max, last 4.5 | 6 → 6; 4 max, last 11.5 | 1 → 1; 2 max, last 4.5 | 2 → 2; 2 max, last 5.5 | 28 → 29 ✓; 6 max, last 13 | 2 → 2; 2 max, last 6 | — |
| fixed ×8 4428 (pilot 5) (20 k) | 21 → 19; 7 max, last 8 | 3 → 3; 3 max, last 8 | 7 → 7; 4 max, last 5.5 | 1 → 1; 2 max, last 5 | 2 → 2; 2 max, last 8 | 26 → 29 ✓; 8 max, last 19 (§5.4) | 2 → 2; 2 max, last 7 | — |
| drift 4381 (25 k) | 1 → 1; 1 max, last 3 | 1 → 1; 1 max, last 3 | 0 → 0; 1 max, last 3 | 0 → 0; 1 max, last 2.5 | 1 → 1; 1 max, last 2.5 | 3 → 4 ✓; 2 max, last 17 | 1 → 1; 2 max, last 17 | 0 → -7 |
| drift 4428 (25 k) | 1 → 1; 1 max, last 3 | 1 → 1; 1 max, last 3 | 0 → 0; 1 max, last 3 | 0 → 0; 1 max, last 2.5 | 1 → 1; 1 max, last 2.5 | 0 → 2 ✓; 2 max, last 22 | 0 → 1 ✓; 2 max, last 22 | 1 → 2 ✓; 1 max, last 6.5 |

- **No arm rises late in §5.1's sense**: the longest horizons are 30 000–36 000 epochs, about 2 000 generations, and
  ten times the plateau epoch is not reached anywhere.
- **The free arms creep at the cap**: classes held 33 → 37 and 54 → 58 and count-bearing bytes 174 → 202 and 206 → 216
  pass the rule and §5.4 in both worlds, with the level standing at f = 15 from 12 500. That is the kind of creep fixed
  ×2 shows at 15 000 (§11.6) and fixed ×8 does not show at 20 000.
- **What still climbs at its horizon** is the cap-1 024 arm (every series, both clauses) and α = 0.03 (classes held,
  the minimum's classes, code and genes, both clauses in both worlds): the two arms whose ceiling, the cap, was not yet
  reached or only just reached.
- α = 0.1 passes in 4428 on the minimum (max depth p10 2 → 5, classes p10 4 → 7), on code (38 → 51) and on the top
  tier's level (f 1 → 3); 4381 stands. α = 0.4 and drift stand.

### 12.7 What pilot 7 says

1. **Fidelity evolves readily when it is free, and runs to the floor.** A heritable level that names no function
   moved from ×8 to ×0.044 in 12 500 epochs in both worlds while drift left it wandering. As expected, free fidelity
   collapses to the minimum.
2. **Then the error threshold is no longer the ceiling; the channel's cap is.** The substitution load falls to
   0.01–0.04 a generation, the frameshift becomes most of what is left, held code doubles past fixed ×2 (`sub` 140–190,
   9–10 load-bearing genes) and fills the 512-byte cap by 7 500–10 000 epochs, then creeps. Doubling the cap lifts
   everything again (81 classes, `sub` 262, 14 load-bearing genes at 15 000, still rising). So held code keeps rising
   under evolvable fidelity only while the channel has room: a ceiling built into the probe, as §5.1 clause 3 warned.
3. **Free fidelity buys code, not repertoire.** At the cap the free worlds hold no more classes than fixed ×2 in twice
   the code, and thin into a near-monoculture with a slow economy.
4. **A cost sets a balance, continuously.** The top lineage's fidelity settles where its own substitution load equals
   the cost exponent α (0.02–0.045 at α = 0.03, about 0.09 at α = 0.1; at α = 0.4 it never moves). §12.2's gradient was
   right and its balance was wrong: fidelity reaches the balance before code does, so there is no critical α near 0.2,
   only a load set by the price, and a rate that falls as code grows.
5. **A small cost does best.** α = 0.03 (1% of births per √2 of fidelity) holds the most classes, depth and minimum of
   any arm here (4428: 80, 11, 10; 4381: 40 against free's 32–34), with the code the free arm holds, by keeping the
   rate off the floor and the population diverse.
6. **The cost's range matters as much as its slope.** Where sloppiness can be bought below the base machine's price,
   the refuge pays more than computing does (1.74–8 against σ 1.3–1.5) and every costly arm collapses within 500–1 000
   epochs, at either α, with or without a burn-in.
7. **A pilot, not a finding**: one seed, two worlds (one for the cap and α = 0.4 arms), 9 000–36 000 epochs.

### 12.8 Recommendation

- **Engineer fidelity as staged and costly, not free and not symmetric.** The level counts proofreading stages above
  the base machine (f ≥ 0, the base the sloppiest and cheapest), with the initiator's price 8 192 · 2^(αf/2) and α
  near 0.03. Free fidelity reaches the floor and a monoculture; a range that lets sloppiness undercut the base destroys
  computing. Engine slice: `meta_fid_steps` (0 = off), `meta_fid_max`, `meta_fid_rate` (0.05 per inheritance),
  `meta_fid_alpha`; the level is world state (hashed and snapshotted beside the metabolism tape); refused without the
  growable channel and the initiator economy. It imports a machine (a heritable heredity knob), not an objective, and
  passes both tests of §5.1 clause 2.
- **Lift the cap next; it is now the ceiling.** `meta_len` is validated at most 1 024, and at 1 024 the free arm filled
  it in 14 000 epochs. Raise the validation (2 048–4 096; under genes each gene has its own budget, so length does not
  run into §9's step budget) and read whether repertoire keeps rising with room, or stops at some later point of its
  own. Add **marker-defined gene boundaries** with it: once fidelity is evolvable the frameshift is 70–80% of the load.
- **Pilot 8 before any sweep**: staged fidelity at α ∈ {0.01, 0.03, 0.1} × cap {1 024, 4 096} on both worlds with two
  seeds, 30 000 epochs, read on classes held by a tenth, the minimum, meta diversity, the top solver's U_sub against α,
  and the rise rule. The question it settles: does α = 0.03's advantage over free hold across seeds, and does
  repertoire keep rising when the cap is out of reach.
- **Then the level sweep's count arms** (§9.10, §10.8, §11.8) become count-genes with staged fidelity (α from pilot 8)
  at the largest cap affordable, against fixed ×8 and free fidelity, horizon at least 30 000 epochs, with two keys
  pre-registered: *H-fidelity*, the top solver's U_sub settles at α (rate × held code ≈ α/T_gen), predicted shown;
  *H-explore*, classes held by a tenth under staged α above free fidelity at the same cap, predicted shown on this
  pilot's two worlds.
- **Not yet a rise sweep.** No arm reaches §5.1's lengths. The most promising reading, the cap-1 024 arm still
  climbing, is one world, one seed and 15 000 epochs.
- **Later**: move the knob into the tape (design a′) once a staged, costly external knob is understood: the drift arms
  show the external knob is neutral without predation, and the refuge arms show what an encoding must avoid (a way to
  be cheaper than the base by being sloppier).

**Files.** Pilot 7's material was pilot artefacts and was not kept: the throwaway engine copy (the fidelity level, its
per-cell hazard walk, its inheritance and moves, the initiator's price and the realised-rate counters, with the pilot
crate's options, census columns and `#fid` lines) and its `pilot7_bin` and `pilot7b_bin` binaries (the second adds
`--fid-start`), every census row of every pilot-7 run (with the level columns, the commonest tapes, the gene solver,
`#fit` and `#fid` lines), the scripts behind the readings above (`analyze7.py`: blocks, rise rule, §5.4, T90, σ, the
realised-rate check; `load7.py`: U of a run's top solvers at their own level; `rise7.py`: §12.6's table; `prior7.py`:
§12.2's numbers, and the staged and refuge predictions added before those arms were read), the replay check, the launch,
stopper and status scripts, targets and log, this study as it stood before pilot 7's edits, and the drafts. Pilot 6's
final readings were `final6.py`'s.

## 13. Pilot 8: the late climb at a cap the run does not reach

2026-10-04, all *pilot*: a throwaway copy of pilot 7's engine (itself `origin/main`, `b30196a`) in a session scratchpad, not kept,
one seed (5002, pilots 2–7's) per lane and world, and a second seed (5003) for one cell. A pilot, not a sample. Nothing
in the repository or the lab was touched. Pilot 7 put four pieces together (strict out-count, the genes machine, the
growable channel, heritable staged costly fidelity at α ≈ 0.03), and held code and repertoire rose until the channel's
cap; a doubled cap lifted them again. The question here is §5.1 clause 4's: with the cap out of reach, does the climb
keep going late, with persistent new maxima in the final quarter?

### 13.1 What was built

- **The cap.** `META_LEN_MAX` lifted from 1 024 to 4 096 (the only validation in the way; `lens` are `u16`, the
  slot is `meta_len` bytes per cell, and under genes each gene keeps its own 64-byte buffer, 16 emits and 4 096 steps,
  so length never meets §9's step budget).
- **A faster gene memo** (no change to what is computed): at G = 32 the predation pass's memo is keyed by a fixed
  32-byte array instead of an allocated vector, and a gene with no emit byte is skipped without a lookup
  (`functions_one` refuses it anyway).
- **Forked lanes.** A count lane runs at cap 4 096 and, at the end of the first epoch in which its longest tape comes
  within 64 bytes of 1 024 (every tape still shorter than 1 024), clones the world and lowers the clone's growth cap
  to 1 024. Until a tape needs room past a cap, the cap draws nothing, so the two are one run up to the fork, and the
  clone *is* the cap-1 024 run: a matched pair that shares its history and differs only in room.
- **Per-lane horizons** read at every census from `targets.txt`, so a lane can be cut or extended without a restart.
- **Marker-defined genes** (`--marker 1`, one probe lane; §13.2).

**Checks.** With markers off, the binary reproduces pilot 7's α = 0.03 run on 4428 (cap 512) line for line to 1 000
epochs (19 lines: census rows, `#top`, `#gsolv`, `#fit`, `#fid`), and the same at cap 4 096. A cap-4 096 lane forked at
cap 128 reproduces a direct cap-128 run line for line to 2 000 epochs (33 lines), and its own main lane reproduces the
unforked cap-4 096 run.

### 13.2 Marker-defined genes: the rule, and why it is a probe

**The rule.** Every byte outside the 13 values an `isa` draw names outright (the no-op class, drawn at 1/14 and shown
`_`) is a **gene boundary**. A frame starts at offset 0 and right after every marker byte; each maximal run of
non-marker bytes is cut into 32-byte genes from its own start, each zero-padded to 32 and run as before (alone, on its
own 64-byte buffer, 16 emits, 4 096 steps; the union is the tape's set). The marker bytes belong to no gene. A tape with
no marker is read exactly as the fixed-offset machine of §10. So a deletion moves only the frames up to the next
marker, and a gene behind its own marker is out of reach of every deletion upstream.

**Why it is honest.** The boundaries are bytes the tape carries, which mutation writes and erases at the draw's own
odds (the draw is unchanged: no new symbol, no new share), and which duplication copies. The rule reads no output,
names no function, class or depth, and pays nothing; the interaction rule is untouched. *Relabelling*: the partition
depends on the bytes alone, so permuting functions permutes every gene's set and the union, and out-count's sizes are
unchanged. *Relational*: in a monoculture every cell has the same genes and the same union, and no encounter moves
energy. What it imports is a machine feature: a byte class the interpreter ignores now also delimits genes (a promoter
without a sequence), on top of G = 32 as the longest frame. Why the no-op class and not a new byte: a new symbol would
change the mutation spectrum of every arm; this changes only the partition.

**Why a probe and not every lane** (decided before launch). It changes the machine from descent (the descended own
tapes and every junk run are cut at no-op bytes, so frames are short until selection clears them), so putting it in
every lane would make pilot 8 a different machine from pilot 7's, and the cap's effect could not be read against §12.
And the frameshift is not a candidate for the late ceiling: deletions come at 0.05 per inheritance, so U_frame ≤ 0.05 a
generation whatever the code, against ln σ ≈ 0.3–0.4; it is "most of the load" (§12.4) only because evolvable fidelity
has driven the substitution load below it. So one lane, matched to the main α = 0.03 lane on 4428 (same world, seed, α
and cap), reads what markers do to the load and to the climb.

### 13.3 Arms, predictions, cost

From 4381 and 4428 at their epoch 20 000 (`own_tape`, nothing computing at descent), pilot 7's bundle (×8 base rate,
`transfer` 8 192, `loss` 0.5, the pass every 8 epochs on average), the genes machine, the channel (dup/del 0.05,
segments 1–16, floor 8), strict out-count, **staged fidelity** (f ∈ [0, 16], rate ×8 · 2^(−f/2), price
8 192 · 2^(αf/2), level moved ±1 at 0.05 per inheritance, every cell at f = 0 at descent). Census every 500 epochs;
the three solvers and `#fit` every 1 000.

| lane | rule | α | cap | seed | genes | horizon past descent | CPU-min (process) |
|---|---|---|---|---|---|---|---|
| **α 0.03**, 4381 and 4428 | out-count | 0.03 | 4 096 | 5002 | fixed offsets | **35 000** | 46.4, 54.1 (with its fork) |
| ↳ **fork at 1 024** | out-count | 0.03 | 1 024 from the fork (13 625, 12 516) | 5002 | fixed | 30 000 | (in the above) |
| **α 0.01**, 4381 and 4428 | out-count | 0.01 | 4 096 | 5002 | fixed | **35 000** | 35.4, 33.8 (with its fork) |
| ↳ **fork at 1 024** | out-count | 0.01 | 1 024 from the fork (11 521, 14 883) | 5002 | fixed | 30 000 | (in the above) |
| **second seed**, 4428 | out-count | 0.03 | 4 096 | 5003 | fixed | 30 000 | 25.5 |
| **marker probe**, 4428 | out-count | 0.03 | 4 096 | 5002 | markers | 30 000 | 27.7 |
| **drift**, 4381 and 4428 | none | 0.03 | 4 096 | 5002 | fixed | 30 000 | about 9, 10.0 |

**Cost.** Runs 242 CPU-minutes at `nice 19` (one process per line above; a forked lane runs in its parent's
process), builds, the replay and fork checks about 4, offline reads about 1: **about 4.1 CPU-hours**, inside the
brief's 5. The Mac's load average was 20–240 from other sessions. A count lane at cap 4 096 cost 51–62 CPU-ms an
epoch averaged over its run (α 0.03; 40 at α 0.01, whose populations are less diverse and hit the gene memo more), and
about 67 late, at 1 500–2 100 bytes; drift about 20.

**Predictions** (`prior8.md`, written at 00:38, right after launch and before any lane was read past descent), checked
in §13.9. **Decisions made after seeing data:** one. At 01:00, having seen status lines (classes held and the like)
but no rise reading, I set a CPU-only rule (extend the four main cap-4 096 lanes from 30 000 to 35 000 if the projected
total stayed under 280 CPU-minutes when they passed 28 000), and applied it at 01:15 (174 CPU-minutes used, 255
projected). The forks, the second seed and the marker probe stop at 30 000, and every reached/unreached comparison is
read at 30 000. The second seed's cell (α 0.03, 4428) was chosen before launch as pilot 7's best, not after. **Not run:**
α 0.1 (pilot 7: it holds less at every horizon), a second seed of the other cells, a shadow arm, markers at α 0.01 or
on 4381.

### 13.4 Results: at a cap the run does not reach, the climb goes on

5 000-epoch block medians: **classes held by a tenth · essential genes held by a tenth · count-bearing bytes of the
top solver · mean length**.

| k epochs | 4381 α 0.03 | 4428 α 0.03 | 4428 α 0.03, seed 2 | 4381 α 0.01 | 4428 α 0.01 | 4428 α 0.03, markers | drift 4381 | drift 4428 |
|---|---|---|---|---|---|---|---|---|
| 0–5 | 21 · 3 · 63 · 196 | 33 · 2 · 43 · 121 | 27 · 3 · 49 · 151 | 25 · 3 · 59 · 225 | 20 · 2 · 85 · 138 | 20 · 4 · 55 · 188 | 1 · 1 · 2 · 53 | 1 · 1 · 2 · 50 |
| 5–10 | 39 · 8 · 127 · 503 | 75 · 9 · 180 · 461 | 70 · 10 · 169 · 472 | 54 · 8 · 139 · 570 | 45 · 6 · 168 · 451 | 80 · 12 · 211 · 489 | 1 · 1 · 2 · 83 | 1 · 1 · 1 · 80 |
| 10–15 | 44 · 12 · 210 · 791 | 114 · 14 · 271 · 835 | 111 · 15 · 282 · 836 | 81 · 15 · 265 · 918 | 58 · 10 · 245 · 719 | 151 · 20 · 334 · 813 | 1 · 1 · 1 · 95 | 1 · 1 · 2 · 100 |
| 15–20 | 56 · 15 · 316 · 1097 | 134 · 18 · 362 · 1087 | 126 · 18 · 362 · 1105 | 100 · 16 · 325 · 1202 | 86 · 14 · 329 · 1002 | 202 · 27 · 497 · 1112 | 1 · 1 · 3 · 116 | 1 · 1 · 1 · 137 |
| 20–25 | 68 · 19 · 384 · 1378 | 145 · 21 · 444 · 1404 | 147 · 22 · 453 · 1386 | 126 · 21 · 416 · 1548 | 100 · 16 · 402 · 1289 | 236 · 38 · 697 · 1469 | 1 · 1 · 2 · 134 | 1 · 1 · 4 · 159 |
| 25–30 | 71 · 20 · 429 · 1654 | 169 · 25 · 506 · 1694 | 161 · 25 · 498 · 1683 | 149 · 25 · 527 · 1887 | 102 · 17 · 374 · 1537 | 297 · 46 · 950 · 1944 | 1 · 1 · 3 · 130 | 1 · 1 · 3 · 185 |
| 30–35 | 80 · 22 · 476 · 1952 | 179 · 28 · 579 · 1988 | | 169 · 29 · 594 · 2178 | 114 · 20 · 429 · 1806 | | | |

**The last census** (per-cell max depth and classes over computing cells; the rate as a multiple of 1/8 192 per byte
per epoch, over all cells, and of the cells carrying the top-repertoire solver's tape):

| lane | max depth p10 / p50 | classes per computing cell p10 / p50 / p90 | depth held 10% / 1% | classes held 10% / 1% | essential genes held 10% | top solver: count-bearing bytes · load-bearing genes · classes | rate p10–p50–p90, top tape | length p50 / max | meta diversity | replicator share · eat rate · T_gen |
|---|---|---|---|---|---|---|---|---|---|---|
| 4381 α 0.03 (35 k) | 8 / 8 | 74 / 84 / 84 | 8 / 8 | 84 / 88 | 23 | 488 · 23 · 84 | ×0.044–0.088–0.18, ×0.031 | 2 149 / 2 233 | 8 659 | 0.69 · 0.25 · 14.1 |
| 4428 α 0.03 (35 k) | 10 / 10 | 150 / 180 / 181 | 10 / 10 | 182 / 198 | 29 | 595 · 29 · 182 | ×0.062–0.12–0.25, ×0.088 | 2 125 / 2 215 | 9 261 | 0.77 · 0.34 · 12.9 |
| 4428 α 0.03 seed 2 (30 k) | 11 / 11 | 137 / 162 / 164 | 11 / 11 | 165 / 171 | 28 | 551 · 28 · 164 | ×0.062–0.18–0.25, ×0.044 | 1 859 / 1 942 | 9 257 | 0.80 · 0.37 · 12.7 |
| 4381 α 0.01 (35 k) | 11 / 11 | 135 / 173 / 173 | 11 / 11 | 173 / 189 | 30 | 617 · 30 · 173 | ×0.031–0.062–0.12, ×0.031 | 2 364 / 2 483 | 7 671 | 0.66 · 0.30 · 12.8 |
| 4428 α 0.01 (35 k) | 11 / 11 | 94 / 122 / 122 | 11 / 11 | 122 / 129 | 21 | 453 · 21 · 122 | ×0.031–0.044–0.062, ×0.031 | 1 943 / 2 048 | 6 259 | 0.67 · 0.27 · 12.4 |
| 4428 α 0.03 markers (30 k) | 12 / 12 | 288 / 293 / 295 | 12 / 12 | 315 / 350 | 50 | 977 · 49 · 297 | ×0.031–0.044–0.088, ×0.031 | 2 054 / 2 209 | 6 886 | 0.75 · 0.34 · 12.2 |
| drift 4381, 4428 (30 k) | 0 / 0 | 1 / 1 / 1 | 0 / 1 | 1 / 2–3 | 1 | 2 · 1 · 1 | ×4–8–8, ×4–5.7 | 85, 162 / 503, 504 | 10 949, 11 977 | 0.83, 0.92 · — · 8.5–10.2 |

- **Every count lane is still climbing at its horizon, with the cap out of reach** (the longest tape 1 942–2 483 bytes
  against 4 096). Over each lane's last 10 000 epochs classes held by a tenth rose by 15–41 (markers 86), essential
  genes held by a tenth by 3–7 (markers 16) and the top solver's count-bearing bytes by 51–157 (markers 386), in both
  worlds, at both α and in both seeds. Drift holds ECHO alone and one essential gene throughout, its level at the
  base, its tapes at 85–162 bytes (median).
- **Above pilot 7's levels from the moment its cap bound.** The α 0.03 lane on 4428 *is* pilot 7's α 0.03 run until
  a tape needs room past 512 (§13.1); at 15 000 epochs it holds 116 classes by a tenth and seed 2 114, against pilot 7's
  80 at cap 512; 4381 holds 50 (pilot 7: 40 at its 12 000-epoch horizon). By 35 000: 182 and 84.
- **The minimum rises with the rest.** Classes per computing cell p10 go 44 → 72 and 90 → 149 (α 0.03), 59 → 123 and
  54 → 92 (α 0.01), 81 → 135 (seed 2) between the bar and the last decile; at the end p10 is within 2–23% of p50 in
  every lane, so the whole distribution moves, not only the top. Max depth p10 equals depth held by a tenth at the end
  (8–12); depth is near the four-input scale's end (13) and is not an unbounded key.
- **α is not consistent across worlds.** α 0.01 holds the most on 4381 (173 classes against 84) and the least on 4428
  (122 against 182). Its top lineages reach the menu's floor at 6 000–10 000 epochs (§13.7) and its populations are
  less diverse (meta diversity 6 300–7 700 against 8 700–9 300).

### 13.5 Reached against unreached: the matched forks

Each count lane's fork shares its history to the fork and differs only in room after it (§13.1).

| world, α (fork epoch) | classes held 10%: at fork · 30 k, 4 096 · 30 k, 1 024 · 35 k, 4 096 | essential genes held 10% | count-bearing bytes, top | mean length |
|---|---|---|---|---|
| 4381, 0.03 (13 625) | 48 · **73** · 57 · 84 | 12 · **22** · 16 · 23 | 198 · **457** · 309 · 488 | 846 · 1 808 · 1 023 · 2 029 |
| 4428, 0.03 (12 516) | 115 · **179** · 131 · 182 | 14 · **27** · 18 · 28 | 251 · **554** · 381 · 577 | 835 · 1 780 · 1 023 · 2 045 |
| 4381, 0.01 (11 521) | 66 · **156** · 96 · 172 | 14 · **28** · 16 · 30 | 230 · **540** · 321 · 617 | 862 · 2 041 · 1 023 · 2 326 |
| 4428, 0.01 (14 883) | 71 · **101** · 88 · 118 | 12 · **18** · 14 · 21 | 287 · **359** · 331 · 453 | 829 · 1 649 · 1 022 · 1 923 |

The capped lane reaches 1 024 bytes within 1 400–2 100 epochs of the fork and then stands: over its final quarter
(22 500–30 000) it adds 0–7 classes held by a tenth (0 to +0.9 a thousand epochs), 0–1 essential genes and −1 to +42
count-bearing bytes, against +5 to +28 classes, +3 to +6 essential genes and +58 to +113 count-bearing bytes in its
unreached twin, with one exception: on 4428 at α 0.01 the unreached lane paused (100–104 classes, 17 essential genes,
its code flat) from 23 000 to 30 000, then climbed to 122 classes and 21 essential genes by 35 000. At 30 000 the
unreached lane holds 1.15–1.6 times the classes and 1.3–1.75 times the essential genes of its capped twin. **The room
is what the climb runs on**: the same world, history and seed, with the cap reached, flattens within a few thousand
epochs, as pilot 7's cap-512 arms did.

### 13.6 How it climbs: genes side by side, repertoire sublinear in length

- **The program side grows in proportion to length.** Count-bearing bytes are a quarter to a third of the mean length
  in every α 0.03 lane at every block from 10 000 on (4428: 271 of 835, 362 of 1 087, 506 of 1 694, 579 of 1 988;
  4381: 24–29%), and there is about one essential gene held by a tenth per 65–90 bytes. In all 879 solver readings of
  the pilot the top solver's load-bearing genes equal its distinct bodies (no two share a core), as in pilots 5–7:
  additions are new genes side by side, not composition.
- **The function side grows less than in proportion, and slows.** Classes held per 1 000 bytes fall in every lane (4428
  α 0.03: 136 at 10–15 k, 86 at 35 k; seed 2: 133 → 89; 4381 α 0.03: 56 → 41), and the classes per essential gene fall
  (seed 2: 7.4 at 10–15 k, 5.9 at 30 k): each new gene adds fewer classes no other gene already computes. Read at
  30 000, classes held climb at −0.4 to 3.7 a thousand epochs over the final quarter against 1.2–7.7 over the second,
  slower in all six unreached lanes; essential genes keep their pace in five of six (0.4–1.2 a thousand epochs in both
  quarters) and count-bearing bytes in four of six (`late8.py`).
- **Length is selected, not drifted.** The fixed-offset count lanes grow 33–50 bytes every thousand epochs over the
  final quarter (markers 64); drift grows −0.4 to 1.7 (3–4 over its second quarter), and its length is junk: one
  class.

### 13.7 Fidelity, load and σ

The top solver's load (`load8.py`, at its own cells' level; T_gen over the 2 000 epochs before; deletion and duplication
starts read at up to 64 evenly spaced positions per length): level f of the top tape · U_sub · U_frame.

| lane | 15 000 | 25 000 | 30 000 | 35 000 |
|---|---|---|---|---|
| 4381 α 0.03 | 12 · 0.040 · 0.045 | 14 · 0.037 · 0.046 | 15 · 0.032 · 0.049 | 16 · 0.023 · 0.048 |
| 4428 α 0.03 | 15 · 0.018 · 0.050 | 14 · 0.038 · 0.049 | 16 · 0.024 · 0.049 | 13 · 0.075 · 0.050 |
| 4428 α 0.03, seed 2 | 13 · 0.037 · 0.050 | 12 · 0.083 · 0.047 | 15 · 0.033 · 0.049 | |
| 4381 α 0.01 | 16 · 0.012 · 0.050 | 15 · 0.027 · 0.050 | 14 · 0.048 · 0.050 | 16 · 0.027 · 0.049 |
| 4428 α 0.01 | 15 · 0.018 · 0.050 | 16 · 0.017 · 0.046 | 16 · 0.016 · 0.050 | 16 · 0.018 · 0.050 |
| 4428 α 0.03, markers | 14 · 0.034 · 0.027 | 16 · 0.033 · 0.031 | 16 · 0.041 · 0.031 | |
| forks at 1 024 (30 000) | | | 16 · 0.012–0.017 · 0.047–0.050 | |

- **At α 0.03 the balance of §12.5 holds as code grows**: U_sub of the top solver 0.018–0.083, median 0.036, against
  α = 0.03, while `sub` goes from 223–287 at 15 000 to 430–534 at 35 000; the rate falls to keep rate × `sub` × T_gen
  near α (the top tape's level from f 12–15 to 13–16).
- **The menu's floor is reached.** The cells carrying the top tape first sit at f = 16 (×1/32, the end of the staged
  range) at 21 500–28 000 epochs at α 0.03 (markers 16 000) and at 6 000–10 000 at α 0.01, and at f = 13–16 after; at
  α 0.01 U_sub then sits above α (0.012–0.048, median about 0.02), because no cheaper fidelity is left to buy. Past
  the floor the substitution load grows with code (U_sub ≈ 4.8 × 10⁻⁵ per class-losing byte-equivalent a generation
  at T_gen 12.5) and reaches ln σ − U_frame (about 0.2) near `sub` 4 000, roughly 15 000 bytes at the present
  density: a far ceiling, beyond any cap read here, but an imported one (the menu).
- **The frameshift is the larger share of the load** in every fixed-offset lane (U_frame 0.045–0.050, the deletion
  rate times a del_lose of 0.89–1.00), and it does not grow with code: U is 0.055–0.13 a generation throughout, far
  under ln σ. **σ** (`sigma8.py`, `#fit` lineage growth, 5 000-epoch medians) is 1.14–1.53 in every count lane and
  block but one (4381 α 0.01 at 10–15 k, 0.97), and 0.93–1.05 under drift.
- Realised substitution rates match the law at every level in every lane (within ±2.5 sd).

### 13.8 The marker probe

On 4428 at α 0.03, matched to the main lane (same world, seed, α and cap), marker-defined genes:
- **cut the frameshift as intended**: del_lose 0.52–0.62 against 0.90–1.00, U_frame 0.026–0.031 against 0.045–0.050,
  its share of the load 0.25–0.48 against 0.40–0.73;
- **and nearly doubled the level**: at 30 000, 315 classes held by a tenth (the fixed-offset lanes on 4428: 165 and
  172–179), 50 essential genes (27–28), 977 count-bearing bytes (551–554), a minimum of classes p10 288 (130–137),
  depth held 12, at the same length (2 066 against 1 780–1 856). It still climbs at the horizon (+21 classes and +9
  essential genes over the final quarter).
- **The doubling is in the number of computing genes, and the rule hands each a full budget.** The top solver at
  30 000 carries 154 genes on 2 114 bytes (166 markers; genes average 13.7 bytes), of which 65 compute, against 57 genes
  and 33 computing on 1 820 bytes in the matched fixed-offset lane; each computes about as much (4.6 classes against
  5.0). Every gene, however short, has its own 16 emits and 4 096 steps, so a tape that cuts itself into more genes
  gets more of the assay's budget per byte: 1.2 emits a byte against 0.5. The frameshift saving, about 0.02 a generation
  on a load already far below ln σ, is an unlikely cause of a doubling, which points at the budget; but markers mix
  the two changes and the probe cannot separate them. A budget-matched control (a gene's emits proportional to its
  length) would.

### 13.9 The rise rule and §5.4

§9.8's rule (bar → last-decile median; ✓ = rises by at least one) and §5.1 clause 4's persistent new maxima (K = 5),
with the epoch of the last (k past descent); "§5.4" where at least three fall with the last in the final quarter
(`analyze8.py --rise`). Each lane at its horizon:

| lane (horizon) | classes held 10% | essential genes 10% | count-bearing bytes, top | load-bearing genes, top | min: classes p10 | min: max depth p10 | depth held 10% | mean length |
|---|---|---|---|---|---|---|---|---|
| 4381 α 0.03 (35 k) | 54 → 83 ✓; 32 max, last 34 (§5.4) | 14 → 22 ✓; 22 max, last 31 (§5.4) | 271 → 476 ✓; 25 max, last 34 (§5.4) | 14 → 22 ✓; 15 max, last 33 (§5.4) | 44 → 72 ✓; 33 max, last 34.5 (§5.4) | 8 → 8; last 6.5 | 8 → 8; last 3.5 | 1 055 → 1 995 ✓ (§5.4) |
| 4428 α 0.03 (35 k) | 134 → 178 ✓; 36 max, last 31.5 (§5.4) | 17 → 28 ✓; 27 max, last 34.5 (§5.4) | 342 → 577 ✓; 24 max, last 33 (§5.4) | 17 → 28 ✓; 22 max, last 33 (§5.4) | 90 → 149 ✓; 43 max, last 34.5 (§5.4) | 10 → 10; last 10.5 | 10 → 11 ✓; last 6 | 1 049 → 2 023 ✓ (§5.4) |
| 4428 α 0.03 seed 2 (30 k) | 117 → 162 ✓; 33 max, last 29.5 (§5.4) | 16 → 27 ✓; 24 max, last 30 (§5.4) | 292 → 548 ✓; 22 max, last 29 (§5.4) | 15 → 28 ✓; 17 max, last 28 (§5.4) | 81 → 135 ✓; 34 max, last 30 (§5.4) | 10 → 11 ✓; last 25.5 (§5.4) | 11 → 11; last 12.5 | 916 → 1 746 ✓ (§5.4) |
| 4381 α 0.01 (35 k) | 91 → 172 ✓; 32 max, last 34 (§5.4) | 16 → 29 ✓; 26 max, last 34.5 (§5.4) | 281 → 594 ✓; 24 max, last 34 (§5.4) | 16 → 29 ✓; 20 max, last 34 (§5.4) | 59 → 123 ✓; 35 max, last 34.5 (§5.4) | 10 → 11 ✓; last 32 (§5.4) | 10 → 11 ✓; last 29 (§5.4) | 1 117 → 2 274 ✓ (§5.4) |
| 4428 α 0.01 (35 k) | 80 → 118 ✓; 34 max, last 34.5 (§5.4) | 13 → 20 ✓; 20 max, last 34.5 (§5.4) | 287 → 429 ✓; 22 max, last 35 (§5.4) | 12 → 20 ✓; 15 max, last 35 (§5.4) | 54 → 92 ✓; 30 max, last 34.5 (§5.4) | 9 → 11 ✓; last 34 (§5.4) | 9 → 11 ✓; last 21.5 | 914 → 1 878 ✓ (§5.4) |
| 4428 α 0.03 markers (30 k) | 159 → 300 ✓; 38 max, last 29.5 (§5.4) | 22 → 48 ✓; 41 max, last 30 (§5.4) | 367 → 953 ✓; 23 max, last 30 (§5.4) | 22 → 48 ✓; 22 max, last 30 (§5.4) | 135 → 278 ✓; 55 max, last 30 (§5.4) | 10 → 12 ✓; last 29 (§5.4) | 11 → 12 ✓; last 29 (§5.4) | 895 → 2 019 ✓ (§5.4) |
| drift 4381 (30 k) | 1 → 1; last 3 | 1 → 1; last 3 | 1 → 4 ✓; 3 max, last 20 | 1 → 1 | 1 → 1 | 0 → 0 | 0 → 0 | 105 → 128 ✓ |
| drift 4428 (30 k) | 1 → 1; last 3 | 1 → 1; last 3 | 2 → 2 | 1 → 1 | 1 → 1 | 0 → 0 | 0 → 0 | 111 → 188 ✓ (§5.4) |

The forks, against their unreached twins read at the same 30 000 (classes held 10% · essential genes 10%, bar → last;
"§5.4" as above):

| world, α | unreached (4 096) | reached (1 024) |
|---|---|---|
| 4381, 0.03 | 50 → 73 ✓ (§5.4) · 12 → 21 ✓ (§5.4) | 50 → 57 ✓ (§5.4, last 24.5) · 12 → 16 ✓ (§5.4, last 27.5) |
| 4428, 0.03 | 118 → 172 ✓ (§5.4) · 15 → 26 ✓ (§5.4) | 123 → 130 ✓ (§5.4, last 29) · 15 → 18 ✓ (§5.4, last 26) |
| 4381, 0.01 | 84 → 154 ✓ (§5.4) · 15 → 26 ✓ (§5.4) | 94 → 96 ✓ (§5.4, last 29.5) · 14 → 16 ✓ (last 18.5) |
| 4428, 0.01 | 64 → 101 ✓ (§5.4) · 11 → 17 ✓ (§5.4) | 64 → 87 ✓ (§5.4, last 30) · 11 → 14 ✓ (last 19) |

- **Every count lane at the unreached cap passes the rule and §5.4 on every unbounded key**: classes held, essential
  genes held, the top solver's count-bearing bytes and load-bearing genes, and the minimum's classes, in both worlds,
  at both α, in both seeds and with markers, with 15–55 persistent new maxima per series and the last at
  28 000–35 000. Depth and max depth p10 pass in some lanes and stand in others: they sit at 8–12 on a scale that ends
  at 13. Drift passes on length only (and once on a 1 → 4 count-bearing reading).
- **The rule and §5.4 do not tell a creep from a climb.** The reached-cap forks also pass both on classes held, by
  +2 to +7 classes over their bar (4428 α 0.01: +23, because its cap came at 17 000, after the bar was set), with new
  maxima one class at a time in the final quarter. What separates the two is the size of the late rise: 46–83% above
  the bar unreached against 2–14% reached at 30 000 (the 4428 α 0.01 pair: 58% against 36%), and the final-quarter
  gain (§13.5). A sweep must pre-register a magnitude, not only the count of maxima.
- **None of this meets §5.1 clause 6**: 30 000–35 000 epochs are about 2 500 generations (T_gen 12–14), against
  10⁶ epochs asked.

**The predictions** (`prior8.md`): the fork at 11 000–15 000 (11 521–14 883 ✓); cap 4 096 unreached by 30 000 (✓,
mean length 1 650–2 070 at 30 000, a little below the 2 000–2 400 predicted); the capped lane creeping within ~2 000
epochs of the cap (✓); the unreached lanes "still rising at 20 000, slowing by 30 000" (✓ for classes held, whose final-quarter slope is below
the second quarter's in all six lanes; ✗ for essential genes and code, which keep their pace), §5.4 failing on
essential genes in at least one lane (✗, it passes in all); α 0.01 between free and α 0.03 on repertoire (✓ on 4428,
✗ on 4381, where it holds twice α 0.03's); drift at the base level with ECHO alone (✓); markers cutting the frameshift
(✓) with repertoire within the seed spread (✗: nearly double, §13.8).

### 13.10 What pilot 8 says

1. **With the cap out of reach, the climb goes on late.** On the machine pilot 7 assembled (strict out-count, the
   genes machine, the growable channel, staged fidelity at α 0.01–0.03), every one of six count lanes on two worlds,
   two α and two seeds is still making persistent new maxima in classes held by a tenth, essential genes held by a
   tenth, the top solver's count-bearing bytes and load-bearing genes, and the minimum's repertoire, in the final
   quarter of 30 000–35 000 epochs, while drift holds one class. In §5.1 clause 4's terms this is the first pass in
   this study on both the function side and the program side, at a cap the run does not reach. A pilot, not a
   finding: two worlds, one seed for five of six cells, 2 500 generations.
2. **The room is what it runs on.** The same run with its cap lowered to 1 024 at the fork flattens within a few
   thousand epochs; the unreached twin holds 1.15–1.6 times its classes at 30 000 and is still adding. Length is
   selected (33–50 bytes every thousand epochs against drift's 0–2), and the code and the genes grow in proportion to
   it (a quarter to a third of the bytes count-bearing; one essential gene per 65–90 bytes).
3. **The climb is linear in length on the program side and slowing on the function side.** Each new gene adds fewer
   new classes (classes per 1 000 bytes fall by a third over the run), and the final quarter's gain in classes held is
   below the second quarter's in every lane read at 30 000. Nothing composes: genes sit side by side, as in pilots
   5–7.
4. **Fidelity keeps up until its menu ends.** At α 0.03 the top lineage's substitution load stays near α (median
   0.036) while its code doubles; the top tape reaches the floor of the staged range (×1/32) at 21 500–28 000 epochs
   (α 0.01: 6 000–10 000), after which the balance gives way and the load will grow with code toward the
   error threshold, near 15 000 bytes at this density. The frameshift is the larger share of a load (0.055–0.13 a
   generation) far below ln σ.
5. **Markers cut the frameshift by 40% and doubled the level**, but they also hand each short gene a full emit budget,
   so the probe does not show that the frameshift was holding the climb back.
6. **The rise rule and §5.4 pass on a creep too.** The reached-cap forks pass them by a handful of classes; a rise
   sweep needs a pre-registered magnitude or a paired contrast with a capped twin.

### 13.11 Recommendation

**Engineer this machine into the engine and run a pre-registered rise sweep**, as a sweep of whether the late climb at
an unreached cap is general across parents, against controls that remove the drive, the room and the selection. It is
the first machine in this study whose climb is still going in the final quarter on both sides of the map in every lane,
and the forks give a clean, cheap control for room. Say plainly in the pre-registration what it cannot show: the climb
runs on length and cost grows with length, so no affordable horizon reaches §5.1 clause 6's 10⁶ epochs on this machine
(at ~45 bytes a thousand epochs a 10⁶-epoch tape would be ~45 000 bytes); the sweep can show "sustained to 60 000
epochs at an unreached cap", not open-endedness.

**Engine slice** (one PR, every field 0 = off, refused without the initiator economy and `meta_draw: isa`):
- the growable metabolism channel: `meta_max_len` (validation lifted to 8 192), `meta_init_len: 32`, `meta_min_len: 8`,
  `meta_dup: 0.05`, `meta_del: 0.05`, `meta_seg_max: 16` (appended duplicate, uniform deletion, as §9.10);
- the genes machine: `meta_genes: 32` (each 32-byte segment at a fixed offset run alone on its own 64-byte buffer,
  16 emits, 4 096 steps; the union credited);
- strict out-count: `predation: count`, `predation_transfer: 8192`, `predation_loss: 0.5`, `predation_every: 8`, and
  `predation: shadow` (§5.1 clause 5: the same transfers between random pairs, eaten by a coin at
  `predation_shadow_rate`, no assay read);
- staged costly fidelity: `meta_fid_max: 16`, `meta_fid_rate: 0.05`, `meta_fid_alpha: 0.03`, rate ×8 · 2^(−f/2), the
  initiator's price 8 192 · 2^(αf/2), f ∈ [0, max] from 0; the level is world state (hashed, snapshotted with the
  tape);
- observables on the sampled cells, every `sample_every`: classes held by a tenth (exists), **essential genes held by a
  tenth**, classes per computing cell p10, max depth p10, mean and max meta length, the level's p10/p50/p90, meta
  diversity (exists), eat rate. Offline on stored worlds (fifth decile and last): the top solver's count-bearing bytes
  and load-bearing genes, and U_sub.
- **Not in the slice:** markers (§13.8: a budget confound), Ohno duplication, free or symmetric fidelity (§12.5).

**The sweep** (`rise-genes`, a descendant sweep): **30 parents**, the reach-cap128 radius-4 eligible parents with the
lowest run ids, each from its terminal world at 20 000 (`own_tape`, nothing computing at descent), the bundle above
plus §4.4's (`tasks: logic4`, `task_reward: 0`, `logic_nand: stack`, `meta_rate: 8/8192`, `meta_seed: own_tape`,
`task_max_outputs: 16`); seed 6201, one per parent; **60 000 epochs past descent**; four arms:
- **count** — `predation: count`, `meta_max_len: 8192` (pilot length at 60 000 projects to 2 700–3 600 bytes, so the
  cap is unreached by a factor of 2);
- **capped** — the same, `meta_max_len: 1024`, same seed (identical to *count* until a tape needs room past 1 024, as
  pilot 8's forks showed: the paired control for room);
- **shadow** — `predation: shadow` at `predation_shadow_rate: 0.33` (the pilot's α 0.03 eat rates 0.24–0.37),
  `meta_max_len: 8192`;
- **drift** — `predation: off`, the same channel, assay and fidelity.

**Keys**, pre-registered, one-sided sign tests over discordant parents at p < 0.05; "late rise" on a series means the
rule passes, §5.4 passes (≥ 3 persistent maxima, the last in the final quarter, 45 000–60 000) **and** the
last-decile median exceeds the bar by at least 20% (pilot: 33–89% unreached at the horizon; 2–14% in the capped forks
whose cap bound before the bar was set, 36% in the one whose cap came after it):
- *H-rise* (count against drift): late rise in **classes held by a tenth**. Predicted **shown** (pilot 6 of 6 against
  0 of 2).
- *H-rise-genes* (count against drift): late rise in **essential genes held by a tenth**. Predicted **shown**.
- *H-room* (count against capped, paired by parent): the **final-quarter gain** in classes held by a tenth (lower
  median of its last five samples minus that of its first five) larger unreached. Predicted **shown** (pilot 3 of 4 at
  30 000; the fourth, 4428 at α 0.01, paused from 23 000 and climbed again by 35 000).
- *H-shadow* (count against shadow): *H-rise*'s outcome. Predicted **shown** (the shadow arm is unpiloted: the one key
  whose prediction rests on §4's argument alone).
- *H-driven* (count against drift): late rise in **classes per computing cell p10** (McShea's minimum on the
  unbounded key). Predicted **shown**.
- Read apart: the final-quarter against the second-quarter slope (predicted lower: the function side slows), classes
  per 1 000 bytes (predicted falling), the top solver's count-bearing bytes and U_sub (predicted near α until the level
  reaches f = 16, then rising), the level's distribution, meta diversity, depth (predicted at 10–12, not a key).

**Cost on the mini-pc's 12 slots.** On this Mac, under load, a count lane cost 51–62 CPU-ms an epoch averaged over
35 000 epochs and about 67 at 1 500–2 100 bytes, rising roughly linearly with length; extrapolated to 3 000 bytes at
60 000 epochs, about 60 ms averaged over a 60 000-epoch count child, 45 for a capped child, 20 for drift and about 30
for shadow. At §4.4's mini-pc ratio (about 3.7 times the Mac's unloaded rate; this Mac was loaded, so 2.5–3.7 times
these figures): **count 2.5–3.7 h, capped 1.9–2.8 h, shadow 1.3–1.9 h, drift 0.8–1.2 h a child**, so 6.5–9.6 h a
parent, **195–290 run-hours for 30 parents, 16–24 hours of the 12 slots**. Without shadow 13–19 hours. Before it
launches, time one count child to 10 000 epochs on the mini-pc and rescale.

**Before the sweep, cheap and optional:** a budget-matched marker probe (each gene's emit budget proportional to its
length) to read whether markers' doubling is the frameshift or the budget; if the frameshift, markers join the sweep
as a fifth arm.

**Files.** Pilot 8's material was pilot artefacts and was not kept: the throwaway engine copy (`META_LEN_MAX` 4 096,
the marker-defined genes and their fixed-array memo, with the pilot crate's marker, fork, target and lane options, the
marker solver line, the full bearing reading and the `load` reader's options) and its `pilot8_bin` binary, every census
row of every pilot-8 run (with the commonest tapes, the gene solver, `#fit` and `#fid` lines; a fork's file carried the
shared history, then the fork), the scripts behind the readings and every table above (`analyze8.py`: blocks, last
census, rise rule, §5.4; `late8.py`: final-quarter maxima and slopes; `compact8.py`, `sigma8.py`, `load8.py` and its U
readings), the predictions (`prior8.md`) and what was decided when (`decisions.md`), the replay and fork checks (0
differences each; their outputs were deleted after reading), the launch, status and CPU-logging scripts and their
per-process CPU, this study as it stood before pilot 8's edits, and the drafts.

## Sources

The programme: `docs/DESIGN.md` §1.1–§1.4; `docs/design_record.md` from 2026-09-24 ("Where the programme stands after
sweeps 9 and 10") to 2026-10-03 (the reach-cap128 finding); `app/models/findings/registry.rb`; `docs/studies/
metabolism.md`, `logic.md`, `meta-stack.md` (§1–§2, §4, §7), `topless.md`; `research/landscape/README.md`;
`research/minnand/README.md` and `data/minnand4.bin` (the per-depth class counts of §1.2 and §4.1 were computed from it
here).

The literature, as verified in §3 (DOIs and arXiv ids there):
- Avida: Lenski, Ofria, Pennock & Adami 2003 (*Nature* 423:139); Cooper & Ofria 2002 (ALife VIII); Chow, Wilke, Ofria,
  Lenski & Adami 2004 (*Science* 305:84); Zaman, Meyer, Devangam, Bryson, Lenski & Ofria 2014 (*PLoS Biol*
  12:e1002023); Wagner, Zaman, Dworkin & Ofria (arXiv 1310.1369); Adami, Ofria & Collier 2000 (*PNAS* 97:4463);
  Dolson, Vostinar, Wiser & Ofria 2019 (*Artificial Life* 25:50, MODES).
- Tierra: Ray 1991 (ALife II); Ray 1998 (*Complexity* 3(5):25); Ray & Hart 2000 (ALife VII); Standish 2003 (arXiv
  nlin/0210027); Taylor 2014 (arXiv 1407.5719). Amoeba: Pargellis 1996 (*Physica D* 91:86), 2001 (*Artificial Life*
  7:63).
- Geb: Channon 2006 (*GPEM* 7:253), 2019 (*Artificial Life* 25:134). PolyWorld: Yaeger, Griffith & Sporns 2008
  (arXiv 1112.4906).
- Chromaria: Soros & Stanley 2014 (ALIFE 14). MCC: Brant & Stanley 2017, 2019, 2020 (GECCO).
- Lenia: Chan 2019 (arXiv 1812.05433), 2023 (arXiv 2304.05639); Flow-Lenia: Plantec et al. 2023 (arXiv 2212.07906),
  2025 (*Artificial Life* 31:228).
- Soups: Agüera y Arcas et al. 2024 (arXiv 2406.19108); Knierim et al. 2026 (arXiv 2607.01483); Cicala et al. 2026
  (arXiv 2607.09211); Jha et al. 2026 (arXiv 2609.10817).
- Arms races and coevolution: Hillis 1990 (*Physica D* 42:228); Dawkins & Krebs 1979 (*Proc R Soc B* 205:489);
  Ficici & Pollack 1998 (ALife VI); Watson & Pollack 2001 (GECCO); Cartlidge & Bullock 2004 (*Evol Comput* 12:193);
  Seoane & Solé 2023 (*PRE* 108:044407).
- Niche construction: Odling-Smee, Laland & Feldman 2003; Taylor 2004 (ALife IX). Code-reading predation: Hickinbotham
  et al. 2016 (*Artificial Life* 22:49, Stringmol). Computed food: Gerlee & Lundh 2010 (*Evolution* 64:2716).
- Open-endedness tests: Bedau, Snyder & Packard 1998 (ALife VI); Taylor et al. 2016 (*Artificial Life* 22:408);
  Packard et al. 2019 (*Artificial Life* 25:93); McShea 1994 (*Evolution* 48:1747); Hintze 2019 (*Artificial Life*
  25:198).

