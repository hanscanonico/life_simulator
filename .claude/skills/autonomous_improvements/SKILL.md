---
name: autonomous_improvements
description: Unattended multi-hour improvement run for Life Simulator until a given time — drives /improve batches with merge and deploy authority, runs the lab operator on the mini-pc between batches, and files leftovers. Use when the user invokes /autonomous_improvements <until> [focus] or asks for an overnight or hours-long autonomous run.
---

# /autonomous_improvements <until> [focus] — run unattended until a deadline

`$ARGUMENTS` is a clock time (Europe/Paris unless a zone is given), optionally followed by
a focus hint for the scouts. The session model is the ORCHESTRATOR and never implements,
reviews or SSHes itself; the `/improve` skill is the batch engine and its rules apply
unchanged. This skill adds the clock, the lab, and the wrap-up.

Standing authority, granted once and baked in here: merge every PR whose gate is green and
whose reviewer approved (a merge to `main` deploys simulator-life.com), and act freely on the
mini-pc within the `lab` agent's limits.

## Loop

0. **Start.** Resolve the deadline to an absolute timestamp and print it. Check `git status`
   is clean on `main` and `git worktree list` for worktrees another session owns. Load the
   `improve` skill (`Skill: improve`) for the batch steps.
1. **Lab check.** Spawn a `lab` agent (`subagent_type: 'lab'`) with the deadline and the
   earlier checks' summaries. Every `findings_ready` entry becomes a task for the next
   batch: add the `Findings::Registry` entry and its ERB body, with the numbers and seeds
   the lab gave. Anything it proposed outside `Lab::SWEEPS` is recorded for the wrap-up,
   not seeded.
2. **Batch.** Run one `/improve` batch (scout with the focus hint if given, triage, workflow,
   merge, cleanup). Every batch carries at least one task that moves the research
   instrument: an observable, sweep tooling, analysis, or a finding write-up. A batch is
   launched only if it can finish before the deadline: budget 75 minutes per batch, and
   with less than that left, go to wrap.
3. **QA.** After a batch that touched views, a `qa` sweep over the main checkout; findings
   feed the next batch.
4. **Repeat** from 1 until the deadline, or until a stop condition trips.

## Stop conditions

Stop early, and say which condition tripped, when:
- `main`'s CI is red or the production deploy failed after a merge, and one fix-forward
  task (a batch on its own) did not turn it green.
- Two consecutive batches merged nothing.

At the deadline itself, nothing new starts; the batch in flight ends on its own terms.

## Wrap

- Open PRs and rejected or abandoned tasks: one GitHub issue each, labelled
  `ready-for-human`, with the reviewer's reasons.
- Sweep proposals from the lab: one issue each, labelled `needs-triage`.
- Memory: durable findings, both engineering and science, and the sweep state.
- Final message: merged PRs by theme, science state (queue, findings published), what is
  open and why, and which condition ended the run.
