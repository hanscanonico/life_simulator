# frozen_string_literal: true

require "rails_helper"

# The engine is the single authority on the rules (`docs/DESIGN.md` §2), and the browser
# runs a second build of it. These hashes pin the two builds together: the wasm module the
# viewer loads has to land on the very world the native build lands on.
RSpec.describe "The wasm engine", :js, type: :system do
  # `PINNED_SOUP_HASH` and `PINNED_LIFE_HASH` from engine/crates/life-engine/src/world.rs's
  # tests, the source of truth for both: 32×32, seed 42, 50 epochs.
  let(:pinned_soup_hash) { "d25f8c163d9e2dd9" }
  let(:pinned_life_hash) { "200af82208b596b9" }
  let(:epochs) { 50 }
  let(:seed) { 42 }

  def asset(name) = ActionController::Base.helpers.asset_path(name)

  def hash_after_epochs(params)
    args = [asset("life_engine.js"), asset("life_engine_bg.wasm"), params.to_json, epochs, seed]
    page.evaluate_async_script(<<~JS, *args)
      const [moduleUrl, wasmUrl, paramsJson, epochs, seed, done] = arguments
      import(moduleUrl)
        .then(async (engine) => {
          await engine.default({ module_or_path: wasmUrl })
          const world = new engine.World(paramsJson, BigInt(seed))
          world.step(epochs)
          done(world.world_hash().toString(16).padStart(16, "0"))
        })
        .catch((error) => done(`the engine failed: ${error.message}`))
    JS
  end

  before { visit how_it_works_path }

  it "runs the soup to the hash the native build pins" do
    expect(hash_after_epochs("width" => 32, "height" => 32)).to eq(pinned_soup_hash)
  end

  it "runs life to the hash the native build pins" do
    params = {
      "substrate" => "life", "width" => 32, "height" => 32,
      "mutation_rate" => 0.0, "init" => "random"
    }
    expect(hash_after_epochs(params)).to eq(pinned_life_hash)
  end
end
