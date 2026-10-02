//! A stored world as the lab keeps it: a snapshot blob (`snapshots.blob`) and its run's
//! params (`runs.params`, JSON).

use life_engine::{Params, World};
use std::path::Path;

pub struct Stored {
    pub params: Params,
    pub blob: Vec<u8>,
}

impl Stored {
    pub fn load(snapshot: &Path, params: &Path) -> Result<Self, String> {
        Ok(Self {
            params: read_params(params)?,
            blob: std::fs::read(snapshot)
                .map_err(|e| format!("reading {}: {e}", snapshot.display()))?,
        })
    }

    /// The world as stored, resumed under `seed`. The seed moves nothing until the world
    /// is stepped.
    pub fn world(&self, seed: u64) -> Result<World, String> {
        World::from_snapshot(&self.params, seed, &self.blob).map_err(|e| e.to_string())
    }
}

pub fn read_params(path: &Path) -> Result<Params, String> {
    let json =
        std::fs::read_to_string(path).map_err(|e| format!("reading {}: {e}", path.display()))?;
    serde_json::from_str(&json).map_err(|e| format!("parsing {}: {e}", path.display()))
}
