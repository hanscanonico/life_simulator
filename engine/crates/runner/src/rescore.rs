//! `runner rescore` — re-reads one stored world at several `top_k` settings.
//!
//! The replicator test itself is the engine's (`docs/DESIGN.md` §1.2) and is not touched:
//! rescoring only builds the same world again with `top_k` overridden and asks for
//! `metrics()`, so the numbers it prints are the numbers a run with that setting would
//! have reported at that epoch.

use crate::api::{LabClient, StoredWorld};
use anyhow::{anyhow, bail, Context, Result};
use life_engine::metrics;
use life_engine::{Metrics, Params, World};
use serde::Serialize;
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
}
