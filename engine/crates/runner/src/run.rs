//! The execution loop, shared by every sink.

use crate::sink::{RunResult, RunSink};
use anyhow::Result;
use life_engine::{Params, World};
use std::time::Instant;

pub fn execute(
    params: &Params,
    seed: u64,
    epochs: u64,
    sink: &mut dyn RunSink,
) -> Result<RunResult> {
    let mut world = World::new(params, seed).map_err(anyhow::Error::msg)?;
    let sample_every = params.sample_every as u64;
    let snapshot_every = params.snapshot_every as u64;
    let started = Instant::now();

    loop {
        let epoch = world.epoch();
        if epoch % sample_every == 0 {
            let metrics = world.metrics();
            sink.sample(epoch, &metrics)?;
        }
        if epoch % snapshot_every == 0 {
            let raw = world.snapshot();
            sink.snapshot(epoch, &raw, &render_png(&world)?)?;
        }
        if epoch == epochs {
            break;
        }
        world.step();
    }

    let wall_seconds = started.elapsed().as_secs_f64();
    let result = RunResult {
        params: params.clone(),
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
    Ok(result)
}

/// A PNG of the world at its native size, coloured by the engine.
pub fn render_png(world: &World) -> Result<Vec<u8>> {
    let mut pixels = vec![0u8; world.params().cell_count() * 4];
    world.render_rgba(&mut pixels);

    let mut out = Vec::new();
    {
        let mut encoder = png::Encoder::new(&mut out, world.width(), world.height());
        encoder.set_color(png::ColorType::Rgba);
        encoder.set_depth(png::BitDepth::Eight);
        let mut writer = encoder.write_header()?;
        writer.write_image_data(&pixels)?;
    }
    Ok(out)
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
        fn sample(&mut self, epoch: u64, _metrics: &Metrics) -> Result<()> {
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
        let png = render_png(&world).unwrap();
        assert_eq!(&png[1..4], b"PNG");
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
