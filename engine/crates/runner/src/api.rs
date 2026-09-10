//! The lab API client: the runner's half of the endpoints in `app/controllers/api`.
//!
//! Every call carries the bearer token and the runner id holding the run, and retries a
//! transport failure or a 5xx `MAX_ATTEMPTS` times with a doubling backoff before giving
//! up. A 4xx is the app's verdict and is never retried.

use anyhow::{anyhow, bail, Context, Result};
use base64::engine::general_purpose::STANDARD as BASE64;
use base64::Engine as _;
use life_engine::{Metrics, Params};
use serde_json::{json, Value};
use std::thread;
use std::time::Duration;

const MAX_ATTEMPTS: u32 = 5;
const BACKOFF: Duration = Duration::from_secs(2);
const TIMEOUT: Duration = Duration::from_secs(60);
/// How much of an answer the runner is willing to read. `ureq` defaults to 10 MiB, which
/// a large world's snapshot blows through: a 512x256 world resumes from a base64 blob of
/// tens of megabytes.
const MAX_BODY: u64 = 256 * 1024 * 1024;

/// A run handed over by `POST /api/runs/claim`.
#[derive(Debug, Clone, PartialEq)]
pub struct ClaimedRun {
    pub id: i64,
    pub params: Params,
    pub seed: u64,
    pub epochs: u64,
    pub epochs_done: u64,
}

pub struct LabClient {
    agent: ureq::Agent,
    base: String,
    token: String,
    backoff: Duration,
}

impl LabClient {
    pub fn new(base: &str, token: &str) -> Self {
        let config = ureq::Agent::config_builder()
            .http_status_as_error(false)
            .timeout_global(Some(TIMEOUT))
            .build();
        Self {
            agent: config.into(),
            base: base.trim_end_matches('/').to_string(),
            token: token.to_string(),
            backoff: BACKOFF,
        }
    }

    /// Shortens the retry backoff; the tests would otherwise sleep for seconds.
    #[cfg(test)]
    pub fn with_backoff(mut self, backoff: Duration) -> Self {
        self.backoff = backoff;
        self
    }

    pub fn claim(&self, runner_id: &str) -> Result<Option<ClaimedRun>> {
        let (status, body) = self.post("/api/runs/claim", &json!({ "runner_id": runner_id }))?;
        if status == 204 {
            return Ok(None);
        }
        let body = accepted(status, body, "POST /api/runs/claim")?;
        let claimed: Value = serde_json::from_str(&body).context("parsing the claimed run")?;
        Ok(Some(ClaimedRun {
            id: number(&claimed, "id")? as i64,
            params: serde_json::from_value(claimed["params"].clone())
                .context("parsing the run params")?,
            seed: number(&claimed, "seed")?,
            epochs: number(&claimed, "epochs")?,
            epochs_done: number(&claimed, "epochs_done")?,
        }))
    }

    pub fn heartbeat(&self, run: i64, runner_id: &str, epochs_done: u64) -> Result<()> {
        self.member(
            run,
            runner_id,
            "heartbeat",
            json!({ "epochs_done": epochs_done }),
        )
    }

    pub fn samples(&self, run: i64, runner_id: &str, samples: &[Value]) -> Result<()> {
        self.member(run, runner_id, "samples", json!({ "samples": samples }))
    }

    pub fn snapshot(
        &self,
        run: i64,
        runner_id: &str,
        epoch: u64,
        raw: &[u8],
        png: &[u8],
    ) -> Result<()> {
        self.member(
            run,
            runner_id,
            "snapshots",
            json!({ "epoch": epoch, "blob": BASE64.encode(raw), "png": BASE64.encode(png) }),
        )
    }

    pub fn finish(
        &self,
        run: i64,
        runner_id: &str,
        transition_epoch: Option<u64>,
        summary: Option<&Metrics>,
        error: Option<&str>,
    ) -> Result<()> {
        let mut body = json!({});
        if let Some(epoch) = transition_epoch {
            body["transition_epoch"] = json!(epoch);
        }
        if let Some(summary) = summary {
            body["summary"] = serde_json::to_value(summary)?;
        }
        if let Some(error) = error {
            body["error"] = json!(error);
        }
        self.member(run, runner_id, "finish", body)
    }

    /// The world a resumed run continues from: `(epoch, snapshot bytes)`, or `None` when
    /// the run has not snapshotted yet.
    pub fn latest_snapshot(&self, run: i64, runner_id: &str) -> Result<Option<(u64, Vec<u8>)>> {
        let path = format!("/api/runs/{run}/snapshots/latest");
        let (status, body) = self.get(&path, runner_id)?;
        if status == 204 {
            return Ok(None);
        }
        let body = accepted(status, body, &format!("GET {path}"))?;
        let snapshot: Value = serde_json::from_str(&body).context("parsing the snapshot")?;
        let blob = snapshot["blob"]
            .as_str()
            .ok_or_else(|| anyhow!("the snapshot has no blob"))?;
        Ok(Some((
            number(&snapshot, "epoch")?,
            BASE64.decode(blob).context("decoding the snapshot blob")?,
        )))
    }

    fn member(&self, run: i64, runner_id: &str, action: &str, mut body: Value) -> Result<()> {
        let path = format!("/api/runs/{run}/{action}");
        body["runner_id"] = json!(runner_id);
        let (status, response) = self.post(&path, &body)?;
        accepted(status, response, &format!("POST {path}"))?;
        Ok(())
    }

    fn post(&self, path: &str, body: &Value) -> Result<(u16, String)> {
        let url = format!("{}{path}", self.base);
        self.with_retries(&url, || {
            let mut response = self
                .agent
                .post(&url)
                .header("Authorization", self.bearer())
                .send_json(body)?;
            let status = response.status().as_u16();
            Ok((status, read_body(&mut response, &url)?))
        })
    }

    fn get(&self, path: &str, runner_id: &str) -> Result<(u16, String)> {
        let url = format!("{}{path}", self.base);
        self.with_retries(&url, || {
            let mut response = self
                .agent
                .get(&url)
                .header("Authorization", self.bearer())
                .query("runner_id", runner_id)
                .call()?;
            let status = response.status().as_u16();
            Ok((status, read_body(&mut response, &url)?))
        })
    }

    fn bearer(&self) -> String {
        format!("Bearer {}", self.token)
    }

    fn with_retries<F>(&self, url: &str, attempt: F) -> Result<(u16, String)>
    where
        F: Fn() -> Result<(u16, String)>,
    {
        let mut wait = self.backoff;
        for attempted in 1..=MAX_ATTEMPTS {
            let last = attempted == MAX_ATTEMPTS;
            match attempt() {
                Ok((status, body)) if status < 500 => return Ok((status, body)),
                Ok((status, body)) if last => bail!("{url} still answered {status}: {body}"),
                Err(error) if last => {
                    return Err(error.context(format!("{url} failed {MAX_ATTEMPTS} times")))
                }
                _ => {}
            }
            thread::sleep(wait);
            wait *= 2;
        }
        unreachable!("the last attempt always returns")
    }
}

/// Reads an answer whole, up to `MAX_BODY`. Naming the endpoint and the limit keeps a
/// body that is genuinely too big from reading as an unexplained transport failure.
fn read_body(response: &mut ureq::http::Response<ureq::Body>, url: &str) -> Result<String> {
    response
        .body_mut()
        .with_config()
        .limit(MAX_BODY)
        .read_to_string()
        .with_context(|| format!("reading the answer of {url} (limit {MAX_BODY} bytes)"))
}

/// The app answers every runner call with 2xx; anything else is a hard failure the
/// caller turns into a failed run rather than a retry.
fn accepted(status: u16, body: String, what: &str) -> Result<String> {
    if (200..300).contains(&status) {
        Ok(body)
    } else {
        bail!("{what} answered {status}: {body}")
    }
}

fn number(value: &Value, key: &str) -> Result<u64> {
    value[key]
        .as_u64()
        .ok_or_else(|| anyhow!("the response has no numeric {key}"))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::mock_lab::MockLab;

    fn client(lab: &MockLab) -> LabClient {
        LabClient::new(&lab.base_url(), "token").with_backoff(Duration::from_millis(1))
    }

    #[test]
    fn a_claim_carries_the_run_to_execute() {
        let lab = MockLab::start();
        let client = client(&lab);

        let claimed = client.claim("runner-1").unwrap().unwrap();

        assert_eq!(claimed.id, 1);
        assert_eq!(claimed.seed, 7);
        assert_eq!(
            lab.request("POST /api/runs/claim")["runner_id"],
            json!("runner-1")
        );
    }

    #[test]
    fn an_empty_queue_claims_nothing() {
        let lab = MockLab::start();
        lab.set_queue_empty();

        assert_eq!(client(&lab).claim("runner-1").unwrap(), None);
    }

    #[test]
    fn a_missing_token_is_a_hard_failure() {
        let lab = MockLab::start();
        let client = LabClient::new(&lab.base_url(), "").with_backoff(Duration::from_millis(1));

        let error = client.claim("runner-1").unwrap_err().to_string();

        assert!(error.contains("401"), "{error}");
    }

    #[test]
    fn a_server_error_is_retried() {
        let lab = MockLab::start();
        lab.fail_next(2);

        assert!(client(&lab).claim("runner-1").unwrap().is_some());
        assert_eq!(lab.count("POST /api/runs/claim"), 3);
    }

    #[test]
    fn a_server_error_that_never_clears_gives_up() {
        let lab = MockLab::start();
        lab.fail_next(u32::MAX);

        assert!(client(&lab).claim("runner-1").is_err());
        assert_eq!(lab.count("POST /api/runs/claim"), MAX_ATTEMPTS);
    }

    #[test]
    fn a_snapshot_travels_as_base64() {
        let lab = MockLab::start();

        client(&lab)
            .snapshot(1, "runner-1", 30, b"raw", b"png")
            .unwrap();

        let posted = lab.request("POST /api/runs/1/snapshots");
        assert_eq!(posted["blob"], json!(BASE64.encode(b"raw")));
        assert_eq!(posted["epoch"], json!(30));
    }

    #[test]
    fn the_latest_snapshot_comes_back_decoded() {
        let lab = MockLab::start();
        lab.set_latest_snapshot(60, b"restored".to_vec());

        let (epoch, blob) = client(&lab)
            .latest_snapshot(1, "runner-1")
            .unwrap()
            .unwrap();

        assert_eq!((epoch, blob), (60, b"restored".to_vec()));
    }

    /// A 512x256 world's snapshot travels as a base64 blob well past `ureq`'s default
    /// 10 MiB body limit; reading it must not turn a resumable run into a failed one.
    #[test]
    fn a_snapshot_larger_than_the_default_body_limit_still_comes_back() {
        let lab = MockLab::start();
        let raw = vec![0xab_u8; 9 * 1024 * 1024];
        lab.set_latest_snapshot(60, raw.clone());

        let (epoch, blob) = client(&lab)
            .latest_snapshot(1, "runner-1")
            .unwrap()
            .unwrap();

        assert!(BASE64.encode(&raw).len() > 10 * 1024 * 1024);
        assert_eq!(epoch, 60);
        assert_eq!(blob, raw);
    }

    #[test]
    fn a_run_with_no_snapshot_resumes_from_nothing() {
        let lab = MockLab::start();

        assert_eq!(client(&lab).latest_snapshot(1, "runner-1").unwrap(), None);
    }
}
