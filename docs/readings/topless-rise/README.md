# Topless rise: H-rise-code, the locked offline reading

The descriptive reading the topless-rise pre-registration (`docs/design_record.md`, 2026-10-02,
"Topless rise: does the deepest rung held keep rising when depth is paid?", H-rise-code) locks:
the load-bearing bytes of the dominant deepest solver in each child's fifth-decile world and its
last, labelled new code, co-option, neither, no rise in depth or unread. The lock covers the one
rise child that rises late (5137) and its twins (5138, 5139); every other child of the 162 was
read too, as a descriptive extension (`locked_subset` in `summary.csv`). It was made on
2026-10-04 with `research/landscape/` at main `3a10d32` (the `loadbearing` subcommand of #298),
on the children's stored worlds, read from the lab through SELECTs only. All 486 worlds were
checked byte for byte against the lab (`md5(snapshots.blob)`).

- `summary.txt`: the reading, per arm and per child, with its method, the descriptive context
  that is not locked, a drift baseline and its caveats. It is kept as written; its FILES and
  COMMANDS sections name the working folder it was made in, of which only the files below are
  kept.
- `summary.csv`: one row per child, joined with the sweep's final report.
- `method/`: the scripts as run.

These are the source of the static tables on the finding `paid-depth-jumps-once-and-stands`.

## How it was made

The inputs are the lab's production database: the topless-rise children's `runs.params`, their
samples and their stored snapshots. The scripts run from one working folder `O`, with
`research/landscape` built into `$O/target/release/landscape`
(`CARGO_TARGET_DIR=$O/target cargo build --release --locked` in `research/landscape/`).

1. `method/worlds.sql`, run through `psql -At -F ,`, picks each child's three worlds into
   `worlds.csv`: the earliest stored world at or past the first settled sample, the last at or
   before the fifth decile's end, and the last. Every child resolves to 62 000, 110 000 and
   160 000.
2. Each child's `runs.params` is exported to `params/<run>.json`.
3. `method/fetch.sh RUN FIRST FIFTH LAST` exports the three stored worlds as
   `worlds/<run>/e<epoch>.lsnp`.
4. `method/read.sh RUN FIRST FIFTH LAST` runs `landscape loadbearing --first --fifth --last`
   into `out/<run>.txt`, which ends with the entry's label.
5. The engine's own `logic_depth_max` at the same three epochs is exported to
   `sample_depths.csv`, a cross-check (`summary.txt`, CAVEATS).
6. `method/summarize.py`, run in `O`, joins `out/`, `worlds.csv`, `sample_depths.csv` and the
   sweep's final report (`lab:topless_rise_report FORMAT=csv`, as `../final-report.csv`) by
   header name, writes `summary.csv` and prints the label counts. `summary.txt` was written by
   hand from them.

The intermediate outputs (the 486 stored worlds, about 289 MB, and the per-child tool outputs)
were not kept; the worlds can be read again from the lab, and every step above re-run on them.
