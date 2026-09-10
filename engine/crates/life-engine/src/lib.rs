//! The Life Simulator engine: substrates, metrics, deterministic RNG, snapshots.
//!
//! This crate is the single authority on simulation rules, observables and rendering
//! colours (`docs/DESIGN.md` §2). It compiles natively for the lab and to wasm32 for the
//! browser viewer, and a run is fully determined by `(params, seed)` on both.

pub mod bff;
pub mod hash;
pub mod metrics;
pub mod params;
pub mod render;
pub mod replicator;
pub mod rng;
pub mod snapshot;
pub mod world;

pub use metrics::Metrics;
pub use params::{Init, ParamError, Params, Substrate};
pub use replicator::is_replicator;
pub use snapshot::SnapshotError;
pub use world::World;
