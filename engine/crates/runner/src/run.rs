//! The execution loop, shared by every sink.

use crate::sink::{RunResult, RunSink};
use anyhow::{bail, Result};
use life_engine::{Params, World};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::Arc;
use std::time::Instant;

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
    match execute_world(world, epochs, sink, &Progress::default())? {
        Completion::Finished(result) => Ok(*result),
        Completion::Stopped { epochs_done } => bail!("the run stopped at epoch {epochs_done}"),
    }
}

/// Runs `world` — fresh or restored from a snapshot — up to `epochs`, reporting through
/// `progress` and giving up as soon as it is asked to stop. The sample that settles the
/// transition takes a snapshot of its own, so the run's primary dependent variable has a
/// world behind it to rescore.
pub fn execute_world(
    mut world: World,
    epochs: u64,
    sink: &mut dyn RunSink,
    progress: &Progress,
) -> Result<Completion> {
    let params = world.params().clone();
    let seed = world.seed();
    let sample_every = params.sample_every as u64;
    let snapshot_every = params.snapshot_every as u64;
    let started = Instant::now();
    let mut buffers = SnapshotBuffers::default();
    let mut transition_seen = world.transition_epoch();

    loop {
        let epoch = world.epoch();
        let sampling = epoch.is_multiple_of(sample_every);
        let snapshotting = epoch.is_multiple_of(snapshot_every);
        if sampling && snapshotting {
            let (metrics, raw) = world.metrics_with_snapshot();
            sink.sample(epoch, &metrics, world.transition_epoch())?;
            sink.snapshot(epoch, &raw, buffers.render_png(&world)?)?;
        } else if sampling {
            let metrics = world.metrics();
            sink.sample(epoch, &metrics, world.transition_epoch())?;
        } else if snapshotting {
            let raw = world.snapshot();
            sink.snapshot(epoch, &raw, buffers.render_png(&world)?)?;
        }
        // The one forced snapshot is stored under the sample epoch that confirmed the
        // drop, which trails the settled transition epoch by hold_samples x sample_every.
        let settled = world.transition_epoch();
        if sampling && transition_seen.is_none() && settled.is_some() {
            if !snapshotting {
                let raw = world.snapshot();
                sink.snapshot(epoch, &raw, buffers.render_png(&world)?)?;
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
        snapshots: Vec<u64>,
        finished: bool,
    }

    impl RunSink for RecordingSink {
        fn sample(
            &mut self,
            epoch: u64,
            _metrics: &Metrics,
            _transition_epoch: Option<u64>,
        ) -> Result<()> {
            self.samples.push(epoch);
            Ok(())
        }

        fn snapshot(&mut self, epoch: u64, raw: &[u8], png: &[u8]) -> Result<()> {
            assert!(!raw.is_empty() && !png.is_empty());
            self.snapshots.push(epoch);
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
        execute_world(restored, 8, &mut sink, &Progress::default()).unwrap();

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

        execute_world(restored, 6, &mut sink, &Progress::default()).unwrap();

        assert_eq!(sink.samples, vec![4, 6]);
        assert!(sink.finished);
    }

    #[test]
    fn a_stop_ends_the_run_without_finishing_it() {
        let stop = Arc::new(AtomicBool::new(true));
        let progress = Progress::new(0, stop);
        let mut sink = RecordingSink::default();

        let completion =
            execute_world(World::new(&params(), 1).unwrap(), 6, &mut sink, &progress).unwrap();

        assert!(matches!(completion, Completion::Stopped { epochs_done: 1 }));
        assert!(!sink.finished);
        assert_eq!(progress.epochs_done(), 1);
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
