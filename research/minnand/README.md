# minnand

The exact minimal NAND count of every Boolean function of three and four inputs: the depth
scale of the topless study's nested ladder (`docs/studies/topless.md` §1.1, §1.2 (b), §1.5),
which pre-registers H-rise only on a four-input table exact past 10 gates. This crate makes
the three-input table exact and the four-input one exact to 13 gates for all but 604
functions (75 classes), which it leaves at "13 or more" (see "What remains"). It is
preparation only; no sweep, rule or observable reads it yet.

It is its own Cargo workspace with no engine dependency, so `make verify` does not build it;
`make minnand` (or `make research`, with the landscape tools) runs its fmt, clippy and tests.

```sh
cd research/minnand
cargo build --release          # then ./target/release/minnand …
cargo clean                    # afterwards
```

## The cost

The cost of f is the fewest two-input NAND gates of a circuit computing f from its inputs. A
gate may feed any number of later gates (fan-out is free: a circuit, not a formula), and
NOT a = NAND(a, a) is one gate, as the engine's logic ladder counts it
(`logic::LOGIC_TASKS`: NOT 1, AND 2, OR 3, NOR 4, XOR 4, EQU 5). This is the study's
definition exactly.

**Constants.** The inputs are free and the constants are not given: the constant 1 costs 2,
NAND(x, NOT x), and 0 costs 3, as in the study's table. Given 0 and 1 as free inputs, only
those two entries would change (to 0): a gate reading 1 is NOT of its other operand, which
NAND(a, a) computes at the same cost, and a gate reading 0, or 1 twice, is a constant whose
readers rewire the same way, so a circuit for a non-constant function with free constants
becomes one without them and no more gates. The engine's slot credit never pays a constant.

**Tables.** Bit k of a truth table is f on the row whose input values are k's bits, the
first input the most significant: on three inputs x = 0xF0, y = 0xCC, z = 0xAA; on four
w = 0xFF00, x = 0xF0F0, y = 0xCCCC, z = 0xAAAA, so the three-input functions are the
four-input ones that do not read w (the nested ladder's z and w, study §1.2).

## The files

| file | contents | SHA-256 |
|---|---|---|
| `data/minnand3.bin` | 256 bytes: byte f is the cost of the three-input function f | `66d5ba949ef999c3be27db4c3414227bdebed71f5e4570d884017854a12a0da3` |
| `data/minnand4.bin` | 65 536 bytes: byte f is the cost of the four-input function f | `5f15454855cbfe384bbd065604a7938b7e9e9c38e8b9a770fbd5e523056d13ae` |
| `data/witnesses3.txt`, `data/witnesses4.txt` | a minimal circuit per input-permutation class (80 and 3 984) | |
| `data/proofs3.txt`, `data/proofs4.txt` | how far the enumeration is exhaustive, then one line per class proven above it | |

A cost byte below 0x80 is exact. A byte with the high bit set is a proven lower bound, the
cost left open: 0x8D is "13 or more", held by the 604 four-input functions this slice did not
close. The three-input table has none.

**Witnesses.** One line a class: its representative (the least table among its input
permutations), its cost, and the circuit — the output node, then each gate's two operands,
one character a node (`0`–`9`, `a`–`z`): node i below the input count is input i, the rest
are the gates in order. A member's circuit is the representative's with its inputs
permuted. Cost is invariant under input permutation only, not under negation of an input or
the output (study §1.1), so the classes are P-classes, not NPN classes.

**Proof log.** Its first line gives the gate count to which the enumeration is exhaustive.
Each further line is `class unsat witness seconds`: the sizes above that count at which the
class has no circuit (`-` if none), then the circuit found at the next size (`-` if none),
and the wall seconds it took.

## The method

A hybrid (the slice's option c): exhaustion as far as it is cheap, then a cheap upper bound,
then SAT for what is left.

**1. Exhaustive canonical enumeration** (`src/enumerate.rs`), the study's method 1 sped up.
Every circuit is placed gate by gate with its operand pairs (max, min) strictly increasing
and every gate a function not already present. A minimal circuit computes nothing twice, and
placing at each step its least available gate orders it so, hence the first gate count at
which f appears is its exact cost and an f never reached costs more. Two cuts keep it
exact:
- **the sink bound**: a gate consumes at most two unread gates and is one itself, and a
  minimal circuit ends on one unread gate, its output; so a prefix with more unread gates
  than the remaining gates can absorb is cut, and the last gate is only tried on the unread
  ones;
- **input permutations**: cost is invariant under them, so only circuits that can be the
  lexicographically least of their 24 input-permuted images are kept. If a permutation's
  image of the prefix, ordered greedily, comes out below the prefix, the image's own
  canonical order is lower still, and the circuit is skipped (checked on the first 7 gates,
  where the work splits into tasks). Each function then takes its class's least cost, and
  its witness the permuted circuit.

On four inputs to 10 gates this places 7 × 10⁷ gates in 23 CPU-seconds, against the study's
9 minutes; to 12 gates, 1.9 × 10¹⁰ gates in 1 055 CPU-seconds (6 minutes on 8 threads). To 13
gates it did not finish: stopped at 4.0 CPU-hours with every worker still busy.

**2. Witness extension** (`Table::extend`). Every exact class's witness plus one or two
gates on its nodes: a circuit at an open class's lower bound proves its cost is the bound.
It costs about a second. Above the 12-gate exhaustion it closes 78 of the 153 open classes
(767 functions) at 13; 75 classes (604 functions) stay at "13 or more".

**3. SAT** (`src/sat.rs`, varisat, a pure-Rust solver and a dependency of this crate only).
For a class still open at bound b: is there a circuit of exactly b gates? Each gate selects
one operand pair, its value on each of the 16 rows is the NAND of the pair's, the last gate
is the class representative, and the circuit is held to the enumeration's canonical form
(pairs increasing, every gate new and non-constant, every gate but the output read later),
which every minimal circuit takes. UNSAT raises the bound by one; SAT is a witness at it.
`minnand close --limit L` runs it on the open classes, appending each result to the proof
log as it lands and resuming from it. Measured here on classes the 10- and 11-gate
exhaustions left open, an UNSAT at 11 gates took 7–155 s (wall) a class, and at 12 gates 5 of
9 searches ended (seconds to 6 CPU-minutes, all SAT) while 4 were still running after 6.4
CPU-minutes each; the whole 12-gate exhaustion took 18 CPU-minutes. So the committed table
uses no SAT; the tests use it to re-prove every three-input lower bound and a sample of
four-input ones.

## The tables

Three inputs: costs 0–10 for 3, 6, 13, 26, 43, 48, 53, 36, 22, 5 and 1 functions, the
study's table exactly; the top is "exactly one of three" (0x16) at 10.

Four inputs, by cost (functions, P-classes):

| cost | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | ≥ 13 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| functions | 4 | 10 | 31 | 98 | 293 | 807 | 2 067 | 4 351 | 8 941 | 13 085 | 16 804 | 12 210 | 5 464 | 767 | 604 |
| classes | 1 | 2 | 4 | 10 | 23 | 54 | 124 | 256 | 497 | 731 | 959 | 759 | 411 | 78 | 75 |

Costs 0–10 are the study's `minnand4` counts. XOR4 costs 12 and XNOR4 13; "exactly one of
four" (0x0116) is among the open ones. The four-input maximum is at least 13 and is not
known.

## What remains

The 75 open classes (604 functions), listed as the classes of the bytes 0x8D, each proven
to need 13 gates or more. Closing them needs, per class, a 13-gate circuit (then the cost
is 13) or a proof that none exists (then 14 or more, and the same again at 14). Two routes:
- **the exhaustion to 13 gates** decides them all at once (and finds every 13-gate class),
  but costs more than the 4 CPU-hours its run here was stopped at: the growth from 10 to 12
  gates (×6.8 a gate) predicted 2, so it grows at least ×13 from 12 to 13. Then the witness
  extension at 14, and SAT or the exhaustion to 14 for whatever is still open;
- **SAT per class**: a 13-gate search per class, and an UNSAT at 13 for those that need 14
  or more. At 12 gates searches took from seconds to more than 6 CPU-minutes; at 13 they
  will take longer, so on the order of 10–75 CPU-hours for the 75 (a guess, not measured).

The enumeration's task list cannot be resumed today; a resumable exhaustion (a checkpoint
of finished tasks) would let the 13-gate run spread over several sessions.

## Verification

`cargo test` checks the committed files (`tests/tables.rs`):
- their SHA-256 against the hashes above;
- the three-input table equals the study's checked table, class by class
  (`tests/study3.txt`, transcribed from the study's `minnand_10.txt`), and is re-derived by
  the exhaustive enumeration with and without the symmetry reduction;
- every three-input lower bound is re-proven by SAT: each class has no circuit at any size
  below its cost, and one at its cost;
- every four-input cost to 10 equals the study's `minnand4` output (the SHA-256 of
  `minnand4_best_10.bin`, which encodes "above 10" as 255);
- the four-input table extends the three-input one, and every cost is invariant under all
  input permutations;
- every witness re-evaluates to its class, and every member's permuted witness to that
  member, at the table's cost;
- the proof log accounts for every cost above the enumeration;
- the known costs: XOR 4, EQU 5, XOR3 8, MAJ3 6, the full adder 9 together (its sum is XOR3
  and its carry MAJ3), NAND3 3, AND3 4, OR3 6, NOR3 7, the top 10 (exactly one of three);
  on four inputs AND4 6, OR4 9, XOR4 12; the two-input ladder's NAND counts;
- a sample of four-input lower bounds re-proven by SAT.

The unit tests beside the code check the enumeration against the study's two-input costs,
that its witnesses re-evaluate, that its result does not depend on the thread count, and
that the symmetry reduction changes no cost (three inputs to 10 gates, four to 7).

`minnand check --inputs 4 --study minnand4_best_10.bin --upto 10` compares a table with the
study's binary directly; on the committed table it reports 0 mismatches.

## Reproducing

```sh
minnand enumerate --inputs 3 --gates 10 --out data   # 2 s
minnand enumerate --inputs 4 --gates 12 --out data   # 1 055 CPU-s
minnand close --inputs 4 --limit 12 --data data      # the witness extension; no SAT below 13
minnand check --inputs 4 --data data
minnand close --inputs 4 --limit 13 --deadline 3600 --data data   # to go on: SAT at 13
```

Each step is deterministic: the enumeration's witnesses depend on its task order, not on
its thread count (a unit test holds this), and the extension and SAT run in class order.
