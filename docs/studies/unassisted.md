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

