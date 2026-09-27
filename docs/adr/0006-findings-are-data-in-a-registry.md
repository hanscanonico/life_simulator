# 0006. Findings are content in a registry, not database rows

- **Status:** Accepted
- **Date:** 2026-09-10 (#15)
- **Source:** `docs/DESIGN.md` §1.3 ("A finding is published on the site…");
  `app/models/findings/registry.rb`, `app/models/findings/finding.rb`

## Context

A finding is a claim written up against the runs behind it: a narrative, a status and a
pointer to its sweep. The runs live in Postgres, but the claim is prose that gets revised
as sweeps extend and rules are clarified. It has to be versioned with the code and the
design record it cites, and reviewed like them.

## Decision

Findings are value objects in the repo. `Findings::Registry::ALL` lists them as
`Findings::Finding` entries (slug, title, date, experiment slug, status, summary, related
experiments and findings), and each one names an ERB body under
`app/views/findings/bodies/`. A status is one of `open`, `partial`, `published` or
`negative`, and anything else raises. Adding a finding means adding an entry and its body;
nothing else in the app has to change to publish it. Its evidence is read through the
experiment's own presenter and partials, never a second implementation.

## Consequences

- A finding's wording, status and evidence change in one reviewed PR, next to the
  design-record entry that justifies them. There is no admin UI and no migration.
- Specs pin the registry: unique slugs, order, every `experiment_slug` a sweep the lab can
  build, and every body partial present.
- Per-finding caveats follow the same pattern (`Findings::InstrumentNotes`, #252).
