# Design study: does the climb keep going? A ladder without a near top

2026-10-02. A design study. It seeds nothing and touches neither the repository nor the lab: the lab was read
with SELECTs only (one of them fetched a stored snapshot of a running Meta-stack child to a session scratchpad).

Every number marked *pilot* comes from a throwaway copy of main's engine (`ee180b3`) in a session scratchpad, not
kept, and is not a finding. The copy added two assay-only modules, `logic3.rs` (three inputs) and `logic4.rs` (four
inputs), and a switch in `pay_tasks`; nothing else in the soup moved. The tools lived beside it:

- `minnand/`: exact minimal NAND circuits for all 256 functions of three inputs, two independent ways;
- `minnand4/`: the same enumeration for the 65 536 functions of four inputs, exact to 10 gates;
- `topless/`: the separating-rule check, cheap-tape check, exhaustive short programs (`minprog`), re-expression of
  stored worlds, substitution neighbourhoods (`paths`, `tpaths`), the ancestry of a deep solver (`ancestry`),
  load-bearing bytes (`bearing`), and the pilots (`pilot`, `pilot4`).

The material was pilot artefacts and was not kept: the engine copy, the tools, their raw outputs (the `*.txt`
files named below and `pilot/`) and the copied worlds. The minimal-NAND tables are preserved and checked
against the study's outputs in `research/minnand/`, the four-input one extended past 10 gates (exact to 13 but for
604 functions left at 13 or more); see its README.

## 0. In brief

1. **The ladder.** All 256 Boolean functions of three inputs, read as 78 rungs: ECHO plus Avida's Logic-77 tasks
   (the 9 two-input classes and the 68 three-input ones, each a function up to a permutation of its inputs).
   - Depth is the exact minimal NAND count, computed here and checked two independent ways. It runs 0–10; EQU's 5
     is passed by 117 functions (42 of the 68 three-input classes). The top is one function, "exactly one of
     three", at 10 NANDs; XOR3 is 8, the full adder 9.
   - z sits on the byte left of y, `B[2L−3]`. On a live Meta-stack child's world every one of the 8 138 XOR cells
     and 7 965 EQU cells keeps its credit.
   - Three random whole-byte cases, redrawn until all 8 input combinations appear among the 24 bit columns: 66 %
     of draws separate. A slot's truth table is read off those columns, so crediting is one pass per slot.
   - Units ×√2 per NAND at a `task_reward` of 1 024, so the economy's ×8 income range is not saturated below the
     top. `logic_depth_max` is a 256-byte table lookup per credited slot.
2. **But the three-input top is near for this machine.** *Pilot*: from that Meta-stack child's world, the ladder
   went from depth 5 to **9**.
   - Seed 2001: the first depth-9 cell came at 1 650 epochs, and 9 was held at a tenth from 3 500 to 40 000. Rungs
     6–8 were never held on the way.
   - Seed 2002: 6 at 2 500, then 9 at 4 500, held to 10 000.
   - Neither ever showed 10, the top.
3. **The honesty answer: depth comes in lumps.** Under the stack NAND a loop's later laps compute deeper
   functions with the same bytes.
   - Measured on the shortest straight-line programs and on the commonest evolved tapes, one or two substitutions
     add at most one or two NANDs, and almost never (0–0.6 % of doubles).
   - The lineage that reached 9 did not climb that way. It went 5 → 4 (a credit loss) → **8 in one substitution**
     (a loop's closing `]` became `<`, merging two loops) → 9.
   - So depth is neither ladder height (seed 2001 never held 6–8; seed 2002 held 6 and skipped 7–8) nor a count of
     steps. It is what the lap
     structure computes. A read of `logic_depth_max` alone cannot say "accumulated".
4. **What would count as "keeps rising".** Not a threshold: the pilot passed Lenski's 5 by a single
   reorganisation. It is repeated, persistent increases late in a long run, on a ladder whose top no single
   reorganisation reaches, read beside a program-side measure. Over the 4→8 jump the load-bearing bytes of the
   deepest solver went 14 → 20.
5. **The test (§3).** H-rise, on the nested four-input ladder (w at `B[2L−4]`; every three-input solver keeps its
   depth), descended from Meta-stack's deep children, rise against none and against a depth-capped control.
   - Pre-registrable once the four-input cost table is exact past 10. Today it is exact to 10 for 46 491 of the
     65 536 functions; the remaining 29 % need exact synthesis, an engineering slice.
   - 100 000 epochs, three arms on 54 parents, ≈ 23 h of the 12 slots; 200 000 epochs ≈ 46 h.
6. **Pilots** (≈ 1.1 core-hours, §4):
   - **From the Logic pilot world 1007** under the Meta-stack bundle, from scratch: the ladder reached depth 5
     (three-input classes) by 5 000 epochs and held 5 to 40 000. Of about 85 000 double substitutions of each of its
     commonest solvers, one reaches 7 and none reaches anything else above 5.
   - **From the Meta-stack child:** 9, in both seeds.
   - **The same world on four inputs:** it lost the three-input 9 within 500 epochs, then re-climbed on genuinely
     four-input classes, 4 → 8 at 5 000 and 9 at 10 000, and held 9 to 20 000. A depth above 10 was credited on
     single draws but never held.
   - **Did depth climb past 5?** Yes, from every deep start, by jumps of 3–4 NANDs. Then it stopped at 9 on both
     ladders for the rest of the runs (36 000 epochs in the longest). One world, pilot only.
7. **Live Meta-stack interim** (§5, 09:04Z, 28 of 162 children with settled samples), labelled interim; nothing is
   claimed.
   - **meta-stack:** 3 of 10 children hold `logic_capability_deep` = 2 (XOR and EQU) in their latest samples. All
     three are from parents 944 and 967, and each first reached the deep rungs 1 650–2 300 epochs past descent.
   - **meta-stack-deep-only:** 0 of 9.
   - **meta-inplace:** 0 of 9.

## 1. The ladder (question 1)

### 1.1 The minimal-NAND table for three inputs, computed and checked

**Method.** A truth table is 8 bits, with bit k = f(x, y, z) at x = k>>2, y = k>>1 & 1, z = k & 1, so x = 0xF0,
y = 0xCC and z = 0xAA. The cost of f is the fewest 2-input NAND gates, fan-out free, that compute it from x, y and z.
NOT a = NAND(a, a) is one gate, as the logic ladder counts it (`logic::LOGIC_TASKS.nands`: AND 2, OR 3, NOR 4,
XOR 4, EQU 5).

- **Method 1, canonical circuits** (`minnand 10`). Every circuit whose gates' operand pairs (max, min) strictly
  increase, and whose every gate computes a function not already present.
  - A minimal circuit computes no function twice, and its greedy topological order is canonical. So the first size
    at which f appears is exact.
  - 2.7 × 10⁹ gates were placed to 10 gates (40 s). All 256 functions are reached.
- **Method 2, independent** (`minnand 9 9`). A breadth-first search over the *sets* of functions a circuit has
  computed, with no ordering trick: 22.7 M distinct sets at 9 gates.
- **Agreement.**
  - The two methods agree on all 256 functions: equal cost wherever the cost is ≤ 9, and the one function method 1
    puts at 10 is absent from every set of 9.
  - Every witness circuit was re-evaluated in Rust and, independently, in Python (80 of 80 P-class witnesses).
  - Free constants 0 and 1 change no non-constant function's cost.
  - The four-input enumeration (`minnand4`, a separate implementation) gives every three-input function the same
    cost (0 mismatches of 256).
  - It reproduces the textbook values: XOR 4, XNOR 5, the full adder (sum and carry together) 9.

**A correction to the brief's framing.** NAND cost is invariant under input permutation only, not under the NPN
group, because a negated input or output costs a gate.
- NAND3 (3), AND3 (4), OR3 (6) and NOR3 (7) are one NPN class.
- Across the 14 NPN classes the cost spread within a class is up to 4.
- So the table is per function, or per P-class (80 classes), not per NPN class.

**The table** (`minnand_10.txt` has every P-class with its witness):

| cost | functions | three-input P-classes (Avida's 68) | examples |
|---|---|---|---|
| 0 | 3 | — | x, y, z (ECHO) |
| 1 | 6 | — | NOT, NAND |
| 2 | 13 | 1 | AND, ORN; ¬x ∨ (y ∧ z) = NAND(x, NAND(y, z)) |
| 3 | 26 | 5 | OR, ANDN; NAND3; x ∧ (y ∨ z); x ∨ (y ∧ z) |
| 4 | 43 | 9 | NOR, XOR; AND3; MUX (x ? y : z) |
| 5 | 48 | 11 | EQU; 11 three-input classes |
| 6 | 53 | 16 | OR3; MAJ3 (the carry); x XOR (y ∧ z); x ∧ (y XOR z) |
| 7 | 36 | 12 | NOR3; MIN3; x XOR (y ∨ z); x ∨ (y XOR z) |
| 8 | 22 | 10 | XOR3 (parity); ALL-EQUAL |
| 9 | 5 | 3 | XNOR3; XNOR3 ∧ ¬(x ∧ y) (3 functions); XNOR3 ∨ (x ∧ y ∧ z) |
| 10 | 1 | 1 | exactly one of x, y, z (0x16) |

- **The constants** cost 2 (1) and 3 (0), and are never rungs.
- **Read-once.** 20 of the 68 three-input classes are read-once (each input used at most once over AND, OR and
  NOT). They cost 2–7. The other 48 cost 4–10.
  - This matters for the in-place NAND, under which every rung any soup climbed was read-once (meta-stack.md §2.4).
  - Under the stack NAND, read-once is no barrier (§2).
- **Formula versus circuit.** A NAND *formula* (no internal sharing) costs more than the circuit for 48 of the 80
  classes. XOR3 is 14 as a formula against 8 as a circuit, and the top function 13 against 10. Fan-out is where
  the depth lives.
- **Multi-output.** One circuit holding both XOR3 and MAJ3 (the full adder) is 9 gates, against 8 + 6 singly. XOR
  with EQU is 5.
- **Four inputs, exact to 10 gates** (`minnand4_10.txt`, 9 min). By cost 0–10 the counts are 4, 10, 31, 98, 293,
  807, 2 067, 4 351, 8 941, 13 085 and 16 804 functions, and **19 045 functions (29 %) cost more than 10**.
  - Among them are XOR4 and "exactly one of four".
  - The four-input maximum is not known here. The counts suggest 13–14.

### 1.2 The candidates

The current assay (DESIGN §1.1, the logic assay) puts x at `B[2L−1]` and y at `B[2L−2]` of a buffer that is the
tape and as many zeros, runs it with both heads from byte 0, and credits a rung when one of four output slots holds
one of the rung's forms in all three cases.

**(a) All three-input functions (recommended as the first slice; §1.5 says why it is not enough alone).**

- **Inputs.** z on `B[2L−3]`, the byte left of y: `<<<` reaches it, as `{{{` does for head1. Nothing else moves.
  - *Measured* on the stored world of Meta-stack child 4845 (stack NAND, epoch 31 900; `reexpress_ms4845.txt`).
    Under the three-input assay, on all six fixed sets, the cells credited XOR keep XOR (8 138 of 8 138) and those
    credited EQU keep EQU (7 965 of 7 965). Of the 12 561 cells holding any rung above ECHO, 12 554 keep one.
  - The same holds with z at `2L−4` or `2L−5`.
  - The likely reason: an evolved stack circuit writes the byte z now occupies before it reads it.
  - Where a tape did read that byte as a zero, its meaning changes. The 1007 world's commonest own-tape metabolism
    tape `·{····<·[.·····~····.<··~····~·!` is credited OR(y, z) under three inputs (2 149 cells at descent).
- **The separating draw.** Three cases of whole random bytes (x, y, z), drawn on `STREAM_TASK`, redrawn until:
  - each input's three values are pairwise distinct;
  - **all 8 input combinations appear among the 24 bit columns.** A slot's truth table is then determined, so no
    two of the 254 non-constant functions expect the same outputs;
  - no non-constant function's three outputs are equal (no constant passes);
  - no non-projection function sits a constant offset from an input (no input plus a constant passes, ECHO
    included).
  - *Measured* over 200 000 raw draws (`sepcheck.txt`): **66 %** separate. Coverage fails 30 %, distinctness 3.5 %.
    Given coverage, the other clauses almost never fail.
  - The rule is total with the bounded redraw and a fixed fallback set, as today.
- **Credit.** Per slot, read the truth table off the 24 columns, one pass and no table of forms:
  - a column that contradicts another credits nothing (the output is not a bitwise function);
  - a constant credits nothing;
  - otherwise the slot credits its function's P-class.
  - A tape is credited at most four classes. A cheap-tape check is in §2.1.
- **Rewards:** §1.3.
- **`logic_depth_max`:** §1.4.
- **Top:** 10 NANDs, twice EQU. But the top is thin (5 functions at 9, 1 at 10), and the pilot first reached 9 at
  1 650 epochs (§4).

**(b) Four-input functions, sampled.**

- **Inputs.** w on `B[2L−4]`, nesting the ladders: two-input ⊂ three-input ⊂ four-input, each new input one byte
  further left.
  - *Measured* on the pilot world at depth 9 (`reexpress4_pBr_end.txt`): every cell at three-input depth 9 keeps
    depth 9 under four inputs (3 605 of 3 605), and so do 853 of 993 at depth 8.
- **The draw.** Random coverage of 16 combinations by 24 columns is 0.55 % (64 columns, eight cases, would reach
  77 %). So the draw is *designed*:
  - cases 0 and 1 hold each of the 16 combinations in exactly one of their 16 bit columns, a random bijection;
  - case 2 is random;
  - distinctness is checked as above.
  - The constant and offset clauses cannot be held over 65 534 functions. About one function per draw has three
    equal outputs, and about four sit an input plus a constant, so redrawing would accept under 1 % of draws.
  - They move from the draw to the slot: a slot whose outputs are equal, or an input plus one constant, is credited
    nothing, whatever function it matches.
- **Depth.** Exact to 10 today. 29 % of functions are deeper.
  - "Sampled" can mean the rungs whose cost is known, plus a top bin. A top bin at 11 is a near top again: one
    reorganisation away from where pilot B already stands.
  - To be topless in practice the table must be exact to the four-input maximum. That is enumeration to 11–12 gates
    (about 1.5 h and 15–20 h on this Mac, by the ×11 from 9 to 10 gates), or SAT-based exact synthesis per P-class (3 984
    classes; no solver is installed here). This is one engineering slice before any sweep.
- **Rewards:** flatter than (a), §1.3.
- **Cost:** a 64 KB table, the same slot pass over 16 combinations, and a draw about a millisecond slower.

**(c) Compositions: parity or majority of k inputs, AND_k.**

- **Inputs:** k bytes leftward from `B[2L−1]`.
- **The draw.** The family members are few, so separating them is easy. Coverage of 2^k combinations is impossible
  past k = 4 with 24 columns, but the family need not be covered.
- **The NAND counts:**
  - parity: 4 (k = 2), 8 (k = 3), more than 10 (k = 4; 12 by the chain);
  - majority: 6 (k = 3), more than 10 (k = 4);
  - AND_k: 2, 4, 6.
- **Why not.** It is the least honest candidate on this machine.
  - The ladder is sparse: parity_{k+1} is 4 NANDs past parity_k, with nothing paid between. So each rung is a
    4-step valley unless the intermediates are paid, and then it is (a) or (b).
  - Under the stack NAND, one XOR-accumulating loop over the input window computes parity of any k with the same
    bytes. The count rises with no new code, exactly the lumping of §2.3, made systematic.

**(d) Multi-output tasks.**

- **Inputs:** as (a).
- **Credit:** a *set* of slots, paid by the multi-output circuit size (the full adder 9, against 14 singly).
- **Why not.**
  - Breadth then pays as depth does, and the reading conflates them.
  - Exact multi-output costs for sets of up to four three-input functions need circuits of 12 or more gates. That is
    an hour's enumeration per size step, and the top is still bounded, near the four-input single-output top.
- **Where it belongs:** better reported than paid. The number of distinct classes a solver holds is a free
  descriptive reading under (a).

### 1.3 What the economy allows: how rewards scale with depth

Under the `initiator` payer a cell initiates at most once per epoch, for `max_steps` = 8 192, and earns the influx
of 1 024 per epoch plus `task_reward × units / task_every`.
- Income above 8 192 per epoch buys nothing.
- So **the whole economy spans a factor of 8**, from an unpaid cell to a cell that initiates every epoch.
- The current ladder nearly fills it. A NOT + XOR + EQU cell earns 25 units at 2 048, 7 424 per epoch, which is 91 %
  of saturation.

A topless ladder must therefore spread ×8 over about 10 levels for three inputs, and about 14 for four. Selection
for one more NAND in one slot (other slots holding ECHO + NOT + XOR) works out as follows:

| units by cost | reward | saturates at | s for 5→6 | 6→7 | 7→8 | 8→9 | 9→10 |
|---|---|---|---|---|---|---|---|
| ×√2 per NAND: 1, 1, 2, 3, 4, 6, 8, 11, 16, 23, 32 | **1 024** | 56 units | 0.10 | 0.14 | 0.20 | 0.23 | 0.24 |
| the same | 2 048 | 28 units | 0.12 | 0.17 | 0.24 | 0.23 | **0** |
| linear, cost + 1 | 1 024 | 56 units | 0.05 | 0.04 | 0.04 | 0.04 | 0.04 |
| linear, cost + 1 | 2 048 | 28 units | 0.06 | 0.05 | 0.05 | 0.05 | 0.05 |

**Recommended for (a): ×√2 per NAND, summed over the distinct classes a tape holds, at a `task_reward` of 1 024.**
- s stays at 0.1–0.25 per NAND to the top, and saturation needs the two deepest classes at once (32 + 23).
- Breadth trades evenly with depth at 2 NANDs a slot, and is capped at four slots.

For (b), ×1.25 per NAND (the pilot's 1, 1, 2, 2, 3, 4, 5, 6, 8, 10, 12, 15).

**A measured cost of that choice** (*pilot*, §4). Switching a Meta-stack world from its own pay (deep against
shallow income about 5 : 1) to ×√2 at 1 024 (about 2 : 1) cut the deep solvers' share within 500 epochs in every pilot
that started there: 49 % → 16 % (B), 49 % → 18 % (B′), and 22 % → under a tenth (pilot 4).
- At the metabolism tape's ×32 rate, a deep tape is held by selection against a steady loss of load-bearing bytes,
  so halving the income ratio lowers the equilibrium share.
- The climb went on regardless: all three re-climbed to 9.

**The economy cannot do both.** A 5 : 1 income ratio between deep and shallow cells, inside a ×8 range, leaves
×1.6 for every level above, about ×1.1 per NAND over five more levels. Logic's 2 048 with its doubling units
saturates a cell already at XOR + EQU (24 of 28 units). The ways out are:
- **(i) ×√2 at 1 024**, as piloted: deep shares fall, depth still climbs.
- **(ii) `energy_influx` 512**, which doubles the range to ×16. The unpaid arm then needs its own children, since
  it is no longer Logic's none.
- **(iii) A lower `meta_rate`** (×8 instead of ×32), so weaker selection suffices to hold a deep tape. That moves
  the very supply the Meta-stack study raised on purpose.

This study recommends (i), the one piloted. The record entry has to choose; (ii) and (iii) are untested here.

### 1.4 How `logic_depth_max` is computed

`logic_depth_max` is the minimal NAND count of the deepest rung held at a tenth.
- **Tables.** A 256-byte `COST` table (65 536 bytes for four inputs), and a P-class table built once from the six
  (or 24) input permutations.
- **Per sample.** The existing 256 cells, drawn with replacement on `STREAM_TASK | 3`, on fresh cases, each distinct
  tape assayed once (`Memo`):
  - each credited slot gives a truth table in one pass over 24 columns;
  - tally the cells per class (80 counters, or a hash map for four inputs);
  - `logic_depth_max` = the maximum `COST` over classes credited to at least 26 of 256 cells. −1 if none is,
    because ECHO alone is depth 0.
  - Companions at no extra cost: `logic_depth_classes` (classes at a tenth), and the count of classes at a tenth
    above depth 5.
- **Cost.** *Measured*: one three-input assay of a 32-byte tape on one case set takes about 1 µs.
  Re-expressing 8 203 distinct tapes on 24 case sets each took 0.21 CPU-s. So the 256-cell sample is well under
  a millisecond against a 10-epoch sample interval.
- **The program-side companion of §2.4** (load-bearing bytes of the dominant deepest solver: 32 positions × 13
  symbols × 6 sets, about 2 500 assays) is about 3 ms. It is cheap enough per sample, or per stored world offline.

### 1.5 Recommended ladder

The nested ladder (a) → (b), built in that order:

1. **Slice 1:** z at `B[2L−3]`, the three-input draw and the truth-table credit, the 78 rungs and the cost table.
   Units ×√2 per NAND, at the sweep's reward (1 024 as piloted; §1.3). A new value of `tasks` (say `logic3`), with
   `logic_nand` and the metabolism tape accepted as under `logic`.
2. **Slice 2:** the observables: `logic_depth_max`, `logic_depth_classes`, and the shares of the two-input rungs.
3. **Slice 3:** w at `B[2L−4]`, the designed draw, the slot-side constant and offset refusals, and `tasks =
   logic4`. It is only worth running with **the four-input table exact to its maximum**, an offline computation
   (1.5–20 h of enumeration, or exact synthesis) that the slice locks as a constant.

The three-input ladder alone is a useful pre-registration test bed. But for the rung-4 question it has a near top:
the pilot first reached 9 of 10 at 1 650 epochs. "Does it keep rising" should be asked on four inputs, where the
pilot re-climbed to 9 and held it for 10 000 epochs with 29 % of functions deeper than 10 still unclaimed.

## 2. The honesty question (question 2)

### 2.1 Short programs per rung under the stack NAND

**Exhaustive straight-line programs** (`minprog 13`, z at `2L−3`): every program of up to 13 bytes over the heads,
both copies and `~`, ending in `!`.
- That is 1.6 × 10¹⁰ prefixes, simulated on truth tables, with a program's own bytes as junk data and every read or
  write of a not-yet-placed byte tracked.
- Every shortest program found was confirmed on the engine's assay, on all six fixed three-input sets (33 of 33).

| cost | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| shortest program, bytes (incl. `!`) | 4–5 | 6–7 | 7–10 | 9–12 | 11–13 | 12–13 (2 of 16 classes) |

- XOR is 12 bytes with `.` in the alphabet: `<<{~~.>{~}~!`, one shorter than the study's 13. EQU is 13.
- 45 classes, all of cost ≥ 5, have no straight-line program of ≤ 13 bytes. On this slope (about 2.2 bytes per NAND)
  the top three-input functions need about 22–25 bytes straight, which fits a 32-byte metabolism tape but leaves
  little neutral room.
- **Loops beat the slope.** The pilot's depth-9 solver `·<.<<[~{0~...,!<{>~]…` has about 20 load-bearing bytes.
  Its four laps emit ORN(z, x), NOT z, XOR(x, z), and on lap 4 the cost-9 function.

**Cheap tapes** (`cheap_5.txt`: all 94 297 programs of ≤ 5 bytes over the ten ops, `!` and `~` that hold an emit,
before a zero tail).
- On all six fixed sets none is credited anything deeper than NOT, under either NAND.
- On one set alone, 149 are credited a depth-4 class and 3 a depth-5 class: masked NANDs of a code byte, e.g.
  `-{~~!`.
- So the three-input rule leaves partial bitwise solvers (a NAND with a byte of the tape is the function on some
  bits), as the two-input rule does. A credit needs every one of the 24 columns right, so a solver correct on a
share p of (bit, combination) pairs is credited with probability about p²⁴. The p³-style argument of the Logic entry
carries over. Fresh cases at each sample and the persistence rule are still needed.

### 2.2 Which rungs are one substitution above which

**From the shortest programs** (`tpaths_minprog.txt`): every single and double substitution over the 14-symbol
alphabet, anywhere in the 32-byte tape, for each of the 33 shortest programs.
- **k = 1.** One program of 33 gains a NAND, `{,{~<<~}~!` (3 → 4), in 1 mutant of 416. No other single gains depth.
- **k = 2.** At most +1 NAND from any start, in 0.3–0.6 % of doubles where it happens at all. From the depth-5 and
  depth-6 programs, no double gains depth.
- **The other direction is easy.** Breaking a program leaves a lower rung or nothing. About a fifth of single
  substitutions lose every rung, and most of the rest keep the depth, so every rung sits one substitution above
  *some* lower rung. That is true and uninformative, as
  meta-stack.md §7.3 found for XOR.

**From the evolved tapes** (`paths_ms4845_k1.txt`, `paths_ms4845_k2.txt`): the three commonest metabolism tapes of
the live Meta-stack child (XOR + EQU loops, depth 5 under three inputs).
- No single substitution gains depth.
- Of 84 000 doubles each, one mutant of one tape reaches 6 (a cost-6 three-input class); the other two tapes reach
  nothing above 5.

So by every local measure there **is** a depth gradient: +1 NAND per two substitutions, rarely, and +2 once (in
pilot A's end world, one double of 85 000 reaches NOR3).

### 2.3 The jump, traced

Pilot B (§4) went from EQU (5) to a cost-9 class in 1 650 epochs. Replayed deterministically with a snapshot every
50 epochs (`ancestry_pB.txt`), the first depth-9 tape's nearest relative at each earlier snapshot was:

| epoch past descent | depth | the lineage's tape |
|---|---|---|
| 0 | 5 (XOR, EQU of x, y) | the start world's EQU loop |
| 1 000–1 300 | 5 (a three-input cost-5 class) | `.<<.<[~{0~...!>]{[]·[+>…`, the loop re-pointed at z |
| 1 350–1 400 | **4** | `.<<.<[~{0~.·.,!]{>~][!+[>…`, a credit **loss** |
| 1 450 | **8** | the same with byte 15 `]` → `<` |
| 1 650 | 9 | three more substitutions |

- **The 4 → 8 step is one substitution.** Confirmed directly (`tpaths` on the depth-4 tape): 2 of its 416 single
  mutants are credited depth 8, one of them the `]` → `<` at byte 15 that the lineage took. Of its 84 000 doubles,
  379 are.
  - The `]` closed a loop `[~{0~.·.,!]`. Made a `<`, it lets the loop run on through `{>~]`, bytes the lineage
    already carried just past the loop, executed once. Each lap now stacks more NANDs, and the fourth emits a
    cost-8 function.
- **The program side moved too, but by co-option, not by new code.** Load-bearing bytes of the lineage (`bearing`:
  positions where at least half the 13 other symbols lose the depth):

| tape | depth | load-bearing bytes |
|---|---|---|
| start EQU loop | 5 | 14 |
| the cost-5 three-input loop | 5 | 16 |
| after the credit loss | 4 | 14 |
| after `]` → `<` | 8 | 20 |
| first depth-9 tape | 9 | 20 |
| for comparison: the shortest straight-line XOR, EQU and a cost-6 program | 4, 5, 6 | 12, 13, 12 |

  The jump made six more bytes load-bearing at once. Code the lineage already carried just past the loop became
  part of the loop body: co-option rather than new code.
- **Depth at a tenth skipped 6, 7 and 8 altogether** (`pilot/pB_ms4845_s2001.txt`). Depth-8 cells (9–102 of
  16 384, solid on six sets) appeared 100 epochs before the first depth-9 cell, and neither 6, 7 nor 8 ever reached
  a tenth.

### 2.4 Is there a depth gradient? What counts as "keeps rising"?

**A gradient exists locally and is not where the climbing happens.** From typical tapes, deep rungs are many
substitutions away. Under the stack NAND, though, a loop can sit one substitution from a reorganisation that adds
several NANDs at once (+4 here), often by co-opting bytes carried neutrally, and sometimes after a credit loss.

So "depth" is neither ladder height (no step through each rung) nor a count of accumulated substitutions. It is the
circuit complexity of the function the soup's lap structure happens to compute. That is a real behavioural
complexity: a 9-gate function is computed. But one read of `logic_depth_max` does not say it was built step by step.

**Lenski's EQU was 5 NANDs** (19 Avida instructions). The pilot passed it within 1 650 epochs, by one
reorganisation. So no fixed depth is evidence of a sustained rise on this machine. "Keeps rising" should mean:
- **repeated** increases of `logic_depth_max`, each **persistent** (k = 5 consecutive samples at a tenth, the Logic
  rule), **late** in a long run (in its second half), on a ladder whose top is not within one reorganisation of the
  start;
- read beside **load-bearing bytes**, so a rise by co-option (bytes constant, depth up) is told apart from a rise
  by new code (both up).

What it is not: passing 5, or reaching any single depth. On three inputs the top is 10, and pilot B stood at 9
after 1 650 epochs, so three inputs cannot show a sustained rise from a deep start. On four inputs (exact costs to
10; probable top 13–14) it can, if the table is made exact. In the four-input pilot the same world re-climbed to 9
and then stood there for 10 000 epochs, which is the question H-rise asks at scale.

## 3. The question and its reading (question 3)

This is a draft for a record entry, to be pre-registered only **if Meta-stack's H-deep-Ms reads shown** and the
four-input table is exact.

**H-rise.** On the nested four-input ladder, does the deepest rung held keep rising in the second half of a long
run when depth is paid, and not otherwise?

- **Parents.** Meta-stack's meta-stack children whose last-decile `logic_capability_deep` is at least 1 (the deep
  children), from their end worlds. Their metabolism tapes keep their credit under the nested inputs (§1.2), so the
  climb resumes where Meta-stack left it.
  - If H-deep-Ms reads shown on fewer than about 10 parents, take all 54 meta-stack children, and read the deep ones
    as a declared subgroup.
- **Arms**, merged over each parent's params:
  - **rise**: `tasks: logic4`, the reward of §1.3;
  - **capped**: the same, with every rung deeper than 5 paid as a depth-5 rung. Lenski's control turned upside down:
    is the rise *paid for*, or does depth drift up by hitchhiking?
  - **none**: reward 0, the drift baseline. At reward 0 the tape is never read, so this is Meta-stack's none
    continued.
- **Seed and horizon.** One seed per parent (the parent is already a (parent, seed) child). **100 000 epochs** past
  the parent, priority 40.
  - In the pilots the jumps came 1 650–10 000 epochs past descent, so 100 000 gives a second half five to thirty
    times that long.
  - 200 000 doubles the cost for no sharper reading of "late".
- **Readings, per child.** Logic's settling window, deciles, lower-middle medians, extinction and relapse rules,
  and the persistence rule for first epochs.
  - **The rise rule.** A child *rises late* when its last-decile median `logic_depth_max` is at least the
    fifth-decile median + 1. It is *ceilinged* when its fifth-decile median is already the table's maximum, read as
    no-rise and printed apart.
  - **Program side.** The load-bearing bytes of the dominant deepest solver, read on each stored world offline with
    the landscape tool, first and last decile.
- **Tests.** One-sided sign tests over discordant pairs at p < 0.05, Logic's machinery:
  - **H-rise** (rise against none): the rise rule. With none at no rise it needs 5 discordant pairs.
  - **H-rise-paid** (rise against capped): the same.
  - **H-rise-code** (rise against none, descriptive unless pre-registered): last-decile load-bearing bytes ≥ first
    + 2.
- **What each outcome means.**
  - **Shown, and H-rise-paid shown.** On a paid ladder with no near top, the deepest feature keeps getting deeper
    late in long runs, and only when depth pays. That is the rung-4 claim on this substrate, "complexity keeps
    rising", under the four imports.
    - It is co-option where load-bearing bytes stay flat, and new code where they rise.
  - **Shown, H-rise-paid refuted.** Depth rises without being paid for. It is hitchhiking on the paid lower rungs,
    not selection for depth.
  - **Refuted or not shown.** The climb stops: the soup takes the jumps a reorganisation offers early and then
    plateaus. That is the open-endedness answer here, a negative one: paid parts buy a deeper feature, not a
    climb.
  - **Most children ceilinged.** The ladder had a near top after all, and the question needs more inputs.
- **Cost.**
  - Meta-stack's arms run at 62–69 s per 1 000 epochs on the mini-pc so far, and Logic's none at 42 (SELECT,
    2026-10-02 08:34Z). A reward-0 arm carrying the tape adds 10–17 % (slice B's measurement), about 47. The
    four-input assay adds about a millisecond per assay epoch.
  - 54 parents × 100 000 epochs × (68 + 68 + 47) s ≈ 990 000 run-seconds ≈ **23 h of the 12 slots**.
    - Without capped: ≈ 14 h.
    - At 200 000 epochs (study §5.7's horizon): ≈ 46 h and 29 h.
    - On about 10 deep parents only: ≈ 4 h.
  - Plus the exact four-input table, offline, and four slices: engine three-input, engine four-input,
    observables, and the sweep and its reading.
- **What is not claimed.** The same four imports as Meta-stack (an objective, a primitive, a hereditary channel, the
  primitive's semantics), plus an imported **ladder** of growing input arity. Rung 4 on Soup stays "not shown".

## 4. Pilots (question 4)

All *pilot*, from the engine copy: 128 × 128 worlds, the Meta-stack bundle (stack NAND, 32-byte metabolism tape,
`isa` draws at ×32, `own_tape` seed where the parent had no tape), the three-input ladder with z at `2L−3`, units
×√2 at reward 1 024 unless stated.

Every 500 epochs every cell is assayed on a fresh separating draw, and a class is "held" at a tenth (1 639 cells).
`depth_sampled` is the proposed observable, 26 of 256 sampled cells, and it agreed with the full census at 178 of
183 readings in A, B and B′. All five disagreements were within 3 500 epochs of descent or on a dip. "Solid" means credited on all six fixed sets. `rep` is the orientation-aware detector share of
the replicating tape over 64 cells.

| pilot | start | epochs | depth held at a tenth (first epoch) | end |
|---|---|---|---|---|
| **A** | Logic pilot world 1007 (epoch 40 000), seed 2001, own-tape metabolism tapes | 40 000 | OR(y, z) 3 at 0; ECHO only 500–2 000 (`rep` fell to 0.34–0.44); NOT at 2 500; 3 by 3 000; **5 by 5 000** (class AB, with 0E/4, EE/3, NOT) | 5 (AB on 8 702 cells); `rep` 0.91 |
| **B** | Meta-stack child 4845's stored world (epoch 31 900, XOR + EQU on 49 %), seed 2001 | 40 000 | 5 at 0; 5 lost by 1 500 (2–4 held); **9 by 3 500** (census), the first depth-9 cell at 1 650; 8 held once, at 6 000, beside 9 | 9 (class 29 on 8 969 cells); `rep` 0.91 |
| **B′** | the same world, seed 2002 | 10 000 | 5 at 0; **6 at 2 500** (class BC, held 2 500–4 000); **9 at 4 500** (class 29 again) | 9 (29 on 7 221 cells); `rep` 0.89 |
| **4** | pilot B's world at 4 000 (depth 9), four-input ladder, units ×1.25, seed 2001 | 20 000 | 9 at 0 (the three-input class, now 0AA5); lost by 500 (2 held); 4 at 1 500; **8 at 5 000** (EABF, a four-input class, with EEEA/6 and 8FFF/4); **9 at 10 000** (08EB, four-input, with 07F0/7) | 9 (08EB on 5 539 cells), solver `<<<<[{~~{~!]…`, a loop from w; `rep` 0.81 |

Notes:
- **Pilot A** held depth 5 at 69 of 81 readings. The dips are draws on which its loop `{,[~!{~>]` exits early.
- **Pilot A's end world** (`paths_pA_end.txt`): from the commonest depth-5 tapes no single substitution gains
  depth. Of about 85 000 doubles each, one mutant of one tape reaches NOR3 (7) and the rest nothing above 5.
- **Pilot B** held depth 9 at 74 of 81 readings, from 3 500 to the end (class 29 on 55 % of cells at 40 000).
  `max_any` never showed 10 after the jump.
- **Pilot B′'s end world** (`paths` on it) holds broken copies of the depth-9 loop. One of its depth-6 tapes, a
  depth-4 tape and an ECHO-only tape are each one substitution from 9. That is the mutational load around a deep
  solver, and the reverse direction of §2.2: it does not show how the soup got there.
- **The proposed sampled observable** (`depth_sampled`, 26 of 256 cells) agreed with the full census at 79 of 81
  readings in A, 79 of 81 in B and 20 of 21 in B′.
- **The reward switch** (§1.3) cost every deep start its deep share in the first 500 epochs, before any climb.
- **Both ladders stopped at 9.** That may be the depth a four-emit loop of the evolved shape reaches; it is
  untested.

**Did depth climb past 5?**
- **From the deep starts, yes:** to 9 in B, B′ and on four inputs, by the lumped route of §2.3, with steps of +3 or
  +4 at the census. Once held, 9 stayed at a tenth to the end of every run, so it is heritable in the plain sense.
- **Then it stopped:**
  - no 10 on three inputs in 36 000 epochs;
  - no held depth above 9 on four inputs in 10 000 epochs, where 19 045 functions are deeper than 10.
- **From scratch (pilot A),** depth reached 5 on three-input classes and stopped there, as Logic's soups stopped at
  NOR.
- **For H-rise,** this is a pilot-level hint toward "takes the jumps early, then plateaus". It comes from one
  world.

## 5. The live Meta-stack sweep, interim (read only; nothing is claimed)

Read at 2026-10-02 09:04Z, with SELECTs only (`interim.sql`). The sweep was 16 finished, 12 running and 134
pending, of 162. Over each child's settled samples (epochs past the parent's + 1 000); "latest" means the latest
tenth of the samples the child has so far, which is not a final last decile.

| arm | children with settled samples | of which finished | `logic_capability_deep` > 0 in any sample | latest-tenth median > 0 | max XOR share | max EQU share |
|---|---|---|---|---|---|---|
| meta-stack | 10 | 6 | 3 | 3 (each at 2) | 0.664 | 0.656 |
| meta-stack-deep-only | 9 | 6 | 0 | 0 | 0 | 0 |
| meta-inplace | 9 | 4 | 0 | 0 | 0.004 | 0.004 |

- **The three deep children:**
  - 4845 (parent 944, seed 2003, finished), deep from 1 690 epochs past descent;
  - 4862 (967, 2002), from 1 650;
  - 4863 (967, 2003), from 2 300.
- Each holds XOR and EQU together. The first was the earlier read's "2 deep rungs within 4 000 epochs".
- Logic's none twins are zero everywhere (Logic's final reading). These would be 3 discordant pairs of the 5
  H-deep-Ms needs. Interim; nothing is claimed.
- Child 4845's world at epoch 31 900 is pilot B's start.

## 6. Budget and what was not done

- **Pilots:** about 1.1 core-hours of CPU time.
  - A ran 40 000 epochs, B 40 000, B′ 10 000 and the four-input pilot 20 000.
  - Two deterministic replays of B, to 4 000 and 2 000 epochs, saved snapshots for §2.3.
  - The Mac carried a load average of 30–90 from other sessions, so wall time was 3–10× the CPU time.
- **Enumerations:** three-input to 10 gates (40 s) and the set check (16 s); four-input to 10 gates (9 min);
  straight-line programs to 13 bytes (213 CPU-s, 45 s wall).
- **Not done:**
  - the four-input table past 10;
  - loops in the exhaustive program search (the evolved tapes stand in for them);
  - pilots of the economy options (ii) and (iii) of §1.3;
  - a second start world for the jump (both seeds that jumped share 4845's world);
  - the load-bearing count on four-input solvers;
  - a 14-byte program search, started and stopped for the pilots' CPU.
- The `target/` directory was deleted at the end. The snapshots used (7.7 MB: the two start worlds, every pilot's
  end world, and the replay snapshots that `ancestry_pB.txt` reads) stayed in the scratchpad and were not kept.

## Sources

- Lenski, Ofria, Pennock & Adami (2003). The evolutionary origin of complex features. *Nature* 423:139–144.
- Avida's Logic-77 environment: the nine two-input tasks plus all 68 three-input logic operations, `logic_3AA` to
  `logic_3CP` (devosoft/avida wiki, [Environment file](https://github.com/devosoft/avida/wiki/Environment-file);
  Bryson & Ofria, [Understanding evolutionary potential in virtual CPU instruction set
  architectures](https://arxiv.org/pdf/1309.0719)).
- `docs/studies/meta-stack.md` (§2.4 read-once, §5.7, §7), `docs/studies/logic.md`, `docs/design_record.md`
  (2026-10-02, the Meta-stack pre-registration).
