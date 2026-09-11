# frozen_string_literal: true

# Namespace for lab-wide constants shared by the sweep tasks and the runner API.
module Lab
  # The mutation rate of run 41, the first run of the mutation-rate sweep to show
  # emergence: the later sweeps hold the rate there so their arms are comparable to it.
  EMERGENT_MUTATION_RATE = 2.0**-13

  # The whole BFF instruction set, the arm DESIGN §1.3's ablations are cut from — the same
  # ten bytes the engine declares as the default of its `ops` parameter, where a byte whose
  # op is left out of the set is a no-op.
  FULL_INSTRUCTION_SET = "<>{}+-.,[]"

  # The sweeps of DESIGN.md §1.3, as data: `rake lab:sweep[mutation_rate]` turns one entry
  # into an Experiment and its runs.
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
      # Radius 0 is the engine's well-mixed neighbourhood — a partner drawn uniformly
      # from the whole world: the infinity arm of DESIGN §1.3's {1, 2, 4, infinity}.
      param_grid: { "radius" => [1, 2, 4, 0], "width" => [128], "height" => [128] },
      seeds: (1..10).to_a,
      epochs: 20_000
    },
    "max_steps" => {
      name: "Max steps per interaction",
      description: "How much computation does one interaction need before replicators " \
                   "can appear? Too small a budget cannot finish a copy.",
      param_grid: {
        "max_steps" => [2**8, 2**10, 2**13, 2**16],
        "width" => [128],
        "height" => [128],
        "mutation_rate" => [EMERGENT_MUTATION_RATE]
      },
      seeds: (1..10).to_a,
      epochs: 20_000
    },
    "ops" => {
      name: "Instruction set ablations",
      description: "Which of the ten BFF instructions is abiogenesis actually made of? " \
                   "Each arm removes one family of ops and keeps everything else fixed.",
      param_grid: {
        "ops" => [
          FULL_INSTRUCTION_SET,
          "<>{}+-.[]",  # no `,`: nothing can read a byte back under head0
          "<>{}+-,[]",  # no `.`: nothing can write a byte out under head1
          "<>{}+-.,",   # no loops
          "<>+-.,[]",   # no head1 moves
          "<>{}.,[]"    # no arithmetic
        ],
        "width" => [128],
        "height" => [128],
        "mutation_rate" => [EMERGENT_MUTATION_RATE]
      },
      seeds: (1..10).to_a,
      epochs: 20_000
    },
    "bff_control" => {
      name: "BFF positive control",
      description: "Does the engine reproduce the published BFF emergence at all? A " \
                   "well-mixed soup of 2^17 tapes, the shape the original work used. No " \
                   "sweep is readable as a negative result until this one transitions.",
      # Not one of DESIGN §1.3's sweeps but the control the design record of 2026-09-10
      # makes mandatory, which is why it jumps the queue: priority 10 puts its runs ahead
      # of every sweep's. Tape length and step budget are the engine's defaults already.
      # The two cadences are on the grid — the sparse snapshots the same design-record
      # entry asks for — because a 512×256 world at the engine's default cadence would
      # post 500 full-world snapshots per run.
      param_grid: {
        "mutation_rate" => [0.0, 2.0**-12],
        "width" => [512],
        "height" => [256],
        "radius" => [0],
        "sample_every" => [50],
        "snapshot_every" => [2_000]
      },
      seeds: (1..3).to_a,
      epochs: 50_000,
      priority: 10
    }
  }.freeze
end
