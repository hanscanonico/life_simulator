//! An in-process stand-in for the Rails runner API, so the lab client and the HTTP sink
//! are tested over a real socket rather than against a hand-written fake of themselves.

use base64::engine::general_purpose::STANDARD as BASE64;
use base64::Engine as _;
use life_engine::Params;
use serde_json::{json, Value};
use std::sync::{Arc, Mutex};
use std::thread::{self, JoinHandle};
use tiny_http::{Header, Method, Request, Response, Server};

pub const TOKEN: &str = "token";
/// The length of the run the mock hands out; short enough to execute in a test.
pub const EPOCHS: u64 = 6;
const BINARY: &str = "application/octet-stream";

#[derive(Default)]
struct State {
    requests: Vec<(String, Value)>,
    queue_empty: bool,
    fail_next: u32,
    latest_snapshot: Option<(u64, Vec<u8>)>,
    worlds: Vec<(u64, Vec<u8>)>,
}

pub struct MockLab {
    server: Arc<Server>,
    state: Arc<Mutex<State>>,
    handler: Option<JoinHandle<()>>,
    port: u16,
}

impl MockLab {
    pub fn start() -> Self {
        let server = Arc::new(Server::http("127.0.0.1:0").expect("binding the mock lab"));
        let port = server.server_addr().to_ip().expect("an ip address").port();
        let state = Arc::new(Mutex::new(State::default()));
        let handler = thread::spawn({
            let server = Arc::clone(&server);
            let state = Arc::clone(&state);
            move || {
                for request in server.incoming_requests() {
                    answer(request, &state);
                }
            }
        });
        Self {
            server,
            state,
            handler: Some(handler),
            port,
        }
    }

    pub fn base_url(&self) -> String {
        format!("http://127.0.0.1:{}", self.port)
    }

    /// The params the mock hands out, small enough for a test to actually run.
    pub fn params() -> Params {
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

    pub fn set_queue_empty(&self) {
        self.state.lock().unwrap().queue_empty = true;
    }

    pub fn set_latest_snapshot(&self, epoch: u64, blob: Vec<u8>) {
        self.state.lock().unwrap().latest_snapshot = Some((epoch, blob));
    }

    /// The worlds `GET /api/runs/1/world` serves, newest last.
    pub fn set_worlds(&self, worlds: Vec<(u64, Vec<u8>)>) {
        self.state.lock().unwrap().worlds = worlds;
    }

    /// Answers the next `times` requests with a 500, as a flaky app would.
    pub fn fail_next(&self, times: u32) {
        self.state.lock().unwrap().fail_next = times;
    }

    pub fn count(&self, what: &str) -> u32 {
        self.state
            .lock()
            .unwrap()
            .requests
            .iter()
            .filter(|(seen, _)| seen == what)
            .count() as u32
    }

    /// The body of the first request to `what`; panics when there was none.
    pub fn request(&self, what: &str) -> Value {
        self.requests(what)
            .into_iter()
            .next()
            .unwrap_or_else(|| panic!("no {what} was received"))
    }

    pub fn requests(&self, what: &str) -> Vec<Value> {
        self.state
            .lock()
            .unwrap()
            .requests
            .iter()
            .filter(|(seen, _)| seen == what)
            .map(|(_, body)| body.clone())
            .collect()
    }
}

impl Drop for MockLab {
    fn drop(&mut self) {
        self.server.unblock();
        if let Some(handler) = self.handler.take() {
            let _ = handler.join();
        }
    }
}

/// The world of the `epoch` query, or the newest one when the query names none.
fn world(url: &str, worlds: &[(u64, Vec<u8>)]) -> Option<Value> {
    let asked = url
        .split_once("epoch=")
        .map(|(_, rest)| rest.split('&').next().unwrap_or_default().to_string());
    let (epoch, blob) = match asked {
        Some(epoch) => worlds.iter().find(|(at, _)| at.to_string() == epoch)?,
        None => worlds.last()?,
    };
    Some(json!({
        "id": 1,
        "params": MockLab::params(),
        "seed": 7,
        "epoch": epoch,
        "blob": BASE64.encode(blob),
    }))
}

fn answer(mut request: Request, state: &Arc<Mutex<State>>) {
    let method = request.method().clone();
    let url = request.url().to_string();
    let path = url.split('?').next().unwrap_or_default().to_string();
    let authorized = request.headers().iter().any(|header| {
        header.field.equiv("Authorization") && header.value == format!("Bearer {TOKEN}").as_str()
    });
    let wants_binary = request
        .headers()
        .iter()
        .any(|header| header.field.equiv("Accept") && header.value == "application/octet-stream");
    let mut body = String::new();
    let _ = std::io::Read::read_to_string(request.as_reader(), &mut body);
    let parsed = serde_json::from_str(&body).unwrap_or(Value::Null);

    let mut state = state.lock().unwrap();
    state.requests.push((format!("{method} {path}"), parsed));

    if !authorized {
        let _ = request.respond(Response::empty(401));
        return;
    }
    if state.fail_next > 0 {
        state.fail_next -= 1;
        let _ = request.respond(Response::empty(500));
        return;
    }

    if wants_binary && method == Method::Get && path == "/api/runs/1/snapshots/latest" {
        let _ = match state.latest_snapshot.clone() {
            Some((epoch, blob)) => request.respond(
                Response::from_data(blob)
                    .with_header(
                        Header::from_bytes(&b"Content-Type"[..], BINARY.as_bytes()).unwrap(),
                    )
                    .with_header(
                        Header::from_bytes(&b"X-Snapshot-Epoch"[..], epoch.to_string().as_bytes())
                            .unwrap(),
                    ),
            ),
            None => request.respond(Response::empty(204)),
        };
        return;
    }

    let response = match (&method, path.as_str()) {
        (Method::Post, "/api/runs/claim") if state.queue_empty => None,
        (Method::Post, "/api/runs/claim") => Some(json!({
            "id": 1,
            "params": MockLab::params(),
            "seed": 7,
            "epochs": EPOCHS,
            "epochs_done": 0,
        })),
        (Method::Get, "/api/runs/1/world") => world(&url, &state.worlds),
        (Method::Get, "/api/runs/1/snapshots/latest") => state
            .latest_snapshot
            .as_ref()
            .map(|(epoch, blob)| json!({ "epoch": epoch, "blob": BASE64.encode(blob) })),
        _ => None,
    };

    let _ = match response {
        Some(json) => request.respond(Response::from_string(json.to_string()).with_header(
            Header::from_bytes(&b"Content-Type"[..], &b"application/json"[..]).unwrap(),
        )),
        None => request.respond(Response::empty(204)),
    };
}
