# engine/

The Rust workspace: the simulation itself, and the single authority on rules, metrics and
rendering colours (`docs/DESIGN.md` §2). A run is fully determined by `(params, seed)`,
natively and in the browser.

## Crates

| Crate | What it is |
|---|---|
| `crates/life-engine` (lib `life_engine`) | `Params`, the BFF interpreter, the `Soup` and `Life` substrates, the observables, snapshots, RGBA rendering |
| `crates/runner` (bin `runner`) | Executes runs; local mode writes files. Lab mode (HTTP to Rails) plugs into the same loop through `RunSink` |
| `crates/wasm` (cdylib) | `wasm-bindgen` wrapper over `life_engine::World` for the viewer |

## Commands

```sh
cargo test --workspace                       # unit tests, incl. the pinned determinism hashes
make verify                                  # the whole gate (from the repo root)
make wasm                                    # cargo build -p wasm --target wasm32-unknown-unknown --release

runner schema                                # the parameter schema Rails reads
runner run --params p.json --seed 1 --epochs 20000 --out out/
runner bench --params p.json                 # epochs/s
```

`--params -` reads the JSON from stdin. Output of `run`: `samples.ndjson` (one object per
sample), `snapshots/<epoch>.{bin,png}`, `result.json`.

## Adding a substrate

1. Add a variant to `Substrate` in `params.rs` and to the `substrate` field's values in
   `FIELDS` — defaults and ranges live there and nowhere else.
2. Give it a stride in `Params::stride`, a rule in `World::step_*`, a colour in
   `render.rs`, and a snapshot byte in `snapshot.rs`.
3. Pin a `(params, seed) → world_hash` test for it, as `docs/DESIGN.md` §3 requires.
