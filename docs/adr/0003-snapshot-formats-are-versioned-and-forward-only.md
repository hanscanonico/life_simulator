# 0003. Snapshot formats are versioned and forward-only

- **Status:** Accepted
- **Date:** 2026-09-13 (version 3, #160); extended 2026-09-14 (version 4, #166),
  2026-09-16 (version 5, #201) and 2026-09-19 (versions 6–8, #222)
- **Source:** `docs/design_record.md` 2026-09-13 ("A snapshot carries the lineage tags
  (format version 3)"), 2026-09-14 ("Room to grow"), 2026-09-16 ("An energy stock"),
  2026-09-19 ("A relative transition reading"); `engine/crates/life-engine/src/snapshot.rs`

## Context

Lab runs last hours and are resumed from their latest snapshot whenever the runner
restarts. Rails stores the blobs verbatim in `snapshots`, and the corpus passes restore
them long after the run ends. Each new piece of world state — lineage tags, growable tape
lengths, energy stocks, the relative transition tracker — has to survive a resume, or a
resumed run diverges from the uninterrupted one (ADR 0002). Blobs of every older shape are
still in Postgres.

## Decision

The snapshot is an engine-owned container: `LSNP` magic, a version byte, a header the
engine checks against the run's own params before any restore, then zlib payloads. New
state gets a new version, not a changed one:

- **1–2**: tapes only (version 1 has no transition tracker).
- **3**: plus lineage tags.
- **4**: ragged tapes, their live lengths and the tape cap.
- **5**: plus energy stocks.
- **6, 7, 8**: versions 3, 4 and 5 with the relative transition block written last.

The engine now writes only 6, 7 or 8, the lowest its state needs (8 with a stock, 7 with
ragged tapes, 6 otherwise); 1–5 are read, never written. Every older version still
decodes and restores; a version 1 or 2 blob restores with one lineage id per cell.

## Consequences

- The format is forward-only: an engine that predates a version rejects that blob
  (`UnsupportedVersion`) rather than resuming without the state. Deploy the engine before
  any run writes a new version. Reverting after that strands every run whose latest
  snapshot has the newer version.
- Runs resumed only from version 1 or 2 blobs restart their lineage census at the resume.
  That is a limit of their record, not a reading of their world.
- A header mismatch refuses the restore, for example a blob written under another tape
  cap. It never silently resumes under different conditions.
