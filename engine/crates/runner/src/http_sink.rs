//! The lab-mode sink: metric samples batched to the app with the transition epoch the
//! run has settled on, snapshots posted as they are taken, and one `finish` carrying
//! that epoch again with the last metrics.

use crate::api::LabClient;
use crate::sink::{RunResult, RunSink};
use anyhow::Result;
use life_engine::Metrics;
use serde_json::{json, Value};
use std::time::{Duration, Instant};

/// A batch is posted once it holds this many samples...
pub const BATCH_SIZE: usize = 50;
/// ...or once this long has passed, so a slow run still shows progress on the site.
pub const BATCH_AGE: Duration = Duration::from_secs(10);

pub struct HttpSink<'a> {
    client: &'a LabClient,
    run: i64,
    runner_id: String,
    pending: Vec<Value>,
    batched_at: Instant,
    batch_age: Duration,
    last_metrics: Option<Metrics>,
    transition_epoch: Option<u64>,
}

impl<'a> HttpSink<'a> {
    pub fn new(client: &'a LabClient, run: i64, runner_id: &str) -> Self {
        Self {
            client,
            run,
            runner_id: runner_id.to_string(),
            pending: Vec::with_capacity(BATCH_SIZE),
            batched_at: Instant::now(),
            batch_age: BATCH_AGE,
            last_metrics: None,
            transition_epoch: None,
        }
    }

    /// Shortens the batch deadline; the tests would otherwise wait ten seconds for one.
    #[cfg(test)]
    pub fn with_batch_age(mut self, batch_age: Duration) -> Self {
        self.batch_age = batch_age;
        self
    }

    /// Posts whatever is batched. Called on every full batch, before `finish`, and by
    /// lab mode when a signal interrupts the run.
    pub fn flush(&mut self) -> Result<()> {
        if self.pending.is_empty() {
            return Ok(());
        }
        self.client.samples(
            self.run,
            &self.runner_id,
            &self.pending,
            self.transition_epoch,
        )?;
        self.pending.clear();
        self.batched_at = Instant::now();
        Ok(())
    }
}

impl RunSink for HttpSink<'_> {
    fn sample(
        &mut self,
        epoch: u64,
        metrics: &Metrics,
        transition_epoch: Option<u64>,
    ) -> Result<()> {
        let mut sample = serde_json::to_value(metrics)?;
        sample["epoch"] = json!(epoch);
        self.pending.push(sample);
        self.last_metrics = Some(metrics.clone());
        if transition_epoch.is_some() {
            self.transition_epoch = transition_epoch;
        }
        if self.pending.len() >= BATCH_SIZE || self.batched_at.elapsed() >= self.batch_age {
            self.flush()?;
        }
        Ok(())
    }

    fn snapshot(&mut self, epoch: u64, raw: &[u8], png: &[u8]) -> Result<()> {
        self.client
            .snapshot(self.run, &self.runner_id, epoch, raw, png)
    }

    fn finish(&mut self, result: &RunResult) -> Result<()> {
        self.flush()?;
        self.client.finish(
            self.run,
            &self.runner_id,
            result.transition_epoch,
            self.last_metrics.as_ref(),
            None,
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::mock_lab::MockLab;
    use crate::run;
    use life_engine::{Init, Params};

    fn client(lab: &MockLab) -> LabClient {
        LabClient::new(&lab.base_url(), crate::mock_lab::TOKEN)
            .with_backoff(Duration::from_millis(1))
    }

    fn metrics(compress_ratio: f64) -> Metrics {
        Metrics {
            compress_ratio,
            distinct_tapes: 3,
            top_share: 0.5,
            op_density: 0.04,
            replicator_count: 0,
            entropy_bits: 7.9,
            copy_rate: 0.0,
        }
    }

    #[test]
    fn samples_are_held_until_the_batch_is_full() {
        let lab = MockLab::start();
        let client = client(&lab);
        let mut sink =
            HttpSink::new(&client, 1, "runner-1").with_batch_age(Duration::from_secs(600));

        for epoch in 0..(BATCH_SIZE as u64 - 1) {
            sink.sample(epoch, &metrics(0.9), None).unwrap();
        }

        assert_eq!(lab.count("POST /api/runs/1/samples"), 0);
    }

    #[test]
    fn a_full_batch_goes_out_in_one_request() {
        let lab = MockLab::start();
        let client = client(&lab);
        let mut sink =
            HttpSink::new(&client, 1, "runner-1").with_batch_age(Duration::from_secs(600));

        for epoch in 0..BATCH_SIZE as u64 {
            sink.sample(epoch, &metrics(0.9), None).unwrap();
        }

        let posted = lab.request("POST /api/runs/1/samples");
        assert_eq!(posted["samples"].as_array().unwrap().len(), BATCH_SIZE);
        assert_eq!(posted["samples"][0]["epoch"], json!(0));
        assert_eq!(posted["samples"][0]["compress_ratio"], json!(0.9));
        assert_eq!(posted.get("transition_epoch"), None, "nothing settled yet");
    }

    #[test]
    fn an_old_batch_goes_out_before_it_is_full() {
        let lab = MockLab::start();
        let client = client(&lab);
        let mut sink = HttpSink::new(&client, 1, "runner-1").with_batch_age(Duration::ZERO);

        sink.sample(0, &metrics(0.9), None).unwrap();

        assert_eq!(lab.count("POST /api/runs/1/samples"), 1);
    }

    #[test]
    fn a_whole_run_streams_samples_snapshots_and_a_finish() {
        let lab = MockLab::start();
        let client = client(&lab);
        let mut sink =
            HttpSink::new(&client, 1, "runner-1").with_batch_age(Duration::from_secs(600));

        run::execute(&MockLab::params(), 7, 6, &mut sink).unwrap();

        let samples = lab.request("POST /api/runs/1/samples");
        assert_eq!(samples["samples"].as_array().unwrap().len(), 4);
        assert_eq!(lab.count("POST /api/runs/1/snapshots"), 3);
        assert_eq!(lab.count("POST /api/runs/1/finish"), 1);
    }

    #[test]
    fn a_batch_carries_the_transition_epoch_the_run_has_settled_on() {
        let lab = MockLab::start();
        let client = client(&lab);
        let mut sink =
            HttpSink::new(&client, 1, "runner-1").with_batch_age(Duration::from_secs(600));
        let ordered = Params {
            init: Init::Zero,
            mutation_rate: 0.0,
            ..MockLab::params()
        };

        run::execute(&ordered, 7, 6, &mut sink).unwrap();

        let posted = lab.request("POST /api/runs/1/samples");
        assert_eq!(posted["samples"].as_array().unwrap().len(), 4);
        assert_eq!(posted["transition_epoch"], json!(0));
    }

    #[test]
    fn a_settled_transition_epoch_is_kept_for_later_batches() {
        let lab = MockLab::start();
        let client = client(&lab);
        let mut sink =
            HttpSink::new(&client, 1, "runner-1").with_batch_age(Duration::from_secs(600));

        sink.sample(0, &metrics(0.9), None).unwrap();
        sink.sample(2, &metrics(0.4), Some(2)).unwrap();
        sink.flush().unwrap();
        sink.sample(4, &metrics(0.4), None).unwrap();
        sink.flush().unwrap();

        let batches = lab.requests("POST /api/runs/1/samples");
        assert_eq!(batches.len(), 2);
        assert_eq!(batches[1]["samples"][0]["epoch"], json!(4));
        assert_eq!(batches[1]["transition_epoch"], json!(2));
    }

    #[test]
    fn finish_carries_the_last_metrics_as_the_summary() {
        let lab = MockLab::start();
        let client = client(&lab);
        let mut sink =
            HttpSink::new(&client, 1, "runner-1").with_batch_age(Duration::from_secs(600));

        sink.sample(0, &metrics(0.9), None).unwrap();
        sink.sample(2, &metrics(0.4), Some(2)).unwrap();
        sink.finish(&RunResult {
            params: MockLab::params(),
            seed: 7,
            epochs: 2,
            transition_epoch: Some(2),
            wall_seconds: 1.0,
            epochs_per_second: 2.0,
        })
        .unwrap();

        let finished = lab.request("POST /api/runs/1/finish");
        assert_eq!(finished["transition_epoch"], json!(2));
        assert_eq!(finished["summary"]["compress_ratio"], json!(0.4));
        assert_eq!(finished["runner_id"], json!("runner-1"));
    }
}
