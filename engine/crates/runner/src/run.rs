//! The execution loop, shared by every sink.

use crate::sink::{RunResult, RunSink, SnapshotReason};
use anyhow::{bail, Result};
use life_engine::{Params, World};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};

/// How long lab mode lets a run go without a snapshot. `snapshot_every` sets the epoch
/// cadence (DESIGN.md §1.2), but epochs are not minutes: a 512x256 control world runs at
/// ~21 epochs/min on the mini-pc, so its cadence of 2000 epochs is ~95 minutes of compute
/// a container restart would have to redo. This is the wall-clock floor under that
/// cadence. 30 minutes rather than 10: the extra snapshots are live until the run goes
/// terminal and `PruneSnapshotsService` thins it, and a control world's 8.4 MiB every
/// 10 minutes is ~1.8 GiB of backlog per slot over its 50 000-epoch run (~40 hours at
/// that rate), against ~450 MiB here for a restart cost still a third of the cadence's.
pub const SNAPSHOT_MAX_AGE: Duration = Duration::from_secs(1800);

/// Reads `10m`, `90s`, `2h` or a bare count of seconds into a duration — what the
/// runner's wall-clock flags are written as.
pub fn parse_duration(text: &str) -> Result<Duration, String> {
    let text = text.trim();
    let (digits, scale) = match text
        .char_indices()
        .find(|(_, character)| character.is_ascii_alphabetic())
    {
        Some((at, _)) => {
            let seconds = match text[at..].to_ascii_lowercase().as_str() {
                "s" => 1,
                "m" => 60,
                "h" => 3600,
                unit => return Err(format!("{unit:?} is not a unit: use s, m or h")),
            };
            (&text[..at], seconds)
        }
        None => (text, 1),
    };
    let count: u64 = digits
        .trim()
        .parse()
        .map_err(|_| format!("{text:?} is not a duration like 10m, 90s or a second count"))?;
    count
        .checked_mul(scale)
        .map(Duration::from_secs)
        .ok_or_else(|| format!("{text:?} is longer than a run could ever be"))
}

/// How far a run has got and whether it has been asked to stop. Lab mode reads the
/// progress from its heartbeat thread and sets the stop flag from SIGTERM; local mode
/// uses the default, which never stops.
#[derive(Debug, Default)]
pub struct Progress {
    epochs_done: AtomicU64,
    stop: Arc<AtomicBool>,
}

impl Progress {
    pub fn new(epochs_done: u64, stop: Arc<AtomicBool>) -> Self {
        Self {
            epochs_done: AtomicU64::new(epochs_done),
            stop,
        }
    }

    pub fn epochs_done(&self) -> u64 {
        self.epochs_done.load(Ordering::Relaxed)
    }

    fn record(&self, epochs_done: u64) {
        self.epochs_done.store(epochs_done, Ordering::Relaxed);
    }

    fn stopped(&self) -> bool {
        self.stop.load(Ordering::Relaxed)
    }
}

/// How the loop left the world: with the run complete and `finish` written to the sink,
/// or interrupted, in which case nothing was finished and the run can be resumed.
#[derive(Debug)]
pub enum Completion {
    Finished(Box<RunResult>),
    Stopped { epochs_done: u64 },
}

pub fn execute(
    params: &Params,
    seed: u64,
    epochs: u64,
    sink: &mut dyn RunSink,
) -> Result<RunResult> {
    let world = World::new(params, seed).map_err(anyhow::Error::msg)?;
    match execute_world(world, epochs, None, None, sink, &Progress::default())? {
        Completion::Finished(result) => Ok(*result),
        Completion::Stopped { epochs_done } => bail!("the run stopped at epoch {epochs_done}"),
    }
}

/// Runs `world` — fresh or restored from a snapshot — up to `epochs`, reporting through
/// `progress` and giving up as soon as it is asked to stop. The sample that settles the
/// transition takes a snapshot of its own, so the run's primary dependent variable has a
/// world behind it to rescore. `snapshot_max_age` adds a wall-clock floor under the epoch
/// cadence: past it the next sampled epoch snapshots, so a restart costs at most that
/// much compute. Left `None` — local and file mode — only the cadence snapshots.
/// `resumed_at` is the epoch a restored world came back from, whose observables were
/// already measured and posted before the interruption.
pub fn execute_world(
    mut world: World,
    epochs: u64,
    mut resumed_at: Option<u64>,
    snapshot_max_age: Option<Duration>,
    sink: &mut dyn RunSink,
    progress: &Progress,
) -> Result<Completion> {
    let params = world.params().clone();
    let seed = world.seed();
    let sample_every = params.sample_every as u64;
    let snapshot_every = params.snapshot_every as u64;
    let started = Instant::now();
    let mut last_snapshot_at = Instant::now();
    let mut buffers = SnapshotBuffers::default();
    let mut transition_seen = world.transition_epoch();

    loop {
        let epoch = world.epoch();
        // A restored world has not stepped yet, so its copy_rate reads 0 (World::from_snapshot),
        // and the app upserts samples on [run_id, epoch]: measuring the epoch the snapshot
        // came from would replace the rate measured before the interruption with that zero.
        let resuming = resumed_at.take() == Some(epoch);
        let sampling = !resuming && epoch.is_multiple_of(sample_every);
        let overdue = sampling
            && snapshot_max_age.is_some_and(|max_age| last_snapshot_at.elapsed() >= max_age);
        let reason = if resuming {
            None
        } else if epoch.is_multiple_of(snapshot_every) {
            Some(SnapshotReason::Cadence)
        } else if overdue {
            Some(SnapshotReason::Age)
        } else {
            None
        };
        match (sampling, reason) {
            (true, Some(reason)) => {
                let (metrics, raw) = world.metrics_with_snapshot();
                sink.sample(epoch, &metrics, world.transition_epoch())?;
                sink.snapshot(epoch, &raw, buffers.render_png(&world)?, reason)?;
                last_snapshot_at = Instant::now();
            }
            (true, None) => {
                let metrics = world.metrics();
                sink.sample(epoch, &metrics, world.transition_epoch())?;
            }
            (false, Some(reason)) => {
                let raw = world.snapshot();
                sink.snapshot(epoch, &raw, buffers.render_png(&world)?, reason)?;
                last_snapshot_at = Instant::now();
            }
            (false, None) => {}
        }
        // The one forced snapshot is stored under the sample epoch that confirmed the
        // drop, which trails the settled transition epoch by hold_samples x sample_every.
        let settled = world.transition_epoch();
        if sampling && transition_seen.is_none() && settled.is_some() {
            if reason.is_none() {
                let raw = world.snapshot();
                sink.snapshot(
                    epoch,
                    &raw,
                    buffers.render_png(&world)?,
                    SnapshotReason::Transition,
                )?;
                last_snapshot_at = Instant::now();
            }
            transition_seen = settled;
        }
        if epoch == epochs {
            break;
        }
        world.step();
        progress.record(world.epoch());
        if progress.stopped() {
            return Ok(Completion::Stopped {
                epochs_done: world.epoch(),
            });
        }
    }

    let wall_seconds = started.elapsed().as_secs_f64();
    let result = RunResult {
        params,
        seed,
        epochs,
        transition_epoch: world.transition_epoch(),
        wall_seconds,
        epochs_per_second: if wall_seconds > 0.0 {
            epochs as f64 / wall_seconds
        } else {
            f64::INFINITY
        },
    };
    sink.finish(&result)?;
    Ok(Completion::Finished(Box::new(result)))
}

/// The scratch the run loop lends to every snapshot: the RGBA pixels the engine renders
/// into and the PNG bytes the encoder writes. Both are cleared and reused, so a slot
/// snapshotting a 512x256 world every few epochs allocates them once rather than once
/// per snapshot in each of the mini-pc's twelve slots.
#[derive(Debug, Default)]
pub struct SnapshotBuffers {
    pixels: Vec<u8>,
    png: Vec<u8>,
}

impl SnapshotBuffers {
    /// A PNG of the world at its native size, coloured by the engine.
    pub fn render_png(&mut self, world: &World) -> Result<&[u8]> {
        self.pixels.clear();
        self.pixels.resize(world.params().cell_count() * 4, 0);
        world.render_rgba(&mut self.pixels);

        self.png.clear();
        {
            let mut encoder = png::Encoder::new(&mut self.png, world.width(), world.height());
            encoder.set_color(png::ColorType::Rgba);
            encoder.set_depth(png::BitDepth::Eight);
            let mut writer = encoder.write_header()?;
            writer.write_image_data(&self.pixels)?;
        }
        Ok(&self.png)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sink::NullSink;
    use life_engine::{Init, Substrate};

    fn params() -> Params {
        Params {
            width: 8,
            height: 8,
            tape_len: 16,
            max_steps: 64,
            sample_every: 2,
            snapshot_every: 3,
            ..Params::default()
        }
    }

    #[derive(Default)]
    struct RecordingSink {
        samples: Vec<u64>,
        copy_rates: Vec<f64>,
        snapshots: Vec<u64>,
        reasons: Vec<SnapshotReason>,
        finished: bool,
    }

    impl RunSink for RecordingSink {
        fn sample(
            &mut self,
            epoch: u64,
            metrics: &Metrics,
            _transition_epoch: Option<u64>,
        ) -> Result<()> {
            self.samples.push(epoch);
            self.copy_rates.push(metrics.copy_rate);
            Ok(())
        }

        fn snapshot(
            &mut self,
            epoch: u64,
            raw: &[u8],
            png: &[u8],
            reason: SnapshotReason,
        ) -> Result<()> {
            assert!(!raw.is_empty() && !png.is_empty());
            self.snapshots.push(epoch);
            self.reasons.push(reason);
            Ok(())
        }

        fn finish(&mut self, _result: &RunResult) -> Result<()> {
            self.finished = true;
            Ok(())
        }
    }

    use life_engine::Metrics;

    #[test]
    fn samples_and_snapshots_land_on_their_cadence() {
        let mut sink = RecordingSink::default();
        let result = execute(&params(), 1, 6, &mut sink).unwrap();
        assert_eq!(sink.samples, vec![0, 2, 4, 6]);
        assert_eq!(sink.snapshots, vec![0, 3, 6]);
        assert!(sink.finished);
        assert_eq!(result.epochs, 6);
        assert_eq!(result.transition_epoch, None);
    }

    #[test]
    fn a_png_is_written_for_every_cell() {
        let world = World::new(
            &Params {
                substrate: Substrate::Life,
                init: Init::Random,
                ..params()
            },
            1,
        )
        .unwrap();
        let mut buffers = SnapshotBuffers::default();
        let png = buffers.render_png(&world).unwrap().to_vec();
        assert_eq!(&png[1..4], b"PNG");

        let again = buffers.render_png(&world).unwrap();
        assert_eq!(again, png, "a reused buffer renders the same bytes");
    }

    /// An ordered world's compress ratio is under the threshold from the start, so the
    /// drop settles on the fourth sample — epoch 6, which no snapshot cadence of 4 hits.
    fn settling_params() -> Params {
        Params {
            init: Init::Zero,
            mutation_rate: 0.0,
            snapshot_every: 4,
            ..params()
        }
    }

    #[test]
    fn a_settled_transition_forces_a_snapshot_off_the_cadence() {
        let mut cadence_only = RecordingSink::default();
        let unsettled = Params {
            snapshot_every: 4,
            ..params()
        };
        execute(&unsettled, 1, 6, &mut cadence_only).unwrap();
        assert_eq!(cadence_only.snapshots, vec![0, 4]);

        let mut sink = RecordingSink::default();
        let result = execute(&settling_params(), 3, 6, &mut sink).unwrap();

        assert_eq!(result.transition_epoch, Some(0));
        assert_eq!(sink.samples, vec![0, 2, 4, 6]);
        assert_eq!(sink.snapshots, vec![0, 4, 6]);
        assert!(sink.snapshots.len() > cadence_only.snapshots.len());
    }

    #[test]
    fn only_the_first_settling_sample_forces_a_snapshot() {
        let mut sink = RecordingSink::default();
        execute(&settling_params(), 3, 12, &mut sink).unwrap();

        assert_eq!(sink.snapshots, vec![0, 4, 6, 8, 12]);
    }

    #[test]
    fn a_resumed_world_does_not_force_a_second_transition_snapshot() {
        let params = settling_params();
        let mut world = World::new(&params, 3).unwrap();
        for _ in 0..6 {
            world.metrics();
            world.step();
        }
        assert_eq!(world.transition_epoch(), Some(0));

        let restored = World::from_snapshot(&params, 3, &world.snapshot()).unwrap();
        let mut sink = RecordingSink::default();
        execute_world(restored, 8, None, None, &mut sink, &Progress::default()).unwrap();

        assert_eq!(
            sink.snapshots,
            vec![8],
            "the resumed sample at epoch 6 carries a transition already snapshotted"
        );
    }

    #[test]
    fn a_restored_world_carries_on_from_its_own_epoch() {
        let mut world = World::new(&params(), 1).unwrap();
        for _ in 0..4 {
            world.step();
        }
        let restored = World::from_snapshot(&params(), 1, &world.snapshot()).unwrap();
        let mut sink = RecordingSink::default();

        execute_world(restored, 6, None, None, &mut sink, &Progress::default()).unwrap();

        assert_eq!(sink.samples, vec![4, 6]);
        assert!(sink.finished);
    }

    /// The epoch a resumed world comes back from was measured and posted before the
    /// interruption, and the app upserts a sample on [run_id, epoch].
    #[test]
    fn a_resumed_epoch_is_not_measured_again_over_the_rate_already_posted() {
        let params = Params {
            width: 8,
            height: 8,
            tape_len: 256,
            init: Init::Zero,
            mutation_rate: 0.0,
            sample_every: 1,
            snapshot_every: 2,
            ..Params::default()
        };
        let mut world = World::new(&params, 3).unwrap();
        let tape = life_engine::replicator::handwritten_replicator();
        for x in 0..params.width {
            world.set_cell(x, 0, &tape);
        }
        for _ in 0..4 {
            world.step();
        }
        assert!(world.metrics().copy_rate > 0.0);

        let restored = World::from_snapshot(&params, 3, &world.snapshot()).unwrap();
        let mut sink = RecordingSink::default();
        execute_world(restored, 6, Some(4), None, &mut sink, &Progress::default()).unwrap();

        assert_eq!(sink.samples, vec![5, 6]);
        assert_eq!(sink.snapshots, vec![6]);
        assert!(
            sink.copy_rates.iter().all(|rate| *rate > 0.0),
            "{:?}",
            sink.copy_rates
        );
    }

    #[test]
    fn a_stop_ends_the_run_without_finishing_it() {
        let stop = Arc::new(AtomicBool::new(true));
        let progress = Progress::new(0, stop);
        let mut sink = RecordingSink::default();

        let completion = execute_world(
            World::new(&params(), 1).unwrap(),
            6,
            None,
            None,
            &mut sink,
            &progress,
        )
        .unwrap();

        assert!(matches!(completion, Completion::Stopped { epochs_done: 1 }));
        assert!(!sink.finished);
        assert_eq!(progress.epochs_done(), 1);
    }

    /// Ordinary sweep params: `snapshot_every` is well past the run, so nothing but the
    /// first epoch would be snapshotted on cadence alone.
    fn sparse_params() -> Params {
        Params {
            snapshot_every: 1000,
            ..params()
        }
    }

    fn run_with_max_age(max_age: Option<Duration>, epochs: u64) -> RecordingSink {
        let mut sink = RecordingSink::default();
        execute_world(
            World::new(&sparse_params(), 1).unwrap(),
            epochs,
            None,
            max_age,
            &mut sink,
            &Progress::default(),
        )
        .unwrap();
        sink
    }

    #[test]
    fn a_run_snapshots_again_once_the_age_ceiling_passes() {
        let aged = run_with_max_age(Some(Duration::ZERO), 6);

        assert_eq!(aged.samples, vec![0, 2, 4, 6]);
        assert_eq!(
            aged.snapshots, aged.samples,
            "every sampled epoch is overdue"
        );
        assert_eq!(
            aged.reasons,
            vec![
                SnapshotReason::Cadence,
                SnapshotReason::Age,
                SnapshotReason::Age,
                SnapshotReason::Age
            ]
        );
    }

    #[test]
    fn an_unreached_age_ceiling_leaves_the_cadence_alone() {
        let young = run_with_max_age(Some(Duration::from_secs(3600)), 6);

        assert_eq!(young.snapshots, run_with_max_age(None, 6).snapshots);
        assert_eq!(young.snapshots, vec![0]);
    }

    /// An epoch the cadence covers is never counted twice, and it restarts the clock.
    #[test]
    fn a_cadence_epoch_is_the_only_snapshot_of_its_epoch() {
        let mut sink = RecordingSink::default();
        execute_world(
            World::new(&params(), 1).unwrap(),
            6,
            None,
            Some(Duration::ZERO),
            &mut sink,
            &Progress::default(),
        )
        .unwrap();

        assert_eq!(sink.snapshots, vec![0, 2, 3, 4, 6]);
        assert_eq!(
            sink.reasons,
            vec![
                SnapshotReason::Cadence,
                SnapshotReason::Age,
                SnapshotReason::Cadence,
                SnapshotReason::Age,
                SnapshotReason::Cadence
            ]
        );
    }

    #[test]
    fn a_wall_clock_flag_is_read_with_or_without_a_unit() {
        assert_eq!(parse_duration("30m"), Ok(SNAPSHOT_MAX_AGE));
        assert_eq!(parse_duration("600"), Ok(Duration::from_secs(600)));
        assert_eq!(parse_duration("90s"), Ok(Duration::from_secs(90)));
        assert_eq!(parse_duration(" 2H "), Ok(Duration::from_secs(7200)));
        assert!(parse_duration("often").is_err());
        assert!(parse_duration("10d").is_err());
        assert!(parse_duration("").is_err());
        assert!(parse_duration("18446744073709551615h").is_err());
    }

    #[test]
    fn invalid_params_stop_the_run() {
        let params = Params {
            width: 2,
            ..params()
        };
        assert!(execute(&params, 1, 1, &mut NullSink).is_err());
    }
}
