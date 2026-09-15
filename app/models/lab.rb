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

  # A sweep's key is a Ruby-ish identifier; its Experiment slug is the same word in URL
  # form. One helper so the task, the presenter and the findings agree on the spelling.
  def self.slug_for(key) = key.tr("_", "-")

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
    "mutation_rate_long" => {
      name: "Mutation rate, long runs",
      description: "Sweep 1 saw transitions only at 2^-13 and 2^-12 (one seed in ten " \
                   "each) within 20 000 epochs. Same world, rates around that window, " \
                   "three times longer: is emergence rare or just slow?",
      # Not a sixth question of DESIGN §1.3 but the re-run its first sweep asks for: the
      # four rates around the transitions it found, at three times its budget. The world
      # is the sweep's, so a run here repeats a run there byte for byte up to epoch
      # 20 000; the cadence is raised because 60 000 epochs at the engine's default would
      # post 600 full-world snapshots per run.
      param_grid: {
        "mutation_rate" => (11..14).reverse_each.map { |exponent| 2.0**-exponent },
        "width" => [128],
        "height" => [128],
        "snapshot_every" => [500]
      },
      seeds: (1..10).to_a,
      epochs: 60_000
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
    "energy_per_epoch" => {
      name: "Instruction cost",
      description: "Does paying for computation select for efficient copiers? Every " \
                   "instruction a cell executes draws down an energy budget that refills " \
                   "each epoch, so an interaction halts once its cells have spent theirs " \
                   "and a copier that needs fewer steps finishes more often.",
      # The first arm is 0 — the cost off, the substrate every other sweep ran — so the
      # priced arms are read against a control inside the same experiment. The budgets
      # below it are multiples of one full-length interaction (`max_steps` is 2^13).
      param_grid: {
        "energy_per_epoch" => [0, 2**15, 2**13, 2**11],
        "width" => [128],
        "height" => [128],
        "mutation_rate" => [EMERGENT_MUTATION_RATE]
      },
      # Thirty seeds, not the ten most sweeps run: emergence at 128×128 happens in
      # about one run in ten, and the open-endedness findings read an arm only once two of
      # its runs have emerged.
      seeds: (1..30).to_a,
      epochs: 20_000
    },
    "environmental_structure" => {
      name: "Environmental structure",
      description: "Does a world that varies from place to place raise the complexity " \
                   "plateau the dominant replicator settles at? A structured world runs " \
                   "its mutation rate high in some cells and low in others, so a strategy " \
                   "that pays off in one place need not pay off in the next. The secondary " \
                   "prediction: a heterogeneous world keeps more lineages alive after " \
                   "emergence than a uniform one.",
      # The first arm is the uniform world every earlier sweep ran, so the two structured
      # arms are read against a control inside the same experiment. At amplitude 0.75 the
      # dry cells run at 2^-15 and the wet at about 2^-12.2 — both inside the rate window
      # sweep 1 mapped, so a cell is dry or wet without leaving the window altogether.
      param_grid: {
        "structure" => %w[uniform gradient patchwork],
        "structure_amplitude" => [0.75],
        "width" => [128],
        "height" => [128],
        "mutation_rate" => [EMERGENT_MUTATION_RATE]
      },
      # Thirty seeds, not the ten most sweeps run: emergence at 128×128 happens in
      # about one run in ten, and the open-endedness findings read an arm only once two of
      # its runs have emerged.
      seeds: (1..30).to_a,
      # Ninety for the two structured arms: thirty seeds left each with one emerged run
      # carrying a complexity reading, and the finding reads an arm on two. The control has two.
      seeds_by_arm: { "structure" => { "gradient" => (1..90).to_a, "patchwork" => (1..90).to_a } },
      epochs: 20_000
    },
    "max_tape_len" => {
      name: "Room to grow",
      description: "Is the fixed tape length what makes complexity plateau? With a cap " \
                   "above the length a tape starts at, a head that steps off the end of " \
                   "an interaction claims a fresh byte instead of wrapping, so a tape " \
                   "lengthens through the programs' own copying and the 64-byte ceiling " \
                   "no longer bounds the dominant replicator by construction.",
      # The first arm is the tape length itself — growth off, the fixed-tape world every
      # earlier sweep ran — so the roomy arms are read against a control inside the same
      # experiment. The engine's default tape is 64 bytes; the arms double from it.
      param_grid: {
        "max_tape_len" => [64, 128, 256, 512],
        "tape_len" => [64],
        "width" => [128],
        "height" => [128],
        "mutation_rate" => [EMERGENT_MUTATION_RATE]
      },
      # Thirty seeds, not the ten most sweeps run: emergence at 128×128 happens in
      # about one run in ten, and the complexity-keeps-rising finding reads an arm only
      # once two of its runs have emerged.
      seeds: (1..30).to_a,
      # Ninety for the two arms whose one measured emerged run plateaued above the
      # control's: they need about sixty seeds more each for the second reading the finding
      # reads an arm on, while the control already has two and 512 never emerged.
      seeds_by_arm: { "max_tape_len" => { 128 => (1..90).to_a, 256 => (1..90).to_a } },
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
