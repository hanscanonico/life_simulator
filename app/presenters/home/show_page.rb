# frozen_string_literal: true

module Home
  # Everything the home page's viewer needs before any JavaScript runs: the substrates and
  # parameter defaults the engine declares, the seed of the world the visitor lands on, and
  # the wasm build's URL. The world itself is the engine's, stepped in the browser
  # (`docs/DESIGN.md` §2).
  class ShowPage
    VIEWER_SIZE = 96
    STEPS_PER_FRAME = 1
    MAX_SEED = 2**32

    def self.build(seed: nil)
      new(seed: seed || SecureRandom.random_number(MAX_SEED))
    end

    def initialize(seed:)
      @seed = seed
    end

    attr_reader :seed

    def substrates = Lab::Schema.values_for("substrate")

    def substrate = Lab::Schema.defaults.fetch("substrate")

    def steps_per_frame = STEPS_PER_FRAME

    def worlds
      substrates.index_with { |substrate| params_for(substrate) }
    end

    def params_for(substrate)
      params = Lab::Schema.defaults.merge(
        "substrate" => substrate,
        "width" => VIEWER_SIZE,
        "height" => VIEWER_SIZE
      )
      # Conway's B3/S23 is only itself without noise (`docs/DESIGN.md` §1.1).
      substrate == "life" ? params.merge("mutation_rate" => 0.0) : params
    end

    # nil until `make wasm` has run; the viewer then says so instead of failing silently.
    def wasm_url
      ActionController::Base.helpers.asset_path("life_engine_bg.wasm")
    rescue Propshaft::MissingAssetError
      nil
    end
  end
end
