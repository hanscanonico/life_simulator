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

pub trait RunSink {
    fn sample(&mut self, epoch: u64, metrics: &Metrics) -> Result<()>;
    fn snapshot(&mut self, epoch: u64, raw: &[u8], png: &[u8]) -> Result<()>;
    fn finish(&mut self, result: &RunResult) -> Result<()>;
}

/// Drops everything, for `runner bench`.
pub struct NullSink;

impl RunSink for NullSink {
    fn sample(&mut self, _epoch: u64, _metrics: &Metrics) -> Result<()> {
        Ok(())
    }

    fn snapshot(&mut self, _epoch: u64, _raw: &[u8], _png: &[u8]) -> Result<()> {
        Ok(())
    }

    fn finish(&mut self, _result: &RunResult) -> Result<()> {
        Ok(())
    }
}
