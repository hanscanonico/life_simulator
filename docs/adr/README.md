# Architecture decision records

One markdown file per engineering decision that shapes how the system is built: numbered
`NNNN-short-title.md`, never renumbered, never deleted. A decision that is replaced keeps
its file with its status set to `Superseded by NNNN`, and the new ADR says what it replaces.

Each ADR has a **Status** (`Accepted`, `Superseded by NNNN`), a **Date**, and three
sections: **Context** (the forces at play), **Decision** (what was chosen) and
**Consequences** (what follows, good and bad). It cites the PRs that made the decision and
points at the section of `docs/DESIGN.md` or the entry of `docs/design_record.md` that
states it, rather than restating either.

## How ADRs relate to the design record

`docs/DESIGN.md` is the design of record and `docs/design_record.md` is its dated log:
every locked decision, scientific or architectural, changes only through an entry there.
That stays true. ADRs do not lock anything and do not replace an entry; they record the
engineering reasoning behind an architectural decision in one place, so an implementer can
find why the code is shaped the way it is without reading the whole log.

- **Science decisions** — observables, detectors, sweeps, pre-registered readings,
  relocks — live in the design record only. No ADR is written for them.
- **Engineering architecture** — process and data boundaries, storage formats, deploy
  shape, background work — gets an ADR. Where the decision is also stated in DESIGN.md or
  the design record, the ADR points there, and if the two ever disagree, DESIGN.md and the
  design record win and the ADR is corrected.

The vocabulary is the one in `CONTEXT.md` at the repo root.

## Index

| ADR | Decision |
|---|---|
| [0001](0001-engine-is-the-single-authority.md) | The engine is the single authority on rules and metrics |
| [0002](0002-runs-are-deterministic-and-additions-are-invisible.md) | Runs are deterministic, and nothing added may change an existing run |
| [0003](0003-snapshot-formats-are-versioned-and-forward-only.md) | Snapshot formats are versioned and forward-only |
| [0004](0004-readings-from-stored-worlds-live-in-snapshot-readings.md) | Readings from stored worlds live in `snapshot_readings`, not `samples` |
| [0005](0005-app-and-runner-are-separate-images.md) | App and runner are separate images, so an app-only deploy keeps the runner |
| [0006](0006-findings-are-data-in-a-registry.md) | Findings are content in a registry, not database rows |
| [0007](0007-solid-queue-carries-maintenance-not-simulation.md) | Solid Queue carries maintenance on one lane; simulation never goes through it |
