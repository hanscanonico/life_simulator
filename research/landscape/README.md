# landscape

The offline readings the Meta-stack sweep locks to be measured after it reads
(`docs/design_record.md`, 2026-10-02, "Meta-stack: … pre-registered", "Reported with each deep
child"), and the topless-rise sweep's H-rise-code (below), on the lab's stored worlds. Ported
from the design study's pilot tools (`docs/studies/meta-stack.md`, `dscape`;
`docs/studies/logic.md`, `scape`; `docs/studies/topless.md`, `bearing`) onto the merged
engine: the metabolism tape, `logic_nand`, the logic assay (`logic::assay_on`, `Cases`) and
the topless assay (`topless::assay`).
Every rule is the engine's — the assay, the NAND, the detector, the world — but for the
traced stepper, which a test holds to the engine's interpreter on 20 000 random tapes.

It is its own Cargo workspace with a path dependency on `engine/crates/life-engine`, so
`make verify` does not build it; `make landscape` runs its fmt, clippy and tests.

```sh
cd research/landscape
cargo build --release          # then ./target/release/landscape …
cargo clean                    # afterwards: the target dir is about 500 MB
```

## The subcommands

| command | reading |
|---|---|
| `census --snapshot W --params P [--top 8]` | (a) the commonest metabolism tapes and replicating tapes, each with its credit on the 6 fixed case sets under the run's NAND, the detector on the replicating ones; per rung the cells credited and the commonest tape so credited; the commonest deep solver |
| `distance A B --params P` | (b) substitutions between two tapes (edit distance across lengths), and over every order of them whether one is credited (every step earns more paid units) or neutral or better |
| `paths START --params P [--k 3] [--window N] [--rungs xor,equ]` | (b) every set of 1 to k substitutions over the 14-symbol alphabet inside the window, exhaustive as the study searched (`deeppaths`, §2.4 and §7.3): the mutants credited a target rung on all 6 sets, by k, with their orders; the shortest and the shortest credited k |
| `plant --snapshot END --params P --deep T --rung R [--source W \| --replicating T]` | (c) heritability by planting with its unplanted control, the entry's rule exactly |
| `loadbearing T --params P [--depth D]` | the topless ladder's load-bearing bytes of a tape against a depth, its own by default (H-rise-code below) |
| `loadbearing --snapshot W --params P [--last W2]` | the same for a stored world's dominant deepest solver against its deepest solid rung; with `--last`, both worlds and the H-rise-code label |
| `trace T --params P --rung R [--lines 60]` | (d) the traced stepper on x = 0x5a, y = 0x33 and the 6 fixed sets: the circuit behind the rung's output and what it fans out, descriptive |

A tape is `hex:` and two digits a byte (what `census` prints), or its shown form (ops, `!`,
`~`, `0` for a zero, `·` or `_` for a no-op), padded with zeros to the run's assayed length.
The params file is the run's `runs.params`, the JSON the runner is handed.

**The 6 fixed case sets** are the study's landscape draw (`logic::Cases::draw` six times off
`rng::seeded(0xdee9, 1, 0)`), frozen in `src/score.rs`. "Credited" in every reading means
credited on all six; paid units are counted from the run's `task_floor`.

**On a `logic3` or `logic4` run** (the topless ladder), `census` reads the topless assay
(`topless::assay`) under the run's own instruction set and NAND, a rung credited where all six
of the ladder's fixed sets credit it, and ignores `--top`. It prints, per depth, the cells
credited a rung that deep and the commonest tape so credited; the rungs held by a tenth of the
world; the world's deepest solid rung; and its dominant deepest solver. The four-input sets
are the topless-rise entry's (`topless::Cases::draw(Inputs::Four, ·)` six times off
`rng::seeded(0xdee9, 4, 0)`), the three-input ones the same rule off
`rng::seeded(0xdee9, 3, 0)`, all frozen in `src/depth.rs`. `distance`, `paths`, `plant` and
`trace` read the two-input ladder only.

## Getting a stored world out of the lab

SELECTs only. For a child run `$RUN` and a snapshot epoch `$EPOCH`:

```sh
psql "$LAB_DATABASE_URL" -At -c "SELECT params FROM runs WHERE id = $RUN" > child.json
psql "$LAB_DATABASE_URL" -At -c \
  "SELECT encode(blob, 'hex') FROM snapshots WHERE run_id = $RUN AND epoch = $EPOCH" \
  | xxd -r -p > e$EPOCH.lsnp
# the stored epochs: SELECT epoch FROM snapshots WHERE run_id = $RUN AND blob IS NOT NULL ORDER BY epoch
```

The first epochs below are the reading's own (`lab:meta_stack_report`, first own epoch at
1/10 under k = 5).

## The locked readings, per deep child

**1. The substitution distance.** Let `E_last` be the first epoch of the last lower rung to
reach the line, and `E_deep` the deep rung's first epoch.

```sh
# the dominant metabolism tape: the stored world nearest at or before E_last
./target/release/landscape census --snapshot e$E_BEFORE.lsnp --params child.json --top 1
#   -> the first row of "commonest metabolism tapes": DOMINANT
# the first deep solver: the first stored world after E_deep
./target/release/landscape census --snapshot e$E_AFTER.lsnp --params child.json --top 1
#   -> "commonest deep solver": DEEP
./target/release/landscape distance $DOMINANT $DEEP --params child.json
```

`substitutions` is the distance. **A multi-step crossing only if it is ≥ 2.** For the
study's view of the path, `paths $DOMINANT --params child.json --k 3` lists every deep
mutant within 3 substitutions and whether a credited order reaches it.

**2. Heritability by planting.** On the child's end world, once per deep rung it reached:

```sh
./target/release/landscape plant --snapshot e$END.lsnp --params child.json \
  --deep $DEEP --rung xor --source e$E_AFTER.lsnp
```

`--source` is the world the deep solver was read on; the planted replicating tape is that of
its first cell in row order holding it (or give it with `--replicating`). The defaults are
the entry's: a 4×4 block in the centre, seeds 2001–2003, 2 000 epochs. The verdict is
**Heritable** where in at least 2 of the 3 seeds the planted world has at least a tenth of
the world (1 639 cells) credited the rung at 2 000 epochs and its control, same seed, 16 or
fewer; **Unresolved** where any seed's control reaches the tenth, whatever the other seeds
read; **NotHeritable** otherwise. Each
seed's readings every 500 epochs are printed.

How the run is made (the entry locks each of these too):
- every cell outside the block whose assayed tape is credited the rung **on any one** of
  the 6 sets is wiped, so no partial solver is left to restart it; the filler is the
  world's commonest assayed tape credited the rung on none;
- the control keeps the block's planted replicating tapes and gives it the filler as its
  metabolism tape, so the two worlds differ only in the block's metabolism tapes;
- the end world is resumed from its snapshot under the child's params and each seed
  (`World::from_snapshot`), so planting is deterministic from the stored world, the params
  and the seed.

**3. The circuit behind it (descriptive).**

```sh
./target/release/landscape trace $DEEP --params child.json --rung xor
```

The stepper gives every value a provenance (an input, a byte of the buffer, a NAND, a shift;
a copy moves a value without making a new one) and reads the circuit behind the rung's
output slot. A value fans out where two different NANDs of that circuit take it as an
operand; NAND(x, x) reads x once. It prints the traced case's circuit and what it fans out,
then over the 6 sets' 18 cases how many fan out an input or an intermediate and how many x or
y itself. The entry prints this and tests nothing on it: every NAND circuit for XOR or EQU
fans a value out, since neither is read-once, and read-once rungs can be built fanning out
too — the stack ORN `<<{~~!` is NAND(NAND(y, x), x), and the stack OR and NOR fan out NOT x.

## H-rise-code, per topless-rise child (descriptive)

The topless-rise entry (`docs/design_record.md`, 2026-10-02, "Topless rise: … pre-registered")
locks the method; this tool applies it exactly:
- **the world's deepest solid rung**: the deepest rung credited on all 6 fixed four-input
  sets to at least a tenth of the cells (1 639 of 16 384);
- **the dominant deepest solver**: the commonest metabolism tape credited a rung of that depth
  held by a tenth, on all 6 sets, ties broken by byte order;
- **load-bearing bytes** (study §2.3): the positions at which at least 7 of the 13 other
  symbols of the 14-symbol alphabet (`src/tape.rs`) leave the tape credited, on all 6 sets, no
  rung as deep as the world's deepest solid rung. A byte outside the alphabet is read as the
  generic no-op it stands for, so it too has 13 others;
- **the worlds**: the earliest stored world at or past the first settled sample (the first
  sample above `parent_epoch` + 1 000), and the last stored world;
- **printed**: both depths and both counts, and the label: **new code** where the depth rose
  and the count rose by 2 or more, **co-option** where the depth rose and the count did not,
  "neither" where the count rose by 1, "no rise in depth" otherwise.

SELECTs only. For a child run `$RUN`:

```sh
psql "$LAB_DATABASE_URL" -At -c "SELECT params FROM runs WHERE id = $RUN" > child.json
# the two worlds: FIRST, the earliest stored at or past the first settled sample; LAST
read FIRST LAST < <(psql "$LAB_DATABASE_URL" -At -F ' ' -c "
  SELECT MIN(sn.epoch) FILTER (WHERE sn.epoch >= (
           SELECT MIN(s.epoch) FROM samples s WHERE s.run_id = r.id
             AND s.epoch > r.parent_epoch + 1000)),
         MAX(sn.epoch)
  FROM runs r JOIN snapshots sn ON sn.run_id = r.id AND sn.blob IS NOT NULL
  WHERE r.id = $RUN GROUP BY r.id")
for EPOCH in $FIRST $LAST; do
  psql "$LAB_DATABASE_URL" -At -c \
    "SELECT encode(blob, 'hex') FROM snapshots WHERE run_id = $RUN AND epoch = $EPOCH" \
    | xxd -r -p > e$EPOCH.lsnp
done
./target/release/landscape loadbearing --snapshot e$FIRST.lsnp --last e$LAST.lsnp \
  --params child.json
```

It prints each world's deepest solid rung, its dominant solver with the positions that bear
it and how many of the 13 substitutes lose the depth at each, and the label. `census` on
either world shows the tally behind it. A world holding no rung by a tenth reads "unread".
Run it on every rise child that rises late and on its twins in the other arms.

## What was dropped from the pilot tools

The pilot tools ran on throwaway engine copies. Not ported:
- the `NAND_MODE` switch and its semantics a–e and the accumulator's `^` byte (§7.1): the
  merged engine has `logic_nand: in_place | stack` only, and the readings use the run's own;
- the pilot's metabolism-tape scaffolding (`META`, `META_LEN`, `META_MU`, `META_OPBIAS`,
  `mpilot`) and its input-repeat, assay-only head-move and input-load probes
  (`INPUT_REPEATS`, `INPUT_OPS`): the engine carries the tape itself now;
- the interaction tallies (`rates`, `STATS`), and the one-off searches the study used to
  map the woven landscape (`sub3`, `deep3`, `nsub`, `beam`, `path2`, `mk`, `msearch`,
  `mpath2`, `bothforms`, `minprog`, `nearest`, `cover`, `dfe`, `offspring`, `bytefreq`) and
  `scape`'s neighbourhood and indel enumerations: no locked reading needs them;
- the pilot's own world loaders, which read scratchpad paths: a world is now a snapshot
  and a params file.
