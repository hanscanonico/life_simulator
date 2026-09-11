//! Where a run's output goes. The execution loop writes through this trait so the local
//! file mode and the future lab mode (HTTP to Rails) share one loop.

use anyhow::Result;
use life_engine::{Metrics, Params};
use serde::Serialize;

#[derive(Debug, Clone, Serialize)]
pub struct RunResult {
    pub params: Params,
    pub seed: u64,
    pub epochs: u64,
    pub transition_epoch: Option<u64>,
    pub wall_seconds: f64,
    pub epochs_per_second: f64,
}

/// Why the loop took a snapshot: the epoch cadence, the wall-clock ceiling on snapshot
/// age, or the sample that settled the transition. Lab mode logs it so a shift's restart
/// cost can be read off the log rather than inferred from the snapshot epochs.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SnapshotReason {
    Cadence,
    Age,
    Transition,
}

impl SnapshotReason {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Cadence => "cadence",
            Self::Age => "age",
            Self::Transition => "transition",
        }
    }
}

pub trait RunSink {
    /// One sampled epoch, with the transition epoch the engine has settled on so far so
    /// a run that dies before `finish` still reports its measurement.
    fn sample(
        &mut self,
        epoch: u64,
        metrics: &Metrics,
        transition_epoch: Option<u64>,
    ) -> Result<()>;
    fn snapshot(
        &mut self,
        epoch: u64,
        raw: &[u8],
        png: &[u8],
        reason: SnapshotReason,
    ) -> Result<()>;
    fn finish(&mut self, result: &RunResult) -> Result<()>;
}

/// Drops everything, for `runner bench`.
pub struct NullSink;

impl RunSink for NullSink {
    fn sample(
        &mut self,
        _epoch: u64,
        _metrics: &Metrics,
        _transition_epoch: Option<u64>,
    ) -> Result<()> {
        Ok(())
    }

    fn snapshot(
        &mut self,
        _epoch: u64,
        _raw: &[u8],
        _png: &[u8],
        _reason: SnapshotReason,
    ) -> Result<()> {
        Ok(())
    }

    fn finish(&mut self, _result: &RunResult) -> Result<()> {
        Ok(())
    }
}
