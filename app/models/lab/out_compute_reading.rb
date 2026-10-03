# frozen_string_literal: true

module Lab
  # The numbers the out-compute sweep was pre-registered with (`docs/design_record.md`,
  # 2026-10-03, "Out-compute: does an endogenous rule make computing climb, and keep climbing,
  # with nothing paid?"). The sweep reads its parent rule and its four bundles from here and
  # Experiments::OutComputeReadingService reads the rest, so the entry and the code name one
  # set of values. Every per-child rule is the topless-rise entry's, unchanged
  # (Lab::ToplessRiseReading), and through it the logic entry's.
  module OutComputeReading
    # The parents: reach-cap128's eligible parents (radius 4, emerged, terminal world at least
    # half replicators: 108 runs), the PARENT_COUNT with the lowest run ids, each from its
    # terminal world. Their history is fitness-free: none has ever been paid.
    PARENT_COUNT = 54
    PARENTS = {
      "experiment" => Lab.slug_for("reach_cap128"),
      "arms" => [{ "radius" => ReachCap128Reading::TREATMENT_RADIUS }],
      "emerged" => true,
      "instrument" => ReachCap128Reading::INSTRUMENT,
      "share_key" => ReachCap128Reading::SHARE_KEY,
      "min_share" => ReachCap128Reading::PARENT_SHARE,
      "first" => PARENT_COUNT
    }.freeze

    # What every arm switches on, each value named: the initiator economy with theft off, the
    # four-input ladder unpaid, the stack NAND on a 32-byte metabolism tape drawn at 8/8192
    # (×8, a quarter of Meta-stack's 32/8192) from each cell's own tape, every output slot the
    # assay allows read, and the predation pass's take, loss, period and shadow coin.
    #
    # A world every SNAPSHOT_EVERY epochs rather than the runner's 100, for disk (issue #268):
    # pruning keeps one in Runs::PruneSnapshotsService::KEEP_FACTOR, so a child keeps about 22
    # worlds instead of about 100. The offline readings' stored worlds then fall within 5 000
    # epochs of the decile boundaries they are read at, and a restart redoes up to 500 epochs.
    SNAPSHOT_EVERY = 500
    BUNDLE = {
      "energy_payer" => "initiator", "energy_influx" => 1024, "energy_stock_cap" => 65_536, "steal_amount" => 0,
      "tasks" => "logic4", "task_reward" => 0, "logic_nand" => "stack",
      "meta_len" => 32, "meta_rate" => 0.0009765625, "meta_draw" => "isa", "meta_seed" => "own_tape",
      "task_max_outputs" => 16,
      "predation_transfer" => 8192, "predation_loss" => 0.5, "predation_every" => 8, "predation_shadow_p" => 0.3,
      "snapshot_every" => SNAPSHOT_EVERY
    }.freeze
    OUT_COMPUTE_BUNDLE = BUNDLE.merge("predation" => "subset_class").freeze
    EQUAL_BUNDLE = BUNDLE.merge("predation" => "equal").freeze
    SHADOW_BUNDLE = BUNDLE.merge("predation" => "shadow").freeze
    # Predation off moves nothing, whatever the transfer; the 16 slots keep its depth readings
    # comparable with the other arms'.
    NONE_BUNDLE = BUNDLE.merge("predation" => "off").freeze

    SEEDS = [6001].freeze
    EPOCHS = 100_000
    PRIORITY = 40

    # The label (DESIGN.md §1.4): a run whose energy moves by what its tapes compute imports a
    # machine (the NAND, its stack semantics, the metabolism tape, the emit op and cap, the
    # input bytes and the predation rule), but no objective. Never pooled with plain Soup.
    LABEL = "imports a machine, not an objective"

    # A run is predatory where its pass runs: a relation chosen and a transfer to move
    # (`Params::predation_active` in the engine). The engine reads the relation only as a
    # string and the transfer only as a JSON number, so anything else is no predation. Run's
    # `predatory` scope is the same rule in SQL; keep the two in step.
    PREDATION_KEY = "predation"
    TRANSFER_KEY = "predation_transfer"
    OFF = "off"

    def self.predatory_run?(params)
      relation = params[PREDATION_KEY]
      transfer = params[TRANSFER_KEY]
      relation.is_a?(String) && relation != OFF && transfer.is_a?(Numeric) && transfer.positive?
    end

    SETTLING_WINDOW = ToplessRiseReading::SETTLING_WINDOW
    EXTINCT_SHARE = ToplessRiseReading::EXTINCT_SHARE
    MIN_DECILE_SAMPLES = ToplessRiseReading::MIN_DECILE_SAMPLES
    SIGN_TEST_LEVEL = ToplessRiseReading::SIGN_TEST_LEVEL
    PERSISTENCE_RUN = ToplessRiseReading::PERSISTENCE_RUN
    RISE_DECILE = ToplessRiseReading::RISE_DECILE
    DECILES = ToplessRiseReading::DECILES
    RISE_STEP = ToplessRiseReading::RISE_STEP
    CEILING_DEPTH = ToplessRiseReading::CEILING_DEPTH
    KEPT_SUFFIX = ToplessRiseReading::KEPT_SUFFIX
    DEPTH_KEY = ToplessRiseReading::DEPTH_KEY
    CLASSES_KEY = ToplessRiseReading::CLASSES_KEY
    SHARE_KEY = DescendantReading::SHARE_KEY

    # Descriptive, as last-decile medians: what the pass did and what the tapes compute.
    DESCRIPTIVE_KEYS = %w[repertoire_mean silent_share predation_rate predation_relation_rate].freeze

    # McShea's minimum, descriptive and offline (`research/landscape` on the fifth-decile and
    # last stored worlds): this percentile of per-cell max depth among the cells computing
    # anything, on the topless-rise entry's six fixed case sets over TASK_MAX_OUTPUTS slots.
    MINIMUM_PERCENTILE = 10
    TASK_MAX_OUTPUTS = BUNDLE.fetch("task_max_outputs")
    # H-code, descriptive and offline: the topless-rise entry's method, unchanged.
    CODE_CASE_SETS = ToplessRiseReading::CODE_CASE_SETS
    CODE_CASE_SEED = ToplessRiseReading::CODE_CASE_SEED
    CODE_BEARING_SYMBOLS = ToplessRiseReading::CODE_BEARING_SYMBOLS
    CODE_NEW_BYTES = ToplessRiseReading::CODE_NEW_BYTES

    TREATMENT_NAMES = { out_compute: "out-compute", equal: "equal", shadow: "shadow", none: "none" }.freeze

    # Each test: the treated arm, the control, and what a pair compares. `level` the
    # last-decile median `logic_depth_max`, the higher favoured; `depth` and `classes` the rise
    # rule on `logic_depth_max` and on `logic_depth_classes`, the side that rises alone favoured.
    HYPOTHESES = {
      "H-endogenous" => %i[out_compute none level],
      "H-ratchet" => %i[out_compute equal level],
      "H-driven" => %i[out_compute shadow level],
      "H-rise-unassisted" => %i[out_compute none depth],
      "H-repertoire" => %i[out_compute none classes]
    }.freeze

    CHILD_COLUMNS = %w[
      run_id parent seed treatment status settled_relapse_epoch extinct descent_depth first_half_held
      fifth_decile_depth rise_bar last_decile_depth rises ceilinged deepest_held deepest_held_epoch late_depths
      reached_floor descent_classes classes_bar last_decile_classes classes_rise repertoire_mean silent_share
      predation_rate predation_relation_rate replicator_share
    ].freeze
    ARM_COLUMNS = %w[
      treatment children finished settled_relapses extinct level_measured rises classes_rises ceilinged reached_floor
      median_last_decile_depth
    ].freeze
    # The Experiments::OutComputeReadingService::ChildRow predicate each count after
    # `children` reads.
    ARM_COUNTS = %i[finished? settled_relapse? extinct? level_measured? rises? classes_rise? ceilinged?
                    reached_floor?].freeze
    TEST_COLUMNS = LogicReading::TEST_COLUMNS
    AGREEMENT_COLUMNS = LogicReading::AGREEMENT_COLUMNS

    # The arm a child runs under, read off its relation; nil for a relation no arm runs.
    def self.treatment_key(params)
      { "subset_class" => :out_compute, "equal" => :equal, "shadow" => :shadow, OFF => :none }
        .fetch(params.fetch(PREDATION_KEY, OFF), nil)
    end
  end
end
