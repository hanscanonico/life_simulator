# 0004. Readings from stored worlds live in `snapshot_readings`, not `samples`

- **Status:** Accepted
- **Date:** 2026-09-25 (#246)
- **Source:** `docs/DESIGN.md` §2 ("Readings from stored worlds live in
  `snapshot_readings`"); `app/models/snapshot_reading.rb`

## Context

The orientation-aware census (#247) arrived after most of the corpus had finished. The
only way to read those runs with it was to restore their stored worlds and read them
again. That output had no correct home. `samples` is the live record, written only while
a run runs, and ADR 0002 forbids a later instrument from rewriting it. `rescores` has fixed
columns and is keyed by `top_k`.

## Decision

A table of its own, `snapshot_readings`: `run`, `epoch`, `source_epoch` (the stored world
it was stepped from, never later than `epoch`), a named, versioned `instrument`
(`name/version`, e.g. `oriented_census/1`) and `values jsonb`. It is unique on
`(run, instrument, epoch)`, so a repeat pass overwrites. The runner computes the values
with the engine (`runner readings-corpus`) and posts them to `POST /api/runs/:id/readings`.
`Runs::RecordReadingsService` validates the whole batch before one upsert.

## Consequences

- Samples stay a faithful live record, and a finding can always say which of the two it
  reads.
- Readings outlive their worlds: pruning snapshots never deletes them.
- What an instrument version reads never changes once readings exist under it. A
  wider reading is a new version (`oriented_census/2`, a pass of its own), and every
  summary that reads `/1` goes on reading `/1`.
- A restored world is read at a kept-snapshot resolution (about every 1 000 epochs for a
  finished run), which is coarser than the live samples.
