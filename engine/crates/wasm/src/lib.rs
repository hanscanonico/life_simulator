//! `wasm-bindgen` wrapper over `life-engine` for the browser viewer. It adds no rules and
//! no metrics of its own: the canvas draws `render_rgba`'s pixels and reads
//! `metrics_json`'s numbers (`docs/DESIGN.md` §2).

use life_engine::{Params, World as EngineWorld};
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub struct World {
    inner: EngineWorld,
}

#[wasm_bindgen]
impl World {
    #[wasm_bindgen(constructor)]
    pub fn new(params_json: &str, seed: u64) -> Result<World, JsValue> {
        Self::build(params_json, seed).map_err(|message| JsValue::from_str(&message))
    }

    pub fn step(&mut self, n: u32) {
        for _ in 0..n {
            self.inner.step();
        }
    }

    pub fn epoch(&self) -> u64 {
        self.inner.epoch()
    }

    pub fn width(&self) -> u32 {
        self.inner.width()
    }

    pub fn height(&self) -> u32 {
        self.inner.height()
    }

    pub fn render_rgba(&self, buf: &mut [u8]) {
        self.inner.render_rgba(buf);
    }

    pub fn metrics_json(&mut self) -> String {
        serde_json::to_string(&self.inner.metrics()).expect("metrics always serialise")
    }

    pub fn world_hash(&self) -> u64 {
        self.inner.world_hash()
    }
}

impl World {
    /// The fallible half of the constructor, kept off the `wasm_bindgen` boundary so it
    /// can be tested on the host as well as in a browser.
    fn build(params_json: &str, seed: u64) -> Result<World, String> {
        let params: Params = serde_json::from_str(params_json).map_err(|e| e.to_string())?;
        let inner = EngineWorld::new(&params, seed).map_err(|e| e.to_string())?;
        Ok(World { inner })
    }
}

#[wasm_bindgen]
pub fn schema_json() -> String {
    Params::schema_json()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_world_steps_and_reports_through_the_wrapper() {
        let mut world = World::build(r#"{"width": 8, "height": 8}"#, 1).unwrap();
        assert_eq!(world.width(), 8);
        assert_eq!(world.epoch(), 0);

        world.step(2);
        assert_eq!(world.epoch(), 2);

        let mut buf = vec![0u8; 8 * 8 * 4];
        world.render_rgba(&mut buf);
        assert!(buf.as_chunks::<4>().0.iter().all(|p| p[3] == 255));

        let metrics: serde_json::Value = serde_json::from_str(&world.metrics_json()).unwrap();
        assert!(metrics["compress_ratio"].as_f64().unwrap() > 0.0);
        assert!(
            metrics["copy_rate"].is_f64(),
            "the readout formats the engine's own copy_rate: {metrics}"
        );
    }

    #[test]
    fn bad_json_and_bad_params_come_back_as_errors() {
        assert!(World::build("not json", 1).is_err());
        assert!(World::build(r#"{"width": 2}"#, 1).is_err());
    }

    #[test]
    fn the_schema_is_the_engines_own() {
        assert_eq!(schema_json(), Params::schema_json());
    }
}
