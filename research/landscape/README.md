# landscape

The offline readings the Meta-stack sweep locks to be measured after it reads
(`docs/design_record.md`, 2026-10-02, "Meta-stack: … pre-registered", "Reported with each deep
child"), the topless-rise sweep's H-rise-code and the genes-rise sweep's gene-wise readings
(below), on the lab's stored worlds. Ported
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
| `loadbearing --snapshot W --params P` | the same for a stored world's dominant deepest solver against its deepest solid rung |
| `loadbearing --first W1 --fifth W5 --last W10 --params P` | a topless-rise child's three worlds, each as above, and the H-rise-code label from the fifth-decile world to the last |
| `genes --snapshot W --params P` | a genes world's gene-wise census and its top solver's program side and load (the genes machine, below) |
| `genes --fifth W5 --last W10 --params P` | a genes-rise child's fifth-decile and last worlds, each as above, then key by key |
| `genes T --params P [--level F]` | one tape's solver reading under the run's genes machine, at fidelity level F (level 0's rate by default) |
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
`trace` read the two-input ladder only. On a run that reads its metabolism tapes as genes
(`meta_genes`), `census` prints `genes --snapshot`'s reading and `loadbearing` refuses: it
reads a tape whole, which is not that run's machine. Every other run reads exactly as it did.

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
- **the worlds**: the earliest stored world at or past the first settled sample (the
  settled samples are the child's samples above `parent_epoch` + 1 000), the last stored
  world at or before the fifth decile's end, and the last stored world. Deciles cut the n
  settled samples by index, decile k from ⌊(k − 1)·n/10⌋ to before ⌊k·n/10⌋, so the fifth
  ends at the ⌊n/2⌋-th settled sample;
- **printed**: the three worlds' depths and counts, and the label, judged from the
  fifth-decile world to the last: **new code** where the depth rose and the count rose by 2
  or more, **co-option** where the depth rose and the count did not, **neither** where the
  depth rose and the count rose by exactly 1, **no rise in depth** where the depth did not
  rise, and **unread** where the fifth-decile or the last world holds no rung by a tenth.

SELECTs only. For a child run `$RUN`:

```sh
psql "$LAB_DATABASE_URL" -At -c "SELECT params FROM runs WHERE id = $RUN" > child.json
# the three worlds: FIRST, the earliest stored at or past the first settled sample; FIFTH,
# the last stored at or before the fifth decile's end; LAST, the last stored
read FIRST FIFTH LAST < <(psql "$LAB_DATABASE_URL" -At -F ' ' -c "
  WITH r AS (SELECT id, parent_epoch FROM runs WHERE id = $RUN),
  settled AS (
    SELECT s.epoch, ROW_NUMBER() OVER (ORDER BY s.epoch) AS i, COUNT(*) OVER () AS n
    FROM samples s JOIN r ON s.run_id = r.id WHERE s.epoch > r.parent_epoch + 1000),
  bounds AS (
    SELECT MIN(epoch) AS first_settled, MAX(epoch) FILTER (WHERE i <= 5 * n / 10) AS fifth_end
    FROM settled),
  stored AS (
    SELECT sn.epoch FROM snapshots sn JOIN r ON sn.run_id = r.id WHERE sn.blob IS NOT NULL)
  SELECT (SELECT MIN(epoch) FROM stored, bounds WHERE epoch >= first_settled),
         (SELECT MAX(epoch) FROM stored, bounds WHERE epoch <= fifth_end),
         (SELECT MAX(epoch) FROM stored)")
for EPOCH in $FIRST $FIFTH $LAST; do
  psql "$LAB_DATABASE_URL" -At -c \
    "SELECT encode(blob, 'hex') FROM snapshots WHERE run_id = $RUN AND epoch = $EPOCH" \
    | xxd -r -p > e$EPOCH.lsnp
done
./target/release/landscape loadbearing --first e$FIRST.lsnp --fifth e$FIFTH.lsnp \
  --last e$LAST.lsnp --params child.json
```

It prints each world's deepest solid rung, its dominant solver with the positions that bear
it and how many of the 13 substitutes lose the depth at each, and the label. `census` on any
of the three shows the tally behind it. Run it on every rise child that rises late and on
its twins in the other arms.

## The genes machine, per genes-rise child

For the genes-rise sweep's offline keys, on worlds whose metabolism tapes grow, are read as
genes and may carry fidelity levels (`meta_genes`, `meta_max_len`, `meta_fid_max`; snapshot
versions 12 to 17). The definitions are the design study's (`docs/studies/unassisted.md`),
applied as its pilots 5 to 8 applied them, with the engine's own gene split
(`topless::genes`) and assay (`topless::assay_upto` at the run's `task_max_outputs` slots):
- **a gene's classes** (§10.1): the gene, cut at offsets 0, G, 2G… and the last zero-padded
  to G, run alone; its classes are those credited on all 6 fixed four-input sets. A cell's
  classes are the union of its genes'. A gene holding no emit byte is never run;
- **essential genes** (§10.1, the engine's `topless::essential_genes`): the genes grouped by
  their class sets, copies being one group, a group counted where it computes a class no
  other group of the tape computes. **Held by a tenth**: the most that at least a tenth of
  all cells carry (1 639 of 16 384), the engine's `genes_essential_held` read over every
  cell instead of 256 sampled;
- **the census**, over all cells: silent cells and classes per cell; classes held by a
  tenth and the deepest of them; classes per computing cell p10, p50, p90 and the most, and
  per-cell max depth the same; **the minimum** (§13.4) is classes p10 and max depth p10;
  essential genes per computing cell; live length; the fidelity levels, cells per level
  and p10, p50, p90. Percentiles are at the nearest rank (the ⌈n·p/100⌉-th smallest), as
  the engine reads `fidelity_p10` and the rest;
- **the top solver** (§9's top-repertoire solver): the commonest tape among the cells whose
  classes reach the computing cells' p90, ties broken by byte order;
- **count-bearing bytes** (§10.1, `nbc`): positions where at least 7 of the 13 other
  symbols of the 14-symbol alphabet leave the tape fewer classes (the mutant gene re-run,
  the union re-taken). **Load-bearing genes** (§10.1, `bseg`): the genes holding a
  count-bearing byte, with their distinct bodies (`bbod`: a core runs from a gene's first
  count-bearing byte to its last);
- **`sub`** (§11.1): over the live bytes, the share of the 14 draws of a substitution (the
  byte's own symbol among them) that leave the tape fewer classes, summed; a byte whose 13
  others all lose a class counts 13/14;
- **U** (§11.1, §12.1): the solver's own rate, `meta_rate` · 2^(−f/2) (`fidelity::rate`) at
  f the median level of the cells carrying it, times `sub`: the substitution load per epoch.
  §11.1's U_sub per generation is that times the generation time T_gen, which no stored
  world holds; §11.1's frameshift share U_frame is not read.

The pilots took a gene's six-set credit as the functions every set credits, then their
classes; the engine's credits hold classes, so here a class is credited where every set
credits it. On the study's §10.1 checks the two agree: the loop `<<<<[!{~!~]` reads 12
classes alone; two copies read one essential gene and no load-bearing one; beside its tandem
variant `<<<<[!{~!{~!~]` it reads 26 classes, two essential genes, two load-bearing genes of
11 and 14 count-bearing bytes.

The worlds are the topless-rise entry's fifth-decile and last stored worlds (above): the
settled samples are the child's above `parent_epoch` + 1 000, the fifth decile ends at the
⌊n/2⌋-th, and the world read is the last stored at or before it. Under `snapshot_every` 500
the cadence stores one every 500 epochs, so the fifth-decile world is within 500 epochs of
the decile's end. SELECTs only. For a child run `$RUN`:

```sh
psql "$LAB_DATABASE_URL" -At -c "SELECT params FROM runs WHERE id = $RUN" > child.json
read FIFTH LAST < <(psql "$LAB_DATABASE_URL" -At -F ' ' -c "
  WITH r AS (SELECT id, parent_epoch FROM runs WHERE id = $RUN),
  settled AS (
    SELECT s.epoch, ROW_NUMBER() OVER (ORDER BY s.epoch) AS i, COUNT(*) OVER () AS n
    FROM samples s JOIN r ON s.run_id = r.id WHERE s.epoch > r.parent_epoch + 1000),
  bounds AS (SELECT MAX(epoch) FILTER (WHERE i <= 5 * n / 10) AS fifth_end FROM settled),
  stored AS (
    SELECT sn.epoch FROM snapshots sn JOIN r ON sn.run_id = r.id WHERE sn.blob IS NOT NULL)
  SELECT (SELECT MAX(epoch) FROM stored, bounds WHERE epoch <= fifth_end),
         (SELECT MAX(epoch) FROM stored)")
for EPOCH in $FIFTH $LAST; do
  psql "$LAB_DATABASE_URL" -At -c \
    "SELECT encode(blob, 'hex') FROM snapshots WHERE run_id = $RUN AND epoch = $EPOCH" \
    | xxd -r -p > e$EPOCH.lsnp
done
./target/release/landscape genes --fifth e$FIFTH.lsnp --last e$LAST.lsnp --params child.json
```

It prints each world's census and top solver (per gene: its classes, those no other gene
computes, its count-bearing bytes and its bytes), then each key fifth-decile → last with the
change. `genes --snapshot e$EPOCH.lsnp --params child.json` reads one world;
`genes $TAPE --params child.json --level 12` reads one tape at a level.

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
