//! Lab mode: the stateless worker of `docs/DESIGN.md` §2. Each thread claims a run from
//! the app, streams it back through `HttpSink`, heartbeats while it works, and either
//! finishes the run or reports the failure that ended it. On SIGTERM the current sample
//! batch and a last heartbeat go out and the process exits; the app releases the run as
//! stale and the next claim resumes it from its latest snapshot.

use crate::api::{ClaimedRun, LabClient};
use crate::http_sink::HttpSink;
use crate::run::{self, Completion, Progress};
use anyhow::Result;
use life_engine::World;
use std::any::Any;
use std::panic::{self, AssertUnwindSafe};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

/// How long a worker waits before asking for work again when the queue is empty.
pub const IDLE: Duration = Duration::from_secs(15);
/// DESIGN.md §2: a run silent for 5 minutes is released, so beat well inside that.
pub const HEARTBEAT: Duration = Duration::from_secs(30);
const TICK: Duration = Duration::from_millis(100);
/// How far apart slots start. A restart has every slot claim and resume at once, and a
/// dozen multi-megabyte snapshot answers in the same instant is what exhausted the
/// mini-pc's swap; spreading the start-up spreads those reads.
const STAGGER: Duration = Duration::from_millis(500);
/// How often a blocked worker says so; a spike lasts minutes and every worker sees it.
const COMPLAINT: Duration = Duration::from_secs(60);
const MIB: u64 = 1 << 20;

pub struct Lab {
    client: LabClient,
    runner_id: String,
    parallelism: usize,
    idle: Duration,
    heartbeat: Duration,
    stagger: Duration,
    memory: Option<MemoryGuard>,
    stop: Arc<AtomicBool>,
}

impl Lab {
    pub fn new(
        api: &str,
        token: &str,
        runner_id: &str,
        parallelism: usize,
        max_memory: Option<u64>,
    ) -> Self {
        Self {
            client: LabClient::new(api, token),
            runner_id: runner_id.to_string(),
            parallelism: parallelism.max(1),
            idle: IDLE,
            heartbeat: HEARTBEAT,
            stagger: STAGGER,
            memory: max_memory.map(MemoryGuard::detect),
            stop: Arc::new(AtomicBool::new(false)),
        }
    }

    /// Claims and executes runs until a signal asks for a stop.
    pub fn work(&self) -> Result<()> {
        for signal in [signal_hook::consts::SIGTERM, signal_hook::consts::SIGINT] {
            signal_hook::flag::register(signal, Arc::clone(&self.stop))?;
        }
        println!(
            "{}: lab mode, {} worker(s), {}",
            self.runner_id,
            self.parallelism,
            match &self.memory {
                Some(guard) => guard.describe(),
                None => "no memory guard".to_string(),
            }
        );
        thread::scope(|scope| {
            for worker in 0..self.parallelism {
                scope.spawn(move || self.claim_loop(worker));
            }
        });
        Ok(())
    }

    /// One worker: its own runner id, so the app hands it its own runs.
    fn claim_loop(&self, worker: usize) {
        let runner_id = format!("{}-{worker}", self.runner_id);
        self.wait(self.stagger * worker as u32);
        while !self.stopping() {
            if self.out_of_memory_headroom(&runner_id) {
                self.wait(self.idle);
                continue;
            }
            match self.client.claim(&runner_id) {
                Ok(Some(claimed)) => {
                    println!("{runner_id}: claimed run {}", claimed.id);
                    self.execute(&runner_id, &claimed);
                }
                Ok(None) => self.wait(self.idle),
                Err(error) => {
                    eprintln!("{runner_id}: claiming failed: {error:#}");
                    self.wait(self.idle);
                }
            }
        }
        println!("{runner_id}: stopped");
    }

    /// A claim can double the memory the process holds — a resumed world arrives as a
    /// snapshot blob and becomes a `World` — so a worker that would claim past the limit
    /// waits instead. Runs already in flight are never dropped: an OOM kill would cost
    /// each of them the 5-minute stale release before anyone could resume it.
    fn out_of_memory_headroom(&self, runner_id: &str) -> bool {
        self.memory
            .as_ref()
            .is_some_and(|guard| guard.exceeded(runner_id))
    }

    /// Executes one claimed run. Anything that ends it other than completion or a signal
    /// — a bad snapshot, an HTTP failure that outlived its retries, a panic in the
    /// engine — is reported to the app as the run's error.
    fn execute(&self, runner_id: &str, claimed: &ClaimedRun) {
        let failure =
            match panic::catch_unwind(AssertUnwindSafe(|| self.stream(runner_id, claimed))) {
                Ok(Ok(Completion::Finished(result))) => {
                    println!(
                        "{runner_id}: finished run {} in {:.1}s",
                        claimed.id, result.wall_seconds
                    );
                    return;
                }
                Ok(Ok(Completion::Stopped { epochs_done })) => {
                    println!(
                        "{runner_id}: left run {} at epoch {epochs_done} for a later claim",
                        claimed.id
                    );
                    return;
                }
                Ok(Err(error)) => format!("{error:#}"),
                Err(panic) => panic_message(&panic),
            };
        eprintln!("{runner_id}: run {} failed: {failure}", claimed.id);
        if let Err(error) = self
            .client
            .finish(claimed.id, runner_id, None, None, Some(&failure))
        {
            eprintln!("{runner_id}: reporting the failure failed too: {error:#}");
        }
    }

    fn stream(&self, runner_id: &str, claimed: &ClaimedRun) -> Result<Completion> {
        let world = self.restore(runner_id, claimed)?;
        let progress = Progress::new(world.epoch(), Arc::clone(&self.stop));
        let done = AtomicBool::new(false);

        thread::scope(|scope| {
            scope.spawn(|| self.beat(claimed.id, runner_id, &progress, &done));
            let _beating = StopOnDrop(&done);

            let mut sink = HttpSink::new(&self.client, claimed.id, runner_id);
            let completion = run::execute_world(world, claimed.epochs, &mut sink, &progress)?;
            if let Completion::Stopped { epochs_done } = completion {
                sink.flush()?;
                self.client.heartbeat(claimed.id, runner_id, epochs_done)?;
            }
            Ok(completion)
        })
    }

    /// A run with epochs behind it continues from its latest snapshot; everything else
    /// starts from `(params, seed)`.
    fn restore(&self, runner_id: &str, claimed: &ClaimedRun) -> Result<World> {
        if claimed.epochs_done > 0 {
            let latest = self
                .client
                .latest_snapshot(claimed.id, runner_id, &claimed.params)?;
            if let Some((epoch, blob)) = latest {
                println!("{runner_id}: resuming run {} at epoch {epoch}", claimed.id);
                return World::from_snapshot(&claimed.params, claimed.seed, &blob)
                    .map_err(anyhow::Error::msg);
            }
        }
        World::new(&claimed.params, claimed.seed).map_err(anyhow::Error::msg)
    }

    fn beat(&self, run: i64, runner_id: &str, progress: &Progress, done: &AtomicBool) {
        let mut next = Instant::now() + self.heartbeat;
        while !done.load(Ordering::Relaxed) {
            if Instant::now() < next {
                thread::sleep(TICK.min(self.heartbeat));
                continue;
            }
            next = Instant::now() + self.heartbeat;
            if let Err(error) = self
                .client
                .heartbeat(run, runner_id, progress.epochs_done())
            {
                eprintln!("{runner_id}: heartbeat for run {run} failed: {error:#}");
            }
        }
    }

    fn stopping(&self) -> bool {
        self.stop.load(Ordering::Relaxed)
    }

    /// Sleeps in short ticks so a signal is noticed straight away.
    fn wait(&self, total: Duration) {
        let until = Instant::now() + total;
        while Instant::now() < until && !self.stopping() {
            thread::sleep(TICK.min(total));
        }
    }
}

/// Stops the heartbeat thread however the run ends — including a panic, which would
/// otherwise leave the scope waiting for a thread that never returns.
struct StopOnDrop<'a>(&'a AtomicBool);

impl Drop for StopOnDrop<'_> {
    fn drop(&mut self) {
        self.0.store(true, Ordering::Relaxed);
    }
}

fn panic_message(panic: &Box<dyn Any + Send>) -> String {
    if let Some(message) = panic.downcast_ref::<&str>() {
        format!("panic: {message}")
    } else if let Some(message) = panic.downcast_ref::<String>() {
        format!("panic: {message}")
    } else {
        "panic: the run ended in an unprintable panic".to_string()
    }
}

/// Holds claims back while the process is over `limit` bytes. The reader is a field so a
/// test can hand in a usage figure instead of a file this machine may not have.
struct MemoryGuard {
    limit: u64,
    source: &'static str,
    usage: UsageReader,
    complained_at: Mutex<Option<Instant>>,
}

/// Bytes the process holds, or `None` when this machine cannot say.
type UsageReader = Box<dyn Fn() -> Option<u64> + Send + Sync>;

/// cgroup v2, the shape of the mini-pc's docker host.
const CGROUP_V2: &str = "/sys/fs/cgroup/memory.current";
const CGROUP_V1: &str = "/sys/fs/cgroup/memory/memory.usage_in_bytes";
const STATM: &str = "/proc/self/statm";
/// `statm` counts pages, and there is no page size to ask for without libc; 4 KiB is
/// right on the x86-64 host and this is the last resort of three sources anyway.
const PAGE: u64 = 4096;

impl MemoryGuard {
    /// The first source that answers on this machine. macOS has none of them, so the
    /// guard reads nothing there and local runs behave as they always did.
    fn detect(limit: u64) -> Self {
        match MemorySource::detect() {
            Some(source) => Self::reading(limit, source.path, Box::new(source.read)),
            None => Self::reading(limit, "no source on this platform", Box::new(|| None)),
        }
    }

    fn reading(limit: u64, source: &'static str, usage: UsageReader) -> Self {
        Self {
            limit,
            source,
            usage,
            complained_at: Mutex::new(None),
        }
    }

    fn describe(&self) -> String {
        format!(
            "memory guard at {} MiB, read from {}",
            self.limit / MIB,
            self.source
        )
    }

    fn exceeded(&self, runner_id: &str) -> bool {
        let Some(usage) = (self.usage)() else {
            return false;
        };
        if usage <= self.limit {
            return false;
        }
        let mut complained_at = self.complained_at.lock().unwrap();
        if complained_at.is_none_or(|at| at.elapsed() >= COMPLAINT) {
            *complained_at = Some(Instant::now());
            println!(
                "{runner_id}: {} MiB held, over the {} MiB guard — waiting to claim",
                usage / MIB,
                self.limit / MIB
            );
        }
        true
    }
}

struct MemorySource {
    path: &'static str,
    read: fn() -> Option<u64>,
}

impl MemorySource {
    /// The first of the three that this machine answers from.
    fn detect() -> Option<Self> {
        [
            Self {
                path: CGROUP_V2,
                read: cgroup_v2_usage,
            },
            Self {
                path: CGROUP_V1,
                read: cgroup_v1_usage,
            },
            Self {
                path: STATM,
                read: statm_usage,
            },
        ]
        .into_iter()
        .find(|source| (source.read)().is_some())
    }
}

fn cgroup_v2_usage() -> Option<u64> {
    first_number(CGROUP_V2)
}

fn cgroup_v1_usage() -> Option<u64> {
    first_number(CGROUP_V1)
}

/// The second field of `statm` is the resident set, in pages.
fn statm_usage() -> Option<u64> {
    let statm = std::fs::read_to_string(STATM).ok()?;
    let pages: u64 = statm.split_whitespace().nth(1)?.parse().ok()?;
    pages.checked_mul(PAGE)
}

fn first_number(path: &str) -> Option<u64> {
    std::fs::read_to_string(path)
        .ok()?
        .split_whitespace()
        .next()?
        .parse()
        .ok()
}

/// `--max-memory` and compose's own limits speak the same sizes: `5g`, `512m`, or bytes.
pub fn parse_memory_size(text: &str) -> Result<u64, String> {
    let lowered = text.trim().to_ascii_lowercase();
    let digits = lowered
        .strip_suffix("ib")
        .or_else(|| lowered.strip_suffix('b'))
        .unwrap_or(&lowered);
    let (digits, scale) = if let Some(rest) = digits.strip_suffix('g') {
        (rest, 1 << 30)
    } else if let Some(rest) = digits.strip_suffix('m') {
        (rest, 1 << 20)
    } else if let Some(rest) = digits.strip_suffix('k') {
        (rest, 1 << 10)
    } else {
        (digits, 1)
    };
    let size: u64 = digits
        .trim()
        .parse()
        .map_err(|_| format!("{text:?} is not a size like 5g, 512m or a byte count"))?;
    size.checked_mul(scale)
        .filter(|&bytes| bytes > 0)
        .ok_or_else(|| format!("{text:?} is not a usable memory limit"))
}

/// The default worker count of DESIGN.md §2: every core but the two the site keeps.
pub fn default_parallelism() -> usize {
    thread::available_parallelism()
        .map(|cores| cores.get().saturating_sub(2))
        .unwrap_or(1)
        .max(1)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::mock_lab::{self, MockLab};
    use life_engine::Params;
    use serde_json::json;

    /// A lab wired to the mock, with every wait short enough for a test.
    fn lab(mock: &MockLab) -> Lab {
        Lab {
            client: LabClient::new(&mock.base_url(), mock_lab::TOKEN)
                .with_backoff(Duration::from_millis(1)),
            runner_id: "runner-test".to_string(),
            parallelism: 1,
            idle: Duration::from_millis(10),
            heartbeat: Duration::from_millis(10),
            stagger: Duration::ZERO,
            memory: None,
            stop: Arc::new(AtomicBool::new(false)),
        }
    }

    /// A guard reading a fixed usage, so the test does not depend on this machine.
    fn guard(limit: u64, usage: u64) -> MemoryGuard {
        MemoryGuard::reading(limit, "a test reader", Box::new(move || Some(usage)))
    }

    /// Runs `worker` until `stop`, long enough for a claim or two.
    fn claim_briefly(lab: &Lab, worker: usize) {
        thread::scope(|scope| {
            scope.spawn(|| lab.claim_loop(worker));
            thread::sleep(Duration::from_millis(100));
            lab.stop.store(true, Ordering::Relaxed);
        });
    }

    fn claimed(params: Params, epochs: u64, epochs_done: u64) -> ClaimedRun {
        ClaimedRun {
            id: 1,
            params,
            seed: 7,
            epochs,
            epochs_done,
        }
    }

    #[test]
    fn a_claimed_run_is_streamed_and_finished() {
        let mock = MockLab::start();
        let lab = lab(&mock);

        lab.execute("runner-1", &claimed(MockLab::params(), 6, 0));

        assert_eq!(mock.count("POST /api/runs/1/finish"), 1);
        assert!(mock.request("POST /api/runs/1/finish")["error"].is_null());
    }

    #[test]
    fn an_empty_queue_makes_the_worker_idle_until_it_is_stopped() {
        let mock = MockLab::start();
        mock.set_queue_empty();
        let lab = lab(&mock);

        thread::scope(|scope| {
            scope.spawn(|| lab.claim_loop(0));
            thread::sleep(Duration::from_millis(60));
            lab.stop.store(true, Ordering::Relaxed);
        });

        assert!(mock.count("POST /api/runs/claim") >= 1);
        assert_eq!(mock.count("POST /api/runs/1/finish"), 0);
    }

    #[test]
    fn a_run_that_cannot_start_is_reported_as_failed() {
        let mock = MockLab::start();
        let lab = lab(&mock);
        let params = Params {
            width: 2,
            ..MockLab::params()
        };

        lab.execute("runner-1", &claimed(params, 6, 0));

        let finished = mock.request("POST /api/runs/1/finish");
        assert!(finished["error"].as_str().unwrap().contains("width"));
    }

    #[test]
    fn a_run_with_epochs_behind_it_resumes_from_its_latest_snapshot() {
        let mock = MockLab::start();
        let mut world = World::new(&MockLab::params(), 7).unwrap();
        for _ in 0..4 {
            world.step();
        }
        mock.set_latest_snapshot(4, world.snapshot());

        lab(&mock).execute("runner-1", &claimed(MockLab::params(), 6, 4));

        let samples = mock.request("POST /api/runs/1/samples");
        assert_eq!(samples["samples"][0]["epoch"], json!(4));
        assert_eq!(mock.count("POST /api/runs/1/finish"), 1);
    }

    /// Restarting the world from `(params, seed)` when its snapshot cannot be fetched
    /// would silently throw away the epochs already computed, so the run fails instead.
    #[test]
    fn a_snapshot_that_cannot_be_fetched_fails_the_run_rather_than_starting_it_over() {
        let mock = MockLab::start();
        mock.set_latest_snapshot(4, World::new(&MockLab::params(), 7).unwrap().snapshot());
        mock.fail_next(crate::api::MAX_ATTEMPTS);

        lab(&mock).execute("runner-1", &claimed(MockLab::params(), 6, 4));

        let failure = mock.request("POST /api/runs/1/finish");
        let error = failure["error"].as_str().unwrap_or_default();
        assert!(error.contains("/api/runs/1/snapshots/latest"), "{failure}");
        assert_eq!(mock.count("POST /api/runs/1/samples"), 0);
    }

    #[test]
    fn a_stop_leaves_the_run_heartbeated_but_unfinished() {
        let mock = MockLab::start();
        let lab = lab(&mock);
        lab.stop.store(true, Ordering::Relaxed);

        lab.execute("runner-1", &claimed(MockLab::params(), 6, 0));

        let beat = mock.request("POST /api/runs/1/heartbeat");
        assert_eq!(beat["epochs_done"], json!(1));
        assert_eq!(mock.count("POST /api/runs/1/finish"), 0);
    }

    /// A slot waits its own offset out before its first claim, so twelve resumes do not
    /// fetch their snapshots in the same instant.
    #[test]
    fn a_later_slot_starts_after_the_earlier_ones() {
        assert!(STAGGER > Duration::ZERO, "slots would all start at once");

        let mock = MockLab::start();
        mock.set_queue_empty();
        let mut lab = lab(&mock);
        lab.stagger = Duration::from_secs(1);

        thread::scope(|scope| {
            scope.spawn(|| lab.claim_loop(0));
            scope.spawn(|| lab.claim_loop(2));
            thread::sleep(Duration::from_millis(60));
            lab.stop.store(true, Ordering::Relaxed);
        });

        let claimants: Vec<String> = mock
            .requests("POST /api/runs/claim")
            .iter()
            .map(|body| body["runner_id"].as_str().unwrap_or_default().to_string())
            .collect();
        assert!(
            claimants.contains(&"runner-test-0".to_string()),
            "{claimants:?}"
        );
        assert!(
            !claimants.contains(&"runner-test-2".to_string()),
            "{claimants:?}"
        );
    }

    #[test]
    fn a_worker_over_the_memory_guard_claims_nothing() {
        let mock = MockLab::start();
        let mut lab = lab(&mock);
        lab.memory = Some(guard(4 * MIB, 8 * MIB));

        claim_briefly(&lab, 0);

        assert_eq!(mock.count("POST /api/runs/claim"), 0);
    }

    #[test]
    fn a_worker_under_the_memory_guard_claims_as_usual() {
        let mock = MockLab::start();
        let mut lab = lab(&mock);
        lab.memory = Some(guard(8 * MIB, 4 * MIB));

        claim_briefly(&lab, 0);

        assert!(mock.count("POST /api/runs/claim") >= 1);
        assert!(mock.count("POST /api/runs/1/finish") >= 1);
    }

    /// macOS, where none of the three sources exist: the guard reads nothing and claims.
    #[test]
    fn a_guard_without_a_memory_source_holds_nothing_back() {
        let unreadable = MemoryGuard::reading(0, "no source", Box::new(|| None));

        assert!(!unreadable.exceeded("runner-test-0"));
    }

    #[test]
    fn the_detected_guard_names_the_source_it_reads() {
        assert!(MemoryGuard::detect(5 << 30).describe().contains("5120 MiB"));
    }

    #[test]
    fn memory_sizes_are_read_with_or_without_a_binary_suffix() {
        assert_eq!(parse_memory_size("5g"), Ok(5 << 30));
        assert_eq!(parse_memory_size("512M"), Ok(512 << 20));
        assert_eq!(parse_memory_size("1024k"), Ok(1024 << 10));
        assert_eq!(parse_memory_size("6GiB"), Ok(6 << 30));
        assert_eq!(parse_memory_size(" 4096 "), Ok(4096));
        assert!(parse_memory_size("plenty").is_err());
        assert!(parse_memory_size("0").is_err());
        assert!(parse_memory_size("-1g").is_err());
    }

    #[test]
    fn the_default_parallelism_leaves_the_site_two_cores() {
        assert!(default_parallelism() >= 1);
    }
}
