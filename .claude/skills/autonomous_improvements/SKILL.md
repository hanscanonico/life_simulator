---
name: autonomous_improvements
description: Unattended multi-hour improvement run for Life Simulator until a given time — drives /improve batches with merge and deploy authority, runs the lab operator on the mini-pc between batches, and files leftovers. Use when the user invokes /autonomous_improvements <until> [focus] or asks for an overnight or hours-long autonomous run.
---

# /autonomous_improvements <until> [focus] — run unattended until a deadline

`$ARGUMENTS` is a clock time (Europe/Paris unless a zone is given), optionally followed by
a focus hint for the scouts. Without a parseable time, ask for one and stop. The session
model is the ORCHESTRATOR and never implements, reviews or SSHes itself; the `/improve`
skill is the batch engine and its rules apply unchanged. This skill adds the clock, the
lenses, the lab, and the wrap-up.

Standing authority, granted by the user in the design session of 2026-09-10 and baked in
here so an invocation is one line: merge every PR whose gate is green and whose reviewer
approved (a merge to `main` deploys simulator-life.com through the CI `deploy` job), and
act freely on the mini-pc within the `lab` agent's limits. Nothing is posted to the user
mid-run; the wrap is the report.

## Loop

0. **Start.** Resolve the deadline to an absolute timestamp and print it. Check `git status`
   is clean on `main` and `git worktree list` for worktrees another session owns. Load the
   `improve` skill (`Skill: improve`) for the batch steps.
1. **Lab check.** Spawn a `lab` agent (`subagent_type: 'lab'`) with the deadline and the
   earlier checks' reports. Every `findings_ready` entry becomes a task for the next
   batch: the `Findings::Registry` entry and its ERB body, carrying the numbers and seeds
   the lab gave. `proposals` are kept for the wrap-up.
2. **Batch.** One `/improve` batch. Scout lenses are the whole programme, chosen by
   value: public site UX and content, Rails health, Rust engine quality and performance,
   the research instrument (observables, sweep tooling, analysis, finding write-ups),
   deploy and ops. The focus hint, if given, narrows them. Every batch carries at least
   one research-instrument task. A batch starts only with 75 minutes or more before the
   deadline (scout, implement, review, retry and merge for 4–6 tasks); with less, go to
   wrap. After a batch that touched views, the `qa` sweep of `/improve` step 5.
3. **Repeat** from 1 until the deadline or a stop condition.

## Stop conditions

Stop early, naming the condition, when:
- `main` is red: `gh run list --branch main --limit 1` shows a failed run, or its `deploy`
  job failed. One fix-forward task, run as a batch of its own, gets one chance to turn it
  green.
- Two consecutive batches merged nothing.

At the deadline nothing new starts and nothing more merges: a PR still open then is
filed at wrap, whatever its verdict.

## Wrap

- Open PRs and rejected or abandoned tasks: one GitHub issue each, labelled
  `ready-for-human`, with the reviewer's reasons and the PR link.
- Lab proposals: one issue each, labelled `needs-triage`, with the measurement plan.
- Memory: durable findings, engineering and science, and the sweep state.
- Final message: merged PRs by theme, science state (queue, findings published), what is
  open and why, and which condition ended the run.
