//! `runner rescore` — re-reads one stored world at several `top_k` settings.
//!
//! The replicator test itself is the engine's (`docs/DESIGN.md` §1.2) and is not touched:
//! rescoring only builds the same world again with `top_k` overridden and asks for
//! `metrics()`, so the numbers it prints are the numbers a run with that setting would
//! have reported at that epoch.

use crate::api::{CorpusRun, LabClient, StoredWorld};
use anyhow::{anyhow, bail, Context, Result};
use life_engine::metrics;
use life_engine::{Metrics, Params, World};
use serde::Serialize;
use serde_json::{json, Value};
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

/// How many of the most populous tapes the report breaks down one by one.
const TOP_TAPES: u32 = 5;

/// Which stored world to read.
pub enum Source {
    /// A run's world, as the lab holds it.
    Lab {
        api: String,
        token: String,
        run: i64,
        /// The newest stored world when `None`.
        epoch: Option<u64>,
    },
    /// A snapshot blob on disk, with the params that describe its bytes. The epoch comes
    /// from the blob's own header, as it does for a world fetched from the lab.
    File {
        path: PathBuf,
        params: Params,
        seed: u64,
    },
}

pub struct Options {
    pub source: Source,
    pub top_k: Vec<u32>,
}

/// Which stored worlds of a run the corpus pass reads.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, clap::ValueEnum)]
pub enum Epochs {
    /// The newest stored world of each run.
    #[default]
    Latest,
    /// Every stored world of each run.
    All,
}

pub struct CorpusOptions {
    pub api: String,
    pub token: String,
    pub experiment: String,
    pub top_k: Vec<u32>,
    pub epochs: Epochs,
    /// How many worlds to measure at most; all of them when `None`.
    pub limit: Option<usize>,
    /// Measure and print, store nothing.
    pub dry_run: bool,
}

/// What a corpus pass did, for the caller and the tests: the worlds it measured, the
/// worlds it could not read, and the readings it stored.
#[derive(Debug, Default, PartialEq, Eq)]
pub struct CorpusSummary {
    pub worlds: usize,
    pub failed: usize,
    pub stored: usize,
}

#[derive(Debug, Serialize)]
pub struct Report {
    pub run: Option<i64>,
    pub epoch: u64,
    pub seed: u64,
    pub width: u32,
    pub height: u32,
    pub settings: Vec<Setting>,
    pub top_tapes: Vec<TapeReading>,
}

/// What one `top_k` reads on this world.
#[derive(Debug, Serialize)]
pub struct Setting {
    pub top_k: u32,
    pub replicator_count: u64,
    pub top_share: f64,
    pub distinct_tapes: u64,
    pub compress_ratio: f64,
    pub entropy_bits: f64,
}

#[derive(Debug, Serialize)]
pub struct TapeReading {
    pub rank: u32,
    pub count: u64,
    pub share: f64,
    pub replicates: bool,
}

pub fn execute(options: Options) -> Result<Report> {
    let (run, stored) = match options.source {
        Source::Lab {
            api,
            token,
            run,
            epoch,
        } => {
            let stored =
                LabClient::new(&api, &token)
                    .world(run, epoch)?
                    .ok_or_else(|| match epoch {
                        Some(epoch) => anyhow!("run {run} has no stored world at epoch {epoch}"),
                        None => anyhow!("run {run} has no stored world"),
                    })?;
            (Some(run), stored)
        }
        Source::File { path, params, seed } => (None, read_blob(&path, params, seed)?),
    };
    measure(&stored, run, &options.top_k)
}

/// Re-measures a whole experiment: every selected stored world of every finished run, at
/// every `top_k` asked for, with the readings stored as rescore rows. A world that cannot
/// be read is reported and skipped, since one corrupt snapshot must not cost the pass;
/// only a pass where nothing at all could be read is a failure.
pub fn execute_corpus(options: CorpusOptions) -> Result<CorpusSummary> {
    let client = LabClient::new(&options.api, &options.token);
    let runs = client.corpus(&options.experiment)?;
    let mut summary = CorpusSummary::default();

    for (run, epoch) in selected(&runs, options.epochs, options.limit) {
        match rescore_world(&client, run, epoch, &options) {
            Ok(stored) => {
                summary.worlds += 1;
                summary.stored += stored;
            }
            Err(error) => {
                summary.failed += 1;
                println!(
                    "event=error run={} epoch={epoch} message={:?}",
                    run.id,
                    format!("{error:#}")
                );
            }
        }
    }

    if summary.worlds == 0 && summary.failed > 0 {
        bail!(
            "every one of the {} worlds of {} failed to rescore",
            summary.failed,
            options.experiment
        );
    }
    println!(
        "event=rescore_done experiment={} worlds={}",
        options.experiment, summary.worlds
    );
    Ok(summary)
}

fn rescore_world(
    client: &LabClient,
    run: &CorpusRun,
    epoch: u64,
    options: &CorpusOptions,
) -> Result<usize> {
    let stored = client
        .world(run.id, Some(epoch))?
        .ok_or_else(|| anyhow!("run {} no longer holds a world at epoch {epoch}", run.id))?;
    let report = measure(&stored, Some(run.id), &options.top_k)?;
    for setting in &report.settings {
        println!(
            "event=rescore run={} epoch={} top_k={} replicators={}",
            run.id, report.epoch, setting.top_k, setting.replicator_count
        );
    }
    if options.dry_run {
        return Ok(0);
    }
    let rows = rows(report.epoch, &report.settings)?;
    client.post_rescores(run.id, &rows)?;
    Ok(rows.len())
}

/// The worlds to read, in corpus order: the newest stored one of each run, or all of them.
fn selected(runs: &[CorpusRun], epochs: Epochs, limit: Option<usize>) -> Vec<(&CorpusRun, u64)> {
    let worlds = runs.iter().flat_map(|run| {
        let selected: Vec<u64> = match epochs {
            Epochs::Latest => run.epochs.last().copied().into_iter().collect(),
            Epochs::All => run.epochs.clone(),
        };
        selected.into_iter().map(move |epoch| (run, epoch))
    });
    match limit {
        Some(limit) => worlds.take(limit).collect(),
        None => worlds.collect(),
    }
}

/// The rows `POST /api/runs/:id/rescores` stores: a setting's readings plus the epoch they
/// were read at. Keep the field names in step with `Rescore::READINGS`.
fn rows(epoch: u64, settings: &[Setting]) -> Result<Vec<Value>> {
    settings
        .iter()
        .map(|setting| {
            let mut row = serde_json::to_value(setting).context("serialising a reading")?;
            row["epoch"] = json!(epoch);
            Ok(row)
        })
        .collect()
}

fn read_blob(path: &Path, params: Params, seed: u64) -> Result<StoredWorld> {
    let blob = std::fs::read(path).with_context(|| format!("reading {}", path.display()))?;
    Ok(StoredWorld { params, seed, blob })
}

fn measure(stored: &StoredWorld, run: Option<i64>, top_k: &[u32]) -> Result<Report> {
    let mut asked: Vec<u32> = top_k.to_vec();
    asked.sort_unstable();
    asked.dedup();
    if asked.is_empty() {
        bail!("rescore needs at least one top_k");
    }

    let (header, cells) = life_engine::snapshot::decode(&stored.params, &stored.blob)?;
    let mut measured: BTreeMap<u32, Metrics> = BTreeMap::new();
    for top_k in asked.iter().copied().chain(1..=TOP_TAPES) {
        if measured.contains_key(&top_k) {
            continue;
        }
        measured.insert(top_k, at_top_k(stored, top_k)?);
    }

    Ok(Report {
        run,
        epoch: header.epoch,
        seed: stored.seed,
        width: stored.params.width,
        height: stored.params.height,
        settings: asked
            .iter()
            .map(|top_k| setting(*top_k, &measured[top_k]))
            .collect(),
        top_tapes: top_tapes(stored, &cells, &measured),
    })
}

fn at_top_k(stored: &StoredWorld, top_k: u32) -> Result<Metrics> {
    let params = Params {
        top_k,
        ..stored.params.clone()
    };
    params.validate().map_err(anyhow::Error::msg)?;
    let mut world = World::from_snapshot(&params, stored.seed, &stored.blob)?;
    Ok(world.metrics())
}

/// The engine puts the ranked tapes through the replicator test in rank order from one
/// stream, so `replicator_count` at `top_k = r` differs from the count at `r - 1` exactly
/// when rank `r` passed the test — which is how a per-tape verdict is read off the sweep
/// rather than by re-running the test here with a stream of our own.
fn top_tapes(
    stored: &StoredWorld,
    cells: &[u8],
    measured: &BTreeMap<u32, Metrics>,
) -> Vec<TapeReading> {
    let ranked = metrics::ranked_tapes(cells, stored.params.stride());
    let cell_count = stored.params.cell_count() as f64;

    let mut readings = Vec::new();
    let mut counted_so_far = 0;
    for (rank, (_, count)) in ranked.iter().take(TOP_TAPES as usize).enumerate() {
        let rank = rank as u32 + 1;
        let counted = measured[&rank].replicator_count;
        readings.push(TapeReading {
            rank,
            count: *count,
            share: *count as f64 / cell_count,
            replicates: counted > counted_so_far,
        });
        counted_so_far = counted;
    }
    readings
}

fn setting(top_k: u32, metrics: &Metrics) -> Setting {
    Setting {
        top_k,
        replicator_count: metrics.replicator_count,
        top_share: metrics.top_share,
        distinct_tapes: metrics.distinct_tapes,
        compress_ratio: metrics.compress_ratio,
        entropy_bits: metrics.entropy_bits,
    }
}

impl Report {
    pub fn print(&self) {
        let run = self
            .run
            .map_or_else(|| "a stored world".to_string(), |run| format!("run {run}"));
        println!(
            "{run} at epoch {}, seed {}, {}×{}",
            self.epoch, self.seed, self.width, self.height
        );
        println!(
            "\n{:>6}  {:>16}  {:>10}  {:>14}  {:>14}  {:>12}",
            "top_k", "replicators", "top_share", "distinct_tapes", "compress_ratio", "entropy_bits"
        );
        for setting in &self.settings {
            println!(
                "{:>6}  {:>16}  {:>10.6}  {:>14}  {:>14.4}  {:>12.4}",
                setting.top_k,
                setting.replicator_count,
                setting.top_share,
                setting.distinct_tapes,
                setting.compress_ratio,
                setting.entropy_bits
            );
        }
        println!(
            "\n{:>6}  {:>10}  {:>10}  replicates",
            "rank", "cells", "share"
        );
        for tape in &self.top_tapes {
            println!(
                "{:>6}  {:>10}  {:>10.6}  {}",
                tape.rank,
                tape.count,
                tape.share,
                if tape.replicates { "yes" } else { "no" }
            );
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::mock_lab::MockLab;
    use life_engine::{replicator, Init};

    /// A 16×16 world of zero tapes with `replicators` cells holding the hand-written
    /// replicator: rank 1 is the zero tape, rank 2 the replicator.
    fn seeded_world(replicators: u32) -> StoredWorld {
        let params = Params {
            width: 16,
            height: 16,
            tape_len: 256,
            init: Init::Zero,
            ..Params::default()
        };
        let mut world = World::new(&params, 3).expect("legal params");
        let tape = replicator::handwritten_replicator();
        for x in 0..replicators {
            world.set_cell(x, 0, &tape);
        }
        StoredWorld {
            params,
            seed: 3,
            blob: world.snapshot(),
        }
    }

    /// The same 16×16 zero world, but with `variants` cells each holding its own variant
    /// of the hand-written replicator: one byte of the filler the interpreter never
    /// executes carries the cell's index, so the variants are distinct tapes of one cell
    /// each, ranked behind the zero tape in ascending byte order. The carried byte stays
    /// non-zero because a zero there would end the copy loop early and stop the tape
    /// replicating.
    fn world_of_replicator_variants(variants: u32) -> StoredWorld {
        let params = Params {
            width: 16,
            height: 16,
            tape_len: 256,
            init: Init::Zero,
            ..Params::default()
        };
        let mut world = World::new(&params, 3).expect("legal params");
        for variant in 0..variants {
            let mut tape = replicator::handwritten_replicator();
            *tape.last_mut().expect("the tape is not empty") = variant as u8 + 1;
            world.set_cell(variant % params.width, variant / params.width, &tape);
        }
        StoredWorld {
            params,
            seed: 3,
            blob: world.snapshot(),
        }
    }

    /// Run 186 of bff-control read a census of 0 replicators at `top_k` 16 and 38 at 64:
    /// the lineage had diffused across more tape variants than the default census looks
    /// at, so most of its cells sat below the cut and went uncounted.
    #[test]
    fn a_lineage_spread_over_many_tapes_is_undercounted_at_the_default_top_k() {
        const VARIANTS: u32 = 30;
        let stored = world_of_replicator_variants(VARIANTS);

        let report = measure(&stored, None, &[16, 64]).unwrap();

        let (at_16, at_64) = (
            report.settings[0].replicator_count,
            report.settings[1].replicator_count,
        );
        assert!(at_16 < at_64, "{at_16} at top_k 16, {at_64} at 64");
        assert_eq!(
            at_64,
            u64::from(VARIANTS),
            "every variant replicates, so the census at 64 holds one cell per variant"
        );
        assert_eq!(at_64 - at_16, variants_ranked_below_the_default(&stored));
    }

    /// How many of the variants the census at `top_k` 64 reaches and the one at 16 does
    /// not — the cells the default cut loses.
    fn variants_ranked_below_the_default(stored: &StoredWorld) -> u64 {
        let (_, cells) = life_engine::snapshot::decode(&stored.params, &stored.blob).unwrap();
        let zero_tape = vec![0u8; stored.params.stride()];
        metrics::ranked_tapes(&cells, stored.params.stride())
            .iter()
            .take(64)
            .skip(16)
            .filter(|(tape, _)| *tape != &zero_tape[..])
            .map(|(_, count)| *count)
            .sum()
    }

    #[test]
    fn a_tape_outside_top_k_goes_uncounted_and_inside_it_counts_its_cells() {
        let stored = seeded_world(3);

        let report = measure(&stored, Some(45), &[1, 16]).unwrap();

        let counts: Vec<(u32, u64)> = report
            .settings
            .iter()
            .map(|setting| (setting.top_k, setting.replicator_count))
            .collect();
        assert_eq!(counts, vec![(1, 0), (16, 3)]);
        assert_eq!(report.run, Some(45));
        assert_eq!(report.epoch, 0);
    }

    #[test]
    fn the_top_tapes_name_which_rank_replicates() {
        let stored = seeded_world(3);

        let report = measure(&stored, None, &[16]).unwrap();

        let ranks: Vec<(u32, u64, bool)> = report
            .top_tapes
            .iter()
            .map(|tape| (tape.rank, tape.count, tape.replicates))
            .collect();
        assert_eq!(ranks, vec![(1, 253, false), (2, 3, true)]);
    }

    #[test]
    fn a_blob_on_disk_is_rescored_without_the_lab() {
        let stored = seeded_world(2);
        let path = std::env::temp_dir().join(format!("rescore-{}.snapshot", std::process::id()));
        std::fs::write(&path, &stored.blob).unwrap();

        let report = execute(Options {
            source: Source::File {
                path: path.clone(),
                params: stored.params.clone(),
                seed: 3,
            },
            top_k: vec![16],
        })
        .unwrap();

        std::fs::remove_file(&path).unwrap();
        assert_eq!(report.run, None);
        assert_eq!(report.settings[0].replicator_count, 2);
    }

    #[test]
    fn a_run_the_lab_holds_a_world_for_is_rescored_from_the_api() {
        let params = MockLab::params();
        let world = World::new(&params, 7).expect("legal params");
        let lab = MockLab::start();
        lab.set_worlds(vec![(0, world.snapshot())]);

        let report = execute(Options {
            source: Source::Lab {
                api: lab.base_url(),
                token: crate::mock_lab::TOKEN.to_string(),
                run: 1,
                epoch: None,
            },
            top_k: vec![16],
        })
        .unwrap();

        assert_eq!((report.run, report.epoch, report.seed), (Some(1), 0, 7));
        assert_eq!(report.settings.len(), 1);
    }

    #[test]
    fn a_run_with_no_stored_world_is_reported_as_such() {
        let lab = MockLab::start();

        let error = execute(Options {
            source: Source::Lab {
                api: lab.base_url(),
                token: crate::mock_lab::TOKEN.to_string(),
                run: 1,
                epoch: None,
            },
            top_k: vec![16],
        })
        .unwrap_err()
        .to_string();

        assert!(error.contains("run 1 has no stored world"), "{error}");
    }

    /// A corpus of two finished runs, each holding the same two worlds.
    fn corpus_lab(epochs: Vec<u64>) -> MockLab {
        let lab = MockLab::start();
        let mut world = World::new(&MockLab::params(), 7).expect("legal params");
        let mut worlds = Vec::new();
        for epoch in &epochs {
            while world.epoch() < *epoch {
                world.step();
            }
            worlds.push((*epoch, world.snapshot()));
        }
        for run in [1, 2] {
            lab.set_run_worlds(run, worlds.clone());
        }
        let described: Vec<Value> = [1, 2]
            .iter()
            .map(|run| {
                json!({
                    "id": run,
                    "seed": 7,
                    "params": MockLab::params(),
                    "status": "finished",
                    "transition_epoch": Value::Null,
                    "epochs": epochs,
                })
            })
            .collect();
        lab.set_corpus(json!({ "slug": "radius", "runs": described }));
        lab
    }

    fn corpus_options(lab: &MockLab, epochs: Epochs, dry_run: bool) -> CorpusOptions {
        CorpusOptions {
            api: lab.base_url(),
            token: crate::mock_lab::TOKEN.to_string(),
            experiment: "radius".to_string(),
            top_k: vec![16, 64],
            epochs,
            limit: None,
            dry_run,
        }
    }

    #[test]
    fn every_world_of_every_run_is_measured_at_every_top_k_and_stored() {
        let lab = corpus_lab(vec![0, 3]);

        let summary = execute_corpus(corpus_options(&lab, Epochs::All, false)).unwrap();

        assert_eq!(
            summary,
            CorpusSummary {
                worlds: 4,
                failed: 0,
                stored: 8
            }
        );
        let posted = lab.requests("POST /api/runs/1/rescores");
        assert_eq!(posted.len(), 2);
        let rows = posted[0]["rescores"].as_array().unwrap();
        assert_eq!(rows.len(), 2);
        assert_eq!(rows[0]["top_k"], json!(16));
        assert_eq!(rows[0]["epoch"], json!(0));
        assert!(rows[0]["entropy_bits"].is_number(), "{rows:?}");
    }

    #[test]
    fn the_latest_pass_reads_one_world_per_run() {
        let lab = corpus_lab(vec![0, 3]);

        let summary = execute_corpus(corpus_options(&lab, Epochs::Latest, false)).unwrap();

        assert_eq!(summary.worlds, 2);
        assert_eq!(lab.count("POST /api/runs/1/rescores"), 1);
        assert_eq!(
            lab.request("POST /api/runs/2/rescores")["rescores"][0]["epoch"],
            json!(3)
        );
    }

    #[test]
    fn a_limit_stops_the_pass_early() {
        let lab = corpus_lab(vec![0, 3]);
        let mut options = corpus_options(&lab, Epochs::All, false);
        options.limit = Some(3);

        assert_eq!(execute_corpus(options).unwrap().worlds, 3);
    }

    #[test]
    fn a_dry_run_measures_and_stores_nothing() {
        let lab = corpus_lab(vec![0, 3]);

        let summary = execute_corpus(corpus_options(&lab, Epochs::All, true)).unwrap();

        assert_eq!(summary.worlds, 4);
        assert_eq!(summary.stored, 0);
        assert_eq!(lab.count("POST /api/runs/1/rescores"), 0);
    }

    /// One unreadable world must not cost the rest of the pass.
    #[test]
    fn a_world_the_lab_no_longer_holds_is_reported_and_skipped() {
        let lab = corpus_lab(vec![0, 3]);
        lab.set_run_worlds(2, vec![]);

        let summary = execute_corpus(corpus_options(&lab, Epochs::All, false)).unwrap();

        assert_eq!((summary.worlds, summary.failed), (2, 2));
    }

    #[test]
    fn a_pass_where_no_world_could_be_read_fails() {
        let lab = corpus_lab(vec![0, 3]);
        lab.set_run_worlds(1, vec![]);
        lab.set_run_worlds(2, vec![]);

        let error = execute_corpus(corpus_options(&lab, Epochs::All, false))
            .unwrap_err()
            .to_string();

        assert!(error.contains("every one of the 4 worlds"), "{error}");
    }

    #[test]
    fn an_experiment_that_finished_no_run_measures_nothing() {
        let lab = MockLab::start();
        lab.set_corpus(json!({ "slug": "radius", "runs": [] }));

        let summary = execute_corpus(corpus_options(&lab, Epochs::Latest, false)).unwrap();

        assert_eq!(summary, CorpusSummary::default());
    }
}
