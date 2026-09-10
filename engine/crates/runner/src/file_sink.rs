//! The local-mode sink: `samples.ndjson`, `snapshots/<epoch>.{bin,png}`, `result.json`.

use crate::sink::{RunResult, RunSink};
use anyhow::{Context, Result};
use life_engine::Metrics;
use std::fs::{self, File};
use std::io::{BufWriter, Write};
use std::path::{Path, PathBuf};

pub struct FileSink {
    dir: PathBuf,
    samples: BufWriter<File>,
}

impl FileSink {
    pub fn create(dir: &Path) -> Result<Self> {
        fs::create_dir_all(dir.join("snapshots"))
            .with_context(|| format!("creating {}", dir.display()))?;
        let samples = File::create(dir.join("samples.ndjson"))
            .with_context(|| format!("creating {}/samples.ndjson", dir.display()))?;
        Ok(Self {
            dir: dir.to_path_buf(),
            samples: BufWriter::new(samples),
        })
    }
}

impl RunSink for FileSink {
    fn sample(&mut self, epoch: u64, metrics: &Metrics) -> Result<()> {
        let mut line = serde_json::to_value(metrics)?;
        line["epoch"] = serde_json::json!(epoch);
        writeln!(self.samples, "{}", serde_json::to_string(&line)?)?;
        Ok(())
    }

    fn snapshot(&mut self, epoch: u64, raw: &[u8], png: &[u8]) -> Result<()> {
        let at = self.dir.join("snapshots");
        fs::write(at.join(format!("{epoch}.bin")), raw)?;
        fs::write(at.join(format!("{epoch}.png")), png)?;
        Ok(())
    }

    fn finish(&mut self, result: &RunResult) -> Result<()> {
        self.samples.flush()?;
        fs::write(
            self.dir.join("result.json"),
            serde_json::to_string_pretty(result)?,
        )?;
        Ok(())
    }
}
