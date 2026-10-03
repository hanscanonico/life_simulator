# Meta-stack: the locked offline readings

The readings the Meta-stack pre-registration (`docs/design_record.md`, 2026-10-02, "Meta-stack:
does a soup assemble the deep rungs from paid parts on a metabolism tape read with a stack
NAND?", "Reported with each deep child") locks for each of the sweep's 9 deep children:
the substitution distance, heritability by planting and the circuit behind each deep solver.
They were made on 2026-10-02 with `research/landscape/` at main `3cd9abb`, on the children's
stored worlds, read from the lab through SELECTs only.

- `summary.txt`: the reading, per child, with its totals, the descriptive context that is
  not locked, and the places where the locked method had to be interpreted.
- `summary.csv`: one row per planting (16: 15 locked and 1 labelled extension).
- `method/`: the scripts as run, and the source of the descriptive helper.

These are the source of the static table on the finding
`paid-parts-assemble-deep-logic-on-a-stack-nand`.

## How they were made

The inputs are the lab's production database: each deep child's `runs.params`, its stored
snapshots and its samples' `logic_share_*` values. Every script takes one argument, the output
directory `O`, and expects `research/landscape` built into `$O/target/release/landscape`
(`cargo build --release --target-dir $O/target` in `research/landscape/`).

1. `method/samples.sql` (run through `psql`) exports the samples to `$O/data/samples.csv`.
   `method/first_epochs.py` recomputes each rung's first epoch under the entry's k = 5 rule
   and picks the pre-deep and post-deep stored worlds (`$O/data/epochs.json`). It takes the
   directory above `meta-stack/offline/` and reads `meta-stack/offline/data/samples.csv` under it.
2. `method/fetch.sh $O/data` exports each child's params and the stored worlds it needs
   (pre, post and the end world at 60 000) as `$O/data/<run>/child.json` and `e<epoch>.lsnp`.
3. `landscape census` on each pre and post world, by hand, as `research/landscape/README.md`
   shows, into `$O/census/<run>-e<epoch>.txt`.
4. `method/tapes.sh $O` reads the dominant tape and the first deep solver off the censuses
   and runs `landscape distance` (`$O/distance/<run>.txt`).
5. By hand, from the README's commands: `landscape paths DOMINANT --k 3` (`$O/paths/`),
   `landscape trace DEEP --rung R` (`$O/trace/`) and `landscape paths FILLER --k 1` from each
   planting's filler (`$O/filler/`).
6. `method/plant.sh $O` runs `landscape plant` for the 16 plantings (`$O/plant/`).
7. The helper, `method/helper/` (`cargo run --release -- child.json e<pre>.lsnp DOMINANT DEEP`),
   prints the descriptive orders past the tool's 16-site lattice, the fewest substitutions
   that make the dominant tape deep and the pre-deep world's nearest tape
   (`$O/orders/<run>.txt`). It depends on `research/landscape` and `engine/` by path and is
   built nowhere by `make verify`.
8. `method/collate.py $O` writes `summary.csv` from those outputs. `summary.txt` was written
   by hand from them.

The intermediate outputs (the stored worlds, about 14 MB, and the per-child tool outputs) were
not kept; the worlds can be read again from the lab, and every step above re-run on them.
