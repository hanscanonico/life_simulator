# frozen_string_literal: true

# Namespace for lab-wide constants shared by the sweep tasks and the runner API.
module Lab
  # Substrate parameter defaults from DESIGN.md §1.1. The engine's `runner schema` is the
  # authority on the parameter set, its defaults and its ranges; a later task loads the
  # schema from the engine and this constant goes away. Parameters DESIGN leaves without a
  # default (`sample_every`) are deliberately absent: the engine decides them.
  ENGINE_DEFAULTS = {
    "width" => 128,
    "height" => 128,
    "tape_len" => 64,
    "radius" => 1,
    "max_steps" => 2**13,
    "mutation_rate" => 1.0 / 4096,
    "init" => "random",
    "top_k" => 16
  }.freeze

  # The sweeps of DESIGN.md §1.3, as data: `rake lab:sweep[mutation_rate]` turns one entry
  # into an Experiment and its runs. Sweeps 4 and 5 land with the experiments they need.
  SWEEPS = {
    "mutation_rate" => {
      name: "Mutation rate",
      description: "Is there a mutation rate window for abiogenesis? Zero mutation should " \
                   "delay emergence and too much should destroy it (error threshold).",
      param_grid: {
        "mutation_rate" => [0.0, *(8..16).reverse_each.map { |exponent| 2.0**-exponent }],
        "width" => [128],
        "height" => [128]
      },
      seeds: (1..10).to_a,
      epochs: 20_000
    },
    "world_size" => {
      name: "World size",
      description: "Does time to emergence scale with cell count (more lottery tickets) " \
                   "or is emergence a per-cell rate?",
      # Width and height travel together so the worlds stay square instead of the grid
      # multiplying every width against every height.
      param_grid: {
        "world_size" => [32, 64, 128, 256].map { |side| { "width" => side, "height" => side } }
      },
      seeds: (1..10).to_a,
      epochs: 20_000
    },
    "radius" => {
      name: "Neighbourhood radius",
      description: "Does spatial locality speed emergence and stabilise diversity afterwards?",
      # 64 is half the 128-wide torus, so every cell can reach every other one: the
      # well-mixed arm of DESIGN §1.3's {1, 2, 4, infinity}.
      param_grid: { "radius" => [1, 2, 4, 64], "width" => [128], "height" => [128] },
      seeds: (1..10).to_a,
      epochs: 20_000
    }
  }.freeze
end
