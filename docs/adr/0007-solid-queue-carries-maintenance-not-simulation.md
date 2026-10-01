# 0007. Solid Queue carries maintenance on one lane; simulation never goes through it

- **Status:** Accepted
- **Date:** 2026-09-10 (#5, #13)
- **Source:** `docs/DESIGN.md` §2 ("The runner is a stateless worker"), §4;
  `docs/DEPLOY.md`; `config/queue.yml`, `config/recurring.yml`

## Context

Simulation is the lab's heavy work: runs take hours, use every core the runner has, and
must survive restarts. Rails needs only a little background work of its own. It has to
release runs whose runner went silent, prune the snapshots of terminal runs, and clear
finished jobs.

## Decision

- Runs are not jobs. The Rust runner claims them over HTTP (`POST /api/runs/claim`),
  heartbeats and streams its results. A run's state lives on its `runs` row and in its
  snapshots, not in a queue.
- Solid Queue runs inside Puma in production, with a single worker over all queues. Every
  job uses the `default` lane. The recurring schedule is `Runs::ReleaseStaleJob` every
  5 minutes, `Runs::PruneSnapshotsJob` every 30 minutes, and the Solid Queue cleanup every
  hour.

## Consequences

- There is no separate job container, and the job database's connection needs are sized
  with Puma's (`docs/DEPLOY.md`, pinned by `spec/config/database_pool_spec.rb`).
- One lane is enough while every job is maintenance of the same urgency. When a
  time-sensitive job arrives, give it a named lane in `config/queue.yml`, as the project
  guide requires, so bulk work cannot delay it.
