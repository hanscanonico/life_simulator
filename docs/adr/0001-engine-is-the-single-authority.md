# 0001. The engine is the single authority on rules and metrics

- **Status:** Accepted
- **Date:** 2026-09-10
- **Source:** `docs/DESIGN.md` §2 ("The engine is the single authority"), since the
  scaffold commit

## Context

The simulation runs in two places: natively in the lab `runner` and in the browser viewer
through wasm. Rails then reads what those runs stored, long after they end. A rule
or a metric written twice, once in Rust and once in Ruby or JavaScript, would drift, and a
finding would then rest on whichever copy happened to compute it.

## Decision

The Rust crate `life-engine` owns every rule, every observable and the rendering colours.
It compiles natively for the runner and to wasm for the viewer, so both run the same code.
Rails never re-implements a rule and the browser never re-implements a metric. Parameters
are data: `Params` in the engine holds each one's name, default and range, and Rails reads
them through `runner schema` (§3).

Where Rails has to re-read stored samples by an engine rule — the transition predicate, to
recover crossings and read persistence — it asks one module, `Lab::TransitionRule`, whose
numbers come from the engine's schema. Rails-side readings of stored series (emergence
confirmation, persistence, the pre-registered sweep readings) combine engine observables.
They never compute a new observable.

## Consequences

- A new observable is an engine change (a `Metrics` field and its tests), never a
  presenter or a Stimulus controller. In the browser, the simulation is the viewer's one
  Stimulus controller driving the wasm world. The other controllers handle page behaviour
  and compute no metric.
- An engine change restarts lab runs on deploy (ADR 0005). An app change does not.
- Readings taken later from stored worlds are engine readings too: the runner computes
  them and posts the values (ADR 0004).
