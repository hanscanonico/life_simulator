# Design study: if Logic's deep rungs do not come, what binds next?

2026-10-02. This is a design study. It seeds nothing, and it touches neither the repository nor the lab. I read
the lab with SELECTs only.

Every number marked *pilot* comes from a throwaway copy of main's engine in a session scratchpad, not kept. The copy is
`dba2c96`, which has `tasks = logic`, `task_floor` and the logic observables. It adds:
- interaction tallies;
- three assay-side probes: repeated inputs, assay-only head moves and assay-only input loads;
- the candidate mechanism, the metabolism tape, with its variants (§3). Pilot numbers come from
a pilot; they are not findings.

The material was pilot artefacts and was not kept: the tools (`dscape`), their raw outputs (`out/`), the
waiting-time arithmetic (`calc/waiting.py`), the SQL (`sql/`) and the copied worlds. The tools the Meta-stack
sweep's locked offline readings need (`deeppaths`, `plant`, the traced stepper) are preserved, ported to the merged
engine, in `research/landscape/`; see its README.

## 0. In brief

1. **The binding constraint is the valley between rungs, not supply.**
   - A specific substitution occurs somewhere in the world every 128 epochs, and the one-step rungs arrive on
     schedule.
   - XOR and EQU are the only rungs that read an input twice, and that costs ≥ 3–4 coordinated substitutions
     through intermediates that stop copying or lose credit.
   - At those depths the expected wait is 10¹⁰–10²⁰ epochs. No horizon reaches it, and neither does any rate
     below the copier's error threshold, which sits between × 8 and × 16.
2. **The evolved code is the copy loop.**
   - No byte is free: 0 of 128 in both pilot worlds.
   - Beyond the 56-byte window EQU is only **3 substitutions** from 1007's NOR solver (94 triples on 6 case sets,
     20 of which pass the detector).
   - But every intermediate stops copying, and the deep form copies with a one-byte rotation. Four planted blocks
     were gone within 500 epochs.
3. **Neither named suspect lifts it alone (pilots).**
   - The rate at × 4 and × 8 gave no deep rung; at × 16 the copiers melted.
   - A metabolism tape, a code region the soup never executes, climbed from nothing to NOR in 2 000 epochs at
     Avida's per-site rate. In 17 500 more epochs it reached no XOR or EQU.
   - Six other metabolism-tape arms, including one made neutral by redundancy, stalled in the same place.
4. **The one change: that metabolism tape, at an instruction-set rate of × 32.** One sweep tests both
   pre-registered suspects at once, copying and supply, against the Logic sweep's own children:
   - 54 + 54 children, about 3–6 h of the 12 slots;
   - 2 engine slices and 2 Rails slices.
   - Its pilot predicts **H-deep-M refuted**. That outcome would turn "a NAND machine that writes in place climbs
     every read-once rung and none that reads twice" from a pilot into a finding.
5. **If Logic's H-deep comes out shown instead:**
   - first check that the deep solvers are heritable, by planting them; the near one here was not;
   - then ask the next rung-4 question on a ladder without a top: 3-input logic, read with the rise rule on the
     deepest rung held.

The tables below are pilots and measurements on stored worlds, not findings.

**Revision, §7 (2026-10-02, before the Logic reading).** A stack-like NAND (`~` writes NAND(B[h0], B[h1]) into
B[h0−1], and head0 follows it) turned the metabolism tape from 0 deep pilots into 2 of 3. The revised recommendation
is §7.6: the metabolism tape with that NAND, plus its deep-only control and an in-place control. That is the change
to point 4 above.

## 1. The waiting-time arithmetic (question 1)

### 1.1 The soup's actual variation, measured on the pilot worlds

**Mutation.** `World::mutate` replaces each live byte with a uniform random byte at `mutation_rate` = 1/8192 per
epoch, in every parent and every Logic child.
- A specific value lands at a specific site at **u = 4.77 × 10⁻⁷ per cell per epoch**.
- Over 16 384 cells, every specific single substitution happens **somewhere in the world about once every 128
  epochs**.
- A 128-byte tape takes 0.0156 mutations per epoch.

**Copy fidelity.** The interpreter makes no errors. A "copy error" is a mutation of the source.

I took the commonest OR + NOR solver of 1007's pilot B end world and ran it against 300 partners drawn from its
world:
- 58 offspring are exact reverse copies;
- 242 are reverse copies that keep exactly one byte of the partner, always the offspring's last byte;
- none failed, and none was a forward copy.

Copying is exact on 127 bytes of 128.

**Interactions and generations.** Under the `initiator` economy a cell initiates only when its stock holds the
price, `max_steps` = 8 192. Its income is the influx of 1 024 per epoch plus its task pay. So a "generation" is set
by income, not by the epoch: an unpaid cell initiates once every 8 epochs.

Measured over epochs 80–400 of a continuation, with every interaction tallied (`dscape rates`, `out/rates.txt`):

| world (Logic full bundle) | income / cell / epoch | initiations / cell / epoch | near copies (≥ 90 %) / cell / epoch | **epochs per generation** | 40 000 epochs is |
|---|---|---|---|---|---|
| parent 1007, epoch 20 000 | 1 029 | 0.129 | 0.100 | **10.0** | 4 000 generations |
| parent 944, epoch 20 000 | 1 035 | 0.131 | 0.074 | **13.5** | 3 000 generations |
| 1007 pilot B end (OR + NOR paid, 10 units per cell) | 3 579 | 0.437 | 0.339 | **2.95** | 13 600 generations |
| 944 pilot B end (NAND/ORN/ANDN, 3.8 units per cell) | 1 995 | 0.243 | 0.001 | ≈ 300–860 just after loading | — |

**The paid world breeds 3.4 times faster than its unpaid parent**, because pay is income.

944's restored world interacts in short runs: 1 740 steps per interaction against 8 041 in 1007's. It rewrites
0.3 % of a partner's bytes per epoch, so it barely copies at first. Within 4 000 epochs of the continuation its
detector share climbed back from 0.03 to 0.8–0.9 (§4.1). The Logic study's §5.6 worried that the extinction rule
would drop a world like this. This is its "partial copier" state, measured, and it is transient.

**Per generation.** In the paid world a specific substitution arrives at u · T = 1.4 × 10⁻⁶ per cell. The whole tape
takes 0.046 mutations. Under the real operator (a uniform byte), a single mutation of 1007's solver is:
- neutral in 74 % of cases;
- a credit loss in 15 %;
- the end of its copying in 11 % (§2.3).

### 1.2 Calibration: the one-step rungs come on time

A rung with M₁ replicating single mutants in a carrier class of N_c cells, at advantage s, gets an established
mutant at N_c · M₁ · u · s/(1+s) per epoch:
- NOR from an OR class of 2 000 cells (M₁ = 14): one every 325 epochs. From 10 000 cells: one every 65.
- AND from a NAND class (M₁ = 58): one every 108 epochs.

It then spreads as a Fisher wave. Offspring land on one of 8 neighbours, so D = 0.375 cells² per generation and
the wave moves at 2√(D s) cells per generation. A rung at s ≈ 0.2–0.4 holds a tenth of the world 85–120 epochs
after it establishes, and the whole world after 270–370.

Pilot B is consistent with this. Its one-step rungs came 500–1 000 epochs apart once the rung below them was
common:
- OR at 8 500 epochs, then NOR at 9 500 (1007);
- AND at 15 500, then ANDN at 16 500 (944);
- the two-step ORN took 5 500 epochs.

**One-step rungs are arrival-plus-sweep limited, and fast.**

### 1.3 K coordinated substitutions

The model is Weissman, Desai, Fisher & Feldman (2009), eq. 15, with τ₀ = 1/(N μ₀ p₁) and N = 16 384.
- **Path multiplicity.** m onward substitutions per step, so μ_j = m · u · T per generation.
- **The final rung's pay.** XOR on an OR + NOR cell takes the income from 4 096 to 6 144 (s = 0.5); EQU gives s = 1.0.
- **The mirror.** Either is paid in one orientation of the two that alternate (§2.1), so s_eff = √(1+s) − 1: 0.22
  for XOR and 0.41 for EQU.
- **Neutral intermediates.** Tunnelling, p_k = √(μ p_{k+1}). Where that falls below 1/N, the step fixes by drift
  instead, at a cost of 1/μ + N generations (eqs. 5–6). On the 2D lattice neutral fixation is slower than N.
- **Deleterious intermediates.** p_k = μ p_{k+1}/δ.

Expected epochs to the first established XOR, in the paid 1007 world. EQU is within a factor of 1.5.

| K | m | neutral | δ = 0.25 | δ = 0.5 | δ = 0.75 |
|---|---|---|---|---|---|
| 2 | 10 | 7.2 × 10³ | 1.0 × 10⁶ | 2.0 × 10⁶ | 3.0 × 10⁶ |
| 3 | 1 | 2.4 × 10⁶ | 1.8 × 10¹³ | 7.2 × 10¹³ | 1.6 × 10¹⁴ |
| 3 | 10 | 8.1 × 10⁴ | 1.8 × 10¹⁰ | 7.2 × 10¹⁰ | 1.6 × 10¹¹ |
| **4** | **10** | **3.4 × 10⁵** | 3.2 × 10¹⁴ | 2.6 × 10¹⁵ | 8.6 × 10¹⁵ |
| 4 | 100 | 3.6 × 10³ | 3.2 × 10¹⁰ | 2.6 × 10¹¹ | 8.6 × 10¹¹ |
| **5** | **10** | **6.0 × 10⁵** | 5.7 × 10¹⁸ | 9.1 × 10¹⁹ | 4.6 × 10²⁰ |

How the wait scales with the mutation rate, at m = 10:

| K | neutral | deleterious |
|---|---|---|
| 2 | μ^−1.5 | μ^−2 |
| 3 | μ^−1.75 | μ^−3 |
| 4 | μ^−2.2 | μ^−4 |
| 5 | μ^−1.4 | μ^−5 |

The neutral exponent falls at K = 5 because the early steps fix by drift there, and drift is linear in μ. To bring
the expected wait for XOR to 40 000 epochs:

| K | m | multiplier on μ, intermediates neutral | multiplier on μ, δ = 0.5 |
|---|---|---|---|
| 4 | 10 | × 2.8 | × 515 |
| 5 | 10 | × 3.7 | × 1 180 |

**Fixation once paid** is not the constraint, provided the feature is heritable.
- XOR establishes with probability s_eff/(1+s_eff) ≈ 0.18, and EQU with 0.29.
- An established rung holds a tenth of the world within about 120 epochs and the whole world within about 370.
- The one deep mutant this study could plant was not heritable (§2.5).

### 1.4 The answers

- **Is 40 000 epochs simply too short for K = 4–5?**
  - Only on a neutral plateau with many paths. At m = 10 the wait is 3.4–6.0 × 10⁵ epochs, which is **8–15
    times** the horizon. A 200 000-epoch horizon would then succeed in 26–45 % of children, against 6–11 % now.
  - With intermediates costing even a quarter of a cell's income, the wait is **10¹⁴ epochs or more**.
  - The world actually offers EQU 3 substitutions away, through intermediates that all stop copying (§2.4). That
    path's wait is **1.6 × 10¹³ epochs** at the current rate:
    - 2.4 × 10¹¹ at × 4;
    - 3.8 × 10⁹ at × 16, beyond the error threshold, where the soup melts (§4.1);
    - and its endpoint is not heritable (§2.5).
  - No horizon reaches that.
- **Is the binding constraint supply or the valley?** It is the valley.
  - Supply of single steps is ample: a specific substitution arrives every 128 epochs, and the one-step rungs
    arrive on schedule.
  - XOR and EQU are the only rungs that read an input twice (§2.4). This NAND writes over its own operand, so
    reuse needs a stored copy and re-aligned heads.
  - In the woven tapes the stored copies come from the copy loop. The deep rung is then close in substitutions but
    behind a **copier valley**: every step that changes data flow stops copying, or shifts the copy's register so
    that the feature is lost in the grandchildren.
  - In a free region the deep rungs are ≥ 4 substitutions away, and coordinated pairs cross a credit loss in
    79–100 % of cases (§2.4).
  - A rate arm moves a valley's wait as μ^−K. A × 4 arm buys a factor of 64–256 against a gap of 10⁹ or more.

## 2. What the pilot worlds actually do (question 2)

The end worlds are pilot B's 20 000-epoch continuations of 1007 and 944 (pilot snapshots, not kept), loaded
in main's engine under the Logic full bundle. The focal tape is the world's commonest tape that is credited with
its rung on 6 fixed case sets and passes the detector:
- 1007: OR + NOR, n = 4. The world holds 16 044 distinct tapes in 16 384 cells; OR in 15 254, NOR in 12 346;
- 944: NAND + ORN + ANDN, n = 6. It holds 16 257 distinct tapes; ANDN in 9 448.

A traced stepper (`trace.rs`) records every executed position and every byte read as data. It agrees with the
engine's assay outputs and soup interactions on 1 000 of 1 000 pairs in each world.

### 2.1 Where the evolved code sits

**1007 is a mirrored reverse copier.**
- Its offspring are its reverse (300 of 300).
- Its tape carries a copy loop for each orientation:
  - S's loop is `[`11 … `]`49;
  - rev(S)'s loop runs from 19 to 77 in rev(S)'s own coordinates, which is S's bytes 50–108.
- **Each orientation computes OR + NOR with its own circuit.** A feature built into one circuit is therefore
  expressed in every other generation. That is the "mirror halves selection" of the pre-registration, and the
  reason for s_eff.

**The OR/NOR circuit is the copy loop.** Traced on x = 0x5a, y = 0x33 (`dscape explain 1007 7`):
- All five NANDs the S assay executes (bytes 18, 27, 32, 43 and 48) sit inside the copy loop, and so does its emit
  (34).
- The circuit is unrolled over four laps of the loop:
  - the loop's own `.` and `,` store the intermediates: ¬x goes into byte 0 and into x's cell;
  - its head steps walk the operands;
  - the emit fires once per lap. Lap 1 emits OR = NAND(NAND(y, ¬x), ¬x), and lap 3 emits NOR.
- On cases where the loop's test byte runs out early, the pointer continues into bytes 50–85, the mirror's loop,
  and emits there.

**944 computes in straight-line code in front of, and at the top of, its loops.**
- NAND is computed at byte 10 and emitted at 13.
- ORN = NAND(NAND(x, y), y) is computed at 21 and emitted at 36.
- ANDN, the NAND of that, is computed at 55 and emitted at 66.
- It is a chain in which each rung is the NAND of the one before.

### 2.2 Does every executed byte also have to survive copying? How much of the tape is free?

Every byte has to survive copying: the copy covers the whole tape, 127 of 128 bytes exactly. And in both tapes
**every byte the assay executes is also executed by a copy loop in one orientation or the other**:

| focal | S assay executes | S copy executes | both | assay only, in S | rev(S) assay | rev(S) copy | **free** |
|---|---|---|---|---|---|---|---|
| 1007 OR + NOR | 86 (0–85) | 50 (0–49) | 50 | 36 (50–85: rev(S)'s copy loop) | 128 | 79 | **0 of 128** |
| 944 NAND/ORN/ANDN | 90 (0–89) | 119 | 81 | 9 | 104 | 128 | **0 of 128** |

**No byte is free.** None lies outside both the assay and the copy path. The 56-byte window of the next-substrate
study was not hiding spare room: the rest of the tape is the mirror copier.

### 2.3 What one substitution does

Every single substitution over the 14-value alphabet (the ten ops, `!`, `~`, 0 and a no-op), weighted to the real
operator, where the no-op stands for 243 byte values:

| focal | neutral | gains credit | loses credit (still copies) | stops copying |
|---|---|---|---|---|
| 1007 OR + NOR | 0.736 | 0.0000 | 0.153 | 0.111 |
| 944 NAND/ORN/ANDN | 0.802 | 0.024 (each one a `!`, ECHO) | 0.100 | 0.073 |

A byte is neutral **only to another no-op**. An op written at a byte both the assay and the copy execute is
costly:
- of 683 such mutants of 1007, 412 stop copying;
- 150 cost credit;
- 120 are neutral.

### 2.4 The landscape beyond the 56-byte window

**Every triple substitution over the whole tape**, in both orientations (`dscape sub3 … 0`, `dscape deep3`): all
C(128, 3) position triples over 13–14 values each, read for XOR or EQU in S and in rev(S).

| focal | screened | XOR/EQU on one case set | **on all 6 sets** | **and passes the detector** |
|---|---|---|---|---|
| 1007 OR + NOR | 886 M | 157 | **94** | **20** |
| 944 NAND/ORN/ANDN | 889 M | 0 | **0** | **0** |

**For 1007 the deep rungs are three substitutions away.** They sit in the mirror's half (bytes 78–113, the rev(S)
circuit), which is beyond the window the earlier study searched.
- The 20 replicating triples are a single structure, in three parts:
  - a `}` written over a no-op at one of 88–91;
  - the copier's own `<` at 95 turned into `{`;
  - a `<` written over a no-op at one of 97–100 (the 16 XOR forms), or over the NAND at 101 (the 4 EQU forms).
- They give rev(S) NAND + OR + XOR (25 units, against 24) or ORN + EQU (30 units).
- They compute the task on **99.6 %** of 4 000 random inputs.
- Traced on x = 0x5a, y = 0x33, the EQU form works over two laps:
  - in lap 1 it computes NAND(x, y), then both forms of ORN (x ∨ ¬y, emitted, and y ∨ ¬x, emitted);
  - the inserted head steps leave the two ORN values under the two heads at lap 2;
  - lap 2 NANDs them into XOR (0x69) and NANDs that with itself into EQU (0x96, emitted).
- The other 74 triples are credited NAND + OR + NOR + EQU (`{` at 88–93, `,` at 93–94, `<` at 112–113) and do not
  replicate.

**Every intermediate of every one of the 20 stops copying.** All 3 singles and all 3 doubles of each triple fail
the detector and lose 7–12 units of 24. None of the 20 has an order through intermediates that both copy and keep
their credit. The rung is close, but the valley is lethal: each intermediate lives only until its cell is
overwritten, about 3 epochs.

**Copy-neutral substitutions.** Writing a nonzero no-op, `~` or `!` over a byte that is already one of those
leaves the copier's instruction stream as it was, because those bytes are no-ops in the soup. Only their value as
data can differ, and every hit was checked with the detector. This is the subspace in which a
circuit could be rearranged without touching the copier (`dscape nsub`). It covers the 69–79 such bytes of each
orientation's assay-executed region.

| focal | k = 1 | k = 2 | k = 3 | k = 4 | k = 5 |
|---|---|---|---|---|---|
| 1007, S | 0 of 144 | 0 of 10 224 | 0 of 477 120 | 0 of 16.5 M | **0 of 448 M** |
| 1007, rev(S) | 0 of 138 | 0 of 9 384 | 0 of 419 152 | 0 of 13.8 M | — |
| 944, S | 0 of 158 | 0 of 12 324 | 0 of 632 632 | 0 of 24.0 M | — |

Not even one case set credits any of these mutants with XOR or EQU. **Each route to a deep rung moves data, and in
these tapes data is moved by the copy loop.**

**What the intermediates of coordinated pairs do** (`dscape path2`). Take every double substitution that gains a rung
neither single gains, and that still replicates. Ask whether one of its two orders passes through a neutral single:

| from | to | replicating doubles | **a neutral order** | every order loses credit | every order stops copying |
|---|---|---|---|---|---|
| 1007 OR + NOR | NOT | 763 | 152 (20 %) | 588 | 23 |
| | NAND | 369 | **0** | 309 | 60 |
| | AND | 53 | **0** | 53 | 0 |
| | ORN | 407 | 43 (11 %) | 179 | 185 |
| | ANDN | 61 | 8 (13 %) | 21 | 32 |
| 944 NAND/ORN/ANDN | NOT | 336 | 178 (53 %) | 158 | 0 |
| | AND | 262 | 63 (24 %) | 193 | 6 |

Weissman's neutrality condition at these success probabilities is δ < √(μ p), about 10⁻³. So a one-unit loss
(δ ≈ 0.06) already puts a path in the deleterious regime.

**A free region removes the copier, not the depth.** These are hand-written and evolved solvers padded with zeros,
with no copier, searched exhaustively (`dscape mk`, `msearch`, `mpath2`):

| start | XOR/EQU within | screened |
|---|---|---|
| hand-written OR `<{~<{~}~!` | 3: none | 4.4 M, 24-byte window |
| hand-written OR `<{~<{~}~!` | 4: none in the first 16 bytes | 52 M |
| hand-written OR `<{~<{~}~!` | 4: none | 303 M, 24-byte window |
| hand-written NOR | 3: none | 4.4 M |
| the metabolism-tape pilot's evolved ORN + OR + NOR (§4.2) | 3: none | 10.9 M, whole 32 bytes |
| hand-written OR and NOR, with three (y, x) pairs in the assay buffer instead of one | 3: none | 4.4 M each |

The evolved metabolism-tape solver's two-step gains have a neutral order in **0–21 %** of cases: NOT 42 of 515, NAND
72 of 343, AND 0 of 320, ANDN 27 of 294. That is the same as the copy-woven tapes. Where there is no copier, credit
is still a valley. These compact solvers spend every byte, and XOR needs a stored copy of an input that they
overwrite in place.

**Why these two rungs: they are the only ones that read an input twice.** Every rung any soup climbed here is a
**read-once** NAND formula, built by consuming each operand once:

| rung | read-once form |
|---|---|
| NOT | NAND(x, x), with both heads on x's cell |
| NAND | NAND(x, y) |
| AND | NOT(NAND) |
| ORN | NAND(¬x, y) |
| OR | NAND(¬x, ¬y) |
| ANDN | NOT(NAND(x, ¬y)) |
| NOR | NOT(OR) |

XOR and EQU are the only two-input functions that are not read-once over AND, OR and NOT. Any NAND formula for them
reads each input twice, or uses an intermediate twice. The circuit of the near EQU in §2.4 NANDs the two ORN forms,
so it uses NAND(x, y) twice.

This machine's NAND writes in place, over its own operand. Using a value twice therefore needs a stored copy (`,`
or `.`) and re-aligned heads, which costs several coordinated substitutions in any region.
- In the woven tapes the copy loop supplies the copies, so EQU is only 3 away, but every change to them is a
  change to the copier.
- In a free region nothing supplies them: no XOR or EQU appears within 4 substitutions of OR, nor within 4 by
  appending code.
- Making the inputs re-readable (an input-load op, or three copies of the inputs) puts none within 3.
- No single substitution of either focal holds both ORN forms, or both ANDN forms, at once. That pair is the
  stepping stone XOR would be built from.

### 2.5 Is the near deep rung heritable? (pilot)

I planted the 3-substitution EQU form of 1007's solver as a 4×4 block in the centre of 1007's end world, under the
full bundle, with seeds 2001–2003. I planted the XOR form the same way with seed 2001.
- **All four blocks were gone within 500 epochs**: no tape within 4 bytes of the plant or of its reverse, and no
  cell credited with XOR or EQU on 6 sets, at any later reading to 2 000 epochs.
- The reason: in its EQU-computing orientation the mutant copies with a one-byte rotation (300 of 300 offspring at
  rotation 1). The planted orientation copies at rotation 0.
- So its grandchildren are rotated by a byte, and their circuit no longer lines up with the inputs. The detector
  passes it because it allows rotations; the world does not keep it.
- **The deep rung the landscape offers is not heritable.** The edit that re-aligns the operands also re-aligns the
  copy.

## 3. Candidate changes (question 3)

| candidate | what it changes | why it would lift the measured constraint | measured here (*pilot*) | build cost | risk | literature |
|---|---|---|---|---|---|---|
| **Higher mutation rate** (a descendant arm) | `mutation_rate` in the child bundle (dynamics; no engine change) | Supply. The wait goes as μ^−1.75–2.2 on a neutral plateau and μ^−K on a valley | × 4 and × 8 from 1007's end world: no deep rung in 20 000 epochs, copying held (detector 0.8–0.9 at × 4, 0.7–0.86 at × 8). × 16: **error catastrophe**: the detector share was 0.05 by 2 000 epochs, OR fell from 15 262 cells to 404, and the world never recovered OR. A lost circuit lengthens the generation, so each generation carries more mutations | 0 engine slices, 1 Rails slice | The ceiling sits at × 8–16, with the economy feeding back on load. A valley needs × 500 or more. The default is untouched | Weissman et al. 2009; Eigen 1971; Lenski et al. 2003 (Avida's per-site rate for a specific instruction, per generation, is about 70 × this soup's) |
| **Longer horizon** (200 000 epochs past the parent) | Epochs | Linear in time: success = 1 − e^(−t/τ) | The × 1 continuation of 1007 to 40 000 epochs past its parent (pilot B plus this run): no deep rung | 0 slices | 26–45 % per child on a neutral plateau with m = 10; 0 on any valley. **Cost**: a full child at 47–77 s per 1 000 epochs (Logic so far 47, Metabolism's reward 72–77) is 9 500–15 400 s; a none child at 37–46 s is 7 400–9 200 s. Full + none on 54 pairs ≈ 1.1 M run-seconds ≈ **25 h of the 12 slots**; with deep-only, ≈ 36 h | — |
| **Locality** | `radius` | Spatial structure changes tunnelling | Not piloted. Radius 1 is already the most local reach | 0 slices for a radius; 2 for walled demes | Komarova, Shahriyari & Wodarz (2014): a 2D Moran process crosses faster than a well-mixed one when the intermediates are neutral or disadvantageous ("mutant islands"). So widening to radius 4 (sweep 13's emergence peak) would, if anything, slow the crossing. Subdivision helps only for demes in the sequential-fixation regime (Bitbol & Schwab 2014): N_d ≲ 1 800 cells for neutral steps, and N_d δ ≲ 1 (≤ 10 cells at δ = 0.1) for deleterious ones. **Not a lever** | Komarova et al. 2014; Bitbol & Schwab 2014 |
| **A separate executed region** (a "metabolism tape") | Each cell carries a second, 32-byte tape. The soup never executes it. It is assayed instead of the replicating tape, inherited whole whenever the cell's tape is overwritten by a near copy (≥ 90 %), and mutated at its own rate | It removes the copier from every path, both the lethal intermediates and the register shifts of §2.5, and lets the computing region take a high mutation rate without the copier's error threshold | Seeded with the hand-written OR, from 1007's end world. **μ_M × 1**: NOT + ANDN by 2 500 epochs and ORN by 16 000, no NOR, no deep rung. **× 8**: ANDN 500, ORN 1 000, NOT 2 000, NOR 5 500, then nothing more to 20 000. **× 32**: ANDN, ECHO, ORN and NOT 500, NOR 4 500, NAND 12 000, no deep rung. The evolved ORN + OR + NOR metabolism tape has no deep rung within 3 substitutions | 2 engine slices (state, snapshot section, inheritance, mutation and pay; then the observables) and 2 Rails slices | It **imports a hereditary channel**: the world, not the program, copies the metabolism tape. The existing solvers stop being paid, so the ladder restarts. In the uniform-rate arms the replicating tape's detector share ended at 0.53–0.66, from 0.92: the copier is no longer tied to pay. Off by default, so byte-identical | Avida's genome (Ofria & Wilke 2004): the copy loop exits, and task code evolves in neutral filler. Lenski 2003's ancestor is mostly filler |
| **Recombination / HGT** | An explicit transfer of segments | Joins separately arisen intermediates (Weissman, Feldman & Fisher 2010: it helps at a recombination rate below about s, and hurts above) | BFF already recombines. In 1007, 0.07 partial overwrites per cell per epoch against 0.34 near copies, and each copy keeps one partner byte. 944's writes are all partial | 1–2 slices | It works only when the intermediates stand at appreciable frequency. Here they are lethal or cost credit, so they never do. **Not a lever** | Weissman et al. 2010 |
| **Pay the better orientation** (from the numbers) | The assay credits max(S, rev S) | Removes the mirror's halving: XOR's s_eff goes from 0.22 to 0.5 | Not piloted | 1 slice | Multiplies the establishment probability by about 2. **Too small a lever** | — |
| **Repeated inputs** (from the numbers) | Three (y, x) pairs in the assay buffer | XOR needs an input twice, and in-place NANDs destroy the inputs | Free region, hand-written OR and NOR: still no deep rung within 3 | 1 slice | Changes every solver's credit. **No measured gain** | — |
| **Metabolism tape copied from the replicating tape, paid on its better orientation** (from the numbers) | As above, with each cell's metabolism tape a copy of its own 128-byte tape at descent, and the pay the better of its two orientations | Keeps the woven circuits and their data movement, so EQU stays 3 substitutions away. Removes the copier, and makes the mirror a redundant copy: the credit lost in one orientation is covered by the other, so the measured EQU path becomes neutral (K = 3, s = 0.375). On the arithmetic: 2 × 10³–3 × 10⁴ epochs at × 8 | × 8, 20 000 epochs: **no deep rung, not even on one case set**. OR and NOR held at about 14 000 cells and NOT rose to 15 500. The redundant circuit is neutral, so it decays: about 30 bytes at μ_M ≈ 10⁻³ per epoch are hit within tens of epochs, while the three specific changes arrive at 10⁻⁵. The parts erode thousands of times faster than the path is walked | As above | As above. **Its own pilot rules it out as a shortcut** | Walsh 1995 (a duplicate is far likelier to decay than to gain a function) |
| **Assay-only head moves or input loads** (from the numbers) | Four bytes that move the heads only inside the assay, or two that write x or y under head0 only inside it. Both are no-ops in the soup, as `~` and `!` are | Let a circuit re-align its operands, or re-read its inputs, without touching the copier | Copy-neutral search on 1007's solver, k ≤ 3, with the new bytes in the alphabet. Head moves: 0 deep of 11.3 M (rev(S)) and 12.9 M (S). Input loads: 0 of 3.35 M (rev(S); 140 credited on one set) and 3.8 M (S). The measured EQU edit turns the copier's own `<` into a `{`, and no byte can be both | 1 slice each | A primitive import each. **No measured gain** | — |
| **Duplication or indels inside the metabolism tape** (from the numbers) | A variation operator that copies or shifts segments of the free region | Gives a circuit a spare copy to tinker with: Ohno's neutral route around a credit valley | Not piloted. In the tape, the earlier study measured no gain, because the copier and the mirror pin every offset; a free region removes both | 1 slice on top of the metabolism tape | A second import | Ohno 1970; Lenski 2003 used 0.05 insertions and 0.05 deletions per divide |

## 4. Pilots (question 4)

All *pilot*: seed 2001 unless stated, 20 000 epochs from the logic pilot B end worlds of 1007 and 944, under the
Logic full bundle. Every 500 epochs all 16 384 cells are read on a fresh separating case set. A cell counts as
**solid deep** only if XOR or EQU is credited on all 6 fixed case sets, in either orientation. The detector share is
over 64 sampled cells.

**Budget.** About **2.7 core-hours** of pilot runs, which is more than the brief's 2 hours:
- 6 rate arms, about 6 600 s;
- 7 metabolism-tape arms, about 3 400 s. The last three were added to test the recommendation itself;
- 4 plantings, about 550 s.

Landscape enumeration took about 4 core-hours more, most of it the two full-tape triple searches (1.8 G mutants).
The data volume went from 90 % to 92 % during the study. That was not this study: `deep-study/` holds 61 MB,
including one end world per rate arm (12 snapshots, 2.3 MB).

### 4.1 Mutation-rate arms

| world | μ multiplier | rungs at 1/10 (first epoch) | deep cells credited on one set, max | **solid deep** | detector share, range |
|---|---|---|---|---|---|
| 1007 | × 1 | OR, NOR, NOT throughout | 1 (EQU, one reading) | **0** | 0.91–1.00 |
| 1007 | × 4 | OR, NOR, NOT; ECHO 3 500 | 0 | **0** | 0.81–0.92 |
| 1007 | × 8 | OR, NOR, NOT throughout; ECHO and ORN 500; ANDN 7 000. OR sinks to 6 000–9 600 cells | 41 XOR (one reading, partial solvers) | **0** | 0.67–0.94 |
| 1007 | × 16 | collapse; ECHO and ORN at 500 | 0 | **0** | 0.05 by 2 000, then 0.23–0.45 |
| 944 | × 1 | NAND, ORN, ANDN, ECHO throughout; no OR or NOR ever | 1 | **0** | 0.03 → 0.69–0.84 |
| 944 | × 4 | the same, plus AND and NOT at 500; no OR or NOR ever | 4 | **0** | 0.03 → 0.83–0.97 |

On the neutral-plateau model of §1.3, these arms do not see a deep rung in 20 000 epochs with these probabilities:

| K, m, intermediates neutral | × 4 | × 8 |
|---|---|---|
| 4, 10 | 0.37 | **0.026** |
| 4, 30 | < 0.001 | < 0.001 |
| 5, 10 | 0.55 | 0.10 |
| 5, 30 | 0.007 | < 0.001 |

So on one world and one seed, × 8 holding no deep rung argues against "K = 4, neutral, m ≥ 10" (p ≈ 0.03), and × 4
against "m ≥ 30". A single world is weak evidence, but it agrees with the landscape: the valley is not neutral.

### 4.2 The metabolism tape

The metabolism tape was 32 bytes, seeded in every cell with the hand-written OR, `<{~<{~}~!`.

| μ_M | rungs at 1/10 (first epoch) | end state (cells of 16 384) | deep | detector share of the replicating tape |
|---|---|---|---|---|
| × 1 | ANDN, NOT 2 500; ECHO 11 000; ORN 16 000 | NOT 15 815, ANDN 15 667, ORN 15 162; OR lost | **0** | 0.92 → 0.55 |
| × 8 | ANDN 500; ORN 1 000; NOT 2 000; ECHO 5 000; **NOR 5 500** | OR 10 980, NOR 10 777, ORN 7 262 | **0** | 0.92 → 0.53 |
| × 32 | ANDN, ECHO, ORN, NOT 500; NOR 4 500; NAND 12 000 | OR 7 203, ORN 5 176, NOR 3 906 | **0** | 0.66–0.92 |
| × 8, seeded with zeros (10 000 epochs) | ECHO 1 500, then nothing | ECHO 13 781, NOT 30 | **0** | 0.64–0.92 |
| × 8, 128 bytes copied from each cell's own tape, paid on the better orientation | OR, NOR, NOT from the start; ECHO, ORN 500; ANDN 1 500 | NOT 15 460, OR 14 189, NOR 13 823 | **0** (and 0 on one set) | 0.59–0.92 |
| × 32, mutations drawn from the instruction set (each of the ten ops, `!`, `~`, 0 and a random no-op at 1/14), seeded with OR | ECHO, ORN, NOT, ANDN 500; **NOR 1 000** | ECHO 12 235, OR 9 702, NOR 9 157 | **0** (and 0 on one set) | 0.73–0.94 |
| × 32, instruction-set draws, **seeded with zeros** | ECHO 500; NOT, ORN 1 500; OR, NOR 2 000; ANDN 2 500 | NOT 13 047, OR 9 345, NOR 9 264, ECHO 3 836 | **0** (and 0 on one set) | 0.62–0.98 |

**A free region climbs every rung but the deep ones.**
- Seeded with nothing, at an instruction-set rate of × 32, it took ECHO at 500 epochs and NOR at 2 000. Every rung
  up to four NANDs was held by 2 500 epochs.
- Then nothing more came in the 17 500 epochs that followed: no deep rung, not even on one case set.
- The six other metabolism-tape arms stalled in the same place.
- Seeding the tape from the cell's own solver and paying its better orientation made the measured EQU path neutral.
  The pilot still found nothing: the spare circuit is unprotected, so it decays long before three specific changes
  arrive.

With copying out of the path and the per-site rate at Avida's level, the barrier is still there. §5 names it.

### 4.3 Planting the near deep rung

See §2.5. The EQU form planted as a 4×4 block (3 seeds) and the XOR form (1 seed) were all gone within 500
epochs. The edit that re-aligns the operands also rotates the copy.

## 5. Recommendation (question 5)

### 5.1 What binds, in one paragraph

Supply does not bind, and neither does the horizon. A specific substitution arrives somewhere every 128 epochs.
Every one-step rung came on schedule, in the woven worlds and in a free region alike.

What binds is the depth of the two rungs that read an input twice, measured three ways.
- **In the copy-woven worlds** the copy loop is the only thing that stores copies of values. So the nearest deep
  rung, EQU three substitutions from 1007's NOR solver, is a rewiring of the copier:
  - every intermediate stops copying;
  - the end point copies with a one-byte rotation;
  - it is not heritable (§2.4–2.5).
- **In a free region** no copier is in the way, but nothing stores a copy either. The deep rungs are ≥ 4
  coordinated substitutions from any solver that evolved there (§2.4), and the pilots stall at NOR (§4.2).
- **The arithmetic** (§1.3) says a K ≥ 3 valley with costly intermediates takes 10¹⁰ epochs or more. A neutral one,
  made neutral by a spare copy, decays faster than it is walked.

The pre-registration's "the code must run before a copy loop that never exits" is true, but it is the smaller part.
Taking the code off the copy loop does not bring the deep rungs nearer.

### 5.2 The one change: a metabolism tape, at an instruction-set rate

**What it is.**
- Each cell carries a 32-byte **metabolism tape**:
  - zero at descent;
  - never executed in the soup;
  - assayed by the logic assay instead of the replicating tape.
- **Inheritance.** It is copied whole from the initiator onto the partner whenever an interaction leaves the
  partner's tape a near copy (≥ 90 % of bytes, either orientation) of the initiator's.
- **Mutation.** It mutates on its own stream at `meta_rate` per byte per epoch, drawn from the instruction set: each
  of the ten ops, `!`, `~`, 0 and a random no-op at 1/14.
- **The values.** `meta_len` 32, `meta_rate` 32/8192, `meta_draw` isa. At `meta_len` 0, the default, nothing is
  allocated and every pin stays put.
- **A reward of 0** never reads the tape, so such a child's world is the Logic none child's, byte for byte.

**Why this one.**
- It is the pre-registration's second suspect, and it carries the first inside it. The tape is free of the copier,
  so its rate can be raised to Avida's per-site level, which is out of reach on the replicating tape: × 16 melted
  the copiers.
  - Here: 32/8192 per byte per epoch, a given instruction drawn 1 time in 14, about 8 × 10⁻⁴ per site per
    generation.
  - Avida in Lenski et al. 2003: about 10⁻⁴, at the commonly cited 0.0025 per instruction copied over 26
    instructions.
  - The replicating tape: 1.4 × 10⁻⁶.
- One sweep therefore tests both named suspects together, on 18 parents and 3 seeds rather than one pilot world.
- It is also the platform any continuation needs: indels, duplication, a larger ladder. The woven mirror forbids
  those in the replicating tape (next-substrate study §3).
- Pilot, seeded with zeros: ECHO 500, NOT and ORN 1 500, OR and NOR 2 000, ANDN 2 500. That is the whole
  read-once ladder in 2 500 epochs, against 9 500 epochs for pilot B's 1007 to reach NOR. Then no deep rung in
  17 500 epochs.

**Label.** It imports an objective, a primitive **and a hereditary channel**. The world copies the metabolism tape
on a copy event of the replicating tape; the program does not. It carries Metabolism's badge and pooling rule, and
rung 4 on Soup stays "not shown".

### 5.3 The sweep and its hypotheses (paired, the Logic reading's machinery)

**The sweep.** A descendant sweep from the same 18 parents (`Lab::FROM_EMERGED_PARENTS`), seeds 2001–2003, 40 000
epochs, priority 40. Two bundles over the Logic full bundle:
- **meta**: `meta_len: 32, meta_rate: 0.00390625, meta_draw: isa`;
- **meta-deep-only**: the same at `task_floor: xor`, Lenski's control.

That is 108 children. The none twin is the Logic sweep's own none child of the same (parent, seed): at reward 0
the metabolism tape is never read, so no new none arm is needed. Readings, deciles, settling window, extinction
and relapse rules, the persistence rule, per-parent agreement, leave-one-or-two-out, and the extinct-kept and
unpiloted re-readings all follow the Logic entry. The pairs cross two sweeps by (parent, seed).

**The tests.** One-sided sign tests at p < 0.05, read as the Logic entry reads them.
- **H-capability-M** (meta against Logic none): the last-decile median `logic_capability`, read on the
  metabolism tape. The pilot predicts it shown.
- **H-deep-M**, the rung-4 question (meta against Logic none): `logic_capability_deep`. The pilot predicts it
  **refuted**: 0 deep in 7 metabolism-tape arms, the longest 17 500 epochs past a complete read-once ladder.
  - The power is Logic's: 5 discordant pairs suffice, and the power is 0.64 at a rate of 0.1 per child.
- **H-decouple** (meta against Logic full, same (parent, seed)): `logic_capability_deep`. Do deep rungs come more
  often off the copy loop than on it?
- **H-stones-M** (meta against meta-deep-only): the same key. It is Lenski's control, read as Logic's H-stones is.
  It can be shown only if deep rungs come.

**Descriptive.** The first epoch each rung reaches 1/10. The share of interactions that pass a metabolism tape.
The replicating tape's `replicator_share` against its Logic twin's: in the uniform-rate pilot arms it ended at
0.53–0.66, from 0.92.

For every deep solver found:
- its heritability, by planting it as §2.5 did;
- its substitution distance from the child's commonest metabolism tape at the 10 % line;
- whether it reads an input twice.

### 5.4 What each outcome means

- **H-deep-M shown, H-decouple shown.** Copying and supply together were the constraint. Off the copier, and at
  Avida's per-site rate, paid parts assemble the deep rungs, and H-stones-M then says whether through the parts.
  This study's read-once reading would be wrong for the soup at scale.
- **H-deep-M shown, H-decouple refuted.** The woven children reached deep rungs as often. The metabolism tape is
  not needed, and Logic's own reading is the result.
- **H-deep-M refuted (the pilot's prediction).** Both pre-registered suspects are closed by one sweep.
  - With the copier out of the path and the rate at Avida's per-site level, this machine climbs every read-once
    composition and none that reads an input twice.
  - **The binding constraint is fan-out in a two-head machine whose NAND writes in place.**
  - Rung 4 by composition then needs either:
    - a machine with non-destructive storage. That means registers, Avida's answer, which is a new-substrate
      decision for the user and not a slice; or
    - a question this machine can answer: a ladder without a top made of read-once compositions, for example
      3-input read-once functions of growing size. It would ask whether the climb continues, not whether it jumps.
- **H-deep-M not shown.** The rate of deep climbing is below what 54 pairs resolve. Metabolism's power arithmetic
  applies.

### 5.5 Engineering slices (each about 90 minutes)

1. **Engine: the metabolism tape.**
   - `params.rs`: `meta_len` (0 = off), `meta_rate` and `meta_draw` (`uniform`, `isa`). They are dynamics, so a
     descendant may set them.
   - `world.rs`: per-cell state; inheritance on a near copy, on the tally the pilot used (`dscape`'s `STATS` block);
     mutation on a stream of its own; and `pay_tasks` reads the metabolism tape when it is on.
   - `snapshot.rs`: an optional section. A snapshot without it reads as off.
   - Specs:
     - at 0, every pin and digest is unmoved;
     - at reward 0, with the tape on, the world hash equals the tape-off run's;
     - inheritance on exact, near and partial copies;
     - determinism;
     - a metabolism reward pin.
2. **Engine: the observables.** When the tape is on, the logic observables read it: `logic_share_*`,
   `logic_capability`, `logic_capability_deep` and `dominant_logic_tasks`. Add `meta_inherit_rate`. They are
   live-only, with their digest split as the logic observables' was.
3. **Rails: the sweep and its pre-registration.**
   - `Lab::SWEEPS["meta_logic"]`, built on the from-emerged parent rule;
   - the label and the badge;
   - `Lab::MetaLogicReading`;
   - pairing across the `logic` and `meta-logic` experiments by (parent, seed);
   - the record entry, DESIGN §1.3 item 17 and a §1.4 paragraph.
4. **Rails: the reading.** `Experiments::MetaLogicReadingService` and `lab:meta_logic_report`, reusing
   `Lab::LogicReading`'s tests over the cross-sweep pairs.

### 5.6 Cost on the mini-pc's 12 slots

- A Logic full child at cap 128 costs 47 s per 1 000 epochs so far. Metabolism's reward children cost 72–77 s, and
  its none children 40–46 s. Cap 256 is 1.3 ×.
- In the pilots a metabolism-tape child ran at 0.35–0.8 × a woven full child's time on the same Mac.
- Taking the Logic full cost as an upper bound: 108 × 40 000 epochs × 47–77 s per 1 000 epochs ≈ 200 000–330 000
  run-seconds, **about 3–6 h** of the 12 slots.
- About 2 h of that is the deep-only arm, which can be dropped if H-stones-M is not wanted.

### 5.7 If Logic's H-deep comes out **shown** instead

Then XOR or EQU reached a tenth in rewarded children, which no pilot here managed. The next rung-4 question, in order:
1. **Is it heritable?** The one deep solver the landscape offered here copies with a rotation and dies out (§2.5).
   - Plant each child's commonest deep solver back into its own end world, as §2.5 did.
   - Count a deep rung as climbed only where it persists, and report the substitution distance from the parent's
     copier, as the Logic entry already plans.
2. **Read H-stones.** Shown means deep features are built on paid parts, which is Lenski's mechanism in a soup.
3. **Does the climb continue?** The two-input ladder tops out at EQU, five NANDs. The rung-4 question is whether
   complexity *keeps* rising, and that needs a ladder without a near top: 3-input logic, the 256 functions, scored
   by minimal NAND count.
   - The new reading is `logic_depth_max`: the minimal NAND count of the deepest rung held at a tenth.
   - Read it with the from-emerged rise rule over a 200 000-epoch horizon, full against none: about 25 h of the
     12 slots (§3).
   - H-rise is shown if the deepest rung keeps rising in the last half.

## 6. The live Logic sweep, interim (read only; nothing is claimed from it)

Read at 2026-10-02 00:26Z, with SELECTs only (`sql/q_interim*.sql`). The sweep was 41 finished, 12 running and
109 pending, of 162. **Interim: nothing is claimed from it.**

Over the settled samples (epochs past the parent's + 1 000) of the 53 children that had any:

| arm | children | most rungs at 1/10, any sample | `logic_capability_deep` > 0, any sample | max XOR share | max EQU share | recent median capability, per child | mean recent replicator share |
|---|---|---|---|---|---|---|---|
| full | 18 | 7 | **never** | 1/256 (3 samples in 61 006) | 0 | 2, 4, 2, 5, 5, 3, 4, 3, 2, 3, 1, 2, 4, 3, 4, 4, 4, 2 | 0.86 |
| deep-only | 18 | 1 | never | 0 | 0 | all 0 | 0.74 |
| none | 17 | 1 | never | 0 | 0 | all 0 | 0.76 |

At the 23:53Z read (27 finished):
- full children of 950 held OR and NOR at up to 0.99 and 0.97 of the world;
- 1007 seed 2002 held OR at 1.0 and NOR at 0.96.

No full child has had XOR or EQU at a tenth in any sample.

So far the full arm's capability sits above its twins', and the deep key is at zero everywhere. That is the case §5
is written for. It is interim, and nothing is claimed from it.

## Literature

- Weissman, Desai, Fisher & Feldman (2009). The rate at which asexual populations cross fitness valleys.
  *Theor. Popul. Biol.* 75:286–300.
  - Eq. 15: p₁ ≈ s^(1/2^(K−1)) ∏ μ_j^(1/2^j) for neutral intermediates, and s ∏ (μ_j/δ_j) for strongly
    deleterious ones.
  - Eqs. 5–6: the 1/N floor and sequential fixation.
  - τ₀ = 1/(N μ₀ p₁).
  - §6: several pathways.
- Iwasa, Michor & Nowak (2004). Stochastic tunnels in evolutionary dynamics. *Genetics* 166:1571–1579. The two-hit
  tunnel, for neutral and for less fit intermediates.
- Weissman, Feldman & Fisher (2010). The rate of fitness-valley crossing in sexual populations. *Genetics*
  186:1389–1410. Recombination speeds valley crossing below a rate of about the adaptation's advantage, and slows it
  above.
- Komarova, Shahriyari & Wodarz (2014). Complex role of space in the crossing of fitness valleys by asexual
  populations. *J. R. Soc. Interface* 11:20140014.
- Bitbol & Schwab (2014). Quantifying the role of population subdivision in evolution on rugged fitness
  landscapes. *PLoS Comput. Biol.* 10:e1003778.
- Lenski, Ofria, Pennock & Adami (2003). The evolutionary origin of complex features. *Nature* 423:139–144. EQU arose
  in 23 of 50 populations when the simpler functions were rewarded, and in none of 50 when only EQU was.
- Covert, Lenski, Wilke & Ofria (2013). Experiments on the role of deleterious mutations as stepping stones in
  adaptive evolution. *PNAS* 110:E3171–E3178. Deleterious steps sat just before EQU on some lines of descent, and
  forbidding deleterious mutations hindered the evolution of complex functions.
- Ofria & Wilke (2004). Avida: a software platform for research in computational evolutionary biology. *Artif.
  Life* 10:191–229.
- Eigen (1971). The error threshold.
- Ohno (1970). *Evolution by Gene Duplication*.
- Walsh (1995). How often do duplicated genes evolve new functions? *Genetics* 139:421–428. A redundant copy
  usually decays before it gains a function, unless beneficial mutations are common relative to null ones.

## 7. Follow-up: does a non-destructive NAND lower the deep rungs? (2026-10-02, before the Logic reading)

The question: `~` is assay-only and new, so its semantics are ours to choose. Is there a semantics under which XOR
and EQU sit 2–3 credited substitutions from the solvers a soup actually evolves, while staying ≥ 2 from the rung
below?

The setup:
- the same throwaway engine, with `NAND_MODE` switching the byte's meaning in the logic assay only. The soup and
  the arithmetic assay are untouched;
- tools `minprog`, `deeppaths` and `nearest` (`dscape`);
- outputs `out/minprog_*`, `out/deeppaths_*`, `out/nearest_*`, `out/reexpress_census.txt` and `out/pilot_m*`.

**Everything in this section is pilot or measurement, not finding.**

### 7.1 The semantics tried

| | `~` does | operands afterwards |
|---|---|---|
| **0** (Logic today) | B[h0] = NAND(B[h0], B[h1]) | h1's kept, h0's lost |
| **a** | B[h0+1] = NAND(B[h0], B[h1]) | both kept, h0's neighbour lost |
| **b** | B[h1] = NAND(B[h0], B[h1]) | h0's kept, h1's lost |
| **c** | an accumulator A (from 0xFF): A = NAND(A, B[h0]); a second assay-only byte `^` stores A to B[h0] | all kept; A reusable |
| **d** | the fixed scratch cell (the buffer's third byte from the end) = NAND(B[h0], B[h1]) | both kept; one scratch |
| **e** (added) | B[h0−1] = NAND(B[h0], B[h1]): the result goes left, into the zero scratch beside the inputs | both kept |
| **f** (added) | as e, and head0 moves onto the result, so chains of NANDs stack leftward like a stack machine | both kept |

### 7.2 Minimal programs per rung

These are every straight-line program over the heads, the two copies, `~` (and `^` under c), ending in one emit,
padded to 16 bytes and credited on all 6 case sets: exhaustive to 11 bytes (10 for c), about 3 × 10⁸ programs per
semantics. "Hand" is the shortest program I could write by hand, verified on the assay.

| semantics | NOT | NAND | AND | ORN | OR | ANDN | NOR | XOR | EQU |
|---|---|---|---|---|---|---|---|---|---|
| 0, today | 4 | 5 | 7 | 6 | 7 | 8 | 9 | > 11; hand 17 | > 11; hand 19 |
| a, into h0+1 | 5 | 6 | 8 | 7 | 9 | 9 | 11 | > 11 | > 11 |
| b, into h1 | 4 | 6 | 7 | 7 | 8 | 8 | 9 | > 11; hand 20 | > 11 |
| c, accumulator + `^` | 4 | 7 | 9 | 6 | 9 | 8 | > 10 | > 10 | > 10 |
| d, fixed scratch | 6 | 6 | 8 | 7 | 11 | 9 | > 11 | > 11 | > 11 |
| e, into h0−1 | 5 | 6 | 8 | 7 | 9 | 9 | 11 | > 11; hand 15 | > 11 |
| **f, into h0−1, head follows** | 4 | 5 | 6 | 6 | 7 | 7 | 9 | > 11; hand **13** (`<<{~~{{>>~{~!`) | > 11 |

The rungs below XOR keep their order and their spacing under every semantics. No semantics brings XOR or EQU
within reach of exhaustive search:
- none at ≤ 11 bytes under any semantics (≤ 10 under c);
- the shortest known XOR is 13 bytes under f, 15 under e and 17 today.

### 7.3 Distances from realistic starting points

- **Re-expressed evolved solvers lose their ladder** (`out/reexpress_census.txt`). 1007's end world under each
  semantics, counting cells on 6 case sets:
  - today: OR + NOR in 12 213 cells;
  - a: ECHO + NOT 13 314, OR at most 629;
  - b: ECHO + ANDN 12 591;
  - c: ECHO 15 732;
  - d: ECHO 16 073;
  - e: ECHO + NOT 12 151.

  The metabolism-tape pilot's evolved ORN + OR + NOR tape keeps nothing above NOT under any new semantics. A Logic
  variant therefore re-climbs from scratch, as Logic did. The realistic starting points are the short solvers a soup
  finds: the minimal ones above, and what the pilots of §7.4 evolved.
- **From the minimal lower-rung solvers to XOR/EQU** (`deeppaths`: every k ≤ 3 substitution over the 14 symbols,
  plus `^` under c, in a 20-byte window: 2.5–3.2 M mutants per start).
  - 26 starts: the minimal NOR, OR, ANDN, ORN or AND under each semantics, plus today's hand NOR and the
    evolved metabolism-tape NOR.
  - **0 deep mutants at k = 1, 2 or 3 from every start under every semantics.** XOR and EQU stay ≥ 4 from the
    short solvers.
- **The other direction: lower-rung solvers one step below a known XOR** (`nearest`, k ≤ 3).

| semantics, XOR program | rungs one substitution away | OR | NOR |
|---|---|---|---|
| today, 17 bytes | NOT, NAND, AND, ORN, OR, ANDN | 1 | 2 |
| e, 15 bytes | NOT, NAND, AND, ORN, ANDN | 2 | 3 |
| f, 13 bytes | NOT, NAND, AND, ORN, ANDN | 2 | 3 |

  So in **every** semantics, the current one included, XOR is one substitution from *some* lower-rung solver. Those
  solvers are XOR-shaped: 13–17 bytes, a deep circuit with one byte broken. The forms evolution finds are the 6–9-byte
  ones, and from those XOR is ≥ 4 away.

  That is why the ladder stays honest only relative to the evolved solvers, which is how the Logic entry already
  measures the per-child substitution distance. It is also why no semantics makes a deep rung one step from the
  solvers that are actually there (k = 1: 0 everywhere).
- **The best case, f, has a neutral route that is too long to walk.**
  - f's 13-byte XOR, `<<{~~{{>>~{~!`, begins with its ORN solver `<<{~~` (`<<{~~!` is f's 6-byte ORN).
  - From an evolved f-ORN, XOR can be built after the ORN emit: append `{{>>~{~!`. The seven bytes before the
    final emit are neutral: code after an emit cannot change what was emitted.
  - That is a K = 8 path whose first seven steps are neutral. By the §1.3 arithmetic it is out of reach unless very
    many such completions exist.

### 7.4 Pilots

All *pilot*: the metabolism tape at 32 bytes, instruction-set draws at × 32, in 1007's pilot B end world, seed
2001 unless stated, 20 000 epochs, read every 500 epochs as in §4. The "own tape" start copies each cell's first 32
replicating-tape bytes into its metabolism tape at descent, so it carries the copy loop's opening `[` and its body.

| semantics | start | rungs at 1/10 (first epoch) | **XOR/EQU at 1/10** | most deep cells, on 6 sets | detector share |
|---|---|---|---|---|---|
| **f** | own tape | NOT 1 500; ORN, ANDN 2 000; NOR, NAND, OR 2 500 | **XOR and EQU at 4 000** | **8 078** (from 3 000 on) | 0.72–0.98 |
| **f** | own tape, seed 2002 | NOT, NAND, ORN 2 000; ANDN, OR 2 500; NOR 3 500 | none | 1 (one reading) | 0.67–0.95 |
| **f** | own tape, seed 2003 | NOT, ORN 1 500; NOR, OR 2 000; NAND 2 500 | **EQU at 14 500** | **8 434** (from 13 000 on) | 0.69–0.98 |
| f | zeros | ECHO 500; NOT 1 500; OR, NAND, ORN, ANDN 2 000; NOR 2 500 | none | 2 (one reading) | 0.58–0.95 |
| f, **deep-only** (`task_floor: xor`) | own tape | ECHO only | none | 0 | 0.45–0.92 |
| 0, today (control) | own tape | OR 0; ECHO 500; NOT, ORN 1 500; NOR 2 000 | none | 0 | 0.58–0.98 |
| e | own tape | NOT 0; ECHO 500; NAND 2 500; ORN 3 000; ANDN 3 500 | none | 0 | 0.62–0.92 |
| e | zeros | ECHO 500; NOT 2 500; NOR, OR 3 000; ORN, ANDN 3 500 | none | 0 | 0.56–0.94 |
| **f on the woven tape** (μ × 1, no metabolism tape) | 1007's world | NOT, ECHO 0; NAND, AND, ANDN, ORN 500; OR 1 500; NOR 10 000 | none | 1 (one reading) | 0.92–1.00 |

**What the stack-like NAND does.** Traced, the s2001 deep solver is a loop: `<<[~><~{~{!]`. Each lap stacks three
NANDs leftward into the zero scratch, and h1 trails two cells behind on what earlier laps wrote. So every
intermediate stays on the stack and is read again on a later lap, which is fan-out for free. On x = 0x5a,
y = 0x33 the laps emit:
1. ¬y;
2. **XOR** (0x69);
3. ¬y;
4. **EQU** (0x96).

The loop's raw material is the copier's own `[`, carried over from the replicating tape. Seeded with zeros, the
same semantics climbed to NOR in 2 500 epochs but made no deep rung. Under today's in-place NAND, seeded the same
way, nothing deep came either.

**Where the deep solvers sit, measured** (`nearest`, `deeppaths`, k ≤ 2–3 over the whole 32 bytes):
- **Lower rungs are one substitution from the evolved deep solvers.**
  - s2001's NOT + XOR + EQU tape has ANDN, ORN, NAND, AND and NOT one substitution away, and OR and NOR two.
  - s2003's NOT + ORN + OR + EQU tape has ANDN, ORN, OR, NAND, AND and NOT one away, and NOR two.

  These loop-shaped solvers are the stepping stones the population passed through. ORN, ANDN and OR all reached a
  tenth before the deep rungs did: 1 500–2 000 epochs before in s2001, and about 12 000 in s2003.
- **From the dominant tapes before the deep rungs, the deep rungs are ≥ 3–4 away, through credit losses:**
  - s2001 at 2 000 epochs (ORN + ANDN): no deep within 3 (11 M);
  - s2003's NOT + ORN + OR + NOR tape: EQU at exactly 3 (2 triples), each order through a credit loss;
  - the other NOT + ORN + OR + NOR form: none within 3;
  - s2002 (NOT + OR + NOR): none within 3;
  - the zero-seeded run (NOT + OR + ANDN + NOR): none within 3.
- **Lenski's contrast holds in the pilot.** With every rung below XOR unpaid (deep-only), the same start climbed
  nothing past ECHO.

So under f the soup assembles XOR and EQU in two steps of the population's history:
1. the paid lower rungs reorganise into a loop, a stack circuit that reads its own intermediates;
2. a final substitution or two turns that loop into XOR or EQU.

The last step is short. **The depth is in the reorganisation, which the lower rungs pay for.**

### 7.5 A register machine, sketched

**What Avida-style storage is.** Avida's CPU keeps values in three registers and two stacks.
- `nand` writes BX = NAND(BX, CX). It overwrites a register but leaves the copies, swaps and pushes intact, so a
  value can be used twice at no cost.
- `IO` emits a register and reads the next input into it, so inputs are never used up.
- The copy loop (`h-copy` … `h-divide`) ends and divides, so the task code runs outside it, in filler that
  mutation is free to rewrite.

None of that is in a two-head byte machine.

**As a Logic variant (assay-only).** The metabolism tape (or the tape's assay) is read by a small register ISA:
- three registers;
- `nand`, `swap`, `push`/`pop`, `IO`, and nop-modifiers to pick the register;
- the soup keeps BFF.

It changes:
- the assay interpreter (a second machine beside BFF's);
- the ladder's hand-written solvers;
- the separating rule, re-checked for the new ISA;
- the observables, unchanged in shape.

It costs about 3–4 engine slices (the interpreter with equivalence tests, the ladder proofs, the observables, the
metabolism tape it runs on) and the sweep. Emergence is untouched, because the soup is BFF.

What it imports is large: a CPU, not a byte. The label becomes "imports an objective, a machine and a hereditary
channel", and the programme's claim about BFF shrinks to "BFF replicators can carry an imported computer". Its
depth is also unmeasured: Lenski's EQU needs 19 Avida instructions. The landscape tool should measure XOR's
distance from the solvers that evolve under it before anything is built.

**As a real substrate (Avida-like replication too).** Then the register machine also copies itself (`h-alloc`,
`h-copy`, `h-divide`), and a cell is born by division, not by a byte-level overwrite.
- That is a new substrate: weeks of work across the interpreter, world, detector, observables and site.
- **It risks rung 1.** Avida never shows spontaneous emergence; it starts from a hand-written ancestor. Whether a
  register soup ever emerges from noise is unknown, and probably harder than in BFF. Replication would then need
  allocation, a copy loop that exits and a divide, in place of BFF's single never-ending loop.
- The programme would trade its one demonstrated result for a better rung 4.

My view: build neither yet. §7.4 shows that a change of `~` alone, the stack-like NAND f, already puts XOR and EQU
in reach on a metabolism tape.

### 7.6 Revised recommendation

**Does any semantics meet the ask?** The ask was XOR/EQU at a credited-stepping-stone distance of 2–3, while
staying ≥ 2 substitutions from the rung below. No semantics meets it cleanly.
- **a, b, c, d and e** change nothing that matters:
  - XOR stays > 11 bytes, and ≥ 4 substitutions from every minimal and evolved lower-rung solver (0 deep among 2.5–3.2
    M mutants per start);
  - no deep rung came in any pilot of e.
- **f, the stack-like NAND**, is the only one that moves the deep rungs into reach:
  - the shortest known XOR falls to 13 bytes;
  - on a metabolism tape seeded from the cell's own tape, 2 of 3 pilot seeds held XOR and/or EQU at a tenth, of up
    to 8 400 cells, within 20 000 epochs;
  - with the lower rungs unpaid, it climbed nothing;
  - under today's NAND, with the same start, it climbed nothing deep.
- **But f meets the ask by moving the depth, not by keeping it.**
  - From the forms the soup holds before the deep rungs, XOR/EQU are ≥ 3–4 substitutions away, and the paths cross
    credit losses.
  - The soup then evolves loop-shaped ORN/ANDN/OR solvers that sit **one** substitution below XOR/EQU, and takes
    that step.
  - So the deep rungs end up one step above a paid stepping stone. That is Lenski's mechanism exactly, and it is
    also what the next-substrate study's §5.1 called a one-step rung relative to the solvers present.
  - Today's NAND has the same property in principle: its 17-byte XOR has OR, ORN, ANDN, NAND, AND and NOT forms one
    substitution away (§7.3). The difference is that under f the soup actually finds those forms.

**What this means for the reading.** Under f, "a deep rung at a tenth" is not by itself a multi-step crossing.
Pre-registered under f, H-deep must be read with the per-child substitution distance the Logic entry already lists
as descriptive. Measure it from the dominant solver at the last capability rung's 10 % line to the first deep
solver, and promote it to a reported reading.

The shown/refuted language must say "assembled from paid parts" (H-stones), not "crossed a valley". H-stones (full
against deep-only) is what makes the result a mechanism: in the pilot, deep-only climbed nothing.

**Revised recommendation: both combined, in one sweep.** The metabolism tape with the stack-like NAND as a
`logic_nand` parameter (`in_place` by default, which is byte-identical; or `stack`), seeded from each cell's own
first 32 tape bytes, at the instruction-set rate × 32. The arms:
- **meta-stack**, the full ladder;
- **meta-stack-deep-only**, `task_floor: xor`;
- **meta-inplace**, the full ladder: the §5 design, kept as the semantics control.

That is 3 × 54 = 162 children against the Logic sweep's own none and full children. The tests, all one-sided sign
tests by the Logic rules:
- **H-deep-Ms** (meta-stack against Logic none). Pilot: 2 of 3 seeds.
- **H-stones-Ms** (meta-stack against meta-stack-deep-only). Pilot: 1 seed, 0 deep.
- **H-stack** (meta-stack against meta-inplace): does the NAND's semantics decide it? Pilot: 2 of 3 against 0 of 1.
- **H-deep-M** (meta-inplace against Logic none), as in §5. Pilot: 0 of 8 metabolism-tape arms with today's NAND.
- **Reported with each deep child:** the substitution distance from the pre-deep dominant solver, and its
  heritability by planting.

**Cost.** About 5–9 h of the 12 slots:
- 162 children at the 47–77 s per 1 000 epochs upper bound of §5.6;
- the pilot's metabolism-tape children ran faster than woven ones.

**Engineering.** 3 engine slices and 2 Rails slices:
- the metabolism tape (§5.5 slice 1, plus the `own_tape` seed);
- `logic_nand: stack` in `bff.rs`, with:
  - the NAND's target at h0−1 and h0 following it;
  - no lap replay across it, like today's NAND;
  - pins unmoved at `in_place`;
  - the hand-written ladder re-proved under `stack`;
- the observables;
- the sweep and the reading.

**The label.** It imports an objective, a primitive, a hereditary channel, and now a choice of the primitive's
semantics made because it lets the deep rungs come. That last import should be named in the record entry as
exactly that.

**If you want only one arm's worth of cost:** run meta-stack and meta-stack-deep-only (108 children, about 4–6 h)
and drop meta-inplace. Its answer is already predicted by 8 pilot arms. The woven stack variant (no metabolism tape)
re-climbed its ladder fast but made no deep rung in 20 000 epochs, so it is not worth an arm.

**Budget used.** Pilots about 1.7 core-hours; landscape enumeration about 2.5 core-hours (the exhaustive
short-program searches). All labelled pilot. `target/` was deleted at the end, and the study folder is 5 MB. The volume read 92 %, not from this study.
