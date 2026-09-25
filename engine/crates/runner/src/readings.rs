//! `runner readings-corpus` — reads the orientation-aware observables (`docs/DESIGN.md`
//! §1.2) off every stored world of an experiment, so a finding that rests on the census
//! can be re-read without re-running anything, and stores them as snapshot readings
//! (§2), never as samples.
//!
//! The readings are the engine's: a world restored at epoch E is asked for `metrics()`,
//! and because every draw is keyed by `(seed, stream, epoch)` it reads at E what the live
//! run read there. The copy rates are the exception — they count the interactions of the
//! step into a sample epoch and a restored world has taken no step — so the world is
//! stepped on to the next sample epoch E' and read there, which reproduces the live
//! sample at E'. Those readings are labelled E' with `source_epoch` E.

use crate::api::{CorpusRun, LabClient, StoredWorld, OUTAGE_GRACE};
use crate::rescore::Epochs;
use anyhow::{anyhow, bail, Result};
use life_engine::{Metrics, Params, Substrate, World};
use serde::Serialize;
use serde_json::{json, Value};
use std::collections::BTreeSet;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Mutex;
use std::thread;

/// The instrument a pass reads with and stores its readings under. A version is never
/// changed once readings exist under it — what it reads is part of its name — so reading
/// more is a new version with its own pass, and the old readings stay as they were.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, clap::ValueEnum)]
pub enum Instrument {
    /// The census's orientation-aware companions and both copy rates (#248). What every
    /// reading of the from-emerged pre-registration and `OrientedSummary` is read off.
    #[default]
    #[value(name = "oriented_census/1")]
    OrientedCensus1,
    /// Everything `/1` reads, and the oriented companions of the lineage readings and of
    /// `copy_cost` (`docs/design_record.md`, 2026-09-25), each beside the aligned reading
    /// it accompanies.
    #[value(name = "oriented_census/2")]
    OrientedCensus2,
}

impl Instrument {
    pub fn name(self) -> &'static str {
        match self {
            Self::OrientedCensus1 => "oriented_census/1",
            Self::OrientedCensus2 => "oriented_census/2",
        }
    }
}

pub struct Options {
    pub api: String,
    pub token: String,
    pub experiment: String,
    pub instrument: Instrument,
    pub epochs: Epochs,
    /// How many unread worlds to start from at most; all of them when `None`.
    pub limit: Option<usize>,
    /// Read and print, store nothing.
    pub dry_run: bool,
    /// Runs read at once.
    pub jobs: usize,
}

/// What a pass did: the worlds it read, the ones it could not, the ones an earlier pass
/// had already read, and the readings it stored.
#[derive(Debug, Default, Clone, Copy, PartialEq, Eq)]
pub struct Summary {
    pub worlds: usize,
    pub failed: usize,
    pub skipped: usize,
    pub stored: usize,
}

impl Summary {
    fn add(&mut self, other: Summary) {
        self.worlds += other.worlds;
        self.failed += other.failed;
        self.skipped += other.skipped;
        self.stored += other.stored;
    }
}

/// One row of `POST /api/runs/:id/readings`.
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct Reading {
    pub epoch: u64,
    pub source_epoch: u64,
    pub values: Value,
}

/// What one restored world yielded: the stored worlds it covered and their readings.
#[derive(Debug)]
pub struct Walk {
    pub worlds: Vec<u64>,
    pub readings: Vec<Reading>,
}

/// The stored worlds of one run the pass starts from, and the ones still unread, which a
/// walk steps through rather than restoring each again.
struct RunPlan<'a> {
    run: &'a CorpusRun,
    sources: Vec<u64>,
    unread: BTreeSet<u64>,
    skipped: usize,
}

/// Reads every unread stored world of an experiment's terminal runs and stores the
/// readings, one batch per run. A world that cannot be read is reported and skipped, since
/// one corrupt snapshot must not cost the pass; only a pass where nothing at all could be
/// read is a failure.
pub fn execute_corpus(options: Options) -> Result<Summary> {
    let client = lab_client(&options);
    let instrument = options.instrument;
    let runs = client.corpus(&options.experiment, Some(instrument.name()))?;
    let plans = plan(&runs, instrument, options.epochs, options.limit);
    let next = AtomicUsize::new(0);
    let total = Mutex::new(Summary::default());

    thread::scope(|scope| {
        for _ in 0..options.jobs.max(1) {
            scope.spawn(|| {
                let client = lab_client(&options);
                while let Some(plan) = plans.get(next.fetch_add(1, Ordering::Relaxed)) {
                    let done = read_run(&client, plan, instrument, options.dry_run);
                    total.lock().unwrap().add(done);
                }
            });
        }
    });

    let total = total.into_inner().unwrap();
    if total.worlds == 0 && total.failed > 0 {
        bail!(
            "every one of the {} worlds of {} failed to read",
            total.failed,
            options.experiment
        );
    }
    println!(
        "event=readings_done experiment={} instrument={} worlds={} failed={} skipped={} stored={}",
        options.experiment,
        instrument.name(),
        total.worlds,
        total.failed,
        total.skipped,
        total.stored
    );
    Ok(total)
}

/// A pass runs for hours beside a lab that auto-deploys, and a POST that gives up loses
/// every reading of its run, so the calls wait a deploy out as lab mode does rather than
/// giving up after a one-off command's half minute.
fn lab_client(options: &Options) -> LabClient {
    LabClient::new(&options.api, &options.token).with_grace(OUTAGE_GRACE)
}

/// The worlds to start from, in corpus order: each run's newest stored world or all of
/// them, less the ones a reading already exists at, cut at `limit` worlds.
fn plan(
    runs: &[CorpusRun],
    instrument: Instrument,
    epochs: Epochs,
    limit: Option<usize>,
) -> Vec<RunPlan<'_>> {
    let mut left = limit.unwrap_or(usize::MAX);
    let mut plans = Vec::new();
    for run in runs {
        let read: BTreeSet<u64> = run
            .read_epochs
            .get(instrument.name())
            .into_iter()
            .flatten()
            .copied()
            .collect();
        let wanted: Vec<u64> = match epochs {
            Epochs::Latest => run.epochs.last().copied().into_iter().collect(),
            Epochs::All => run.epochs.clone(),
        };
        let mut sources: Vec<u64> = wanted
            .iter()
            .copied()
            .filter(|epoch| !read.contains(epoch))
            .collect();
        let skipped = wanted.len() - sources.len();
        sources.truncate(left);
        left -= sources.len();
        plans.push(RunPlan {
            run,
            sources,
            unread: run
                .epochs
                .iter()
                .copied()
                .filter(|epoch| !read.contains(epoch))
                .collect(),
            skipped,
        });
    }
    plans
}

fn read_run(
    client: &LabClient,
    plan: &RunPlan<'_>,
    instrument: Instrument,
    dry_run: bool,
) -> Summary {
    let id = plan.run.id;
    let mut summary = Summary {
        skipped: plan.skipped,
        ..Summary::default()
    };
    let mut walked = BTreeSet::new();
    let mut readings = Vec::new();
    for &source in &plan.sources {
        if walked.contains(&source) {
            continue;
        }
        let walk = client
            .world(id, Some(source))
            .and_then(|stored| {
                stored.ok_or_else(|| anyhow!("run {id} no longer holds a world at epoch {source}"))
            })
            .and_then(|stored| {
                read_walk(&stored, instrument, |epoch| plan.unread.contains(&epoch))
            });
        match walk {
            Ok(walk) => {
                summary.worlds += walk.worlds.len();
                walked.extend(walk.worlds);
                readings.extend(walk.readings);
            }
            Err(error) => {
                summary.failed += 1;
                println!(
                    "event=error run={id} epoch={source} message={:?}",
                    format!("{error:#}")
                );
            }
        }
    }

    if !dry_run && !readings.is_empty() {
        let rows: Vec<Value> = readings.iter().map(|reading| json!(reading)).collect();
        match client.post_readings(id, instrument.name(), &rows) {
            Ok(()) => summary.stored = rows.len(),
            Err(error) => {
                summary.failed += summary.worlds;
                summary.worlds = 0;
                println!("event=error run={id} message={:?}", format!("{error:#}"));
            }
        }
    }
    println!(
        "event=readings run={id} worlds={} rows={} failed={} skipped={} stored={}",
        summary.worlds,
        readings.len(),
        summary.failed,
        summary.skipped,
        summary.stored
    );
    summary
}

/// Restores `stored` and reads it: the static readings at its own epoch E, then — on a
/// soup that samples — the copy rates at the next sample epoch E'. When E' is itself a
/// stored world `continues` names, the stepped world is that world (the run is a pure
/// function of its seed), so the walk reads it there and goes on to its own next sample
/// epoch instead of leaving it to be restored and read again. Every reading carries E as
/// its `source_epoch`: the world it was actually restored from.
pub fn read_walk(
    stored: &StoredWorld,
    instrument: Instrument,
    continues: impl Fn(u64) -> bool,
) -> Result<Walk> {
    stored.params.validate().map_err(anyhow::Error::msg)?;
    let mut world = World::from_snapshot(&stored.params, stored.seed, &stored.blob)?;
    let source = world.epoch();
    let mut walk = Walk {
        worlds: vec![source],
        readings: vec![Reading {
            epoch: source,
            source_epoch: source,
            values: static_values(&world.metrics(), instrument),
        }],
    };
    if !steps_to_a_sample(&stored.params) {
        return Ok(walk);
    }
    loop {
        step_to_next_sample(&mut world);
        let epoch = world.epoch();
        walk.readings.push(Reading {
            epoch,
            source_epoch: source,
            values: in_situ_values(&world.metrics(), instrument),
        });
        if !continues(epoch) {
            return Ok(walk);
        }
        walk.worlds.push(epoch);
    }
}

/// Only a soup counts copies; Life has no tape to copy.
fn steps_to_a_sample(params: &Params) -> bool {
    params.substrate == Substrate::Soup
}

/// Steps until the step just taken produced a sample epoch — the step the live run
/// counted copies on (`World::counts_copies`).
fn step_to_next_sample(world: &mut World) {
    let sample_every = u64::from(world.params().sample_every);
    loop {
        world.step();
        if world.epoch().is_multiple_of(sample_every) {
            return;
        }
    }
}

/// What a restored world reads exactly as the live run read it. `replicator_count` rides
/// along as the control: it must equal the run's own sample at the same epoch. `/2` adds
/// the oriented lineage readings and `copy_latency`, each with the aligned reading it
/// accompanies riding along as a control of its own.
fn static_values(metrics: &Metrics, instrument: Instrument) -> Value {
    let mut values = json!({
        "replicator_count": metrics.replicator_count,
        "replicator_share": metrics.replicator_share,
        "replicator_share_rotated": metrics.replicator_share_rotated,
        "dominant_self_replicates": metrics.dominant_self_replicates,
    });
    if instrument == Instrument::OrientedCensus2 {
        let oriented = json!({
            "lineage_variation": metrics.lineage_variation,
            "lineage_variation_oriented": metrics.lineage_variation_oriented,
            "conserved_core_bytes": metrics.conserved_core_bytes,
            "conserved_core_bytes_oriented": metrics.conserved_core_bytes_oriented,
            "conserved_core_ops": metrics.conserved_core_ops,
            "conserved_core_ops_oriented": metrics.conserved_core_ops_oriented,
            "copy_cost": metrics.copy_cost,
            "copy_latency": metrics.copy_latency,
            "copy_latency_orientation": metrics.copy_latency_orientation,
        });
        for (key, value) in oriented.as_object().expect("an object") {
            values[key] = value.clone();
        }
    }
    values
}

/// The stepped world's readings: the static ones at E', and the copy rates the step into
/// it counted — `copy_rate` the control a live sample at E' holds too.
fn in_situ_values(metrics: &Metrics, instrument: Instrument) -> Value {
    let mut values = static_values(metrics, instrument);
    values["copy_rate"] = json!(metrics.copy_rate);
    values["reverse_copy_rate"] = json!(metrics.reverse_copy_rate);
    values
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::mock_lab::{MockLab, TOKEN};
    use life_engine::replicator;
    use std::collections::BTreeMap;

    /// A 16×16 soup whose top half holds the handwritten forward replicator and whose
    /// bottom half holds a reverse copier, so both copy rates read something.
    fn copying_world() -> World {
        let forward = replicator::handwritten_replicator();
        let params = Params {
            width: 16,
            height: 16,
            tape_len: forward.len() as u32,
            sample_every: 5,
            ..Params::default()
        };
        let reverse = replicator::handwritten_reverse_replicator(forward.len());
        let mut world = World::new(&params, 11).expect("legal params");
        for y in 0..params.height {
            for x in 0..params.width {
                world.set_cell(x, y, if y < 8 { &forward } else { &reverse });
            }
        }
        world
    }

    fn stored(world: &World) -> StoredWorld {
        StoredWorld {
            params: world.params().clone(),
            seed: world.seed(),
            blob: world.snapshot(),
        }
    }

    fn step_to(world: &mut World, epoch: u64) {
        while world.epoch() < epoch {
            world.step();
        }
    }

    #[test]
    fn a_restored_world_stepped_to_the_next_sample_reads_the_live_copy_rates() {
        let mut live = copying_world();
        step_to(&mut live, 7);
        let restored = stored(&live);
        step_to(&mut live, 10);
        let expected = live.metrics();

        let walk = read_walk(&restored, Instrument::OrientedCensus1, |_| false).unwrap();

        let stepped = &walk.readings[1];
        assert_eq!((stepped.epoch, stepped.source_epoch), (10, 7));
        assert!(expected.reverse_copy_rate > 0.0, "{expected:?}");
        assert!(expected.copy_rate > 0.0, "{expected:?}");
        assert_eq!(stepped.values["copy_rate"], json!(expected.copy_rate));
        assert_eq!(
            stepped.values["reverse_copy_rate"],
            json!(expected.reverse_copy_rate)
        );
    }

    #[test]
    fn a_world_stored_on_a_sample_epoch_is_read_one_whole_sample_later() {
        let mut live = copying_world();
        step_to(&mut live, 5);

        let walk = read_walk(&stored(&live), Instrument::OrientedCensus1, |_| false).unwrap();

        let epochs: Vec<(u64, u64)> = walk
            .readings
            .iter()
            .map(|reading| (reading.epoch, reading.source_epoch))
            .collect();
        assert_eq!(epochs, vec![(5, 5), (10, 5)]);
    }

    #[test]
    fn the_static_readings_of_a_restored_world_are_the_live_ones() {
        let mut live = copying_world();
        step_to(&mut live, 5);
        let restored = stored(&live);
        let expected = live.metrics();

        let walk = read_walk(&restored, Instrument::OrientedCensus1, |_| false).unwrap();

        assert_eq!(
            walk.readings[0].values,
            static_values(&expected, Instrument::OrientedCensus1)
        );
        assert!(expected.replicator_share.is_some_and(|share| share > 0.0));
        assert_eq!(
            walk.readings[0].values["replicator_count"],
            json!(expected.replicator_count)
        );
    }

    /// A stored world one sample after another is the stepped world itself, so it is read
    /// in the same walk rather than restored again, and its row carries every value.
    #[test]
    fn a_stored_world_one_sample_on_is_read_in_the_same_walk() {
        let mut live = copying_world();
        step_to(&mut live, 5);
        let restored = stored(&live);
        step_to(&mut live, 10);
        let at_ten = live.metrics();

        let walk = read_walk(&restored, Instrument::OrientedCensus1, |epoch| epoch == 10).unwrap();

        assert_eq!(walk.worlds, vec![5, 10]);
        let epochs: Vec<u64> = walk.readings.iter().map(|reading| reading.epoch).collect();
        assert_eq!(epochs, vec![5, 10, 15]);
        assert_eq!(
            walk.readings[1].values,
            in_situ_values(&at_ten, Instrument::OrientedCensus1)
        );
        assert_eq!(walk.readings[2].source_epoch, 5);
    }

    #[test]
    fn a_life_world_is_read_where_it_stands() {
        let params = Params {
            substrate: Substrate::Life,
            width: 16,
            height: 16,
            ..Params::default()
        };
        let mut world = World::new(&params, 3).expect("legal params");
        step_to(&mut world, 3);

        let walk = read_walk(&stored(&world), Instrument::OrientedCensus1, |_| true).unwrap();

        assert_eq!(walk.readings.len(), 1);
        assert_eq!(walk.readings[0].values["replicator_share"], Value::Null);
        assert_eq!(walk.readings[0].values.get("copy_rate"), None);
    }

    /// A corpus of two terminal runs over the mock lab's worlds, stored at 0, 4 and 6
    /// (sample_every 2: the walk from 4 reaches 6, the one from 6 stops at 8).
    fn corpus_lab(read: Value) -> MockLab {
        let lab = MockLab::start();
        let mut world = World::new(&MockLab::params(), 7).expect("legal params");
        let mut worlds = Vec::new();
        for epoch in [0, 4, 6] {
            step_to(&mut world, epoch);
            worlds.push((epoch, world.snapshot()));
        }
        for run in [1, 2] {
            lab.set_run_worlds(run, worlds.clone());
        }
        lab.set_corpus(json!({
            "slug": "radius",
            "runs": [
                { "id": 1, "epochs": [0, 4, 6], "read_epochs": read },
                { "id": 2, "epochs": [0, 4, 6], "read_epochs": {} },
            ],
        }));
        lab
    }

    fn options(lab: &MockLab, epochs: Epochs) -> Options {
        Options {
            api: lab.base_url(),
            token: TOKEN.to_string(),
            experiment: "radius".to_string(),
            instrument: Instrument::OrientedCensus1,
            epochs,
            limit: None,
            dry_run: false,
            jobs: 1,
        }
    }

    fn posted_epochs(lab: &MockLab, run: i64) -> Vec<(u64, u64)> {
        lab.requests(&format!("POST /api/runs/{run}/readings"))
            .iter()
            .flat_map(|body| body["readings"].as_array().unwrap().clone())
            .map(|row| {
                (
                    row["epoch"].as_u64().unwrap(),
                    row["source_epoch"].as_u64().unwrap(),
                )
            })
            .collect()
    }

    #[test]
    fn every_stored_world_is_read_and_posted_in_one_batch_per_run() {
        let lab = corpus_lab(json!({}));

        let summary = execute_corpus(options(&lab, Epochs::All)).unwrap();

        assert_eq!(
            summary,
            Summary {
                worlds: 6,
                failed: 0,
                skipped: 0,
                stored: 10
            }
        );
        assert_eq!(lab.count("POST /api/runs/1/readings"), 1);
        let body = lab.request("POST /api/runs/1/readings");
        assert_eq!(body["instrument"], json!("oriented_census/1"));
        assert_eq!(
            posted_epochs(&lab, 1),
            vec![(0, 0), (2, 0), (4, 4), (6, 4), (8, 4)]
        );
        let rows = body["readings"].as_array().unwrap();
        let keys = |row: &Value| -> Vec<String> {
            row["values"].as_object().unwrap().keys().cloned().collect()
        };
        assert_eq!(
            keys(&rows[0]),
            vec![
                "dominant_self_replicates",
                "replicator_count",
                "replicator_share",
                "replicator_share_rotated"
            ]
        );
        assert_eq!(
            keys(&rows[1]),
            vec![
                "copy_rate",
                "dominant_self_replicates",
                "replicator_count",
                "replicator_share",
                "replicator_share_rotated",
                "reverse_copy_rate"
            ]
        );
    }

    /// `/2` is a pass of its own: it reads the worlds `/1` has already read, stores under
    /// its own name, and adds the oriented readings to every row `/1` would have written.
    #[test]
    fn the_second_version_reads_again_under_its_own_name() {
        let lab = corpus_lab(json!({ "oriented_census/1": [0, 2, 4, 6, 8] }));
        let options = Options {
            instrument: Instrument::OrientedCensus2,
            ..options(&lab, Epochs::All)
        };

        let summary = execute_corpus(options).unwrap();

        assert_eq!((summary.worlds, summary.skipped), (6, 0));
        let body = lab.request("POST /api/runs/1/readings");
        assert_eq!(body["instrument"], json!("oriented_census/2"));
        let rows = body["readings"].as_array().unwrap();
        let values = rows[0]["values"].as_object().unwrap();
        for key in [
            "replicator_share",
            "lineage_variation",
            "lineage_variation_oriented",
            "conserved_core_bytes_oriented",
            "conserved_core_ops_oriented",
            "copy_cost",
            "copy_latency",
            "copy_latency_orientation",
        ] {
            assert!(values.contains_key(key), "{key}: {values:?}");
        }
        assert!(
            rows[1]["values"]["reverse_copy_rate"].is_number(),
            "{rows:?}"
        );
    }

    #[test]
    fn the_second_version_reads_the_live_oriented_readings() {
        let mut live = copying_world();
        step_to(&mut live, 5);
        let restored = stored(&live);
        let expected = live.metrics();

        let walk = read_walk(&restored, Instrument::OrientedCensus2, |_| false).unwrap();

        let values = &walk.readings[0].values;
        assert_eq!(
            values["lineage_variation_oriented"],
            json!(expected.lineage_variation_oriented)
        );
        assert_eq!(values["copy_latency"], json!(expected.copy_latency));
        assert!(expected.copy_latency.is_some(), "{expected:?}");
        assert_eq!(
            values["copy_latency_orientation"],
            json!(expected.copy_latency_orientation)
        );
        assert_eq!(
            values["replicator_count"],
            static_values(&expected, Instrument::OrientedCensus1)["replicator_count"]
        );
    }

    #[test]
    fn a_pass_reads_with_the_first_version_unless_told_otherwise() {
        assert_eq!(Instrument::default().name(), "oriented_census/1");
    }

    #[test]
    fn a_world_already_read_is_skipped() {
        let lab = corpus_lab(json!({ "oriented_census/1": [0, 2, 4], "other/1": [6] }));

        let summary = execute_corpus(options(&lab, Epochs::All)).unwrap();

        assert_eq!((summary.worlds, summary.skipped), (4, 2));
        assert_eq!(posted_epochs(&lab, 1), vec![(6, 6), (8, 6)]);
    }

    /// A stored world an earlier pass read where it stands has no copy rates: the walk
    /// from the world before it rewrites its row with them, and restores it no more.
    #[test]
    fn a_world_read_one_sample_on_gains_its_copy_rates() {
        let lab = corpus_lab(json!({ "oriented_census/1": [0, 2, 6, 8] }));

        let summary = execute_corpus(options(&lab, Epochs::All)).unwrap();

        assert_eq!((summary.worlds, summary.skipped), (4, 2));
        assert_eq!(posted_epochs(&lab, 1), vec![(4, 4), (6, 4)]);
        let rows = lab.request("POST /api/runs/1/readings")["readings"].clone();
        assert!(rows[1]["values"]["reverse_copy_rate"].is_number(), "{rows}");
    }

    #[test]
    fn a_post_the_app_fails_is_tried_again() {
        let lab = corpus_lab(json!({}));
        lab.fail_next_at("/api/runs/1/readings", 1);

        let summary = execute_corpus(options(&lab, Epochs::Latest)).unwrap();

        assert_eq!((summary.failed, summary.stored), (0, 4));
        assert_eq!(lab.count("POST /api/runs/1/readings"), 2);
    }

    #[test]
    fn a_run_read_through_is_not_posted_again() {
        let lab = corpus_lab(json!({ "oriented_census/1": [0, 2, 4, 6, 8] }));

        execute_corpus(options(&lab, Epochs::All)).unwrap();

        assert_eq!(lab.count("POST /api/runs/1/readings"), 0);
    }

    #[test]
    fn the_latest_pass_reads_each_runs_newest_world() {
        let lab = corpus_lab(json!({}));

        let summary = execute_corpus(options(&lab, Epochs::Latest)).unwrap();

        assert_eq!(summary.worlds, 2);
        assert_eq!(posted_epochs(&lab, 2), vec![(6, 6), (8, 6)]);
    }

    #[test]
    fn a_world_that_fails_to_restore_is_skipped_and_the_rest_are_read() {
        let lab = corpus_lab(json!({}));
        lab.set_run_worlds(1, vec![(0, vec![1, 2, 3])]);

        let summary = execute_corpus(options(&lab, Epochs::All)).unwrap();

        assert_eq!((summary.worlds, summary.failed), (3, 3));
        assert_eq!(lab.count("POST /api/runs/1/readings"), 0);
        assert_eq!(lab.count("POST /api/runs/2/readings"), 1);
    }

    #[test]
    fn a_pass_where_no_world_could_be_read_fails() {
        let lab = corpus_lab(json!({}));
        lab.set_run_worlds(1, vec![]);
        lab.set_run_worlds(2, vec![]);

        let error = execute_corpus(options(&lab, Epochs::Latest))
            .unwrap_err()
            .to_string();

        assert!(error.contains("every one of the 2 worlds"), "{error}");
    }

    #[test]
    fn a_dry_run_reads_and_stores_nothing() {
        let lab = corpus_lab(json!({}));
        let options = Options {
            dry_run: true,
            ..options(&lab, Epochs::All)
        };

        let summary = execute_corpus(options).unwrap();

        assert_eq!((summary.worlds, summary.stored), (6, 0));
        assert_eq!(lab.count("POST /api/runs/1/readings"), 0);
    }

    #[test]
    fn a_limit_bounds_the_worlds_a_pass_starts_from() {
        let lab = corpus_lab(json!({}));
        let options = Options {
            limit: Some(1),
            ..options(&lab, Epochs::All)
        };

        let summary = execute_corpus(options).unwrap();

        assert_eq!(summary.worlds, 1);
        assert_eq!(lab.count("POST /api/runs/2/readings"), 0);
    }

    #[test]
    fn parallel_jobs_read_what_one_job_reads() {
        let one = corpus_lab(json!({}));
        let many = corpus_lab(json!({}));

        execute_corpus(options(&one, Epochs::All)).unwrap();
        execute_corpus(Options {
            jobs: 4,
            ..options(&many, Epochs::All)
        })
        .unwrap();

        let bodies = |lab: &MockLab| -> BTreeMap<i64, Value> {
            [1, 2]
                .into_iter()
                .map(|run| (run, lab.request(&format!("POST /api/runs/{run}/readings"))))
                .collect()
        };
        assert_eq!(bodies(&one), bodies(&many));
    }
}
