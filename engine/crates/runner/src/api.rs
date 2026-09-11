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

pub(crate) const MAX_ATTEMPTS: u32 = 5;
const BACKOFF: Duration = Duration::from_secs(2);
const TIMEOUT: Duration = Duration::from_secs(60);
/// How much of a JSON answer the runner is willing to read. Every endpoint but the two
/// that serve worlds answers a handful of fields, so a megabyte is already generous.
const MAX_JSON_BODY: u64 = 1024 * 1024;
/// `GET .../world` answers a base64 blob of a whole world and the caller knows no params
/// to bound it with, so it keeps the flat limit `ureq`'s 10 MiB default cannot meet.
const MAX_WORLD_BODY: u64 = 256 * 1024 * 1024;
/// Slack over the uncompressed world a snapshot answer is allowed: header, framing and
/// the pathological case of zlib growing incompressible bytes.
const SNAPSHOT_SLACK: u64 = 64 * 1024;
/// Where a binary snapshot answer carries the epoch its bytes are at.
const SNAPSHOT_EPOCH_HEADER: &str = "X-Snapshot-Epoch";
const BINARY: &str = "application/octet-stream";
/// How much of a binary answer a failure message quotes.
const DESCRIBED_BYTES: usize = 512;

/// A run handed over by `POST /api/runs/claim`.
#[derive(Debug, Clone, PartialEq)]
pub struct ClaimedRun {
    pub id: i64,
    pub params: Params,
    pub seed: u64,
    pub epochs: u64,
    pub epochs_done: u64,
}

/// A world the lab has stored, with everything needed to read it again: `runner rescore`
/// decodes `blob` against `params` and measures it at the run's own seed. The epoch is
/// the blob's own header's, so it is not carried twice.
#[derive(Debug, Clone, PartialEq)]
pub struct StoredWorld {
    pub params: Params,
    pub seed: u64,
    pub blob: Vec<u8>,
}

/// A binary answer: the bytes and the epoch its header named.
struct BinaryAnswer {
    epoch: Option<u64>,
    bytes: Vec<u8>,
}

/// How an answer reads inside a failure message. A rejected or broken call answers a
/// short text body whichever content type was asked for, so a binary one is worth
/// printing too — truncated, since it may also be a whole world.
trait Answer {
    fn describe(&self) -> String;
}

impl Answer for String {
    fn describe(&self) -> String {
        self.clone()
    }
}

impl Answer for BinaryAnswer {
    fn describe(&self) -> String {
        let head = &self.bytes[..self.bytes.len().min(DESCRIBED_BYTES)];
        String::from_utf8_lossy(head).into_owned()
    }
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

    pub fn samples(
        &self,
        run: i64,
        runner_id: &str,
        samples: &[Value],
        transition_epoch: Option<u64>,
    ) -> Result<()> {
        let mut body = json!({ "samples": samples });
        if let Some(epoch) = transition_epoch {
            body["transition_epoch"] = json!(epoch);
        }
        self.member(run, runner_id, "samples", body)
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
    /// the run has not snapshotted yet. The answer is asked for as bytes and read once
    /// into the vector `World::from_snapshot` reads, so resuming holds one copy of the
    /// blob rather than a base64 string, a `Value` owning it again and the decoding of
    /// both. `params` are the claimed run's, and bound the answer.
    pub fn latest_snapshot(
        &self,
        run: i64,
        runner_id: &str,
        params: &Params,
    ) -> Result<Option<(u64, Vec<u8>)>> {
        let path = format!("/api/runs/{run}/snapshots/latest");
        let query = [("runner_id", runner_id.to_string())];
        let (status, answer) = self.get_binary(&path, &query, snapshot_body_limit(params))?;
        if status == 204 {
            return Ok(None);
        }
        let answer = accepted(status, answer, &format!("GET {path}"))?;
        let epoch = answer
            .epoch
            .ok_or_else(|| anyhow!("the snapshot answer has no {SNAPSHOT_EPOCH_HEADER} header"))?;
        Ok(Some((epoch, answer.bytes)))
    }

    /// A stored world of `run`, at `epoch` or at the newest snapshot when it is `None`.
    /// `None` when the run stored no world to read.
    pub fn world(&self, run: i64, epoch: Option<u64>) -> Result<Option<StoredWorld>> {
        let path = format!("/api/runs/{run}/world");
        let query: Vec<(&str, String)> = epoch
            .map(|epoch| vec![("epoch", epoch.to_string())])
            .unwrap_or_default();
        let (status, body) = self.get(&path, &query, MAX_WORLD_BODY)?;
        if status == 204 {
            return Ok(None);
        }
        let body = accepted(status, body, &format!("GET {path}"))?;
        let world: Value = serde_json::from_str(&body).context("parsing the stored world")?;
        let blob = world["blob"]
            .as_str()
            .ok_or_else(|| anyhow!("the stored world has no blob"))?;
        Ok(Some(StoredWorld {
            params: serde_json::from_value(world["params"].clone())
                .context("parsing the run params")?,
            seed: number(&world, "seed")?,
            blob: BASE64.decode(blob).context("decoding the stored world")?,
        }))
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
            Ok((status, read_body(&mut response, &url, MAX_JSON_BODY)?))
        })
    }

    fn get(&self, path: &str, query: &[(&str, String)], limit: u64) -> Result<(u16, String)> {
        let url = format!("{}{path}", self.base);
        self.with_retries(&url, || {
            let mut response = self.send_get(&url, query, None)?;
            let status = response.status().as_u16();
            Ok((status, read_body(&mut response, &url, limit)?))
        })
    }

    fn get_binary(
        &self,
        path: &str,
        query: &[(&str, String)],
        limit: u64,
    ) -> Result<(u16, BinaryAnswer)> {
        let url = format!("{}{path}", self.base);
        self.with_retries(&url, || {
            let mut response = self.send_get(&url, query, Some(BINARY))?;
            let status = response.status().as_u16();
            let epoch = response
                .headers()
                .get(SNAPSHOT_EPOCH_HEADER)
                .and_then(|value| value.to_str().ok())
                .and_then(|value| value.parse().ok());
            let bytes = read_bytes(&mut response, &url, limit)?;
            Ok((status, BinaryAnswer { epoch, bytes }))
        })
    }

    fn send_get(
        &self,
        url: &str,
        query: &[(&str, String)],
        accept: Option<&str>,
    ) -> Result<ureq::http::Response<ureq::Body>> {
        let mut request = self.agent.get(url).header("Authorization", self.bearer());
        if let Some(accept) = accept {
            request = request.header("Accept", accept);
        }
        for (key, value) in query {
            request = request.query(*key, value);
        }
        Ok(request.call()?)
    }

    fn bearer(&self) -> String {
        format!("Bearer {}", self.token)
    }

    fn with_retries<T, F>(&self, url: &str, attempt: F) -> Result<(u16, T)>
    where
        F: Fn() -> Result<(u16, T)>,
        T: Answer,
    {
        let mut wait = self.backoff;
        for attempted in 1..=MAX_ATTEMPTS {
            let last = attempted == MAX_ATTEMPTS;
            match attempt() {
                Ok((status, body)) if status < 500 => return Ok((status, body)),
                Ok((status, body)) if last => {
                    bail!("{url} still answered {status}: {}", body.describe())
                }
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

/// What a snapshot answer of a world described by `params` is allowed to weigh: the
/// uncompressed world twice over plus slack. A compressed blob is always well under it,
/// and a runner resuming twelve slots at once can afford this where a flat limit of
/// hundreds of megabytes per slot is what exhausted the mini-pc's swap.
fn snapshot_body_limit(params: &Params) -> u64 {
    (params.cell_count() as u64) * (params.stride() as u64) * 2 + SNAPSHOT_SLACK
}

/// Reads an answer whole, up to `limit`. Naming the endpoint and the limit keeps a body
/// that is genuinely too big from reading as an unexplained transport failure.
fn read_body(
    response: &mut ureq::http::Response<ureq::Body>,
    url: &str,
    limit: u64,
) -> Result<String> {
    response
        .body_mut()
        .with_config()
        .limit(limit)
        .read_to_string()
        .with_context(|| format!("reading the answer of {url} (limit {limit} bytes)"))
}

fn read_bytes(
    response: &mut ureq::http::Response<ureq::Body>,
    url: &str,
    limit: u64,
) -> Result<Vec<u8>> {
    response
        .body_mut()
        .with_config()
        .limit(limit)
        .read_to_vec()
        .with_context(|| format!("reading the answer of {url} (limit {limit} bytes)"))
}

/// The app answers every runner call with 2xx; anything else is a hard failure the
/// caller turns into a failed run rather than a retry.
fn accepted<T: Answer>(status: u16, body: T, what: &str) -> Result<T> {
    if (200..300).contains(&status) {
        Ok(body)
    } else {
        bail!("{what} answered {status}: {}", body.describe())
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

    /// The control world of DESIGN.md §5, the largest the sweeps run.
    fn control_params() -> Params {
        Params {
            width: 512,
            height: 256,
            tape_len: 64,
            ..Params::default()
        }
    }

    #[test]
    fn the_latest_snapshot_comes_back_as_bytes_with_its_epoch() {
        let lab = MockLab::start();
        lab.set_latest_snapshot(60, b"restored".to_vec());

        let (epoch, blob) = client(&lab)
            .latest_snapshot(1, "runner-1", &MockLab::params())
            .unwrap()
            .unwrap();

        assert_eq!((epoch, blob), (60, b"restored".to_vec()));
    }

    /// A 512x256x64 world's snapshot runs well past `ureq`'s default 10 MiB body limit;
    /// reading it must not turn a resumable run into a failed one.
    #[test]
    fn a_snapshot_larger_than_the_default_body_limit_still_comes_back() {
        let lab = MockLab::start();
        let raw = vec![0xab_u8; 12 * 1024 * 1024];
        lab.set_latest_snapshot(60, raw.clone());

        let (epoch, blob) = client(&lab)
            .latest_snapshot(1, "runner-1", &control_params())
            .unwrap()
            .unwrap();

        assert!(raw.len() as u64 > 10 * 1024 * 1024);
        assert_eq!(epoch, 60);
        assert_eq!(blob, raw);
    }

    /// The bound is what keeps twelve slots resuming at once inside the mini-pc's
    /// memory, so an answer over it is refused rather than read.
    #[test]
    fn a_snapshot_over_the_bound_its_params_derive_is_refused() {
        let lab = MockLab::start();
        let limit = snapshot_body_limit(&MockLab::params());
        lab.set_latest_snapshot(60, vec![0u8; limit as usize + 1]);

        let error = format!(
            "{:#}",
            client(&lab)
                .latest_snapshot(1, "runner-1", &MockLab::params())
                .unwrap_err()
        );

        assert!(error.contains("/api/runs/1/snapshots/latest"), "{error}");
        assert!(error.contains(&format!("limit {limit} bytes")), "{error}");
    }

    /// The derivation has to admit the largest world the sweeps run, however badly its
    /// cells compress.
    #[test]
    fn the_bound_admits_the_control_world() {
        let params = control_params();
        let snapshot = life_engine::World::new(&params, 7).unwrap().snapshot();

        assert!(
            snapshot.len() as u64 <= snapshot_body_limit(&params),
            "a {}-byte snapshot against a {}-byte bound",
            snapshot.len(),
            snapshot_body_limit(&params)
        );
    }

    #[test]
    fn a_stored_world_comes_back_with_the_params_that_describe_it() {
        let lab = MockLab::start();
        lab.set_worlds(vec![(100, b"old".to_vec()), (300, b"newest".to_vec())]);
        let client = client(&lab);

        let newest = client.world(1, None).unwrap().unwrap();
        let asked = client.world(1, Some(100)).unwrap().unwrap();

        assert_eq!(newest.blob, b"newest".to_vec());
        assert_eq!(newest.params, MockLab::params());
        assert_eq!(newest.seed, 7);
        assert_eq!(asked.blob, b"old".to_vec());
    }

    #[test]
    fn a_run_with_no_stored_world_rescores_nothing() {
        let lab = MockLab::start();

        assert_eq!(client(&lab).world(1, None).unwrap(), None);
    }

    #[test]
    fn a_run_with_no_snapshot_resumes_from_nothing() {
        let lab = MockLab::start();

        assert_eq!(
            client(&lab)
                .latest_snapshot(1, "runner-1", &MockLab::params())
                .unwrap(),
            None
        );
    }
}
