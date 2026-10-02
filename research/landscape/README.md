# landscape

The offline readings the Meta-stack sweep locks to be measured after it reads
(`docs/design_record.md`, 2026-10-02, "Meta-stack: … pre-registered", "Reported with each deep
child"), on the lab's stored worlds. Ported from the design study's pilot tools
(`docs/studies/meta-stack.md`, `dscape`; `docs/studies/logic.md`, `scape`) onto the merged
engine: the metabolism tape, `logic_nand` and the logic assay (`logic::assay_on`, `Cases`).
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
| `trace T --params P --rung R [--lines 60]` | (d) the traced stepper on x = 0x5a, y = 0x33 and the 6 fixed sets: the circuit behind the rung's output and what it reads twice |

A tape is `hex:` and two digits a byte (what `census` prints), or its shown form (ops, `!`,
`~`, `0` for a zero, `·` or `_` for a no-op), padded with zeros to the run's assayed length.
The params file is the run's `runs.params`, the JSON the runner is handed.

**The 6 fixed case sets** are the study's landscape draw (`logic::Cases::draw` six times off
`rng::seeded(0xdee9, 1, 0)`), frozen in `src/score.rs`. "Credited" in every reading means
credited on all six; paid units are counted from the run's `task_floor`.

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
fewer; **Unresolved** where a control reaches the tenth; **NotHeritable** otherwise. Each
seed's readings every 500 epochs are printed.

How the run is made, where the entry leaves it open:
- every cell outside the block whose assayed tape is credited the rung **on any one** of
  the 6 sets is wiped, so no partial solver is left to restart it; the filler is the
  world's commonest assayed tape credited the rung on none;
- the control keeps the block's planted replicating tapes and gives it the filler as its
  metabolism tape, so the two worlds differ only in the block's metabolism tapes;
- the end world is resumed from its snapshot under the child's params and each seed
  (`World::from_snapshot`), so planting is deterministic from the stored world, the params
  and the seed.

**3. Whether it reads an input twice.**

```sh
./target/release/landscape trace $DEEP --params child.json --rung xor
```

The stepper gives every value a provenance (an input, a byte of the buffer, a NAND, a shift;
a copy moves a value without making a new one) and reads the circuit behind the rung's
output slot. A value is read twice where two different NANDs of that circuit take it as an
operand; NAND(x, x) reads x once. It prints the traced case's circuit, then over the 6 sets'
18 cases how many read an input or an intermediate twice (the entry's reading) and how many
read x or y itself twice. The rule names the circuit, not the rung: the stack ORN `<<{~~!`
is NAND(NAND(y, x), x) and reads x twice.

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
